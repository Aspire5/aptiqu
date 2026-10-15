import Redis from 'ioredis';
import { ENV } from '../../config/env';
export const socialError = (message: string, status = 400) => Object.assign(new Error(message), { status });
// Initialized only at server startup. No process-local fallback for shared state.
class SocialTransport {
  client: Redis | null = null;
  subscriber: Redis | null = null;
  init() {
    this.client = new Redis(ENV.REDIS_URL, { maxRetriesPerRequest: 1, enableOfflineQueue: false });
    this.subscriber = this.client.duplicate();
    this.client.on('error', () => {}); this.subscriber.on('error', () => {});
  }
  requireReady() {
    if (this.client?.status !== 'ready') throw socialError('Live invitations are temporarily unavailable. Please retry.', 503);
    return this.client;
  }
  async notify(users: string[], event: string, id?: string) {
    const client = this.client;
    if (!client || client.status !== 'ready') return;
    const pipeline = client.pipeline();
    for (const user of new Set(users)) pipeline.publish(`social:user:${user}`, JSON.stringify({ event, id }));
    await pipeline.exec().catch(() => console.warn('[Social] Live event delivery failed; persisted inbox remains available.'));
  }
  async limit(user: string, action: string, max: number, seconds: number) {
    const client = this.requireReady();
    const value = await client.eval(`local n=redis.call('INCR',KEYS[1]); if n==1 then redis.call('EXPIRE',KEYS[1],ARGV[1]) end; return n`,
      1, `social:rate:${action}:${user}`, seconds) as number;
    if (value > max) throw socialError('Too many requests. Please try again later.', 429);
  }
  async presence(ids: string[]) {
    if (!this.client || this.client.status !== 'ready') return ids.map(id => ({ id, online: null }));
    const pipeline = this.client.pipeline();
    for (const id of ids) pipeline.zcount(`social:presence:${id}`, Date.now(), '+inf');
    const results = await pipeline.exec();
    return ids.map((id, i) => ({ id, online: results?.[i]?.[0] ? null : Number(results?.[i]?.[1] ?? 0) > 0 }));
  }
}
export const socialTransport = new SocialTransport();
