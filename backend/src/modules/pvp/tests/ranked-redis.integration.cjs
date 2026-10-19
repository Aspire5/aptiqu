// No Redis connection unless explicitly enabled with an isolated local DB URL.
const test=require('node:test'),assert=require('node:assert/strict'),path=require('node:path'),{randomUUID}=require('node:crypto');
const {loader,users}=require('./pvp-test-fixture.cjs');
test('Ranked Lua ownership, cancellation, symmetric widening, expiry and duplicate claims', {skip:process.env.RANKED_ALLOW_REDIS_TESTS!=='true',timeout:15000},async()=>{
 const raw=process.env.RANKED_TEST_REDIS_URL;assert.ok(raw,'A dedicated test URL is required; REDIS_URL is never used.');const url=new URL(raw);
 assert.ok(['localhost','127.0.0.1','[::1]'].includes(url.hostname));assert.match(url.pathname,/^\/(1[0-5])$/,'Use an isolated Redis test DB, index 10–15.');
 const Redis=require('ioredis'),client=new Redis(raw,{lazyConnect:true,enableOfflineQueue:false,maxRetriesPerRequest:0,connectTimeout:2000});
 const load=loader({}),{RedisRankedQueue}=load(path.join(__dirname,'../ranked/ranked-queue.ts')),{DEFAULT_MATCHMAKING_POLICY}=load(path.join(__dirname,'../ranked/ranked-matchmaking-policy.ts'));
 const prefix=`aptiqu-test:{ranked-${randomUUID()}}`,keys=['wait','rating','entries','expiry'].map(k=>`${prefix}:${k}`),queue=new RedisRankedQueue(()=>client,()=>DEFAULT_MATCHMAKING_POLICY,keys);
 const candidate=(userId,rating)=>({userId,rating,standingVersion:0,seasonId:'2026-10',policyId:'ranked-v1',ratingMode:'RATED',capability:1,league:'UNRANKED'});
 async function age(userId,ageMs){const entry=JSON.parse(await client.hget(keys[2],userId));const time=await client.time();const now=Number(time[0])*1000+Math.floor(Number(time[1])/1000);entry.joinedAt=now-ageMs;await client.hset(keys[2],userId,JSON.stringify(entry));await client.zadd(keys[0],entry.joinedAt,userId);}
 async function expireBehindPruneBatch(userId){
  const e=JSON.parse(await client.hget(keys[2],userId));e.expiresAt=1;
  const batch=client.pipeline().hset(keys[2],userId,JSON.stringify(e)).zadd(keys[3],1,userId);
  for(let i=0;i<129;i++){const id=`expired-${i}`;batch.hset(keys[2],id,JSON.stringify({expiresAt:0})).zadd(keys[3],0,id);}
  const replies=await batch.exec();for(const [error] of replies)assert.equal(error,null);
 }
 try{
  await client.connect();
  const a=await queue.join(candidate(users[0],1200),'old');await queue.join(candidate(users[0],1200),'new');assert.equal((await queue.touch(users[0],'new')).entry.joinedAt,a.entry.joinedAt);
  assert.equal((await queue.cancel(users[0],'old')).status,'STALE');assert.equal(await client.zcard(keys[0]),1);
  await queue.join(candidate(users[1],1340),'b');assert.equal(await queue.claim(),null);
  await age(users[0],60001);assert.equal(await queue.claim(),null); // A fresh opponent still has its narrow window.
  await age(users[1],60001);assert.equal(await new RedisRankedQueue(()=>client,()=>DEFAULT_MATCHMAKING_POLICY,keys).claim(),null);const results=await Promise.all([queue.claim(),queue.claim()]);assert.equal(results.filter(Boolean).length,1);
  const claim=results.find(Boolean);assert.equal((await queue.cancel(users[0],'new')).status,'PAIRING');assert.equal(await queue.renew(claim),true);
  await queue.finish(claim);assert.equal(await client.hlen(keys[2]),0);
  await queue.join(candidate(users[0],1200),'fresh');await queue.finish(claim);assert.equal((await queue.touch(users[0],'fresh')).status,'WAITING_FOR_OPPONENT');
  await expireBehindPruneBatch(users[0]);assert.equal((await queue.touch(users[0],'fresh')).status,'EXPIRED');
  await queue.join(candidate(users[0],1200),'lease-a');await queue.join(candidate(users[1],1200),'lease-b');
  const expiringClaim=await queue.claim();assert.ok(expiringClaim);await expireBehindPruneBatch(users[0]);
  assert.equal(await queue.renew(expiringClaim),false,'An expired claim cannot revive beyond the bounded prune batch.');
 }finally{if(client.status==='ready')await client.del(...keys);client.disconnect();}
});
