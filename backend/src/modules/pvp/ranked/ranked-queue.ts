import { randomUUID } from 'node:crypto';
import { PvpError } from '../pvp.errors';
import { MatchmakingPolicy, matchmakingPolicy, QueueCandidate, QueueClaim, QueueEntry, ratingWindow } from './ranked-matchmaking-policy';

export interface QueueRedis { eval(script: string, numberOfKeys: number, ...args: (string | number)[]): Promise<unknown> }
// One hash tag keeps the four keys in the same Redis cluster slot. Only this
// versioned namespace is touched; no legacy queue or unrelated keys are flushed.
export const RANKED_QUEUE_KEYS = ['wait', 'rating', 'entries', 'expiry'].map(suffix => `pvp:{ranked-v1}:queue:${suffix}`);
export const RANKED_QUEUE_LUA = `
local op=ARGV[1]
local arg=cjson.decode(ARGV[2])
local p=cjson.decode(ARGV[3])
local clock=redis.call('TIME')
local now=tonumber(clock[1])*1000+math.floor(tonumber(clock[2])/1000)
local function get(id)
  local raw=redis.call('HGET',KEYS[3],id)
  if not raw then return nil end
  return cjson.decode(raw)
end
local function erase(id)
  redis.call('ZREM',KEYS[1],id)
  redis.call('ZREM',KEYS[2],id)
  redis.call('HDEL',KEYS[3],id)
  redis.call('ZREM',KEYS[4],id)
end
local function put(e)
  redis.call('HSET',KEYS[3],e.userId,cjson.encode(e))
  redis.call('ZADD',KEYS[4],e.expiresAt,e.userId)
  if e.state=='QUEUED' then
    redis.call('ZADD',KEYS[1],e.joinedAt,e.userId)
    redis.call('ZADD',KEYS[2],e.rating,e.userId)
  end
end
local expired=redis.call('ZRANGEBYSCORE',KEYS[4],'-inf',now,'LIMIT',0,128)
for _,id in ipairs(expired) do local e=get(id); if not e or e.expiresAt<=now then erase(id) end end
local function result(status,e) return cjson.encode({status=status,entry=e,now=now}) end
if op=='join' then
  local old=get(arg.userId)
  if old and old.expiresAt>now and old.state=='CLAIMED' then return result('PAIRING',old) end
  local e=arg
  e.joinedAt=old and old.state=='QUEUED' and old.expiresAt>now and old.joinedAt or now
  e.state='QUEUED'; e.expiresAt=now+p.queueLeaseMs; e.claimId=nil
  put(e); return result('WAITING_FOR_OPPONENT',e)
elseif op=='cancel' then
  local e=get(arg.userId)
  if not e then return result('LEFT_QUEUE',nil) end
  if e.token~=arg.token then return result('STALE',nil) end
  if e.state=='CLAIMED' then return result('PAIRING',nil) end
  erase(e.userId); return result('LEFT_QUEUE',nil)
elseif op=='touch' then
  local e=get(arg.userId)
  if not e or e.token~=arg.token or e.expiresAt<=now then return result('EXPIRED',nil) end
  if e.state=='CLAIMED' then return result('PAIRING',nil) end
  e.expiresAt=now+p.queueLeaseMs; put(e); return result('WAITING_FOR_OPPONENT',e)
elseif op=='renew' or op=='finish' then
  local a=get(arg.a.userId); local b=get(arg.b.userId)
  local function owned(e,expected) return e and e.expiresAt>now and e.token==expected.token and e.state=='CLAIMED' and e.claimId==arg.id end
  if op=='renew' then
    if not owned(a,arg.a) or not owned(b,arg.b) then return result('LOST',nil) end
    a.expiresAt=now+p.claimLeaseMs; b.expiresAt=now+p.claimLeaseMs; put(a); put(b)
    return result('RENEWED',nil)
  end
  if owned(a,arg.a) then erase(a.userId) end
  if owned(b,arg.b) then erase(b.userId) end
  return result('FINISHED',nil)
elseif op=='claim' then
  local function window(e)
    local wait=math.max(0,now-e.joinedAt)
    if wait<p.narrowMs then return p.narrowWindow end
    return math.min(p.maximumWindow,p.narrowWindow+(1+math.floor((wait-p.narrowMs)/p.expandEveryMs))*p.expandBy)
  end
  local size=redis.call('ZCARD',KEYS[1])
  local offset=arg.offset
  if offset>=size then offset=0 end
  local seeds=redis.call('ZRANGE',KEYS[1],offset,offset+31)
  local nextOffset=offset+32; if nextOffset>=size then nextOffset=0 end
  for _,id in ipairs(seeds) do
    local a=get(id)
    if a and a.state=='QUEUED' and a.expiresAt>now and a.ownerId==arg.ownerId then
      local w=window(a)
      local below=redis.call('ZREVRANGEBYSCORE',KEYS[2],a.rating,a.rating-w,'LIMIT',0,32)
      local above=redis.call('ZRANGEBYSCORE',KEYS[2],a.rating,a.rating+w,'LIMIT',0,32)
      local best=nil; local distance=nil; local bestRepeat=nil
      for pass=1,2 do
        local candidates=pass==1 and below or above
        for _,other in ipairs(candidates) do
          local b=get(other)
          if b and b.userId~=a.userId and b.state=='QUEUED' and b.expiresAt>now and b.ownerId==arg.ownerId
            and b.ratingMode==a.ratingMode and b.seasonId==a.seasonId and b.policyId==a.policyId then
            local gap=math.abs(a.rating-b.rating)
            local repeated=(a.recentOpponentId==b.userId and a.recentOpponentUntil and a.recentOpponentUntil>now) or (b.recentOpponentId==a.userId and b.recentOpponentUntil and b.recentOpponentUntil>now) or false
            if gap<=math.min(w,window(b)) and (not best or (bestRepeat and not repeated) or (bestRepeat==repeated and (gap<distance
              or (gap==distance and (b.joinedAt<best.joinedAt or (b.joinedAt==best.joinedAt and b.userId<best.userId)))))) then best=b; distance=gap; bestRepeat=repeated end
          end
        end
      end
      if best then
        a.state='CLAIMED'; best.state='CLAIMED'; a.claimId=arg.id; best.claimId=arg.id
        a.expiresAt=now+p.claimLeaseMs; best.expiresAt=now+p.claimLeaseMs
        redis.call('ZREM',KEYS[1],a.userId,best.userId); redis.call('ZREM',KEYS[2],a.userId,best.userId)
        put(a); put(best)
        return cjson.encode({status='CLAIMED',now=now,nextOffset=nextOffset,claim={id=arg.id,a=a,b=best}})
      end
    end
  end
  return cjson.encode({status='EMPTY',now=now,nextOffset=nextOffset})
end
return redis.error_reply('Unknown ranked queue operation')
`;
interface QueueReply { status: string; now: number; entry?: QueueEntry; claim?: QueueClaim; nextOffset?: number }
export class RedisRankedQueue {
  private offset = 0;
  private readonly ownerId = randomUUID();
  constructor(private readonly client: () => QueueRedis | null, private readonly policy: () => MatchmakingPolicy = matchmakingPolicy,
    private readonly keys = RANKED_QUEUE_KEYS) {}
  private async run(op: string, argument: unknown): Promise<QueueReply> {
    const client = this.client();
    if (!client) throw new PvpError('Match search is temporarily unavailable. Please retry.', 'QUEUE_UNAVAILABLE', 503);
    try {
      let timer: ReturnType<typeof setTimeout> | undefined;
      let raw: unknown;
      try {
        raw = await Promise.race([client.eval(RANKED_QUEUE_LUA, this.keys.length, ...this.keys, op, JSON.stringify(argument), JSON.stringify(this.policy())),
          new Promise((_, reject) => { timer = setTimeout(() => reject(new Error('Queue deadline')), 2500); })]);
      } finally { clearTimeout(timer); }
      if (typeof raw !== 'string') throw new Error();
      const result = JSON.parse(raw) as QueueReply;
      if (!Number.isFinite(result.now) || typeof result.status !== 'string') throw new Error();
      return result;
    } catch (error) {
      if (error instanceof PvpError) throw error;
      throw new PvpError('Match search is temporarily unavailable. Please retry.', 'QUEUE_UNAVAILABLE', 503);
    }
  }
  join(candidate: QueueCandidate, token: string) { return this.run('join', { ...candidate, token, ownerId: this.ownerId }); }
  cancel(userId: string, token: string) { return this.run('cancel', { userId, token }); }
  touch(userId: string, token: string) { return this.run('touch', { userId, token }); }
  async claim(): Promise<QueueClaim | null> {
    const result = await this.run('claim', { id: randomUUID(), offset: this.offset, ownerId: this.ownerId });
    this.offset = result.nextOffset ?? 0;
    return result.claim ?? null;
  }
  async renew(claim: QueueClaim) { return (await this.run('renew', claim)).status === 'RENEWED'; }
  async finish(claim: QueueClaim) { await this.run('finish', claim); }
  status(reply: QueueReply) {
    const wait = reply.entry ? Math.max(0, reply.now - reply.entry.joinedAt) : 0;
    return { status: reply.status, waitedMs: wait, searchExpanded: wait >= 60000,
      ratingWindow: reply.entry ? ratingWindow(wait, this.policy()) : null, serverNow: new Date(reply.now).toISOString() };
  }
}
