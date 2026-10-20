const test=require('node:test'),assert=require('node:assert/strict'),path=require('node:path');
const {readFixture}=require('./ranked-read-fixture.cjs');
const {loader}=require('./pvp-test-fixture.cjs');
test('own ordinal, league, placement and lifetime provisional state share a Repeatable Read observation',async()=>{
 const f=readFixture();f.row();f.row(f.users[1]);f.row(f.outsider,{rating:1700});
 const me=await f.service.me(f.users[1],{fresh:true});assert.equal(me.standing.position,3);assert.equal(me.standing.league,'PLATINUM');assert.equal(me.standing.ratingIsProvisional,false);assert.equal(me.standing.nextLeague.remaining,200);assert.equal(f.state.transactions.at(-1).isolationLevel,'RepeatableRead');
});
test('effective seed is read-only, preserves initial qualification and finds previous-month active matches',async()=>{
 const f=readFixture();f.season('2026-09');f.row(f.users[0],{seasonId:'2026-09',rating:1390,played:8,careerRatedBefore:0,placementsRequired:10,qualifiedAt:null,qualifiedPeakRating:null});
 f.state.active={match:{id:f.matchId,seasonId:'2026-09',status:'QUESTION_TRANSITION',stateVersion:20}};
 const me=await f.service.me(f.users[0]);assert.equal(me.standing.hasRecord,false);assert.equal(me.standing.rating,1390);assert.equal(me.standing.placements.required,3);assert.equal(me.standing.position,null);assert.equal(me.standing.peakRating,null);assert.equal(me.activeMatch.seasonId,'2026-09');assert.equal(me.seedPending,true);assert.equal(f.state.rows.length,1);
});
test('unpersisted current season is a preview, while explicit unknown seasons fail',async()=>{
 const f=readFixture();f.state.seasons.clear();const me=await f.service.me(f.users[0]);assert.equal(me.season.status,'NOT_STARTED');assert.equal(me.season.policyId,null);assert.equal(me.standing.rating,1200);await assert.rejects(f.service.me(f.users[0],{seasonId:'2026-08',fresh:true}),e=>e.code==='SEASON_NOT_FOUND');assert.equal(f.state.seasons.size,0);
});
test('qualified board pages whitelist identity and recompute current ordinals despite live movement',async()=>{
 const f=readFixture();f.row();f.row(f.users[1]);const newcomer=f.row(f.outsider,{rating:1800,qualifiedAt:null,played:1});
 const first=await f.service.leaderboard(f.users[0],{limit:1});assert.equal(first.entries[0].userId,f.users[0]);assert.equal(first.entries[0].position,1);assert.ok(first.nextCursor);assert.ok(!JSON.stringify(first).includes('NEVER_EXPOSE'));
 Object.assign(newcomer,{qualifiedAt:new Date(f.now()),played:10});
 const second=await f.service.leaderboard(f.users[0],{limit:1,cursor:first.nextCursor});assert.equal(second.entries[0].userId,f.users[1]);assert.equal(second.entries[0].position,3);
 const sql=f.state.queries.at(-1);assert.ok(sql.sql.includes('ahead.user_id<first.user_id'));assert.ok(sql.sql.includes('row_number() OVER'));assert.ok(!sql.sql.includes(f.users[0]));assert.ok(sql.values.includes(f.users[0]));
 await assert.rejects(f.service.leaderboard(f.users[0],{limit:1,cursor:first.nextCursor+'x'}),e=>e.code==='CURSOR_RESET');f.setTime(f.now()+300001);await assert.rejects(f.service.leaderboard(f.users[0],{limit:1,cursor:first.nextCursor}),e=>e.code==='CURSOR_RESET');
});
test('final board and played-season history use frozen rating, league, peak and position',async()=>{
 const f=readFixture();f.season('2026-09',{settlementState:'FINALIZED',finalizedAt:new Date(f.now()-10000),eligibleCount:1});f.row(f.users[0],{seasonId:'2026-09',rating:1700,finalRating:1450,finalPeakRating:1500,finalLeague:'PLATINUM',finalPosition:1,finalizedAt:new Date(f.now()-10000)});f.row(f.users[0],{played:0,qualifiedAt:null});
 const board=await f.service.leaderboard(f.users[0],{seasonId:'2026-09',limit:25});assert.equal(board.entries[0].rating,1450);assert.equal(board.pagination,'FINALIZED_STABLE');const history=await f.service.seasons(f.users[0],{limit:12});assert.equal(history.entries.length,1);assert.equal(history.entries[0].standing.peakRating,1500);assert.equal((await f.service.me(f.users[0],{seasonId:'2026-09',fresh:true})).standing.position,1);
});
test('owner cache, fresh bypass and exact-month expiry do not leak or pin stale current months',async()=>{
 const f=readFixture(),a=f.row();f.row(f.users[1],{rating:1350});assert.equal((await f.service.me(f.users[0])).standing.rating,1500);a.rating=1550;assert.equal((await f.service.me(f.users[0])).standing.rating,1500);assert.equal((await f.service.me(f.users[0],{fresh:true})).standing.rating,1550);assert.equal((await f.service.me(f.users[1])).standing.rating,1350);f.cache.invalidate([f.users[0]]);assert.equal((await f.service.me(f.users[0])).standing.rating,1550);
 f.setTime(Date.parse('2026-10-31T18:29:59.999Z'));f.cache.invalidate([f.users[0]]);await f.service.me(f.users[0]);f.setTime(f.now()+1);f.season('2026-11');assert.equal((await f.service.me(f.users[0])).season.id,'2026-11');
});
test('single-flight invalidation prevents a pre-settlement read from repopulating the cache',async()=>{
 const f=readFixture(),{RankedReadCache}=f.load(path.join(__dirname,'../ranked/ranked-cache.ts')),cache=new RankedReadCache(()=>0,2);let release,loads=0;const gate=new Promise(resolve=>{release=resolve;});const old=cache.get('me:a:current',async()=>{loads++;await gate;return'old';}),duplicate=cache.get('me:a:current',()=>Promise.resolve('bad'));cache.invalidate(['a']);release();assert.equal(await old,'old');assert.equal(await duplicate,'old');assert.equal(loads,1);assert.equal(await cache.get('me:a:current',()=>Promise.resolve('new')),'new');
});
test('read authorization, disabled flags and optional section failures never fabricate zero Elo',async()=>{
 const f=readFixture();f.state.users.set(f.users[0],false);await assert.rejects(f.service.me(f.users[0]),e=>e.status===403);await assert.rejects(f.service.leaderboard('unknown',{limit:25}),e=>e.status===401);f.state.users.set(f.users[0],true);f.state.fail=true;assert.equal((await f.service.compact(f.users[0])).status,'UNAVAILABLE');f.runtime.reads=false;assert.equal((await f.service.compact(f.users[0])).status,'DISABLED');
});
test('route query validation rejects arrays, extra identities, invalid months and deep pagination; errors stay safe',async()=>{
 const f=readFixture(),load=loader({'./ranked-query.service':{rankedQueryService:f.service},'./ranked/ranked-history.service':{rankedHistoryService:{history:async()=>{throw new Error('SECRET_SQL');}}},'./services/pvp-match.service':{pvpMatchService:{}}});
 const {RankedController}=load(path.join(__dirname,'../ranked/ranked.controller.ts')),{PvpController}=load(path.join(__dirname,'../pvp.controller.ts'));
 const response=()=>({headers:{},setHeader(k,v){this.headers[k]=v;},status(v){this.code=v;return this;},json(v){this.body=v;}});
 for(const query of[{limit:'0'},{limit:'51'},{limit:['2']},{limit:'0x10'},{seasonId:'2026-13'},{seasonId:'0001-01'},{cursor:'x'.repeat(2049)},{userId:f.users[1]}]){const r=response();await RankedController.leaderboard({userId:f.users[0],query},r);assert.equal(r.code,400);}
 let r=response();await RankedController.me({query:{}},r);assert.equal(r.code,401);r=response();await PvpController.getPlayerHistory({userId:f.users[0],query:{page:'1000',limit:'50'}},r);assert.equal(r.code,400);r=response();await PvpController.getPlayerHistory({userId:f.users[0],query:{}},r);assert.equal(r.code,503);assert.equal(r.headers['Retry-After'],'5');assert.ok(!JSON.stringify(r.body).includes('SECRET_SQL'));
});
test('history preserves existing fields and returns only own ledger with opt-in void rows',async()=>{
 const f=readFixture(),{RankedHistoryService}=f.load(path.join(__dirname,'../ranked/ranked-history.service.ts'));f.state.history=[{matchId:f.matchId,userId:f.users[0],score:2,totalResponseTimeMs:1000,xpAwarded:130,isWinner:true,joinedAt:new Date(f.now()),ratingChanges:[{id:'event',ratingBefore:1200,delta:32,ratingAfter:1232}],match:{status:'COMPLETED',totalQuestions:10,isTie:false,seasonId:'2026-10',ratingMode:'RATED',outcomeReason:'NORMAL',settlement:{disposition:'RATED',settledAt:new Date(f.now())},players:[{userId:f.users[1],score:1,user:{profile:{firstName:'Other',lastName:'Learner',avatarUrl:null,email:'NEVER_EXPOSE'},gameStats:{level:2}}}]}}];let args;const original=f.db.pvpMatchPlayer.findMany;f.db.pvpMatchPlayer.findMany=async q=>{args=q;return original(q);};const service=new RankedHistoryService(f.db,async()=>{}),out=await service.history(f.users[0],{page:1,limit:10});assert.equal(out.history[0].rating.delta,32);assert.equal(out.history[0].opponent.name,'Other Learner');assert.equal(args.where.userId,f.users[0]);assert.equal(args.where.match.OR.length,1);assert.ok(!JSON.stringify(out).includes('NEVER_EXPOSE'));await service.history(f.users[0],{page:1,limit:10,includeVoids:true});assert.equal(args.where.match.OR.length,2);
});
test('per-owner transport limits reject bursts and reset after the configured window',()=>{
 const f=readFixture(),{RankedRateLimit}=f.load(path.join(__dirname,'../ranked/ranked-rate-limit.ts'));let now=0;const budget=new RankedRateLimit(2,100,()=>now,2);budget.take('a');budget.take('a');assert.throws(()=>budget.take('a'),e=>e.status===429);now=100;budget.take('a');
});

