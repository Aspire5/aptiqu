const test=require('node:test'),assert=require('node:assert/strict'),path=require('node:path');
const {loader,fixture,users}=require('./pvp-test-fixture.cjs');
const {readFixture}=require('./ranked-read-fixture.cjs');
const pure=loader({});
const {ratingWindow,candidatesCompatible,DEFAULT_MATCHMAKING_POLICY:p}=pure(path.join(__dirname,'../ranked/ranked-matchmaking-policy.ts'));
const entry=(userId,extra={})=>({userId,token:userId,rating:1200,standingVersion:0,seasonId:'2026-10',policyId:'ranked-v1',ratingMode:'RATED',capability:1,league:'UNRANKED',joinedAt:0,expiresAt:1000000,state:'QUEUED',...extra});
test('narrow window lasts the full first minute, then broadens stepwise both ways and respects the cap',()=>{
 assert.equal(ratingWindow(0),100);assert.equal(ratingWindow(59999),100);assert.equal(ratingWindow(60000),150);assert.equal(ratingWindow(74999),150);assert.equal(ratingWindow(75000),200);assert.equal(ratingWindow(999999),600);
 const a=entry(users[0]),b=entry(users[1],{rating:1340});assert.equal(candidatesCompatible(a,b,59999),false);assert.equal(candidatesCompatible(a,b,60000),true);
 b.rating=1060;assert.equal(candidatesCompatible(a,b,60000),true);b.joinedAt=59999;assert.equal(candidatesCompatible(a,b,60000),false);
});
test('league boundaries are not walls, and self, stale, expired, differently pinned or unrated tickets cannot pair',()=>{
 const a=entry(users[0],{rating:1449,league:'GOLD'}),b=entry(users[1],{rating:1450,league:'PLATINUM'});assert.equal(candidatesCompatible(a,b,1000),true);
 for(const extra of[{userId:a.userId},{seasonId:'2026-11'},{policyId:'other'},{ratingMode:'LEGACY_UNRATED'},{state:'CLAIMED'},{expiresAt:1000}])assert.equal(candidatesCompatible(a,{...b,...extra},1000),false);
});
test('queue adapter uses versioned atomic operations, server timestamps and owner tokens; Redis loss never falls back',async()=>{
 const {RedisRankedQueue,RANKED_QUEUE_LUA}=pure(path.join(__dirname,'../ranked/ranked-queue.ts'));const calls=[];
 const queue=new RedisRankedQueue(()=>({eval:async(...args)=>{calls.push(args);const input=JSON.parse(args.at(-2));return JSON.stringify({status:'WAITING_FOR_OPPONENT',now:60000,entry:{...entry(users[0]),...input,joinedAt:0}});}}),()=>p);
 const result=await queue.join(entry(users[0]),'server-token');assert.equal(queue.status(result).ratingWindow,150);assert.equal(calls[0][1],4);assert.ok(calls[0].slice(2,6).every(k=>k.includes('{ranked-v1}')));assert.equal(JSON.parse(calls[0].at(-2)).token,'server-token');
 await queue.cancel(users[0],'old-token');assert.equal(calls.at(-1)[6],'cancel');assert.equal(JSON.parse(calls.at(-1).at(-2)).token,'old-token');
 assert.ok(RANKED_QUEUE_LUA.includes("redis.call('TIME')"));assert.ok(RANKED_QUEUE_LUA.includes("e.token~=arg.token"));assert.ok(RANKED_QUEUE_LUA.includes('math.min(w,window(b))'));
 await assert.rejects(new RedisRankedQueue(()=>null).join(entry(users[0]),'x'),e=>e.code==='QUEUE_UNAVAILABLE');
 await assert.rejects(new RedisRankedQueue(()=>({eval:async()=>{throw new Error('PRIVATE_REDIS');}})).claim(),e=>e.code==='QUEUE_UNAVAILABLE'&&!e.message.includes('PRIVATE_REDIS'));
});
test('queue eligibility is read-only, capability-gated and blocks incomplete registration and unresolved cross-mode seats',async()=>{
 const f=readFixture(),{RankedEligibilityService}=f.load(path.join(__dirname,'../ranked/ranked-eligibility.service.ts'));
 const activation={enabled:true,launchSeason:'2026-10'},runtime={reads:true,skillMatchmaking:true};const service=new RankedEligibilityService(f.db,()=>activation,()=>runtime);f.row();
 await assert.rejects(service.inspect(f.users[0],0),e=>e.code==='RANKED_CLIENT_UPDATE_REQUIRED');const ticket=await service.inspect(f.users[0],1);assert.equal(ticket.rating,1500);assert.equal(ticket.league,'PLATINUM');assert.equal(f.state.rows.length,1);
 f.state.users.set(f.users[0],false);await assert.rejects(service.inspect(f.users[0],1),e=>e.code==='REGISTRATION_REQUIRED');f.state.users.set(f.users[0],true);
 f.state.friendly=1;await assert.rejects(service.inspect(f.users[0],1),e=>e.code==='FRIENDLY_DUEL_ACTIVE');f.state.friendly=0;f.state.active={matchId:f.matchId};await assert.rejects(service.inspect(f.users[0],1),e=>e.code==='MATCH_PENDING');f.state.active=null;
 runtime.skillMatchmaking=false;await assert.rejects(service.inspect(f.users[0],1),e=>e.code==='ADMISSION_PAUSED');
});
test('admission revalidation rejects stale ratings, versions and season pins instead of computing from queue data',async()=>{
 const f=readFixture(),{RankedEligibilityService}=f.load(path.join(__dirname,'../ranked/ranked-eligibility.service.ts'));const service=new RankedEligibilityService(f.db,()=>({enabled:true,launchSeason:'2026-10'}),()=>({reads:true,skillMatchmaking:true}));const row=f.row();const ticket=await service.inspect(f.users[0],1);await service.validate(f.db,ticket);
 for(const change of[{rating:1510},{version:4}]){const before={...row};Object.assign(row,change);await assert.rejects(service.validate(f.db,ticket),e=>e.code==='QUEUE_STALE');Object.assign(row,before);}
 f.setTime(Date.parse('2026-10-31T18:30:00Z'));f.season('2026-11');await assert.rejects(service.validate(f.db,ticket),e=>e.code==='QUEUE_STALE');assert.equal(f.state.rows.length,1);
});
test('rated match creation rejects a missing claim before selecting or generating content',async()=>{
 const f=fixture(),{PvpMatchService}=f.load(path.join(__dirname,'../services/pvp-match.service.ts'));const service=new PvpMatchService(f.db,()=>new Date(),()=>({enabled:true,launchSeason:'2026-10'}),()=>({reads:true,skillMatchmaking:true}));
 await assert.rejects(service.createMatch(...users),e=>e.code==='QUEUE_CLAIM_REQUIRED');assert.equal(f.state().writes,0);
});

