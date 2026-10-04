import crypto from 'crypto';
import { prisma } from '../../../config/prisma';
import { geminiProvider } from '../../ai/gemini.provider';
import { pdfParserService } from './pdf-parser.service';
import { FingerprintService } from '../../question/services/fingerprint.service';
import {
  BOOK_QUESTION_EXTRACTION_SYSTEM_INSTRUCTION,
  BOOK_QUESTION_ARRAY_JSON_SCHEMA,
} from '../prompts/book-question-extraction.prompt';
import { ExtractedQuestionCandidate, DetectedTopicCandidate } from '../types/book-ingestion.types';
import { QuestionDifficultyEnum, CalculationMode, PreferredSolution } from '@prisma/client';

export class BookQuestionExtractionService {
  private static instance: BookQuestionExtractionService;

  private constructor() {}

  public static getInstance(): BookQuestionExtractionService {
    if (!BookQuestionExtractionService.instance) {
      BookQuestionExtractionService.instance = new BookQuestionExtractionService();
    }
    return BookQuestionExtractionService.instance;
  }

  /**
   * Extracts questions from a page range for a given topic.
   */
  public async extractQuestionsFromPageRange(
    bookId: string,
    topicCandidate: DetectedTopicCandidate,
    dbTopicId: string,
    startPage: number,
    endPage: number,
    startingSeq: number
  ): Promise<any[]> {
    const bookSource = await prisma.bookSource.findUnique({
      where: { id: bookId },
      include: { subject: true },
    });

    if (!bookSource) {
      throw new Error(`BookSource not found: ${bookId}`);
    }

    const sourceText = await pdfParserService.getPagesText(bookId, startPage, endPage);
    if (!sourceText.trim()) {
      return [];
    }

    const prompt = `
Book Title: ${bookSource.title}
Topic: ${topicCandidate.name} (Code: ${topicCandidate.code})
Pages: ${startPage} to ${endPage}

Source Content:
${sourceText}

Extract all practice questions, worked examples, and problem sets from these pages. Ensure each question has full options (A, B, C, D), correct answer, and clear step-by-step explanations.
`.trim();

    const response = await geminiProvider.generateStructuredContent<{
      questions: any[];
    }>({
      systemInstruction: BOOK_QUESTION_EXTRACTION_SYSTEM_INSTRUCTION,
      prompt,
      responseSchema: BOOK_QUESTION_ARRAY_JSON_SCHEMA,
      timeoutMs: 90000,
    });

    if (!response.questions || !Array.isArray(response.questions) || response.questions.length === 0) {
      return [];
    }

    console.log(
      `[BookQuestionExtractionService] Extracted ${response.questions.length} candidates from pages ${startPage}-${endPage}. Validating and persisting...`
    );

    // Fetch existing subtopics for this topic
    const subtopics = await prisma.subtopic.findMany({
      where: { topicId: dbTopicId },
      orderBy: { sequence: 'asc' },
    });

    const defaultSubtopicId = subtopics[0]?.id || `${topicCandidate.code.toLowerCase()}-01-fundamentals`;

    const createdRecords: any[] = [];
    let currentSeq = startingSeq;

    for (const q of response.questions) {
      const promptText = String(q.prompt || '').trim();
      if (!promptText || !Array.isArray(q.options) || q.options.length < 2) {
        continue;
      }

      // Normalize options
      const options = q.options.map((opt: any, idx: number) => {
        const letter = (['A', 'B', 'C', 'D'][idx] || 'A') as 'A' | 'B' | 'C' | 'D';
        return {
          id: (opt.id || letter) as 'A' | 'B' | 'C' | 'D',
          text: String(opt.text || opt.label || '').trim(),
        };
      });

      const correctAnswer = (['A', 'B', 'C', 'D'].includes(q.correctAnswer) ? q.correctAnswer : 'A') as string;
      const fingerprint = FingerprintService.computeFingerprint(promptText, options);

      // Check duplicate in DB
      const existing = await prisma.question.findUnique({
        where: { fingerprint },
      });
      if (existing) {
        continue;
      }

      // Generate collision-proof externalKey scoped to topic, book, and sequence
      const bookPrefix = bookSource.id.replace(/-/g, '').slice(0, 6);
      let externalKey = `${topicCandidate.code.toLowerCase()}-q-${String(currentSeq).padStart(3, '0')}-${bookPrefix}`;
      currentSeq++;

      // Verify key doesn't collide with any existing question in DB
      let uniqueKey = externalKey;
      let collisionSuffix = 1;
      while (await prisma.question.findUnique({ where: { externalKey: uniqueKey } })) {
        uniqueKey = `${externalKey}-${collisionSuffix++}`;
      }

      const difficulty = (['EASY', 'MEDIUM', 'HARD'].includes(q.difficulty) ? q.difficulty : 'MEDIUM') as QuestionDifficultyEnum;
      const calculationMode = (['MENTAL', 'LIGHT_PEN_AND_PAPER', 'PEN_AND_PAPER'].includes(q.calculationMode)
        ? q.calculationMode
        : 'LIGHT_PEN_AND_PAPER') as CalculationMode;

      const preferredSolution = q.preferredSolution === 'ALTERNATIVE'
        ? PreferredSolution.ALTERNATIVE
        : q.preferredSolution === 'BOOK'
        ? PreferredSolution.BOOK
        : null;

      const questionData = {
        subjectId: bookSource.subject.id,
        topicId: dbTopicId,
        subtopicId: defaultSubtopicId, // Initially default; classified in Stage 5
        externalKey: uniqueKey,
        pattern: q.pattern || 'STANDARD_MCQ',
        prompt: promptText,
        options: options as any,
        correctAnswer,
        hints: Array.isArray(q.hints) ? q.hints : [],
        explanation: String(q.explanation || 'Step-by-step solution derived from source.'),
        method: String(q.method || 'Standard Method'),
        difficulty,
        estimatedTimeSeconds: Number(q.estimatedTimeSeconds) || 60,
        calculationMode,
        sourceType: 'MANUAL' as const,
        status: 'DRAFT' as const, // Remains DRAFT until published
        generationMethod: 'AI_EXTRACTED' as const,
        sourceBook: bookSource.title,
        sourceEdition: bookSource.edition,
        sourceChapter: topicCandidate.name,
        sourcePageRange: q.sourcePageNumber ? `p. ${q.sourcePageNumber}` : `pp. ${startPage}-${endPage}`,
        pyq: q.pyq ? String(q.pyq).trim() : null,
        alternativeExplanation: q.alternativeExplanation ? String(q.alternativeExplanation).trim() : null,
        preferredSolution,
        preferredReason: q.preferredReason ? String(q.preferredReason).trim() : null,
        fingerprint,
        generatedAt: new Date(),
      };

      try {
        const record = await prisma.question.create({
          data: questionData,
        });
        createdRecords.push(record);
      } catch (err: any) {
        // Fallback with crypto random hash if concurrent collision occurred
        if (err.message?.includes('external_key') || err.message?.includes('Unique constraint')) {
          try {
            const fallbackKey = `${uniqueKey}-${crypto.randomBytes(3).toString('hex')}`;
            const fallbackRecord = await prisma.question.create({
              data: {
                ...questionData,
                externalKey: fallbackKey,
              },
            });
            createdRecords.push(fallbackRecord);
          } catch (retryErr: any) {
            console.warn(`[BookQuestionExtractionService] Skipping question due to persistent DB error: ${retryErr.message}`);
          }
        } else {
          console.warn(`[BookQuestionExtractionService] Skipping question due to DB insert error: ${err.message}`);
        }
      }
    }

    return createdRecords;
  }

