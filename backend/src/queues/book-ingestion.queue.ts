import { Queue, Worker, Job } from 'bullmq';
import { ENV } from '../config/env';
import { prisma } from '../config/prisma';
import { pdfParserService } from '../modules/admin/services/pdf-parser.service';
import { topicDiscoveryService } from '../modules/admin/services/topic-discovery.service';
import { subtopicDiscoveryService } from '../modules/admin/services/subtopic-discovery.service';
import { bookQuestionExtractionService } from '../modules/admin/services/book-question-extraction.service';
import { bookQuestionClassificationService } from '../modules/admin/services/book-question-classification.service';
import { bookScriptGenerationService } from '../modules/admin/services/book-script-generation.service';
import { contentValidationService } from '../modules/admin/services/content-validation.service';

function parseRedisConnection(urlStr: string) {
  try {
    const url = new URL(urlStr);
    return {
      host: url.hostname,
      port: parseInt(url.port || '6379', 10),
      password: url.password || undefined,
      maxRetriesPerRequest: null,
      enableOfflineQueue: false,
      retryStrategy: (times: number) => {
        if (times > 3) return 30000;
        return Math.min(times * 1000, 5000);
      },
    };
  } catch {
    return {
      host: '127.0.0.1',
      port: 6379,
      maxRetriesPerRequest: null,
      enableOfflineQueue: false,
      retryStrategy: (times: number) => {
        if (times > 3) return 30000;
        return Math.min(times * 1000, 5000);
      },
    };
  }
}

const connection = parseRedisConnection(ENV.REDIS_URL);

export const BOOK_INGESTION_QUEUE_NAME = 'book-ingestion';

export const bookIngestionQueue = new Queue(BOOK_INGESTION_QUEUE_NAME, {
  connection,
  defaultJobOptions: {
    attempts: 1, // Never automatically loop-retry on failure; wait for explicit user action
    removeOnComplete: true,
    removeOnFail: false,
  },
});

/**
 * Helper to update stage progress in BookProcessingJob
 */
async function updateJobStageProgress(
  bookId: string,
  stage: any,
  progress: number,
  totalItems = 0,
  completedItems = 0,
  failedItems = 0,
  details = {}
) {
  try {
    const existing = await prisma.bookProcessingJob.findFirst({
      where: { bookId, stage },
      orderBy: { startedAt: 'desc' },
    });

    if (existing) {
      await prisma.bookProcessingJob.update({
        where: { id: existing.id },
        data: {
          stageProgress: progress,
          totalItems,
          completedItems,
          failedItems,
          details,
          completedAt: progress >= 1.0 ? new Date() : null,
        },
      });
    } else {
      await prisma.bookProcessingJob.create({
        data: {
          bookId,
          stage,
          stageProgress: progress,
          totalItems,
          completedItems,
          failedItems,
          details,
          completedAt: progress >= 1.0 ? new Date() : null,
        },
      });
    }
  } catch (err: any) {
    console.warn(`[BookIngestionQueue] Could not update job stage progress: ${err.message}`);
  }
}

/**
 * Worker to process book ingestion pipeline asynchronously.
 */
