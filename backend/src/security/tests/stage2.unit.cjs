const test=require('node:test'),assert=require('node:assert/strict'),path=require('node:path');
const {loader}=require('../../modules/pvp/tests/pvp-test-fixture.cjs');
const source=p=>path.join(__dirname,'../../',p);
const base={'./env':{ENV:{REDIS_URL:'redis://127.0.0.1:56439'}},'ioredis':{default:class{on(){} }}};
test('queue Redis validates complete URLs without silently falling back',()=>{
 const {validateRedisUrl}=loader(base)(source('config/queue-redis.ts'));
 const input='rediss://acl-user:p%40ss%2Fword@localhost:6380/4';assert.equal(validateRedisUrl(input),input);
 for(const value of ['https://localhost','bad-url','redis://localhost/not-db','redis://localhost/1?db=2'])assert.throws(()=>validateRedisUrl(value));
});
const question={subtopicId:'subtopic',prompt:'2+2?',options:[{id:'A',text:'4'},{id:'B',text:'5'},{id:'C',text:'6'},{id:'D',text:'7'}],correctAnswer:'A',explanation:'2+2=4',difficulty:'EASY',estimatedTimeSeconds:60};
test('admin question allowlist rejects nested ORM writes, duplicate IDs/options and absent answers',()=>{
 const {validateAdminQuestion}=loader({})(source('modules/admin/admin-input.ts'));
 assert.equal(validateAdminQuestion(question).correctAnswer,'A');
 assert.equal(validateAdminQuestion({...question,options:[{id:'A',text:'9007199254740992'},{id:'B',text:'9007199254740993'},{id:'C',text:'-1'},{id:'D',text:'0'}]}).options.length,4);
 for(const value of [{...question,user:{connect:{id:'x'}}},{...question,correctAnswer:undefined},{...question,options:[...question.options.slice(0,3),{id:'D',text:'4.0'}]},{...question,options:[question.options[0],...question.options.slice(0,3)]}])assert.throws(()=>validateAdminQuestion(value));
});
test('calendar buckets use IST across midnight, month/year and leap year boundaries',()=>{
 const {periods}=loader({})(source('modules/admin/admin-analytics.queries.ts'));
 const rows=periods(new Date('2025-12-31T18:30:00Z'));const daily=rows.filter(r=>r.kind==='daily');
 assert.equal(daily.at(-1).date,'2026-01-01');assert.equal(daily.at(-1).start,'2025-12-31T18:30:00.000Z');assert.equal(rows.filter(r=>r.kind==='monthly').at(-1).date,'2026-01-01');
 const leap=periods(new Date('2024-03-01T00:00:00Z')).filter(r=>r.kind==='daily');assert.ok(leap.some(r=>r.date==='2024-02-29'));
});
test('script authoring rejects malformed options, transition entries and unsupported references',()=>{
 const {ScriptValidator}=loader({})(source('modules/lesson/engines/script-validator.ts'));
 const definition={schemaVersion:1,scriptId:'fixture',version:1,entryNodeId:'q',nodes:{q:{id:'q',type:'QUESTION',questionReference:{mode:'INLINE',inlineData:{prompt:'Question',options:[{id:'A',label:'One'},{id:'B',label:'Two'}],correctOptionId:'A'}},transitions:[{targetNodeId:'done'}]},done:{id:'done',type:'COMPLETION',transitions:[]}}};
 assert.equal(ScriptValidator.validate(definition).valid,true);
 for(const mutate of [d=>d.nodes.q.questionReference.inlineData.options='invalid',d=>d.nodes.q.questionReference.inlineData.options=[null,null],d=>d.nodes.q.transitions=[null],d=>d.nodes.q.questionReference.mode='UNKNOWN']){
  const copy=structuredClone(definition);mutate(copy);assert.equal(ScriptValidator.validate(copy).valid,false);
 }
});
test('Daily preparation repairs missed current and late-night schedules using stable date identities',async()=>{
 const added=[];
 const load=loader({'../config/prisma':{prisma:{dailyChallengeScript:{findMany:async()=>[]}}},'./content-generation.queue':{contentGenQueue:{add:async(...args)=>added.push(args)}}});
 const {reconcileDailyPreparation}=load(source('queues/daily-preparation.ts'));
 await reconcileDailyPreparation(new Date('2026-12-31T18:00:00Z'));
 assert.deepEqual(added.map(args=>args[1].targetDate),['2026-12-31','2027-01-01']);
 assert.deepEqual(added.map(args=>args[2].jobId),['prewarm-daily-2026-12-31','prewarm-daily-2027-01-01']);
});
test('Daily preparation skips a complete catalog and propagates an enqueue outage for recovery',async()=>{
 let complete=true,added=0;
 const load=loader({'../config/prisma':{prisma:{dailyChallengeScript:{findMany:async()=>complete?[{tier:1},{tier:2},{tier:3}]:[]}}},'./content-generation.queue':{contentGenQueue:{add:async()=>{added++;throw new Error('fixture outage')}}}});
 const {reconcileDailyPreparation}=load(source('queues/daily-preparation.ts'));
 await reconcileDailyPreparation(new Date('2026-01-01T00:00:00Z'));assert.equal(added,0);
 complete=false;await assert.rejects(()=>reconcileDailyPreparation(new Date('2026-01-01T00:00:00Z')),/fixture outage/);assert.equal(added,1);
});
test('Gemini uses configured model, honors zero thinking budget, clears timeout and hides raw output',async()=>{
 let config,released=0;
 const ENV={GEMINI_API_KEY:'fixture',GEMINI_MODEL:'fixture-model',GEMINI_THINKING_BUDGET:0};
 const load=loader({'../../config/env':{ENV,AI_LIMITS:{timeoutMs:20,maxOutputTokens:100}},'./provider-budget':{reserveProvider:async()=>async()=>{released++;}},'@google/genai':{GoogleGenAI:class{models={generateContent:async request=>{config=request;return {text:'{"ok":true}'}}}}}},{AbortController});
 const {geminiProvider}=load(source('modules/ai/gemini.provider.ts'));
 assert.equal((await geminiProvider.generateStructuredContent({systemInstruction:'system',prompt:'prompt',responseSchema:{}})).ok,true);
 assert.equal(config.model,'fixture-model');assert.equal(config.config.thinkingConfig.thinkingBudget,0);assert.equal(released,1);
});
test('Gemini timeout bounds the caller, aborts SDK transport and releases its reservation',async()=>{
 let aborted=false,released=0;
 const load=loader({'../../config/env':{ENV:{GEMINI_API_KEY:'fixture',GEMINI_MODEL:'model',GEMINI_THINKING_BUDGET:0},AI_LIMITS:{timeoutMs:5,maxOutputTokens:10}},'./provider-budget':{reserveProvider:async()=>async()=>{released++;}},'@google/genai':{GoogleGenAI:class{models={generateContent:request=>new Promise(()=>request.config.abortSignal.addEventListener('abort',()=>{aborted=true}))}}}},{AbortController});
 const {geminiProvider}=load(source('modules/ai/gemini.provider.ts'));await assert.rejects(()=>geminiProvider.generateStructuredContent({systemInstruction:'s',prompt:'p',responseSchema:{}}),/failed/);assert.equal(aborted,true);assert.equal(released,1);
});
test('queue modules are inert on import and unknown jobs reject instead of reporting completion',async()=>{
 let connections=0;
 const deps={'../config/queue-redis':{queueRedis:()=>{connections++;throw new Error('No connection allowed during import')}},'../config/env':{ENV:{}},'../config/prisma':{prisma:{}},'../../../config/prisma':{prisma:{}},
  '../modules/admin/services/book-run':{prisma:{},withBookRun:async()=>{}},
  '../modules/ai/services/question-generation.service':{QuestionGenerationService:{}},'../modules/ai/services/daily-challenge-generation.service':{DailyChallengeGenerationService:{}},
  'bullmq':{Queue:class{},Worker:class{}},
 };
 for(const name of ['pdf-parser','topic-discovery','subtopic-discovery','book-question-extraction','book-question-classification','book-script-generation','content-validation','book-cancellation'])deps[`../modules/admin/services/${name}.service`]={};
 const load=loader(deps);const content=load(source('queues/content-generation.queue.ts')),book=load(source('queues/book-ingestion.queue.ts'));
 assert.equal(connections,0);await assert.rejects(()=>content.processContentJob({name:'unknown',data:{}}));await assert.rejects(()=>book.processBookJob({name:'unknown',data:{}}));assert.equal(connections,0);
});
