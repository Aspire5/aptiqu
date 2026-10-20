// Explicitly authorized disposable local services only. Never reads DATABASE_URL or dotenv.
const test=require('node:test'),assert=require('node:assert/strict'),path=require('node:path');
const {randomUUID}=require('node:crypto');const {loader}=require('../../modules/pvp/tests/pvp-test-fixture.cjs');
test('Stage 2 catalog, projections, ownership and shared controls',{skip:process.env.STAGE2_ALLOW_LOCAL_TESTS!=='true',timeout:60000},async t=>{
 const raw=process.env.STAGE2_TEST_DATABASE_URL;assert.ok(raw);const url=new URL(raw);assert.equal(url.hostname,'127.0.0.1');assert.equal(url.port,'55439');assert.match(url.pathname,/^\/aptiqu_stage2_test_[a-z0-9_]+$/);
 const redisUrl=new URL(process.env.STAGE2_TEST_REDIS_URL);assert.equal(redisUrl.hostname,'127.0.0.1');assert.equal(redisUrl.port,'56439');assert.equal(redisUrl.pathname,'/5');
 const {PrismaClient}=require('@prisma/client');const db=new PrismaClient({datasources:{db:{url:raw}},log:[{emit:'event',level:'query'}]});
 let queries=[];db.$on('query',event=>queries.push(event.query));
 const Redis=require('ioredis'),redis=new Redis(redisUrl.href,{lazyConnect:true,maxRetriesPerRequest:0});await redis.connect();
 const ENV={REDIS_URL:redisUrl.href,GEMINI_API_KEY:'',GEMINI_MODEL:'fixture-model'};
 const deps={
  '../../config/prisma':{prisma:db},'../../../config/prisma':{prisma:db},'./prisma':{prisma:db},'../config/prisma':{prisma:db},
  '../config/env':{ENV},'./env':{ENV},'ioredis':{default:require('ioredis')},'../../config/env':{ENV,AI_LIMITS:{concurrency:1,requestsPerMinute:2,tokensPerDay:1000}},'../../../config/env':{ENV},
  crypto:{default:require('node:crypto')},
  './redis.service':{redisService:{get:async()=>null,set:async()=>{},setNx:async()=>true,del:async()=>{},delByPattern:async()=>{}}},
  '../lesson/services/redis.service':{redisService:{getClient:()=>redis}},
  '../pvp/ranked/ranked-query.service':{rankedQueryService:{}},'../daily-challenge/daily-challenge.service':{dailyChallengeService:{}},
  './friends.service':{lockUsers:async()=>{},friendPair:()=>[],publicUser:()=>{},publicUserSelect:{}},'./social.transport':{socialTransport:{notify:async()=>{}}},
  '../../config/queue-redis':{queueRedis:()=>{throw new Error('Worker must not be started by the reconciliation test')}},
  '../../queues/content-generation.queue':{contentGenQueue:{add:async()=>{}}},'../ai/services/daily-challenge-generation.service':{dailyChallengeGenerationService:{}},
  '../../ai/services/pvp-set-generation.service':{pvpSetGenerationService:{}},
 };
 const load=loader(deps);const source=p=>path.join(__dirname,'../../',p);
 const {AdminSyllabusService:syllabus}=load(source('modules/admin/admin-syllabus.service.ts'));
 const {AdminQuestionsService:questions}=load(source('modules/admin/admin-questions.service.ts'));
 const {roadmapProgressionService:roadmaps}=load(source('modules/roadmap/services/roadmap-progression.service.ts'));
 const {UserService}=load(source('modules/user/user.service.ts'));
 const {AdminDashboardService:dashboard}=load(source('modules/admin/admin-dashboard.service.ts'));
 const {AdminUsersService:adminUsers}=load(source('modules/admin/admin-users.service.ts'));
 const locks=load(source('modules/concurrency/concurrency-lock.service.ts'));
 const books=load(source('modules/admin/services/book-run.ts'));
 const {bookCancellationService:cancel}=load(source('modules/admin/services/book-cancellation.service.ts'));
 const {AiPromptService}=load(source('modules/ai/services/ai-prompt.service.ts'));
 const timing=load(source('config/timing-policy.ts'));
 const {reserveProvider}=load(source('modules/ai/provider-budget.ts'));
 const run=randomUUID();
 let subject,topic,subtopic,script;
 const qData=()=>({subtopicId:subtopic.id,subjectId:subject.id,topicId:topic.id,prompt:'2+2? '+run,options:[{id:'A',text:'4'},{id:'B',text:'5'},{id:'C',text:'6'},{id:'D',text:'7'}],correctAnswer:'A',explanation:'2+2=4',method:'Add',difficulty:'EASY',estimatedTimeSeconds:60,calculationMode:'MENTAL',hints:[]});
 const user=()=>db.user.create({data:{email:randomUUID()+'@stage2.invalid',googleId:randomUUID(),isRegistrationComplete:true,profile:{create:{firstName:'Fixture',lastName:'Learner',gender:'Non-Binary',country:'__proto__',religion:'constructor'}},gameStats:{create:{}},progress:{create:{totalXp:0,level:1}}}});
 function definition(scriptId=run,reference){return {schemaVersion:1,scriptId,version:1,entryNodeId:'same-node',metadata:{title:'Fixture',subjectId:subject.id,topicId:topic.id,subtopicId:subtopic.id},nodes:{'same-node':{id:'same-node',type:'QUESTION',content:{text:'2+2?'},questionReference:reference??{mode:'INLINE',inlineData:{prompt:'2+2?',options:[{id:'A',label:'4'},{id:'B',label:'5'}],correctOptionId:'A',explanation:'Add',difficulty:'EASY'}},transitions:[{targetNodeId:'done'}]},done:{id:'done',type:'COMPLETION',content:{text:'Done'},transitions:[]}}};}
 try{
  await t.test('admin content and its complete roadmap commit atomically; duplicate reconciliation is stable',async()=>{
   subject=await syllabus.createSubject({id:'stage2-'+run,name:'Fixture '+run});topic=await syllabus.createTopic({subjectId:subject.id,name:'Topic '+run});subtopic=await syllabus.createSubtopic({topicId:topic.id,name:'Subtopic '+run});
   script=await syllabus.createScript({title:'Script '+run,subjectId:subject.id,topicId:topic.id,subtopicId:subtopic.id,definition:definition(),status:'PUBLISHED'});
   const before=await db.scriptAssignment.count({where:{scriptId:script.script.id}});assert.ok(before>0);
   await Promise.all([roadmaps.syncRoadmapWithSyllabus(),roadmaps.syncRoadmapWithSyllabus()]);
   assert.equal(await db.scriptAssignment.count({where:{scriptId:script.script.id}}),before);
   const other=await db.roadmap.create({data:{id:'road-'+run,slug:'road-'+run,name:'Second'}});await roadmaps.syncRoadmapWithSyllabus(other.id);
   assert.ok(await db.roadmapStep.count({where:{roadmapId:other.id,topicId:topic.id,isActive:true}}));
   const seq=await db.roadmapStep.findMany({where:{topicId:topic.id}});assert.ok(seq.every(s=>s.sequence<1000));
  });
  await t.test('roadmap learner reads perform no catalog or default-user writes',async()=>{
   const u=await user();queries=[];await roadmaps.getUserActiveRoadmap(u.id);
   assert.ok(!queries.some(q=>/^\s*(INSERT|UPDATE|DELETE)/i.test(q)));assert.equal((await db.user.findUnique({where:{id:u.id}})).activeRoadmapId,null);
  });
  await t.test('reconciliation failure rolls back newly authored script/version instead of exposing a partial graph',async()=>{
   const before=await db.lessonScript.count();await db.$executeRawUnsafe(`CREATE OR REPLACE FUNCTION learning.stage2_fail_assignment() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'fixture reconciliation failure'; END $$`);await db.$executeRawUnsafe(`CREATE TRIGGER stage2_fail_assignment BEFORE INSERT ON learning.script_assignments FOR EACH ROW EXECUTE FUNCTION learning.stage2_fail_assignment()`);
   try{await assert.rejects(()=>syllabus.createScript({title:'Rollback '+run,subjectId:subject.id,topicId:topic.id,subtopicId:subtopic.id,definition:definition()}));}finally{await db.$executeRawUnsafe('DROP TRIGGER stage2_fail_assignment ON learning.script_assignments');}
   assert.equal(await db.lessonScript.count(),before);
  });
  await t.test('question, script hierarchy and graph validation reject inconsistent authoring',async()=>{
   await assert.rejects(()=>questions.createQuestion({...qData(),topicId:'other'}));
   await assert.rejects(()=>questions.createQuestion({...qData(),correctAnswer:'Z'}));
   const invalid=definition();invalid.nodes['same-node'].transitions=[{targetNodeId:'missing'}];await assert.rejects(()=>syllabus.createScript({title:'Bad',subjectId:subject.id,topicId:topic.id,definition:invalid}));
   await assert.rejects(()=>syllabus.updateScript(script.script.id,{title:'Stale',expectedVersion:999}));
   const editor=await syllabus.createScript({title:'Editor '+run,subjectId:subject.id,topicId:topic.id,subtopicId:subtopic.id,definition:definition()});
   const edited=await syllabus.updateScript(editor.script.id,{title:'Changed '+run,expectedVersion:1});assert.equal(edited.version.versionNumber,2);
   await assert.rejects(()=>syllabus.updateScript(editor.script.id,{title:'Stale metadata',expectedVersion:1}),e=>e.code==='VERSION_CONFLICT');
  });
  await t.test('inline solved identity includes the script and repository references count only once',async()=>{
   const u=await user();const second=await syllabus.createScript({title:'Second '+run,subjectId:subject.id,topicId:topic.id,subtopicId:subtopic.id,definition:definition()});
   const q=await questions.createQuestion(qData());
   const repository=await syllabus.createScript({title:'Reference '+run,subjectId:subject.id,topicId:topic.id,subtopicId:subtopic.id,definition:definition(run,{mode:'REPOSITORY',questionId:q.id})});
   for(const [item,questionId] of [[script,null],[second,null],[repository,q.id]]){
    const session=await db.lessonSession.create({data:{userId:u.id,scriptId:item.script.id,scriptVersionId:item.version.id,status:'ACTIVE',currentNodeId:'same-node',stateVersion:1}});
    await db.questionAttempt.create({data:{userId:u.id,sessionId:session.id,nodeId:'same-node',questionId,clientActionId:randomUUID(),rawAnswer:'A',isCorrect:true,score:1}});
   }
   const stats=await new UserService().getUserStats(u.id);assert.equal(stats.questions.easy.solved,3);assert.ok(stats.questions.easy.total>=3);
   const hard=await syllabus.createScript({title:'Wrapped '+run,subjectId:subject.id,topicId:topic.id,subtopicId:subtopic.id,definition:definition()});
   const wrapped=definition();wrapped.nodes['same-node'].questionReference.inlineData.difficulty='HARD';wrapped.nodes=Object.values(wrapped.nodes);
   await db.lessonScriptVersion.update({where:{id:hard.version.id},data:{definition:{script:wrapped}}});
   const session=await db.lessonSession.create({data:{userId:u.id,scriptId:hard.script.id,scriptVersionId:hard.version.id,status:'ACTIVE',currentNodeId:'same-node',stateVersion:1}});
   await db.questionAttempt.create({data:{userId:u.id,sessionId:session.id,nodeId:'same-node',clientActionId:randomUUID(),rawAnswer:'A',isCorrect:true,score:1}});
   assert.equal((await new UserService().getUserStats(u.id)).questions.hard.solved,1);
  });
  await t.test('admin analytics are grouped in SQL, use IST buckets and safely count demographic keys',async()=>{
   const growth=await dashboard.getUserGrowthTrends();assert.equal(growth.daily.length,7);assert.equal(growth.weekly.length,4);assert.equal(growth.monthly.length,12);
   assert.equal((await dashboard.getActivityTrends()).length,7);assert.ok(Array.isArray(await dashboard.getDailyStreakHistory()));
   const stats=await adminUsers.getUserStats();assert.ok(stats.byGender.OTHER>=1);assert.ok(stats.byCountry.some(row=>row.name==='__proto__'));assert.ok(stats.byReligion.some(row=>row.name==='constructor'));
  });
  await t.test('filtered achievement analytics and narrow profile facts preserve their result contracts',async()=>{
   const u=await user();await db.gameStats.update({where:{userId:u.id},data:{highestStreak:2}});
   await db.achievement.create({data:{title:'Stage2 '+run,description:'Fixture',metric:'BEST_STREAK',source:'ALL',target:1}});
   const {achievementAnalyticsQuery}=load(source('modules/achievements/achievement.analytics.ts'));
   const [result]=await db.$queryRaw(achievementAnalyticsQuery(1,10,run,'ACTIVE'));assert.equal(result.payload.total,1);assert.ok(result.payload.items[0].completed>=1);
   const {HomeService}=load(source('modules/home/home.service.ts'));const facts=await new HomeService().getPublicProfileFacts(u.id);
   assert.ok(facts.activity.length<=31);assert.equal(facts.performance.attempted,0);assert.equal(facts.ranked,null);
  });
  await t.test('Ranked page ordinals remain global and deterministic for ties and stale cursors',async()=>{
   const {RankedSeasonService}=load(source('modules/pvp/ranked/ranked-season.service.ts'));
   const {seasonAt}=load(source('modules/pvp/ranked/ranked-season-time.ts'));const now=new Date(),seasonId=seasonAt(now).id;
   await db.$transaction(tx=>new RankedSeasonService(db,()=>({enabled:true,launchSeason:seasonId})).ensureCalendar(tx,now));
   const users=[];for(let i=0;i<4;i++)users.push(await user());users.sort((a,b)=>a.id.localeCompare(b.id));
   for(let i=0;i<4;i++)await db.rankedPlayerSeason.create({data:{seasonId,userId:users[i].id,seedRating:1200,rating:[1500,1400,1400,1300][i],peakRating:1500,qualifiedPeakRating:1500,careerRatedBefore:0,placementsRequired:1,played:1,wins:1,version:1,qualifiedAt:now}});
   const {leaderboardQuery}=load(source('modules/pvp/ranked/ranked-queries.ts'));
   const page=await db.$queryRaw(leaderboardQuery(seasonId,2,false));
   // Earlier test runs may have added standings: compare against the same snapshot's full reference order.
   const ordered=await db.rankedPlayerSeason.findMany({where:{seasonId,qualifiedAt:{not:null}},orderBy:[{rating:'desc'},{userId:'asc'}]});
   for(const row of page)assert.equal(row.position,ordered.findIndex(item=>item.userId===row.userId)+1);
   const after=await db.$queryRaw(leaderboardQuery(seasonId,3,false,{rating:1450,userId:users[0].id}));for(const row of after)assert.equal(row.position,ordered.findIndex(item=>item.userId===row.userId)+1);
  });
  await t.test('Daily history uses a database average across all completed attempts, independent of pagination',async()=>{
   const u=await user();
   for(let i=1;i<=3;i++){
    const dateString=`2050-01-0${i}`;
    const script=await db.dailyChallengeScript.upsert({where:{dateString_tier:{dateString,tier:1}},create:{dateString,tier:1,questionCount:1},update:{}});
    await db.dailyChallengeParticipation.create({data:{userId:u.id,scriptId:script.id,dateString,status:'COMPLETED',totalQuestions:1,correctCount:1,streakAtAttempt:0,totalTimeMs:i*1000,avgTimeMs:i*1000,completedAt:new Date()}});
   }
   const {DailyChallengeService}=load(source('modules/daily-challenge/daily-challenge.service.ts'));
   const result=await new DailyChallengeService(db).getHistory(u.id,1,2);
   assert.equal(result.history.length,2);assert.equal(result.stats.totalCompleted,3);assert.equal(result.stats.overallAvgTimeMs,2000);
  });
  await t.test('generation lease fences expired owners and releasing an old token cannot delete a replacement',async()=>{
   const scope='fixture-'+run,first=await locks.ConcurrencyLockService.acquireLock(scope,60000);assert.ok(first);
   assert.equal(await locks.ConcurrencyLockService.acquireLock(scope,60000),null);await db.generationLease.update({where:{scope},data:{expiresAt:new Date(0)}});
   const second=await locks.ConcurrencyLockService.acquireLock(scope,60000);assert.ok(second&&second!==first);
   try{await assert.rejects(()=>locks.ConcurrencyLockService.runWithLease(scope,first,()=>locks.generationDb.question.create({data:{...qData(),fingerprint:randomUUID()}})),/lease/);
    await locks.ConcurrencyLockService.releaseLock(scope,first);assert.equal((await db.generationLease.findUnique({where:{scope}})).token,second);
    await locks.ConcurrencyLockService.runWithLease(scope,second,()=>locks.generationDb.question.create({data:{...qData(),fingerprint:randomUUID()}}));
   }finally{await locks.ConcurrencyLockService.releaseLock(scope,first);await locks.ConcurrencyLockService.releaseLock(scope,second);}
  });
  await t.test('book processing has one owner, durable cancellation and a write fence after cancellation',async()=>{
   const ownerSubject=await db.subject.create({data:{id:'book-'+run,slug:'book-'+run,name:'Book fixture'}});
   const book=await db.bookSource.create({data:{subjectId:ownerSubject.id,title:'Fixture',storagePath:'/fixture-not-read.pdf',fileSizeBytes:0,fileChecksum:run}});
   await books.withBookRun(book.id,async()=>{
    await assert.rejects(()=>books.withBookRun(book.id,async()=>{}),/active processing owner/);
    await books.prisma.bookSource.update({where:{id:book.id},data:{metadata:{accepted:true}}});await cancel.cancel(book.id);
    await assert.rejects(()=>books.prisma.bookSource.update({where:{id:book.id},data:{metadata:{stale:true}}}),/CANCELLED/);
   },0);
   assert.equal(await cancel.isCancelled(book.id),true);assert.equal((await db.bookSource.findUnique({where:{id:book.id}})).metadata.stale,undefined);
   await cancel.reset(book.id);await assert.rejects(()=>books.withBookRun(book.id,async()=>{},0),/CANCELLED/);
  });
  await t.test('book publication validates hierarchy atomically and publishes only the latest version',async()=>{
   const book=await db.bookSource.create({data:{subjectId:subject.id,title:'Publish fixture',storagePath:'/fixture-not-read.pdf',fileSizeBytes:0,fileChecksum:'publish-'+run}});
   const current=await db.lessonScriptVersion.findUnique({where:{id:script.version.id}});
   await db.lessonScriptVersion.create({data:{scriptId:script.script.id,versionNumber:2,definition:current.definition,checksum:'fixture',status:'DRAFT'}});
   await db.lessonScriptVersion.create({data:{scriptId:script.script.id,versionNumber:3,definition:current.definition,checksum:'fixture',status:'DRAFT'}});
   const q=await db.question.findFirstOrThrow({where:{subjectId:subject.id}});
   const other=await db.topic.create({data:{id:'other-'+run,subjectId:subject.id,slug:'other-'+run,name:'Other fixture'}});
   await db.question.update({where:{id:q.id},data:{topicId:other.id}});
   const {bookPublishingService}=load(source('modules/admin/services/book-publishing.service.ts'));
   await assert.rejects(()=>bookPublishingService.publishBook(book.id),/hierarchy|different topic/);
   assert.equal((await db.lessonScriptVersion.findUnique({where:{scriptId_versionNumber:{scriptId:script.script.id,versionNumber:2}}})).status,'DRAFT');
   await db.question.update({where:{id:q.id},data:{topicId:topic.id}});
   await bookPublishingService.publishBook(book.id);
   assert.equal((await db.lessonScriptVersion.findUnique({where:{scriptId_versionNumber:{scriptId:script.script.id,versionNumber:4}}})).status,'PUBLISHED');
   assert.equal((await db.lessonScriptVersion.findUnique({where:{scriptId_versionNumber:{scriptId:script.script.id,versionNumber:3}}})).status,'DRAFT');
   assert.equal((await db.lessonScriptVersion.findUnique({where:{scriptId_versionNumber:{scriptId:script.script.id,versionNumber:2}}})).status,'DRAFT');
  });
  await t.test('prompt edits use revision CAS and another service sees published changes immediately',async()=>{
   const key='FIXTURE_'+run;await db.aiPrompt.create({data:{key,title:'Fixture',category:'SERVER_GENERATION',draftPrompt:'first',publishedPrompt:'first',version:1}});
   const a=new AiPromptService(),b=new AiPromptService();const edits=await Promise.allSettled([a.saveDraft(key,'second',1),b.saveDraft(key,'other',1)]);assert.equal(edits.filter(r=>r.status==='fulfilled').length,1);
   await a.publishPrompt(key,2);const current=await b.getPublishedPromptSnapshot(key);assert.equal(current.version,'2');assert.notEqual(current.text,'first');await assert.rejects(()=>b.publishPrompt(key,1),e=>e.code==='VERSION_CONFLICT');
  });
  await t.test('practice timing is shared and versioned while fixed PvP policy stays untouched',async()=>{
   const current=await timing.getPracticeTiming();const changes=await Promise.allSettled([timing.updatePracticeTiming({practiceMin:40,practiceMax:100,expectedVersion:current.version}),timing.updatePracticeTiming({practiceMin:45,practiceMax:90,expectedVersion:current.version})]);assert.equal(changes.filter(r=>r.status==='fulfilled').length,1);
   const updated=await timing.getPracticeTiming();await assert.rejects(()=>timing.updatePracticeTiming({practiceMin:-1,expectedVersion:updated.version}));
  });
  await t.test('friendly deadline reconciliation repairs a missing delayed job idempotently',async()=>{
   const a=await user(),b=await user(),[lowId,highId]=[a.id,b.id].sort();
   const friendship=await db.friendship.create({data:{lowId,highId,senderId:a.id,status:'ACCEPTED'}});
   const duel=await db.friendlyDuel.create({data:{requesterId:a.id,recipientId:b.id,friendshipId:friendship.id,requestKey:randomUUID(),subtopicIds:[subtopic.id],expiresAt:new Date(Date.now()-1000)}});
   await db.friendlyDuelSeat.createMany({data:[{userId:a.id,duelId:duel.id},{userId:b.id,duelId:duel.id}]});
   const {reconcileDueDuels}=load(source('modules/social/social.worker.ts'));
   await reconcileDueDuels();await reconcileDueDuels();assert.equal((await db.friendlyDuel.findUnique({where:{id:duel.id}})).status,'EXPIRED');assert.equal(await db.friendlyDuelSeat.count({where:{duelId:duel.id}}),0);
  });
  await t.test('shared AI reservations enforce concurrency, request and token caps without fallback',async()=>{
   const now=Date.now(),keys=['ai:inflight',`ai:rpm:${Math.floor(now/60000)}`,`ai:tokens:${Math.floor(now/86400000)}`];await redis.del(...keys);
   const release=await reserveProvider(400,1000);await assert.rejects(()=>reserveProvider(400,1000),e=>e.code==='AI_BUDGET_EXCEEDED');await release();const release2=await reserveProvider(400,1000);await release2();await assert.rejects(()=>reserveProvider(400,1000),e=>e.code==='AI_BUDGET_EXCEEDED');
   await redis.del(...keys);await assert.rejects(()=>reserveProvider(1001,1000),e=>e.code==='AI_BUDGET_EXCEEDED');redis.disconnect();await assert.rejects(()=>reserveProvider(1,1000),e=>e.code==='AI_UNAVAILABLE');
  });
  await t.test('real queue worker records failed jobs and preserves the selected Redis database',async()=>{
   const queueLoad=loader({...deps,
     '../modules/ai/services/question-generation.service':{QuestionGenerationService:{}},
     '../modules/ai/services/daily-challenge-generation.service':{DailyChallengeGenerationService:{}},
   });
   const queue=queueLoad(source('queues/content-generation.queue.ts'));
   const stop=queue.startContentGenWorker();
   try{
    const job=await queue.contentGenQueue.add('unsupported-fixture',{}, {jobId:'fixture-'+run,attempts:1});
    let state;const end=Date.now()+3000;
    while(Date.now()<end){state=await job.getState();if(state==='failed')break;await new Promise(resolve=>setTimeout(resolve,20));}
    assert.equal(state,'failed');assert.ok((await job.getState())!=='completed');await job.remove();
   }finally{await stop();}
  });
 }finally{redis.disconnect();await db.$disconnect();}
});
