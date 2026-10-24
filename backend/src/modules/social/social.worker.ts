import { log, safeError } from '../../observability/logger';
import { ENV } from '../../config/env';
import { queueRedis } from '../../config/queue-redis';
import { prisma } from '../../config/prisma';
import { Queue, Worker } from 'bullmq';
import { duelsService } from './duels.service';
export async function reconcileDueDuels(limit=100) {
  const due=await prisma.friendlyDuel.findMany({where:{OR:[{status:{in:['PENDING','PREPARING']},expiresAt:{lte:new Date()}},{status:'ACTIVE',matchExpiresAt:{lte:new Date()}}]},select:{id:true},orderBy:{expiresAt:'asc'},take:Math.min(100,Math.max(1,limit))});
  for(const duel of due) await duelsService.expire(duel.id);
  return due.length;
}
export function startSocialWorker() {
  const connection = queueRedis(true);
  connection.on('error', () => {});
  const queue = new Queue('social-deadlines', { connection });
  const worker = new Worker('social-deadlines', async job => duelsService.expire(job.data.id), { connection, concurrency: ENV.SOCIAL_WORKER_CONCURRENCY??20 });
  worker.on('error', error => log('error','social_worker.startSocialWorker.error'));
  duelsService.clearSchedule = async id => {
    for (const delay of [60000,86400000]) await queue.remove(`expire-${id}-${delay}`).catch(() => 0);
  };
  duelsService.schedule = async (id, delay) => { await queue.add('expire', { id }, { jobId: `expire-${id}-${delay}`, delay,
    attempts: 5, backoff: { type: 'exponential', delay: 1000 }, removeOnComplete: true, removeOnFail: {count:ENV.QUEUE_FAILED_RETENTION_COUNT,age:ENV.QUEUE_FAILED_RETENTION_SECONDS} }); };
  let sweeping = false;
  const sweep = async () => {
    if (sweeping) return;
    sweeping = true;
    try {
      await reconcileDueDuels();
    } catch { log('warn','social_worker.startSocialWorker.warn'); }
    finally { sweeping = false; }
  };
  let pending=sweep();
  const timer = setInterval(() => {if(!sweeping)pending=sweep();},30000); timer.unref();
  return Object.assign(async () => { clearInterval(timer); await pending; await worker.close(); await queue.close(); connection.disconnect(); },{pause:()=>worker.pause(true),ready:()=>worker.waitUntilReady(),isReady:()=>worker.isRunning() && connection.status==='ready'});
}
