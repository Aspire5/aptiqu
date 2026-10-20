import { log, safeError } from '../observability/logger';
import { ENV } from '../config/env';
import { queueRedis } from '../config/queue-redis';
import { Queue, Worker, Job } from 'bullmq';
import { QuestionGenerationService } from '../modules/ai/services/question-generation.service';
import { DailyChallengeGenerationService } from '../modules/ai/services/daily-challenge-generation.service';

export const CONTENT_GEN_QUEUE_NAME = 'content-generation';

/**
 * BullMQ Queue for decoupled background AI question generation and pre-warming.
 */
let queue: Queue | undefined;
let producerConnection: ReturnType<typeof queueRedis> | undefined;
export function getContentGenQueue() {
  return queue ??= new Queue(CONTENT_GEN_QUEUE_NAME, {
  connection: producerConnection ??= queueRedis(),
  defaultJobOptions: {
    attempts: 3,
    backoff: {
      type: 'exponential',
      delay: 5000,
    },
    removeOnComplete: true,
    removeOnFail: {count:ENV.QUEUE_FAILED_RETENTION_COUNT??500,age:ENV.QUEUE_FAILED_RETENTION_SECONDS??604800},
  },
  });
}
export const contentGenQueue = {
  add: (...args: Parameters<Queue['add']>) => getContentGenQueue().add(...args),
  close: async () => { if (queue) { await queue.close(); producerConnection?.disconnect(); producerConnection = undefined; queue = undefined; } },
};

/**
 * Background worker with concurrency = 2 to respect Gemini rate limits.
 */
export async function processContentJob(job: Job) {
    const { name, data } = job;
    log('info','content_generation_queue.processContentJob.info');

    switch (name) {
      case 'generate-subtopic-questions': {
        const { subtopicId, count } = data;
        if (typeof subtopicId !== 'string' || !Number.isInteger(count) || count < 1 || count > 50) {
          throw new Error('subtopicId is required for generate-subtopic-questions');
        }
        const service = QuestionGenerationService.getInstance();
        const results = await service.generateQuestionsForSubtopic(subtopicId, count);
        log('info','content_generation_queue.processContentJob.info');
        return { count: results.length };
      }

      case 'prewarm-daily-challenge': {
        const { targetDate } = data;
        if (typeof targetDate !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(targetDate) || !Number.isFinite(Date.parse(targetDate)) || new Date(targetDate).toISOString().slice(0,10)!==targetDate) {
          throw new Error('targetDate is required for prewarm-daily-challenge');
        }
        const service = DailyChallengeGenerationService.getInstance();
        await service.prewarmDailyChallengeScripts(targetDate);
        log('info','content_generation_queue.processContentJob.info');
        return { targetDate };
      }

      default: throw new Error('Unsupported content generation job');
    }
}
export function startContentGenWorker() {
  const connection = queueRedis(true);
  const worker = new Worker(CONTENT_GEN_QUEUE_NAME, processContentJob, {connection,concurrency:ENV.CONTENT_WORKER_CONCURRENCY??2});
  worker.on('error', () => log('warn','content_generation_queue.startContentGenWorker.warn'));
  worker.on('failed', () => log('warn','content_generation_queue.startContentGenWorker.warn'));
  return Object.assign(async () => { await worker.close(); connection.disconnect(); await contentGenQueue.close(); },{pause:()=>worker.pause(true),ready:()=>worker.waitUntilReady(),isReady:()=>worker.isRunning() && connection.status==='ready'});
}
