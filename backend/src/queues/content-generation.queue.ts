import { Queue, Worker, Job } from 'bullmq';
import { ENV } from '../config/env';
import { QuestionGenerationService } from '../modules/ai/services/question-generation.service';
import { DailyChallengeGenerationService } from '../modules/ai/services/daily-challenge-generation.service';

function parseRedisConnection(urlStr: string) {
  try {
    const url = new URL(urlStr);
    return {
      host: url.hostname,
      port: parseInt(url.port || '6379', 10),
      password: url.password || undefined,
      maxRetriesPerRequest: null,
    };
  } catch {
    return {
      host: '127.0.0.1',
      port: 6379,
      maxRetriesPerRequest: null,
    };
  }
}

const connection = parseRedisConnection(ENV.REDIS_URL);

export const CONTENT_GEN_QUEUE_NAME = 'content-generation';

/**
 * BullMQ Queue for decoupled background AI question generation and pre-warming.
 */
export const contentGenQueue = new Queue(CONTENT_GEN_QUEUE_NAME, {
  connection,
  defaultJobOptions: {
    attempts: 3,
    backoff: {
      type: 'exponential',
      delay: 5000,
    },
    removeOnComplete: true,
    removeOnFail: false,
  },
});

/**
 * Background worker with concurrency = 2 to respect Gemini rate limits.
 */
export const contentGenWorker = new Worker(
  CONTENT_GEN_QUEUE_NAME,
  async (job: Job) => {
    const { name, data } = job;
    console.log(`[ContentGenQueue] Processing job: ${name} (ID: ${job.id})`);

    switch (name) {
      case 'generate-subtopic-questions': {
        const { subtopicId, count } = data;
        if (!subtopicId) {
          throw new Error('subtopicId is required for generate-subtopic-questions');
        }
        const service = QuestionGenerationService.getInstance();
        const results = await service.generateQuestionsForSubtopic(subtopicId, count || 10);
        console.log(
          `[ContentGenQueue] Successfully generated ${results.length} questions for subtopic: ${subtopicId}`
        );
        return { count: results.length };
      }

      case 'prewarm-daily-challenge': {
        const { targetDate } = data;
        if (!targetDate) {
          throw new Error('targetDate is required for prewarm-daily-challenge');
        }
        const service = DailyChallengeGenerationService.getInstance();
        await service.prewarmDailyChallengeScripts(targetDate);
        console.log(
          `[ContentGenQueue] Successfully pre-warmed Daily Challenge scripts for date: ${targetDate}`
        );
        return { targetDate };
      }

      default:
        console.warn(`[ContentGenQueue] Unknown job type: ${name}`);
        return null;
    }
  },
  {
    connection,
    concurrency: 2,
  }
);

contentGenWorker.on('completed', (job: Job) => {
  console.log(`[ContentGenQueue] Job ${job.name} (ID: ${job.id}) completed successfully.`);
});

contentGenWorker.on('failed', (job: Job | undefined, err: Error) => {
  console.error(`[ContentGenQueue] Job ${job?.name} (ID: ${job?.id}) failed:`, err);
});
