import { log, safeError } from '../../../observability/logger';
import { pvpMatchService, PvpMatchService } from '../services/pvp-match.service';
import { pvpSocketServer } from '../pvp.socket';
import type { PvpInternalMatch } from '../pvp.dto';

/** Single WebSocket host for v1. DB locks and immutable ledgers fence duplicate
 * work, but cross-host socket routing/queue redesign remains Phase 3. */
export class RankedRecoveryWorker {
  private running?: Promise<void>;
  private stopped = false;
  private timer?: NodeJS.Timeout;
  private cursor?: string;
  private lastMaintenance = 0;
  constructor(private readonly service: PvpMatchService, private readonly publish: (match: PvpInternalMatch) => Promise<void>) {}
  start() {
    void this.tick();
    this.timer = setInterval(() => { void this.tick(); }, 1000);
  }
  async stop() {
    this.stopped = true;
    clearInterval(this.timer);
    await this.running;
  }
  async tick() {
    if (this.stopped || this.running) return;
    this.running = this.run().catch(() => { log('error','ranked_worker.tick.error'); });
    try { await this.running; } finally { this.running = undefined; }
  }
  private async run() {
    const page = await this.service.recoveryPage(this.cursor);
    for (const row of page) {
      if (this.stopped) return;
      try { await this.publish(await this.service.recoverMatch(row.id)); }
      catch { log('error','ranked_worker.run.error'); }
    }
    this.cursor = page.length === 100 ? page[page.length - 1].id : undefined;
    if (Date.now() - this.lastMaintenance >= 60000) {
      await this.service.seasons.maintain();
      this.lastMaintenance = Date.now();
    }
  }
}
export function startRankedWorker() {
  const worker = new RankedRecoveryWorker(pvpMatchService, match => pvpSocketServer.publishRecovered(match));
  worker.start();
  return () => worker.stop();
}
