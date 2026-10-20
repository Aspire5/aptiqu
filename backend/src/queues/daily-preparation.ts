import { log, safeError } from '../observability/logger';
import { prisma } from '../config/prisma';
import { contentGenQueue } from './content-generation.queue';

// Repair a missed cron/enqueue using the existing date identity and generation lease.
// Daily preparation only selects approved manual PYQs; it does not call the AI provider.
export async function reconcileDailyPreparation(now = new Date()) {
  const ist = new Date(now.getTime() + 330 * 60000);
  const dates = [ist.toISOString().slice(0, 10)];
  if (ist.getUTCHours() >= 23) {
    dates.push(new Date(ist.getTime() + 86400000).toISOString().slice(0, 10));
  }
  for (const targetDate of dates) {
    const scripts = await prisma.dailyChallengeScript.findMany({
      where: { dateString: targetDate, tier: { in: [1, 2, 3] } },
      select: { tier: true }, take: 3,
    });
    if (new Set(scripts.map(script => script.tier)).size === 3) continue;
    await contentGenQueue.add('prewarm-daily-challenge', { targetDate }, {
      jobId: `prewarm-daily-${targetDate}`, removeOnComplete: true,
    });
  }
}

export function startDailyPreparationRecovery() {
  let stopping = false;
  let pending: Promise<void> | undefined;
  const sweep = () => {
    if (pending || stopping) return;
    pending = reconcileDailyPreparation()
      .catch(() => log('warn','daily_preparation.startDailyPreparationRecovery.warn'))
      .finally(() => { pending = undefined; });
  };
  sweep();
  const timer = setInterval(sweep, 300000);
  timer.unref();
  return async () => { stopping = true; clearInterval(timer); await pending; };
}
