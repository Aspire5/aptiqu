import { PvpError } from '../pvp.errors';
/** Per-host, bounded transport budget; JWT/DB eligibility remain authoritative. */
export class RankedRateLimit {
  private buckets = new Map<string, { start: number; count: number }>();
  constructor(private readonly maximum: number, private readonly windowMs: number, private readonly clock = Date.now, private readonly capacity = 10000) {}
  take(owner: string) {
    const now = this.clock();
    const previous = this.buckets.get(owner);
    const bucket = previous && now - previous.start < this.windowMs ? previous : { start: now, count: 0 };
    if (bucket.count >= this.maximum) throw new PvpError('Too many Ranked requests. Please wait and retry.', 'RATE_LIMITED', 429, Math.max(1, Math.ceil((bucket.start + this.windowMs - now) / 1000)));
    bucket.count++;
    this.buckets.delete(owner); this.buckets.set(owner, bucket);
    while (this.buckets.size > this.capacity) this.buckets.delete(this.buckets.keys().next().value!);
  }
}
