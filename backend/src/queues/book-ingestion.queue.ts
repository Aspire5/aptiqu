import { log, safeError } from '../observability/logger';
import { ENV } from '../config/env';
import { withBookRun } from '../modules/admin/services/book-run';
import { z } from 'zod';
import { queueRedis } from '../config/queue-redis';
import { Queue, Worker, Job } from 'bullmq';
import { prisma } from '../modules/admin/services/book-run';
import { pdfParserService } from '../modules/admin/services/pdf-parser.service';
import { topicDiscoveryService } from '../modules/admin/services/topic-discovery.service';
import { subtopicDiscoveryService } from '../modules/admin/services/subtopic-discovery.service';
import { bookQuestionExtractionService } from '../modules/admin/services/book-question-extraction.service';
import { bookQuestionClassificationService } from '../modules/admin/services/book-question-classification.service';
import { bookScriptGenerationService } from '../modules/admin/services/book-script-generation.service';
import { contentValidationService } from '../modules/admin/services/content-validation.service';
import { bookCancellationService } from '../modules/admin/services/book-cancellation.service';

export const BOOK_INGESTION_QUEUE_NAME = 'book-ingestion';

let queue: Queue | undefined;
let producerConnection: ReturnType<typeof queueRedis> | undefined;
export function getBookIngestionQueue() { return queue ??= new Queue(BOOK_INGESTION_QUEUE_NAME, {
  connection: producerConnection ??= queueRedis(),
  defaultJobOptions: {
    attempts: 1, // Never automatically loop-retry on failure; wait for explicit user action
    removeOnComplete: true,
    removeOnFail: {count:ENV.QUEUE_FAILED_RETENTION_COUNT??500,age:ENV.QUEUE_FAILED_RETENTION_SECONDS??604800},
  },
}); }
export const bookIngestionQueue = {
  add: (...args: Parameters<Queue['add']>) => getBookIngestionQueue().add(...args),
  getJobs: (...args: Parameters<Queue['getJobs']>) => getBookIngestionQueue().getJobs(...args),
  close: async () => { if (queue) { await queue.close(); producerConnection?.disconnect(); producerConnection = undefined; queue = undefined; } },
};

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
    throw err;
  }
}

/**
 * Worker to process book ingestion pipeline asynchronously.
 */