  /**
   * Extracts all questions across all topics for the book in chunks of 5 pages.
   */
  public async extractAllQuestionsForBook(
    bookId: string,
    onProgress?: (progress: number, extractedCount: number) => Promise<void>
  ): Promise<number> {
    const bookSource = await prisma.bookSource.findUnique({
      where: { id: bookId },
      include: {
        subject: {
          include: {
            topics: true,
          },
        },
      },
    });

    if (!bookSource) {
      throw new Error(`BookSource not found: ${bookId}`);
    }

    await prisma.bookSource.update({
      where: { id: bookId },
      data: { status: 'EXTRACTING_QUESTIONS' },
    });

    const metadata = (bookSource.metadata as any) || {};
    const detectedTopics: DetectedTopicCandidate[] = metadata.detectedTopics || [];

    let totalExtracted = 0;
    const CHUNK_PAGES = 5;

    for (let tIdx = 0; tIdx < detectedTopics.length; tIdx++) {
      const topic = detectedTopics[tIdx];
      const dbTopic = bookSource.subject.topics.find(
        (t) => t.name.toLowerCase() === topic.name.toLowerCase() || t.slug.includes(topic.suggestedSlug)
      );
      const dbTopicId = dbTopic ? dbTopic.id : `${bookSource.subject.slug}-${topic.suggestedSlug}`;

      // Resume sequence count from existing questions in database for this topic
      const existingTopicQCount = await prisma.question.count({
        where: {
          subjectId: bookSource.subject.id,
          topicId: dbTopicId,
        },
      });
      let topicQuestionSeq = existingTopicQCount + 1;

      for (let p = topic.startPage; p <= topic.endPage; p += CHUNK_PAGES) {
        const chunkEnd = Math.min(p + CHUNK_PAGES - 1, topic.endPage);
        const pageRangeStr = `pp. ${p}-${chunkEnd}`;

        // Skip AI call if this page chunk already has extracted questions in DB
        const existingInChunk = await prisma.question.count({
          where: {
            subjectId: bookSource.subject.id,
            topicId: dbTopicId,
            sourcePageRange: { in: [pageRangeStr, `p. ${p}`] },
          },
        });

        if (existingInChunk > 0) {
          console.log(
            `[BookQuestionExtractionService] Pages ${p}-${chunkEnd} for topic "${topic.name}" already have ${existingInChunk} questions. Skipping AI call.`
          );
          totalExtracted += existingInChunk;
          topicQuestionSeq += existingInChunk;
          continue;
        }

        try {
          const chunkQuestions = await this.extractQuestionsFromPageRange(
            bookId,
            topic,
            dbTopicId,
            p,
            chunkEnd,
            topicQuestionSeq
          );
          topicQuestionSeq += Math.max(chunkQuestions.length, 1);
          totalExtracted += chunkQuestions.length;

          if (onProgress) {
            const overallProg = (tIdx + (p - topic.startPage) / (topic.endPage - topic.startPage + 1)) / detectedTopics.length;
            await onProgress(overallProg, totalExtracted);
          }
        } catch (err: any) {
          console.error(
            `[BookQuestionExtractionService] Error extracting from pages ${p}-${chunkEnd} for topic "${topic.name}":`,
            err.message
          );
          topicQuestionSeq += 5; // ensure sequence advances even on failure
        }

        // Pacing delay between chunks to ensure smooth token distribution
        await new Promise((resolve) => setTimeout(resolve, 1500));
      }
    }

    await prisma.bookSource.update({
      where: { id: bookId },
      data: { status: 'QUESTIONS_EXTRACTED' },
    });

    console.log(`[BookQuestionExtractionService] Completed question extraction: ${totalExtracted} questions created.`);
    return totalExtracted;
  }
}

export const bookQuestionExtractionService = BookQuestionExtractionService.getInstance();
