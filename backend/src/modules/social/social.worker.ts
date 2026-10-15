import { Queue, Worker } from 'bullmq';
import Redis from 'ioredis';
import { ENV } from '../../config/env';
import { duelsService } from './duels.service';
export function startSocialWorker() {
  const connection = new Redis(ENV.REDIS_URL, { maxRetriesPerRequest: null });
  connection.on('error', () => {});
  const queue = new Queue('social-deadlines', { connection });
  const worker = new Worker('social-deadlines', async job => duelsService.expire(job.data.id), { connection, concurrency: 20 });
  worker.on('error', error => console.error('[Social deadlines]', error.message));
  duelsService.clearSchedule = async id => {
    for (const delay of [60000,86400000]) await queue.remove(`expire-${id}-${delay}`).catch(() => 0);
  };
  duelsService.schedule = async (id, delay) => { await queue.add('expire', { id }, { jobId: `expire-${id}-${delay}`, delay,
    attempts: 5, backoff: { type: 'exponential', delay: 1000 }, removeOnComplete: true, removeOnFail: 1000 }); };
  return async () => { await worker.close(); await queue.close(); await connection.quit(); };
}
