import Redis from 'ioredis';
import { ENV } from './env';

export function validateRedisUrl(value: string): string {
  const url = new URL(value);
  if (!['redis:', 'rediss:'].includes(url.protocol) || !url.hostname ||
      (url.pathname !== '/' && url.pathname !== '' && !/^\/\d+$/.test(url.pathname)) || url.search || url.hash) {
    throw new Error('REDIS_URL must be a redis/rediss URL with an optional numeric database');
  }
  return value;
}
// Pass the complete URL to ioredis: preserve TLS, ACL username, escaped credentials and DB.
export function queueRedis(worker = false): Redis {
  const client = new Redis(validateRedisUrl(ENV.REDIS_URL), {
    maxRetriesPerRequest: worker ? null : 1, enableOfflineQueue: worker, connectTimeout: 3000, ...(worker?{}:{commandTimeout:ENV.READINESS_TIMEOUT_MS??3000}),
  });
  client.on('error', () => {}); // No credential-bearing connection messages.
  return client;
}