const bookStages = ['process-full-book','parse-pages','detect-topics','discover-subtopics','extract-questions','classify-questions','generate-scripts','validate-content'] as const;
export async function enqueueBookStage(bookId: string, stage: string) {
  z.string().uuid().parse(bookId); z.enum(bookStages).parse(stage);
  const book = await prisma.bookSource.findUniqueOrThrow({where:{id:bookId}});
  if (book.processingToken && book.processingHeartbeat && +book.processingHeartbeat > Date.now()-180000) throw new Error('Book is still processing. Wait for cancellation acknowledgment before retrying.');
  await bookCancellationService.reset(bookId);
  const jobId=`book-${bookId}-${book.processingEpoch}-${stage}`;
  const existing=await getBookIngestionQueue().getJob(jobId);
  if(existing){
    const state=await existing.getState();
    if(state==='failed'){await existing.retry();return existing;}
    if(state==='active')throw new Error('Book stage is still active');
    return existing;
  }
  return bookIngestionQueue.add(stage,{bookId,epoch:book.processingEpoch},{jobId});
}
export async function processBookJob(job: Job) {
  z.enum(bookStages).parse(job.name); const bookId=z.string().uuid().parse(job.data?.bookId);
  const epoch=z.number().int().nonnegative().parse(job.data?.epoch);
  try {return await withBookRun(bookId,()=>processBookBody(job),epoch);}
  catch (err) {if (err instanceof Error && err.message.includes('BOOK_INGESTION_CANCELLED')) return {success:false,cancelled:true};throw err;}
}
async function processBookBody(job: Job) {
    const { name, data } = job;
    const { bookId } = data;

    if (!bookId) {
      throw new Error(`bookId is required for job: ${name}`);
    }

    log('info','book_ingestion_queue.processBookBody.info');

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
          await bookCancellationService.checkAndThrowIfCancelled(bookId, 'before Stage 1 (PDF Parsing)');
          const pageCount = await prisma.bookPage.count({ where: { bookId } });
          if (currentBook.totalPages > 0 && pageCount >= currentBook.totalPages) {
            log('info','book_ingestion_queue.processBookBody.info');
          } else {
            log('info','book_ingestion_queue.processBookBody.info');
            await updateJobStageProgress(bookId, 'PARSING_PAGES', 0.1);
            await pdfParserService.parseBookPdf(bookId, async (prog) => {
              await updateJobStageProgress(bookId, 'PARSING_PAGES', prog);
            });
          }

          // Stage 2: Discover Topics (Skip if already detected)
          await bookCancellationService.checkAndThrowIfCancelled(bookId, 'before Stage 2 (Topic Discovery)');
          const metadata = (currentBook.metadata as any) || {};
          let topics = metadata.detectedTopics || [];
          if (topics.length > 0 && currentBook.subject.topics.length > 0) {
            log('info','book_ingestion_queue.processBookBody.info');
          } else {
            log('info','book_ingestion_queue.processBookBody.info');
            await updateJobStageProgress(bookId, 'DETECTING_TOPICS', 0.1);
            topics = await topicDiscoveryService.discoverTopics(bookId);
            await updateJobStageProgress(bookId, 'TOPICS_DETECTED', 1.0, topics.length, topics.length);
          }

          // Stage 3: Discover Subtopics
          await bookCancellationService.checkAndThrowIfCancelled(bookId, 'before Stage 3 (Subtopic Discovery)');
          log('info','book_ingestion_queue.processBookBody.info');
          await updateJobStageProgress(bookId, 'DISCOVERING_SUBTOPICS', 0.1);
          await subtopicDiscoveryService.discoverAllSubtopicsForBook(bookId, async (prog) => {
            await updateJobStageProgress(bookId, 'DISCOVERING_SUBTOPICS', prog);
          });

          // Stage 4: Extract Questions
          await bookCancellationService.checkAndThrowIfCancelled(bookId, 'before Stage 4 (Question Extraction)');
          log('info','book_ingestion_queue.processBookBody.info');
          await updateJobStageProgress(bookId, 'EXTRACTING_QUESTIONS', 0.1);
          const qCount = await bookQuestionExtractionService.extractAllQuestionsForBook(bookId, async (prog) => {
            await updateJobStageProgress(bookId, 'EXTRACTING_QUESTIONS', prog);
          });

          // Stage 5: Classify Questions
          await bookCancellationService.checkAndThrowIfCancelled(bookId, 'before Stage 5 (Question Classification)');
          log('info','book_ingestion_queue.processBookBody.info');
          await updateJobStageProgress(bookId, 'CLASSIFYING_QUESTIONS', 0.1);
          await bookQuestionClassificationService.classifyQuestionsForBook(bookId, async (prog) => {
            await updateJobStageProgress(bookId, 'CLASSIFYING_QUESTIONS', prog);
          });

          // Stage 6: Generate Scripts
          await bookCancellationService.checkAndThrowIfCancelled(bookId, 'before Stage 6 (Script Generation)');
          log('info','book_ingestion_queue.processBookBody.info');
          await updateJobStageProgress(bookId, 'GENERATING_SCRIPTS', 0.1);
          await bookScriptGenerationService.generateAllScriptsForBook(bookId, async (prog) => {
            await updateJobStageProgress(bookId, 'GENERATING_SCRIPTS', prog);
          });

          // Stage 7: Validate Content
          await bookCancellationService.checkAndThrowIfCancelled(bookId, 'before Stage 7 (Content Validation)');
          log('info','book_ingestion_queue.processBookBody.info');
          await updateJobStageProgress(bookId, 'VALIDATING_CONTENT', 0.1);
          const valRes = await contentValidationService.validateBookContent(bookId);
          await updateJobStageProgress(bookId, valRes.passed ? 'READY_FOR_REVIEW' : 'VALIDATING_CONTENT', 1.0, qCount, qCount, valRes.flaggedCount, { issues: valRes.issues });
          if (!valRes.passed) throw new Error('Book content validation failed; review the recorded issues');

          log('info','book_ingestion_queue.processBookBody.info');
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
          if (!valRes.passed) throw new Error('Book content validation failed; review the recorded issues');
          return { success: true, valRes };
        }

        default:
          throw new Error('Unsupported book ingestion job');
      }
    } catch (err: any) {
      if (err.message?.includes('BOOK_INGESTION_CANCELLED') || await bookCancellationService.isCancelled(bookId)) {
        log('info','book_ingestion_queue.processBookBody.info',safeError(err));
        try {
          const exists = await prisma.bookSource.findUnique({ where: { id: bookId } });
          if (exists) {
            await prisma.bookSource.update({
              where: { id: bookId },
              data: {
                status: 'FAILED',
                errorMessage: 'Processing cancelled by admin',
              },
            });
          }
        } catch (_) {}
        return { success: false, cancelled: true };
      }

      log('error','book_ingestion_queue.processBookBody.error',safeError(err));
      try {
        const exists = await prisma.bookSource.findUnique({ where: { id: bookId } });
        if (exists) {
          await prisma.bookSource.update({
            where: { id: bookId },
            data: {
              status: 'FAILED',
              errorMessage: 'Book processing failed. Review server diagnostics and retry explicitly.',
            },
          });
        }
      } catch (_) {}
      throw err;
    }
}
export function startBookIngestionWorker() {
  const connection = queueRedis(true);
  const worker = new Worker(BOOK_INGESTION_QUEUE_NAME, processBookJob, {
    connection, concurrency:1, lockDuration:900000, stalledInterval:60000, maxStalledCount:0,
  });
  worker.on('error', () => log('warn','book_ingestion_queue.startBookIngestionWorker.warn'));
  worker.on('failed', () => log('warn','book_ingestion_queue.startBookIngestionWorker.warn'));
  return Object.assign(async () => { await worker.close(); connection.disconnect(); await bookIngestionQueue.close(); },{pause:()=>worker.pause(true),ready:()=>worker.waitUntilReady(),isReady:()=>worker.isRunning() && connection.status==='ready'});
}

/**
 * Requests durable cancellation and removes waiting jobs. In-flight work is fenced before writes.
 */
export async function stopBookProcessing(bookId: string): Promise<void> {
  // Persist cancellation before removing waiting jobs.
  await bookCancellationService.cancel(bookId);

  // 2. Remove or discard any queued jobs for this book
  try {
    const jobs = await bookIngestionQueue.getJobs(['waiting', 'delayed'],0,499);
    for (const job of jobs) {
      if (job.data?.bookId === bookId) {
        log('info','book_ingestion_queue.stopBookProcessing.info');
        try {
          await job.remove();
        } catch { /* Active jobs observe durable cancellation at their next write/check. */
        }
      }
    }
  } catch (err: any) {
    log('warn','book_ingestion_queue.stopBookProcessing.warn',safeError(err));
  }
}
