import { prisma } from '../../../config/prisma';
import { geminiProvider } from '../../ai/gemini.provider';

export class BookQuestionClassificationService {
  private static instance: BookQuestionClassificationService;

  private constructor() {}

  public static getInstance(): BookQuestionClassificationService {
    if (!BookQuestionClassificationService.instance) {
      BookQuestionClassificationService.instance = new BookQuestionClassificationService();
    }
    return BookQuestionClassificationService.instance;
  }

  /**
   * Classifies extracted questions under each topic to their most specific subtopic.
   */
  public async classifyQuestionsForBook(
    bookId: string,
    onProgress?: (progress: number, classifiedCount: number) => Promise<void>
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
      data: { status: 'CLASSIFYING_QUESTIONS' },
    });

    let totalClassified = 0;
    const topics = bookSource.subject.topics;

    for (let tIdx = 0; tIdx < topics.length; tIdx++) {
      const topic = topics[tIdx];
      const subtopics = topic.subtopics;

      if (subtopics.length <= 1) {
        // Only 1 subtopic; all questions belong to it
        continue;
      }

      // Fetch questions under this topic
      const questions = await prisma.question.findMany({
        where: {
          subjectId: bookSource.subject.id,
          topicId: topic.id,
        },
        select: { id: true, externalKey: true, prompt: true, pattern: true },
      });

      if (questions.length === 0) continue;

      const subtopicCandidatesSummary = subtopics
        .map((s) => `- ID: ${s.id} | Name: "${s.name}" | Description: "${s.description || ''}"`)
        .join('\n');

      // Classify in batches of 15 questions to prevent prompt bloat
      const BATCH_SIZE = 15;
      for (let i = 0; i < questions.length; i += BATCH_SIZE) {
        const batch = questions.slice(i, i + BATCH_SIZE);

        const prompt = `
Topic: "${topic.name}"

Available Subtopics:
${subtopicCandidatesSummary}

Questions to Classify:
${batch.map((q, idx) => `[Q-${idx + 1}] ID: ${q.id}, Key: ${q.externalKey}, Pattern: ${q.pattern || 'N/A'}\nPrompt: ${q.prompt}`).join('\n\n')}

Assign each question to the most appropriate subtopic ID from the list above.
`.trim();

        const schema = {
          type: 'object',
          properties: {
            classifications: {
              type: 'array',
              items: {
                type: 'object',
                properties: {
                  questionId: { type: 'string' },
                  subtopicId: { type: 'string' },
                  confidence: { type: 'number' },
                },
                required: ['questionId', 'subtopicId'],
              },
            },
          },
          required: ['classifications'],
        };

        try {
          const response = await geminiProvider.generateStructuredContent<{
            classifications: Array<{ questionId: string; subtopicId: string; confidence?: number }>;
          }>({
            systemInstruction: 'You are a precise educational taxonomy classifier. Match questions to subtopics based on mathematical concept overlap.',
            prompt,
            responseSchema: schema,
            timeoutMs: 45000,
          });

          if (response.classifications && Array.isArray(response.classifications)) {
            for (const item of response.classifications) {
              const targetSubtopic = subtopics.find((s) => s.id === item.subtopicId);
              if (targetSubtopic) {
                await prisma.question.update({
                  where: { id: item.questionId },
                  data: { subtopicId: targetSubtopic.id },
                });
                totalClassified++;
              }
            }
          }
        } catch (err: any) {
          console.warn(`[BookQuestionClassificationService] Batch classification warning: ${err.message}`);
        }

        if (onProgress) {
          const prog = (tIdx + (i + batch.length) / questions.length) / topics.length;
          await onProgress(prog, totalClassified);
        }
      }
    }

    console.log(`[BookQuestionClassificationService] Finished classifying questions across all topics (${totalClassified} mapped).`);
    return totalClassified;
  }
}

export const bookQuestionClassificationService = BookQuestionClassificationService.getInstance();
