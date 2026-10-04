import crypto from 'crypto';
import { prisma } from '../../../config/prisma';
import { geminiProvider } from '../../ai/gemini.provider';
import { pdfParserService } from './pdf-parser.service';
import { ScriptValidator } from '../../lesson/engines/script-validator';
import { questionHydrationService } from '../../lesson/services/question-hydration.service';
import { scriptCacheService } from '../../lesson/services/script-cache.service';
import {
  BOOK_SCRIPT_GENERATION_SYSTEM_INSTRUCTION,
  SCRIPT_DEFINITION_JSON_SCHEMA,
} from '../prompts/book-script-generation.prompt';
import { ScriptDefinition } from '../../lesson/interfaces/script-dsl.interface';
import { DiscoveredSubtopicCandidate } from '../types/book-ingestion.types';

export class BookScriptGenerationService {
  private static instance: BookScriptGenerationService;

  private constructor() {}

  public static getInstance(): BookScriptGenerationService {
    if (!BookScriptGenerationService.instance) {
      BookScriptGenerationService.instance = new BookScriptGenerationService();
    }
    return BookScriptGenerationService.instance;
  }

  /**
   * Generates, validates, hydrates, and stores a LessonScript for a specific subtopic.
   */
  public async generateScriptForSubtopic(
    bookId: string,
    subjectId: string,
    topicId: string,
    subtopicId: string,
    subtopicMeta?: DiscoveredSubtopicCandidate
  ): Promise<any> {
    const subtopic = await prisma.subtopic.findUnique({
      where: { id: subtopicId },
      include: {
        topic: true,
      },
    });

    if (!subtopic) {
      throw new Error(`Subtopic not found: ${subtopicId}`);
    }

    // 1. Fetch available questions for this subtopic to reference in interactive cards
    const questions = await prisma.question.findMany({
      where: { subtopicId: subtopic.id },
      select: { id: true, externalKey: true, prompt: true, difficulty: true },
      take: 6,
      orderBy: { difficulty: 'asc' },
    });

    const questionReferenceList = questions
      .map((q) => `- Key: "${q.externalKey}" | Prompt: "${q.prompt.slice(0, 80)}..." | Difficulty: ${q.difficulty}`)
      .join('\n');

    // 2. Fetch relevant source pages
    const startPage = subtopicMeta?.startPage || 1;
    const endPage = subtopicMeta?.endPage || Math.min(startPage + 4, 900);
    const sourceText = await pdfParserService.getPagesText(bookId, startPage, endPage);

    const prompt = `
Subject: ${subjectId}
Topic: ${subtopic.topic.name}
Subtopic: ${subtopic.name}
Subtopic ID: ${subtopic.id}
Target Teaching Duration: ${subtopic.teachingMinutes || 10} minutes

Source Textbook Content (Pages ${startPage}-${endPage}):
${sourceText || 'Cover the foundational principles and speed shortcuts for this subtopic.'}

Available Subtopic Questions to Reference:
${questionReferenceList || 'No pre-extracted questions; create interactive instruction without questionReference.'}

Generate an interactive lesson script in the AptiQu Script DSL format.
The scriptId must be "script-${subtopic.slug || subtopic.id}".
`.trim();

    const response = await geminiProvider.generateStructuredContent<ScriptDefinition>({
      systemInstruction: BOOK_SCRIPT_GENERATION_SYSTEM_INSTRUCTION,
      prompt,
      responseSchema: SCRIPT_DEFINITION_JSON_SCHEMA,
      timeoutMs: 90000,
    });

    // 3. Normalize & Validate DSL Structure
    const normalized = scriptCacheService.normalizeScriptDefinition(response, subtopic.name);
    normalized.scriptId = `script-${subtopic.slug || subtopic.id}`;
    normalized.metadata.subjectId = subjectId;
    normalized.metadata.topicId = topicId;
    normalized.metadata.subtopicId = subtopic.id;

    const validation = ScriptValidator.validate(normalized);
    if (!validation.valid) {
      console.warn(
        `[BookScriptGenerationService] Script validation warnings for ${subtopic.id}:`,
        validation.errors.map((e) => e.message).join(', ')
      );
    }

    // 4. Hydrate referenced questions
    let hydratedDef = normalized;
    try {
      hydratedDef = await questionHydrationService.hydrateScriptDefinition(normalized);
    } catch (err: any) {
      console.warn(
        `[BookScriptGenerationService] Hydration notice for ${subtopic.id}: ${err.message}. Saving baseline script.`
      );
    }

    // 5. Checksum & Persistence
    const slug = normalized.scriptId;
    const definitionString = JSON.stringify(hydratedDef);
    const checksum = crypto.createHash('sha256').update(definitionString).digest('hex');

    const result = await prisma.$transaction(async (tx) => {
      let script = await tx.lessonScript.findUnique({ where: { slug } });

      if (!script) {
        script = await tx.lessonScript.create({
          data: {
            slug,
            title: hydratedDef.metadata?.title || `${subtopic.name} Lesson`,
            subjectId,
            topicId,
            subtopicId: subtopic.id,
            status: 'DRAFT', // Remains DRAFT until book published
          },
        });
      } else {
        await tx.lessonScript.update({
          where: { id: script.id },
          data: {
            title: hydratedDef.metadata?.title || script.title,
            status: 'DRAFT',
          },
        });
      }

      // Latest version
      const latestVer = await tx.lessonScriptVersion.findFirst({
        where: { scriptId: script.id },
        orderBy: { versionNumber: 'desc' },
      });
      const nextVerNumber = (latestVer?.versionNumber || 0) + 1;

      const version = await tx.lessonScriptVersion.create({
        data: {
          scriptId: script.id,
          versionNumber: nextVerNumber,
          definition: hydratedDef as any,
          checksum,
          status: 'DRAFT',
        },
      });

      await tx.lessonScript.update({
        where: { id: script.id },
        data: { publishedVersionId: version.id },
      });

      return { script, version };
    });

    console.log(`[BookScriptGenerationService] Created LessonScript "${slug}" for subtopic "${subtopic.name}".`);
    return result;
  }

