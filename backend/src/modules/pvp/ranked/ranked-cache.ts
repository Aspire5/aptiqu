/** Bounded observation caches. Epochs prevent an in-flight pre-settlement read
 * from repopulating the cache after invalidation. Failures are never cached. */
export class RankedReadCache {
  private values = new Map<string, { value: unknown; expires: number }>();
  private pending = new Map<string, Promise<unknown>>();
  private epoch = 0;
  constructor(private readonly clock = Date.now, private readonly capacity = 512) {}
  async get<T>(key: string, load: () => Promise<T>, ttl: (value: T) => number = () => 5000): Promise<T> {
    const cached = this.values.get(key);
    if (cached && cached.expires > this.clock()) return cached.value as T;
    const pending = this.pending.get(key);
    if (pending) return pending as Promise<T>;
    const epoch = this.epoch;
    const startedAt = this.clock();
    const work = load().then(value => {
      if (epoch === this.epoch) {
        this.values.delete(key);
        // Query latency consumes the observation's TTL rather than extending it
        // beyond a season boundary while the result was in flight.
        this.values.set(key, { value, expires: startedAt + Math.max(0, Math.min(ttl(value), 5000)) });
        while (this.values.size > this.capacity) this.values.delete(this.values.keys().next().value!);
      }
      return value;
    }).finally(() => { if (this.pending.get(key) === work) this.pending.delete(key); });
    if (this.pending.size < this.capacity) this.pending.set(key, work);
    return work;
  }
  invalidate(users: string[] = []) {
    this.epoch++;
    for (const key of this.values.keys()) if (key.startsWith('board:') || users.some(u => key.startsWith(`me:${u}:`))) this.values.delete(key);
    // New requests must not attach to a stale observation already in flight.
    for (const key of this.pending.keys()) if (key.startsWith('board:') || users.some(u => key.startsWith(`me:${u}:`))) this.pending.delete(key);
  }
}
export const rankedReadCache = new RankedReadCache();