test('valid signed cursors reset across month rollover and LIVE-to-FINAL board transitions',async()=>{
 const f=readFixture();f.row();f.row(f.users[1]);const page=await f.service.leaderboard(f.users[0],{limit:1});
 f.state.seasons.get('2026-10').settlementState='FINALIZED';
 await assert.rejects(f.service.leaderboard(f.users[0],{limit:1,cursor:page.nextCursor}),e=>e.code==='CURSOR_RESET');
 f.setTime(Date.parse('2026-10-31T18:30:00Z'));f.season('2026-11');
 await assert.rejects(f.service.leaderboard(f.users[0],{limit:1,cursor:page.nextCursor}),e=>e.code==='CURSOR_RESET');
});

test('a slow read consumes cache TTL and cannot extend an old-month observation beyond rollover',async()=>{
 const f=readFixture(),{RankedReadCache}=f.load(path.join(__dirname,'../ranked/ranked-cache.ts'));let now=0,release;
 const cache=new RankedReadCache(()=>now),gate=new Promise(resolve=>{release=resolve;});
 const pending=cache.get('me:a:current',async()=>{await gate;return'old-month';},()=>1000);
 now=2000;release();assert.equal(await pending,'old-month');
 assert.equal(await cache.get('me:a:current',async()=> 'new-month'),'new-month');
});