export const bookIngestionWorker = new Worker(
  BOOK_INGESTION_QUEUE_NAME,
  async (job: Job) => {
    const { name, data } = job;
    const { bookId } = data;

    if (!bookId) {
      throw new Error(`bookId is required for job: ${name}`);
    }

    console.log(`[BookIngestionQueue] Starting job "${name}" for book ${bookId} (Job ID: ${job.id})`);

    try {
      switch (name) {
        case 'process-full-book': {
          const currentBook = await prisma.bookSource.findUnique({
            where: { id: bookId },
            include: {
              subject: {
                include: {
                  topics: true,
                },
              },
            },
          });

          if (!currentBook) {
            throw new Error(`BookSource not found: ${bookId}`);
          }

          // Stage 1: Parse PDF Pages (Skip if already parsed)
          const pageCount = await prisma.bookPage.count({ where: { bookId } });
          if (currentBook.totalPages > 0 && pageCount >= currentBook.totalPages) {
            console.log(`[BookIngestionQueue:${bookId}] Stage 1: All ${pageCount} pages already parsed. Skipping to Stage 2.`);
          } else {
            console.log(`[BookIngestionQueue:${bookId}] Stage 1: Parsing PDF pages...`);
            await updateJobStageProgress(bookId, 'PARSING_PAGES', 0.1);
            await pdfParserService.parseBookPdf(bookId, async (prog) => {
              await updateJobStageProgress(bookId, 'PARSING_PAGES', prog);
            });
          }

          // Stage 2: Discover Topics (Skip if already detected)
          const metadata = (currentBook.metadata as any) || {};
          let topics = metadata.detectedTopics || [];
          if (topics.length > 0 && currentBook.subject.topics.length > 0) {
            console.log(`[BookIngestionQueue:${bookId}] Stage 2: ${topics.length} topics already discovered. Skipping to Stage 3.`);
          } else {
            console.log(`[BookIngestionQueue:${bookId}] Stage 2: Discovering topics...`);
            await updateJobStageProgress(bookId, 'DETECTING_TOPICS', 0.1);
            topics = await topicDiscoveryService.discoverTopics(bookId);
            await updateJobStageProgress(bookId, 'TOPICS_DETECTED', 1.0, topics.length, topics.length);
          }

          // Stage 3: Discover Subtopics
          console.log(`[BookIngestionQueue:${bookId}] Stage 3: Discovering subtopics...`);
          await updateJobStageProgress(bookId, 'DISCOVERING_SUBTOPICS', 0.1);
          await subtopicDiscoveryService.discoverAllSubtopicsForBook(bookId, async (prog) => {
            await updateJobStageProgress(bookId, 'DISCOVERING_SUBTOPICS', prog);
          });

          // Stage 4: Extract Questions
          console.log(`[BookIngestionQueue:${bookId}] Stage 4: Extracting questions...`);
          await updateJobStageProgress(bookId, 'EXTRACTING_QUESTIONS', 0.1);
          const qCount = await bookQuestionExtractionService.extractAllQuestionsForBook(bookId, async (prog) => {
            await updateJobStageProgress(bookId, 'EXTRACTING_QUESTIONS', prog);
          });

          // Stage 5: Classify Questions
          console.log(`[BookIngestionQueue:${bookId}] Stage 5: Classifying questions...`);
          await updateJobStageProgress(bookId, 'CLASSIFYING_QUESTIONS', 0.1);
          await bookQuestionClassificationService.classifyQuestionsForBook(bookId, async (prog) => {
            await updateJobStageProgress(bookId, 'CLASSIFYING_QUESTIONS', prog);
          });

          // Stage 6: Generate Scripts
          console.log(`[BookIngestionQueue:${bookId}] Stage 6: Generating scripts...`);
          await updateJobStageProgress(bookId, 'GENERATING_SCRIPTS', 0.1);
          await bookScriptGenerationService.generateAllScriptsForBook(bookId, async (prog) => {
            await updateJobStageProgress(bookId, 'GENERATING_SCRIPTS', prog);
          });

          // Stage 7: Validate Content
          console.log(`[BookIngestionQueue:${bookId}] Stage 7: Validating content...`);
          await updateJobStageProgress(bookId, 'VALIDATING_CONTENT', 0.1);
          const valRes = await contentValidationService.validateBookContent(bookId);
          await updateJobStageProgress(bookId, 'READY_FOR_REVIEW', 1.0, qCount, qCount, valRes.flaggedCount, { issues: valRes.issues });

          console.log(`[BookIngestionQueue:${bookId}] Complete pipeline successfully finished! Ready for admin review.`);
          return { success: true, bookId, status: 'READY_FOR_REVIEW' };
        }

        case 'parse-pages': {
          await pdfParserService.parseBookPdf(bookId);
          return { success: true };
        }

        case 'detect-topics': {
          const topics = await topicDiscoveryService.discoverTopics(bookId);
          return { success: true, count: topics.length };
        }

        case 'discover-subtopics': {
          const subtopics = await subtopicDiscoveryService.discoverAllSubtopicsForBook(bookId);
          return { success: true, subtopics };
        }

        case 'extract-questions': {
          const count = await bookQuestionExtractionService.extractAllQuestionsForBook(bookId);
          return { success: true, count };
        }

        case 'classify-questions': {
          const count = await bookQuestionClassificationService.classifyQuestionsForBook(bookId);
          return { success: true, count };
        }

        case 'generate-scripts': {
          const count = await bookScriptGenerationService.generateAllScriptsForBook(bookId);
          return { success: true, count };
        }

        case 'validate-content': {
          const valRes = await contentValidationService.validateBookContent(bookId);
          return { success: true, valRes };
        }

        default:
          console.warn(`[BookIngestionQueue] Unknown job type: ${name}`);
          return null;
      }
    } catch (err: any) {
      console.error(`[BookIngestionQueue] Job "${name}" failed for book ${bookId}:`, err);
      await prisma.bookSource.update({
        where: { id: bookId },
        data: {
          status: 'FAILED',
          errorMessage: err.message || 'Unknown processing error',
        },
      });
      return { success: false, error: err.message };
    }
  },
  {
    connection,
    concurrency: 1, // Strict single-worker to prevent concurrent loop runs
    lockDuration: 900000, // 15 minutes lock window so long AI calls never falsely trigger stalled watchdog
    stalledInterval: 60000, // Check stalled jobs once per minute
    maxStalledCount: 1,
  }
);

bookIngestionWorker.on('completed', (job: Job) => {
  console.log(`[BookIngestionQueue] Job ${job.name} (ID: ${job.id}) completed.`);
});

bookIngestionWorker.on('failed', async (job: Job | undefined, err: Error) => {
  console.error(`[BookIngestionQueue] Job ${job?.name} (ID: ${job?.id}) failed:`, err);
  if (job?.data?.bookId) {
    try {
      await prisma.bookSource.update({
        where: { id: job.data.bookId },
        data: {
          status: 'FAILED',
          errorMessage: err.message || 'Job stalled or failed unrecoverably',
        },
      });
    } catch (e: any) {
      console.warn('[BookIngestionQueue] Could not mark book status as FAILED:', e.message);
    }
  }
});