  /**
   * Generates lesson scripts for all subtopics under a book.
   */
  public async generateAllScriptsForBook(
    bookId: string,
    onProgress?: (progress: number, completedCount: number, totalCount: number) => Promise<void>
  ): Promise<number> {
    const bookSource = await prisma.bookSource.findUnique({
      where: { id: bookId },
      include: {
        subject: {
          include: {
            topics: {
              include: {
                subtopics: { orderBy: { sequence: 'asc' } },
              },
            },
          },
        },
      },
    });

    if (!bookSource) {
      throw new Error(`BookSource not found: ${bookId}`);
    }

    await prisma.bookSource.update({
      where: { id: bookId },
      data: { status: 'GENERATING_SCRIPTS' },
    });

    const allSubtopics: Array<{ topicId: string; subtopic: any }> = [];
    for (const topic of bookSource.subject.topics) {
      for (const sub of topic.subtopics) {
        allSubtopics.push({ topicId: topic.id, subtopic: sub });
      }
    }

    const totalSubtopics = allSubtopics.length;
    let completedCount = 0;

    for (let i = 0; i < totalSubtopics; i++) {
      const item = allSubtopics[i];
      try {
        await this.generateScriptForSubtopic(
          bookId,
          bookSource.subject.id,
          item.topicId,
          item.subtopic.id
        );
        completedCount++;
      } catch (err: any) {
        console.error(
          `[BookScriptGenerationService] Error generating script for subtopic ${item.subtopic.id}:`,
          err.message
        );
      }

      if (onProgress) {
        await onProgress((i + 1) / totalSubtopics, completedCount, totalSubtopics);
      }
    }

    console.log(`[BookScriptGenerationService] Finished generating ${completedCount}/${totalSubtopics} lesson scripts.`);
    return completedCount;
  }
}

export const bookScriptGenerationService = BookScriptGenerationService.getInstance();
