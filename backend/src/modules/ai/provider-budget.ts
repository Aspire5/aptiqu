import { randomUUID } from 'node:crypto';
import { redisService } from '../lesson/services/redis.service';
import { AI_LIMITS } from '../../config/env';
import { PublicError } from '../../security/errors';

// Reserve an upper bound (UTF-8 bytes plus output/thinking budget), never pretend a
// failed/aborted provider request was free. Daily counters expire; no process-local fallback.
export async function reserveProvider(tokens:number,timeoutMs:number) {
  const client=redisService.getClient();
  if(!client || client.status!=='ready')throw new PublicError('AI generation temporarily unavailable','AI_UNAVAILABLE',503);
  const now=Date.now(), token=randomUUID();
  const keys=['ai:inflight',`ai:rpm:${Math.floor(now/60000)}`,`ai:tokens:${Math.floor(now/86400000)}`];
  const result=await client.eval(`
    redis.call('ZREMRANGEBYSCORE',KEYS[1],'-inf',ARGV[1]);
    if redis.call('ZCARD',KEYS[1])>=tonumber(ARGV[2]) then return 1 end;
    if tonumber(redis.call('GET',KEYS[2]) or '0')>=tonumber(ARGV[3]) then return 2 end;
    if tonumber(redis.call('GET',KEYS[3]) or '0')+tonumber(ARGV[4])>tonumber(ARGV[5]) then return 3 end;
    redis.call('ZADD',KEYS[1],ARGV[6],ARGV[7]);if redis.call('PTTL',KEYS[1])<tonumber(ARGV[8]) then redis.call('PEXPIRE',KEYS[1],ARGV[8]) end;
    redis.call('INCR',KEYS[2]);redis.call('EXPIRE',KEYS[2],120);
    redis.call('INCRBY',KEYS[3],ARGV[4]);redis.call('EXPIRE',KEYS[3],172800);return 0;`,3,...keys,now,AI_LIMITS.concurrency,AI_LIMITS.requestsPerMinute,tokens,AI_LIMITS.tokensPerDay,now+timeoutMs+15000,token,timeoutMs+30000).catch(()=>{throw new PublicError('AI generation temporarily unavailable','AI_UNAVAILABLE',503);}) as number;
  if(result)throw new PublicError('AI generation budget is busy or exhausted. Retry later.','AI_BUDGET_EXCEEDED',429,result===3?3600:5);
  return async()=>{await client.zrem(keys[0],token).catch(()=>{});};
}
