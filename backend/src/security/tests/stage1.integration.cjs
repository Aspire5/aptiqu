// Explicit opt-in, loopback-only, fresh disposable database. Never uses DATABASE_URL or dotenv.
const test=require('node:test'); const assert=require('node:assert/strict'); const path=require('node:path');
const {randomUUID}=require('node:crypto'); const {loader}=require('../../modules/pvp/tests/pvp-test-fixture.cjs');
test('Stage 1 PostgreSQL and Redis correctness', {skip:process.env.STAGE1_ALLOW_LOCAL_TESTS!=='true',timeout:60000},async t=>{
 const raw=process.env.STAGE1_TEST_DATABASE_URL; assert.ok(raw); const url=new URL(raw);
 assert.ok(['localhost','127.0.0.1','[::1]'].includes(url.hostname)); assert.match(url.pathname,/^\/aptiqu_stage1_test_[a-z0-9_]+$/);
 const redisUrl=new URL(process.env.STAGE1_TEST_REDIS_URL);assert.equal(redisUrl.hostname,'127.0.0.1');assert.equal(redisUrl.port,'56439');
 const {PrismaClient}=require('@prisma/client');const db=new PrismaClient({datasources:{db:{url:raw}}});
 const Redis=require('ioredis');const redis=new Redis(redisUrl.href,{lazyConnect:true,maxRetriesPerRequest:0}); await redis.connect();
 const ENV={JWT_ACCESS_SECRET:'fixture-access',ADMIN_JWT_SECRET:'fixture-admin',JWT_ACCESS_EXPIRATION:'15m',JWT_REFRESH_EXPIRATION:'7d',JWT_ISSUER:'aptiqu',JWT_AUDIENCE:'aptiqu-mobile'};
 const deps={
  '../../../config/prisma':{prisma:db},'../../config/prisma':{prisma:db},
  '../config/env':{ENV},'../../config/env':{ENV},'../../../config/env':{ENV},
  crypto:{default:require('node:crypto')},jsonwebtoken:{default:require('jsonwebtoken')},
  '../modules/lesson/services/redis.service':{redisService:{getClient:()=>redis}},
  './practice-selection.service':{practiceSelectionService:{}},
  './redis.service':{redisService:{get:async()=>null,set:async()=>{},setNx:async()=>true,del:async()=>{}}},
  '../ai/services/daily-challenge-generation.service':{dailyChallengeGenerationService:{}},
  '../../queues/content-generation.queue':{contentGenQueue:{add:async()=>{}}},
  '../../utils/google':{verifyGoogleToken:async()=>({googleId:'other-google',email:'owner@example.invalid'})},
  '../../social/duels.service':{duelsService:{}},'../../social/friends.service':{lockUsers:async()=>{}},'../../social/social.transport':{socialTransport:{}},
 };
 const load=loader(deps);const source=p=>path.join(__dirname,'../../',p);
 const {DailyChallengeService}=load(source('modules/daily-challenge/daily-challenge.service.ts'));
 const {LessonSessionService}=load(source('modules/lesson/services/lesson-session.service.ts'));
 const {AuthService}=load(source('modules/auth/auth.service.ts'));
 const {PracticeSessionService}=load(source('modules/practice/services/practice-session.service.ts'));
 const {hashToken}=load(source('utils/crypto.ts'));
 const {takeBudget}=load(source('security/request-policy.ts'));
 const run=randomUUID();const subject='subject-'+run,topic='topic-'+run,subtopic='subtopic-'+run;
 let tick=Date.parse('2026-10-20T12:00:00Z');const daily=new DailyChallengeService(db,()=>new Date(tick));
 const user=async(streak=0)=>db.user.create({data:{email:randomUUID()+'@example.invalid',googleId:randomUUID(),gameStats:{create:{streak,highestStreak:streak,lastDailyDate:streak?'2026-10-19':null}},progress:{create:{totalXp:0,level:1}}}});
 const makeQuestion=()=>db.question.create({data:{subjectId:subject,topicId:topic,subtopicId:subtopic,prompt:'2+2?',options:[{id:'A',text:'4'},{id:'B',text:'5'}],correctAnswer:'A',explanation:'2+2=4',method:'Add',fingerprint:randomUUID(),difficulty:'EASY'}});
 try {
  await db.subject.create({data:{id:subject,slug:subject,name:'Fixture'}});await db.topic.create({data:{id:topic,slug:topic,subjectId:subject,name:'Fixture'}});await db.subtopic.create({data:{id:subtopic,topicId:topic,name:'Fixture'}});
  const questions=await Promise.all(Array.from({length:10},makeQuestion));
  for(const [tier,count] of [[1,1],[2,2]]) {
   const qs=await Promise.all(Array.from({length:count},makeQuestion));
   await db.dailyChallengeScript.upsert({where:{dateString_tier:{dateString:'2026-10-20',tier}},update:{},create:{dateString:'2026-10-20',tier,questionCount:count,questions:{create:qs.map((q,i)=>({questionId:q.id,sequence:i+1,difficulty:i?'MEDIUM':'EASY'}))}}});
  }
  await t.test('server timing ignores forged client time, duplicate/final concurrent requests reward once',async()=>{
   const u=await user();const [start,resumed]=await Promise.all([daily.startDailyChallenge(u.id),daily.startDailyChallenge(u.id)]);assert.equal(start.participationId,resumed.participationId);assert.equal(start.questions.length,1);assert.ok(!JSON.stringify(start).includes('correctAnswer'));
   tick+=1500;const input={userId:u.id,participationId:start.participationId,questionId:start.questions[0].question.id,selectedOptionId:'A',responseTimeMs:-99999};
   const results=await Promise.all([daily.submitAnswer(input),daily.submitAnswer({...input,responseTimeMs:0})]);assert.deepEqual(JSON.parse(JSON.stringify(results[0])),JSON.parse(JSON.stringify(results[1])));assert.equal(results[0].responseTimeMs,1500);
   const answer=await db.dailyChallengeAnswer.findFirst({where:{participationId:start.participationId}});assert.equal(answer.responseTimeMs,1500);assert.equal(+answer.answeredAt-+answer.questionStartedAt,1500);
   assert.equal(await db.xpEvent.count({where:{userId:u.id,sourceType:'DAILY_CHALLENGE'}}),1);const stats=await db.gameStats.findUnique({where:{userId:u.id}});assert.equal(stats.streak,1);assert.equal(stats.coins,10);
   await assert.rejects(()=>daily.submitAnswer({...input,selectedOptionId:'B'}),e=>e.code==='ANSWER_CONFLICT');
   await assert.rejects(()=>daily.submitAnswer({...input,userId:'00000000-0000-4000-8000-000000000001'}),e=>e.code==='P2010'||e.code==='NOT_FOUND');
  });
  await t.test('one reveal at a time, order/options/start checks, resumed deadline and aggregate exclude feedback',async()=>{
   const u=await user(10);const start=await daily.startDailyChallenge(u.id);assert.equal(start.totalQuestions,2);assert.equal(start.questions.length,1);
   const p=await db.dailyChallengeParticipation.findUnique({where:{id:start.participationId},include:{script:{include:{questions:{orderBy:{sequence:'asc'}}}}}});
   const base={userId:u.id,participationId:p.id,selectedOptionId:'A',responseTimeMs:0};
   await assert.rejects(()=>daily.submitAnswer({...base,questionId:p.script.questions[1].questionId}),e=>e.code==='QUESTION_ORDER');
   await assert.rejects(()=>daily.submitAnswer({...base,questionId:p.script.questions[0].questionId,selectedOptionId:'Z'}),e=>e.code==='INVALID_OPTION');
   await assert.rejects(()=>daily.submitAnswer({...base,questionId:p.script.questions[0].questionId,selectedOptionId:'TIMEOUT'}),e=>e.code==='QUESTION_NOT_EXPIRED');
   tick+=2000;const resume=await daily.startDailyChallenge(u.id);assert.equal(+resume.questionDeadline,+start.questionDeadline);
   const first=await daily.submitAnswer({...base,questionId:p.script.questions[0].questionId});assert.equal(first.responseTimeMs,2000);assert.equal(first.isComplete,false);
   await assert.rejects(()=>daily.submitAnswer({...base,questionId:p.script.questions[1].questionId}),e=>e.code==='QUESTION_NOT_STARTED');
   tick+=30000;const next=await daily.startDailyChallenge(u.id);assert.equal(next.questions.length,2);assert.equal(next.questions[0].isAnswered,true);assert.equal(next.questions[1].question.correctAnswer,undefined);
   tick+=3000;await Promise.all([daily.submitAnswer({...base,questionId:p.script.questions[1].questionId}),daily.submitAnswer({...base,questionId:p.script.questions[1].questionId})]);assert.equal(await db.xpEvent.count({where:{userId:u.id,sourceType:'DAILY_CHALLENGE'}}),1);const done=await db.dailyChallengeParticipation.findUnique({where:{id:p.id}});assert.equal(done.totalTimeMs,5000);assert.ok(done.completedAt);assert.equal(done.coinsAwarded,20);
  });
  await t.test('expired answer is a durable timeout; midnight rejects old attempts even without cron',async()=>{
   const u=await user();const start=await daily.startDailyChallenge(u.id);tick+=61000;const result=await daily.submitAnswer({userId:u.id,participationId:start.participationId,questionId:start.questions[0].question.id,selectedOptionId:'A',responseTimeMs:0});assert.equal(result.isCorrect,false);assert.equal(result.responseTimeMs,60000);assert.equal(result.xpAwarded,0);
   tick=Date.parse('2026-10-20T18:29:50Z');const v=await user();const late=await daily.startDailyChallenge(v.id);assert.equal(+late.questionDeadline,Date.parse('2026-10-20T18:30:00Z'));
   tick+=10001;assert.equal(daily.getIstDates().todayDate,'2026-10-21');await assert.rejects(()=>daily.submitAnswer({userId:v.id,participationId:late.participationId,questionId:late.questions[0].question.id,selectedOptionId:'A'}),e=>e.code==='DAILY_EXPIRED');
   assert.equal(await db.dailyChallengeAnswer.count({where:{participationId:late.participationId}}),0);tick=Date.parse('2026-10-20T12:10:00Z');
  });
  async function rejectXp(enabled) {
   if(enabled) await db.$executeRawUnsafe(`CREATE OR REPLACE FUNCTION gamification.stage1_fail_xp() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'fixture XP failure'; END $$`);
   await db.$executeRawUnsafe(enabled?`CREATE TRIGGER stage1_fail_xp BEFORE INSERT ON gamification.xp_events FOR EACH ROW EXECUTE FUNCTION gamification.stage1_fail_xp()`:`DROP TRIGGER stage1_fail_xp ON gamification.xp_events`);
  }
  await t.test('failed Daily finalization rolls back answers/stats/rewards and retry succeeds',async()=>{
   const u=await user();const start=await daily.startDailyChallenge(u.id);tick+=1000;const input={userId:u.id,participationId:start.participationId,questionId:start.questions[0].question.id,selectedOptionId:'A'};
   await rejectXp(true);try{await assert.rejects(()=>daily.submitAnswer(input));}finally{await rejectXp(false);}
   assert.equal(await db.dailyChallengeAnswer.count({where:{participationId:start.participationId}}),0);assert.equal((await db.gameStats.findUnique({where:{userId:u.id}})).streak,0);assert.equal((await db.dailyChallengeParticipation.findUnique({where:{id:start.participationId}})).status,'IN_PROGRESS');
   assert.equal((await daily.submitAnswer(input)).isComplete,true);
  });
  const lesson=new LessonSessionService();
  const script=await db.lessonScript.create({data:{slug:run,title:'Fixture',subjectId:subject,topicId:topic,subtopicId:subtopic,status:'PUBLISHED'}});
  const concept=await db.concept.create({data:{code:'concept-'+run,title:'Addition',subjectId:subject,topicId:topic}});
  const definition={schemaVersion:1,scriptId:script.id,version:1,entryNodeId:'question',metadata:{title:'Fixture',subjectId:subject,topicId:topic,subtopicId:subtopic},nodes:{question:{id:'question',type:'QUESTION',content:{text:'2+2?'},questionReference:{mode:'INLINE',conceptId:concept.id,inlineData:{prompt:'2+2?',options:[{id:'A',label:'4'},{id:'B',label:'5'}],correctOptionId:'A',explanation:'Add',incorrectExplanation:'SECRET',variations:[{correctOptionId:'A',explanation:'SECRET'}]}},transitions:[{targetNodeId:'done'}]},done:{id:'done',type:'COMPLETION',content:{text:'Done'},transitions:[]}}};
  const version=await db.lessonScriptVersion.create({data:{scriptId:script.id,versionNumber:1,definition,checksum:'fixture',status:'PUBLISHED'}});
  await db.lessonScript.update({where:{id:script.id},data:{publishedVersionId:version.id}});
  await t.test('lesson ownership precedes receipts, payload conflicts, concurrent actions and durable replay',async()=>{
   const u=await user(),v=await user();const id=randomUUID();const a=await lesson.startOrResumeSession(u.id,run,id);const b=await lesson.startOrResumeSession(v.id,run,id);assert.notEqual(a.sessionId,b.sessionId);assert.ok(!JSON.stringify(a).includes('SECRET'));
   const input={clientActionId:randomUUID(),stateVersion:1,currentNodeId:'question',action:{type:'QUESTION_ANSWER',answer:'A'}};
   const results=await Promise.all([lesson.submitAction(u.id,a.sessionId,input),lesson.submitAction(u.id,a.sessionId,input)]);assert.deepEqual(JSON.parse(JSON.stringify(results[0])),JSON.parse(JSON.stringify(results[1])));assert.equal(results[0].status,'COMPLETED');
   await assert.rejects(()=>lesson.submitAction(v.id,a.sessionId,input),e=>e.code==='NOT_FOUND');await assert.rejects(()=>lesson.submitAction(u.id,a.sessionId,{...input,action:{...input.action,answer:'B'}}),e=>e.code==='IDEMPOTENCY_CONFLICT');
   assert.equal(await db.questionAttempt.count({where:{sessionId:a.sessionId}}),1);assert.equal(await db.lessonEvent.count({where:{sessionId:a.sessionId}}),2);
   assert.deepEqual(JSON.parse(JSON.stringify(await new LessonSessionService().submitAction(u.id,a.sessionId,input))),JSON.parse(JSON.stringify(results[0])));
   await assert.rejects(()=>lesson.submitAction(u.id,a.sessionId,{...input,clientActionId:randomUUID()}));
  });
  await t.test('lesson XP failure rolls back attempt/event/state and durable receipt; retry commits',async()=>{
   const u=await user();const start=await lesson.startOrResumeSession(u.id,run,randomUUID());const input={clientActionId:randomUUID(),stateVersion:1,currentNodeId:'question',action:{type:'QUESTION_ANSWER',answer:'A'}};
   await rejectXp(true);try{await assert.rejects(()=>lesson.submitAction(u.id,start.sessionId,input));}finally{await rejectXp(false);}
   assert.equal(await db.questionAttempt.count({where:{sessionId:start.sessionId}}),0);assert.equal((await db.lessonSession.findUnique({where:{id:start.sessionId}})).stateVersion,1);assert.equal(await db.lessonActionReceipt.count({where:{userId:u.id,operation:'submit'}}),0);assert.equal(await db.xpEvent.count({where:{userId:u.id}}),0);
   assert.equal((await lesson.submitAction(u.id,start.sessionId,input)).status,'COMPLETED');
  });
  await t.test('a late event failure rolls back mastery, XP and session progression together',async()=>{
   const u=await user();const start=await lesson.startOrResumeSession(u.id,run,randomUUID());const input={clientActionId:randomUUID(),stateVersion:1,currentNodeId:'question',action:{type:'QUESTION_ANSWER',answer:'A'}};
   await db.$executeRawUnsafe(`CREATE OR REPLACE FUNCTION learning.stage1_fail_event() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'fixture event failure'; END $$`);
   await db.$executeRawUnsafe(`CREATE TRIGGER stage1_fail_event BEFORE INSERT ON learning.lesson_events FOR EACH ROW EXECUTE FUNCTION learning.stage1_fail_event()`);
   try{await assert.rejects(()=>lesson.submitAction(u.id,start.sessionId,input));}finally{await db.$executeRawUnsafe('DROP TRIGGER stage1_fail_event ON learning.lesson_events');}
   assert.equal(await db.studentConceptMastery.count({where:{userId:u.id}}),0);assert.equal(await db.xpEvent.count({where:{userId:u.id}}),0);assert.equal((await db.lessonSession.findUnique({where:{id:start.sessionId}})).stateVersion,1);
   await lesson.submitAction(u.id,start.sessionId,input);assert.equal((await db.studentConceptMastery.findUnique({where:{userId_conceptId:{userId:u.id,conceptId:concept.id}}})).totalAttempts,1);
  });
  await t.test('unpublished script/version cannot start',async()=>{
   const u=await user();await db.lessonScriptVersion.update({where:{id:version.id},data:{status:'REVIEW'}});try{await assert.rejects(()=>lesson.startOrResumeSession(u.id,run,randomUUID()));}finally{await db.lessonScriptVersion.update({where:{id:version.id},data:{status:'PUBLISHED'}});}
  });
  await t.test('new Daily admission rejects archived questions',async()=>{
   const script=await db.dailyChallengeScript.findUnique({where:{dateString_tier:{dateString:'2026-10-20',tier:1}},include:{questions:true}});const id=script.questions[0].questionId;const u=await user();
   await db.question.update({where:{id},data:{status:'ARCHIVED'}});try{await assert.rejects(()=>daily.startDailyChallenge(u.id),e=>e.code==='DAILY_UNAVAILABLE');}finally{await db.question.update({where:{id},data:{status:'PUBLISHED'}});}
  });
  await t.test('Practice completion XP rolls back with parent session failure',async()=>{
   const u=await user();const p=await db.practiceSession.create({data:{userId:u.id,subjectId:subject,topicId:topic,subtopicIds:[subtopic],status:'ACTIVE',currentIndex:9,totalQuestions:10,questions:{create:questions.map((q,i)=>({questionId:q.id,sequence:i+1,isAnswered:i<9,isCorrect:i<9,userSelectedOptionId:i<9?'A':null,responseTimeMs:i<9?1000:null}))}}});
   const practice=new PracticeSessionService();await db.$executeRawUnsafe(`CREATE OR REPLACE FUNCTION learning.stage1_fail_practice() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN IF NEW.status='COMPLETED' THEN RAISE EXCEPTION 'fixture completion failure'; END IF; RETURN NEW; END $$`);await db.$executeRawUnsafe(`CREATE TRIGGER stage1_fail_practice BEFORE UPDATE ON learning.practice_sessions FOR EACH ROW EXECUTE FUNCTION learning.stage1_fail_practice()`);
   const input={sessionId:p.id,userId:u.id,questionId:questions[9].id,selectedOptionId:'A',responseTimeMs:1000};try{await assert.rejects(()=>practice.submitAnswer(input));}finally{await db.$executeRawUnsafe('DROP TRIGGER stage1_fail_practice ON learning.practice_sessions');}
   assert.equal(await db.xpEvent.count({where:{userId:u.id}}),0);assert.equal((await db.practiceSession.findUnique({where:{id:p.id}})).status,'ACTIVE');await practice.submitAnswer(input);assert.equal(await db.xpEvent.count({where:{userId:u.id,sourceType:'PRACTICE'}}),1);
  });
  await t.test('atomic refresh allows one concurrent consumer; logout revokes opaque token',async()=>{
   const u=await user(),auth=new AuthService();const raw=randomUUID();await db.refreshToken.create({data:{userId:u.id,tokenHash:hashToken(raw),expiresAt:new Date(Date.now()+60000)}});
   const results=await Promise.allSettled([auth.refreshSession(raw),auth.refreshSession(raw)]);assert.equal(results.filter(r=>r.status==='fulfilled').length,1);assert.equal(await db.refreshToken.count({where:{userId:u.id}}),1);
   const rotated=results.find(r=>r.status==='fulfilled').value.refreshToken;await auth.logout(rotated);await assert.rejects(()=>auth.refreshSession(rotated));
  });
  await t.test('email match cannot replace another Google identity',async()=>{
   await db.user.upsert({where:{email:'owner@example.invalid'},update:{},create:{email:'owner@example.invalid',googleId:randomUUID()}});const auth=new AuthService();await assert.rejects(()=>auth.loginWithGoogle('verified-fixture'),/cannot be linked/);
  });
  await t.test('Redis shared limiter returns bounded Retry-After and fails closed during outage',async()=>{
   const owner=randomUUID();await takeBudget('admin',owner);for(let i=0;i<4;i++)await takeBudget('admin',owner);await assert.rejects(()=>takeBudget('admin',owner),e=>e.status===429&&e.retryAfterSeconds>0);
   redis.disconnect();await assert.rejects(()=>takeBudget('admin',owner),e=>e.status===503);
  });
 }finally{redis.disconnect();await db.$disconnect();}
});
