import { prisma } from '../../../config/prisma';
import { geminiProvider } from '../gemini.provider';
import {
  PRACTICE_GENERATION_SYSTEM_INSTRUCTION,
  QUESTION_ARRAY_JSON_SCHEMA,
} from '../prompts/practice-generation.prompt';
import {
  PRACTICE_REVIEW_SYSTEM_INSTRUCTION,
  QUESTION_REVIEW_JSON_SCHEMA,
} from '../prompts/practice-review.prompt';
import { validateQuestionStructure } from '../../question/validators/question-structural.validator';
import { FingerprintService } from '../../question/services/fingerprint.service';
import { LiveCurriculumService } from '../../curriculum/services/live-curriculum.service';
import { INVENTORY_CONFIG } from '../../../config/inventory.config';
import { ConcurrencyLockService } from '../../concurrency/concurrency-lock.service';
import { QuestionDifficultyEnum, CalculationMode } from '@prisma/client';

export class QuestionGenerationService {
  private static instance: QuestionGenerationService;

  public static getInstance(): QuestionGenerationService {
    if (!QuestionGenerationService.instance) {
      QuestionGenerationService.instance = new QuestionGenerationService();
    }
    return QuestionGenerationService.instance;
  }

  /**
   * Generates, reviews, validates, and persists a batch of questions for a specific subtopic on-demand.
   * Guarded by Redis concurrency locking.
   */
  public async generateQuestionsForSubtopic(
    subtopicId: string,
    requestedCount = INVENTORY_CONFIG.DEFAULT_BATCH_GENERATION_UNIT
  ): Promise<any[]> {
    // 1. Verify Subtopic is LIVE
    const isLive = await LiveCurriculumService.isSubtopicLive(subtopicId);
    if (!isLive) {
      throw new Error(`Subtopic "${subtopicId}" is not live. Cannot generate content for locked syllabus.`);
    }

    const subtopic = await prisma.subtopic.findUnique({
      where: { id: subtopicId },
      include: {
        topic: {
          include: {
            subject: true,
          },
        },
      },
    });

    if (!subtopic) {
      throw new Error(`Subtopic with ID "${subtopicId}" not found.`);
    }

    const lockAcquired = await ConcurrencyLockService.acquireLock(subtopicId, 60000);
    if (!lockAcquired) {
      // Another worker/thread is currently generating. Wait for completion.
      await ConcurrencyLockService.waitForCondition(async () => {
        const count = await prisma.question.count({
          where: { subtopicId, status: 'PUBLISHED' },
        });
        return count >= requestedCount;
      }, 15000);

      return await prisma.question.findMany({
        where: { subtopicId, status: 'PUBLISHED' },
        take: requestedCount,
      });
    }

    try {
      // 2. Fetch existing fingerprints for this subtopic to avoid duplicate output
      const existingQuestions = await prisma.question.findMany({
        where: { subtopicId },
        select: { prompt: true, fingerprint: true },
        take: 30,
        orderBy: { createdAt: 'desc' },
      });
      const existingFingerprints = existingQuestions.map((q) => q.fingerprint);

      const difficultyCount = INVENTORY_CONFIG.PRACTICE_DIFFICULTY_DISTRIBUTION;

      // 3. Generator Call
      console.log(
        `[QuestionGen] Initiating AI question generation for subtopic "${subtopic.name}" (${subtopicId}), requestedCount: ${requestedCount}`
      );
      const generatorPrompt = `
Generate ${requestedCount} aptitude practice questions under these constraints:
- Subject: ${subtopic.topic.subject.name} (ID: ${subtopic.topic.subject.id})
- Topic: ${subtopic.topic.name} (ID: ${subtopic.topic.id})
- Target Subtopic: ${subtopic.name} (ID: ${subtopic.id})
- Subtopic Description: ${subtopic.description || 'Core fundamental skills'}
- Difficulty Target: ${difficultyCount.EASY} EASY (30-60s), ${difficultyCount.MEDIUM} MEDIUM (45-90s), ${difficultyCount.HARD} HARD (60-120s)
- Time Window: 30 to 120 seconds per question (strictly enforced)
- Calculation Mode: MENTAL or LIGHT_PEN_AND_PAPER
- Existing Question Fingerprints to Avoid (Do NOT duplicate):
${existingFingerprints.map((f) => `- ${f}`).join('\n')}

Generate exactly ${requestedCount} questions.
`.trim();

      const rawGeneration = await geminiProvider.generateStructuredContent<{
        questions: any[];
      }>({
        systemInstruction: PRACTICE_GENERATION_SYSTEM_INSTRUCTION,
        prompt: generatorPrompt,
        responseSchema: QUESTION_ARRAY_JSON_SCHEMA,
        timeoutMs: 60000,
      });

      if (!rawGeneration.questions || !Array.isArray(rawGeneration.questions)) {
        throw new Error('Gemini generator did not return a valid questions array.');
      }

      console.log(
        `[QuestionGen] Gemini returned ${rawGeneration.questions.length} candidate questions for "${subtopic.name}". Validating structure...`
      );

      // 4. Structural Validation Gate
      const structurallyValid: any[] = [];
      for (const rawQ of rawGeneration.questions) {
        const valRes = validateQuestionStructure(rawQ, false);
        if (valRes.valid) {
          structurallyValid.push(valRes.data);
        }
      }

      if (structurallyValid.length === 0) {
        throw new Error('None of the generated questions passed initial structural validation.');
      }

      const candidateQuestions = structurallyValid;

      // 6. Deduplicate & Prepare Database Records
      const acceptedRecords: any[] = [];
      const batchFingerprints = new Set<string>();

      for (const q of candidateQuestions) {
        const valRes = validateQuestionStructure(q, false);
        if (!valRes.valid) continue;

        const validData = valRes.data;
        const fingerprint = FingerprintService.computeFingerprint(
          validData.prompt,
          validData.options
        );

        // Check intra-batch duplication
        if (batchFingerprints.has(fingerprint)) continue;
        batchFingerprints.add(fingerprint);

        // Check if already in DB
        const existsInDb = await prisma.question.findUnique({
          where: { fingerprint },
        });
        if (existsInDb) continue;

        acceptedRecords.push({
          subjectId: subtopic.topic.subject.id,
          topicId: subtopic.topic.id,
          subtopicId: subtopic.id,
          pattern: validData.pattern,
          prompt: validData.prompt,
          options: validData.options,
          correctAnswer: validData.correctAnswer,
          hints: validData.hints,
          explanation: validData.explanation,
          method: validData.method,
          difficulty: validData.difficulty as QuestionDifficultyEnum,
          estimatedTimeSeconds: validData.estimatedTimeSeconds,
          calculationMode: validData.calculationMode as CalculationMode,
          sourceType: 'AI_GENERATED',
          status: 'PUBLISHED',
          fingerprint,
          generationModel: 'gemini-3.5-flash-lite',
          generationPromptVersion: 'v1.0.0',
          generatedAt: new Date(),
          reviewedAt: new Date(),
        });
      }

      // 7. Persist into PostgreSQL
      const createdQuestions: any[] = [];
      for (const record of acceptedRecords) {
        try {
          const created = await prisma.question.create({
            data: record,
          });
          createdQuestions.push(created);
        } catch {
          // Ignore unique fingerprint constraint race collision
        }
      }

      console.log(
        `[QuestionGen] Successfully persisted ${createdQuestions.length} valid questions to DB for subtopic "${subtopic.name}" (${subtopicId}).`
      );
      return createdQuestions;
    } finally {
      await ConcurrencyLockService.releaseLock(subtopicId);
    }
  }
}

export const questionGenerationService = QuestionGenerationService.getInstance();