test('ordered DB admission rejects a stale claimed estimate before creating any match',async()=>{
 const f=readFixture(),a=f.row(),b=f.row(f.users[1]);
 const activation=()=>({enabled:true,launchSeason:'2026-10'}),runtime=()=>({reads:true,skillMatchmaking:true});
 const {RankedEligibilityService}=f.load(path.join(__dirname,'../ranked/ranked-eligibility.service.ts')),{PvpMatchService}=f.load(path.join(__dirname,'../services/pvp-match.service.ts'));
 const eligibility=new RankedEligibilityService(f.db,activation,runtime),tickets=await Promise.all(f.users.map(id=>eligibility.inspect(id,1)));
 let writes=0;f.db.pvpMatch={findUnique:async()=>null,create:async()=>{writes++;throw new Error('Unexpected admission');}};
 const service=new PvpMatchService(f.db,()=>new Date(f.now()),activation,runtime);service.selectPvPSetForPlayers=async()=>({id:'set',setQuestions:fixture().state().match.questionSet.setQuestions});
 const claim={id:f.matchId,a:entry(f.users[0],tickets[0]),b:entry(f.users[1],tickets[1]),isActive:()=>true};a.rating+=32;a.version++;
 await assert.rejects(service.createMatch(...f.users,claim),e=>e.code==='QUEUE_STALE');assert.equal(writes,0);
});
test('a midnight boundary during admission cannot commit the old queue season into the new month',async()=>{
 const f=readFixture();f.row();f.row(f.users[1]);const activation=()=>({enabled:true,launchSeason:'2026-10'}),runtime=()=>({reads:true,skillMatchmaking:true});
 const {RankedEligibilityService}=f.load(path.join(__dirname,'../ranked/ranked-eligibility.service.ts')),{PvpMatchService}=f.load(path.join(__dirname,'../services/pvp-match.service.ts'));
 const eligibility=new RankedEligibilityService(f.db,activation,runtime),tickets=await Promise.all(f.users.map(id=>eligibility.inspect(id,1)));
 f.setTime(Date.parse('2026-10-31T18:29:59.999Z'));f.season('2026-11');f.row(f.users[0],{seasonId:'2026-11'});f.row(f.users[1],{seasonId:'2026-11'});
 const original=f.db.$queryRaw;let clocks=0,writes=0;
 f.db.$queryRaw=async(query,...args)=>{if(Array.isArray(query)&&query.join('').includes('clock_timestamp')&&++clocks===3)f.setTime(f.now()+1);return original(query,...args);};
 f.db.pvpMatch={findUnique:async()=>null,create:async()=>{writes++;throw new Error('Unexpected admission');}};
 const service=new PvpMatchService(f.db,()=>new Date(f.now()),activation,runtime);service.selectPvPSetForPlayers=async()=>({id:'set',setQuestions:fixture().state().match.questionSet.setQuestions});
 const claim={id:f.matchId,a:entry(f.users[0],tickets[0]),b:entry(f.users[1],tickets[1]),isActive:()=>true};
 await assert.rejects(service.createMatch(...f.users,claim),e=>e.code==='QUEUE_STALE');assert.equal(writes,0);
});
test('drain pauses new admission while the read service and persisted obligations remain available',async()=>{
 const f=readFixture(),{RankedEligibilityService}=f.load(path.join(__dirname,'../ranked/ranked-eligibility.service.ts'));
 const service=new RankedEligibilityService(f.db,()=>({enabled:false}),()=>({reads:true,skillMatchmaking:true,drain:true}));
 await assert.rejects(service.inspect(f.users[0],1),e=>e.code==='ADMISSION_PAUSED');assert.equal((await f.service.me(f.users[0])).standing.league,'UNRANKED');
});
