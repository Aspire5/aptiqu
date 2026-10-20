import cron from 'node-cron';
import { dailyChallengeService } from '../modules/daily-challenge/daily-challenge.service';
import { contentGenQueue } from '../queues/content-generation.queue';
import { log, safeError } from '../observability/logger';
export function startScheduler() {
    let stopped = false;
    const work = new Set<Promise<unknown>>();
    const schedule = (expression: string, event: string, task: () => Promise<unknown>) => cron.schedule(expression, () => {
        if (stopped || work.size)
            return;
        const pending = task().catch(error => log('error', event, safeError(error))).finally(() => work.delete(pending));
        work.add(pending);
    }, { timezone: 'Asia/Kolkata' });
    const tasks = [schedule('0 0 * * *', 'daily.rollover_failed', () => dailyChallengeService.runMidnightIstCron()),
        schedule('0 23 * * *', 'daily.prewarm_failed', async () => {
            const targetDate = new Date(Date.now() + 86400000 + 19800000).toISOString().slice(0, 10);
            await contentGenQueue.add('prewarm-daily-challenge', { targetDate }, { jobId: `prewarm-daily-${targetDate}`, removeOnComplete: true });
        })];
    return async () => { stopped = true; await Promise.all(tasks.map(task => task.stop())); await Promise.allSettled([...work]); await Promise.all(tasks.map(task => task.destroy())); };
}
