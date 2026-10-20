import { PublicError } from './errors';
export { PublicError } from './errors';
import { createHash } from 'node:crypto';
import { RequestHandler } from 'express';
import { redisService } from '../modules/lesson/services/redis.service';

// Shared fixed windows. Outages fail closed for protected operations, never use local counters.
export const policies = {
  auth: [120, 60000], admin: [5, 900000], refresh: [120, 60000],
  read: [60, 60000], create: [30, 60000], mutation: [180, 60000], daily: [60, 60000],
  socketConnect: [120, 60000], socketMessage: [240, 60000], socketQueue: [6, 10000],
} as const;
export async function takeBudget(policy: keyof typeof policies, owner: string): Promise<void> {
  const client = redisService.getClient();
  if (!client || client.status !== 'ready') throw new PublicError('Service temporarily unavailable. Please retry.', 'SERVICE_UNAVAILABLE', 503, 3);
  const [limit, window] = policies[policy];
  const key = `abuse:v1:${policy}:${createHash('sha256').update(owner).digest('hex')}`;
  let result: number[];
  try {
    result = await client.eval(`local n=redis.call('INCR',KEYS[1]); if n==1 then redis.call('PEXPIRE',KEYS[1],ARGV[1]) end; return {n,redis.call('PTTL',KEYS[1])}`,1,key,window) as number[];
  } catch { throw new PublicError('Service temporarily unavailable. Please retry.', 'SERVICE_UNAVAILABLE', 503, 3); }
  if (result[0] > limit) throw new PublicError('Too many requests. Please retry shortly.', 'RATE_LIMITED',429,Math.max(1,Math.ceil(result[1]/1000)));
}
export const requestBudget: RequestHandler = (req, res, next) => {
  const user = (req as typeof req & {userId?: string;adminUser?:{username:string}}).userId;
  const path = req.path;
  const policy = path === '/admin/auth/login' ? 'admin' : path === '/auth/refresh' ? 'refresh'
    : path.startsWith('/auth/') && !user ? 'auth'
    : path.startsWith('/daily-challenge') ? 'daily'
    : req.method === 'GET' && path.startsWith('/pvp/') ? 'read'
    : req.method !== 'GET' && /\/start|\/sessions$|\/replay|\/queue/.test(path) ? 'create'
    : req.method !== 'GET' ? 'mutation' : undefined;
  if (!policy) { next(); return; }
  void takeBudget(policy, user || req.ip || req.socket.remoteAddress || 'unknown').then(() => next(), err => {
    if (err.retryAfterSeconds) res.setHeader('Retry-After', String(err.retryAfterSeconds));
    res.status(err.status || 503).json({success:false,code:err.code,message:err.message});
  });
};
