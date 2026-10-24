const test=require('node:test');const assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),ts=require('typescript');
const {PROFILE}=require('../contracts.ts');
const {runLunaWorkflow}=require('../workflow.ts');
const prompts=require('../prompts.ts');
const USER='00000000-0000-4000-8000-000000000001',JOB='00000000-0000-4000-8000-000000000002';
function fixture({cancelAtSave=false,providerFails=false,providerError,planFails=false,deadline=Date.now()+600000,maxCalls=4,referenceChanged=false}={}){
 const row={id:JOB,requestKey:'request',userIds:[USER],mode:'PRACTICE',tier:'UNRANKED',state:'QUEUED',version:0,scope:{subtopicIds:['sub'],smartPicks:false},manifest:null,callCount:0,usage:[],workerToken:null,resultSetId:null,resultSessionId:null,errorCode:null,deadline:new Date(deadline),createdAt:new Date(),updatedAt:new Date()};
 const slots=Array.from({length:10},(_,i)=>({id:`s${i+1}`,difficulty:'EASY',answerPosition:'B',reference:{id:`00000000-0000-4000-8000-${String(100+i).padStart(12,'0')}`,subjectId:'math',topicId:'numbers',subtopicId:'sub',subtopicName:'Addition',scope:'Add positive integers.',pattern:'ADDITION',prompt:`Add ${i} and 2.`,options:[{id:'A',text:'1'},{id:'B',text:String(i+2)},{id:'C',text:'12'},{id:'D',text:'20'}],correctAnswer:'B',explanation:'Add the integers.',method:'Addition',pyq:null,sourceType:'AI_GENERATED'}}));
 const candidate=s=>({slotId:s.id,pattern:'ADDITION',prompt:`What is ${20+Number(s.id.slice(1))} plus 5?`,options:[{id:'A',text:'1'},{id:'B',text:String(25+Number(s.id.slice(1)))},{id:'C',text:'50'},{id:'D',text:'90'}],correctAnswer:'B',hints:['Add the tens first.','Then add the units.'],explanation:'Add both values. Subtract 5 to check the result.',method:'Addition',alternativeExplanation:null,difficulty:'EASY',estimatedTimeSeconds:12});
 function matches(where){
  return !where||(!where.id||where.id===row.id)&&(!where.workerToken||where.workerToken===row.workerToken)&&(!where.state||(typeof where.state==='string'?where.state===row.state:where.state.in.includes(row.state)))&&(!where.deadline||(!where.deadline.gt||row.deadline>where.deadline.gt)&&(!where.deadline.lte||row.deadline<=where.deadline.lte))&&(!where.callCount||row.callCount<where.callCount.lt)&&(!where.userIds||row.userIds.includes(where.userIds.has));
 }
 function apply(data){for(const [k,v] of Object.entries(data)){if(v!==undefined)row[k]=v&&typeof v==='object'&&'increment' in v?row[k]+v.increment:v;}}
 const saved=[],allocations=[],calls=[],logs=[];
 const db={questionPreparation:{updateMany:async({where,data})=>{if(!matches(where))return {count:0};apply(data);return {count:1};},findUnique:async()=>({...row}),findUniqueOrThrow:async()=>({...row}),findFirst:async({where})=>matches(where)?{...row}:null,update:async({data})=>{apply(data);return row;}},
  question:{findMany:async(args)=>args.where.id?slots.map(s=>({...s.reference,...(referenceChanged?{prompt:'Changed after review'}:{}),subtopic:{name:s.reference.subtopicName,description:s.reference.scope}})):[],count:async()=>10,create:async({data})=>{saved.push(data);return {...data,id:`question-${saved.length}`};}},
  friendlyDuelSeat:{count:async()=>0},practiceSession:{create:async({data})=>{allocations.push(data);return {id:'session-result'};}},practiceSessionQuestion:{createMany:async({data})=>allocations.push(data)},
  $queryRaw:async query=>String(query).includes(' AS now')?[{now:new Date()}]:[],
 };
 db.$transaction=async fn=>{if(cancelAtSave)row.state='CANCELLED';return fn(db);};
 const deps={
  '../../../observability/logger':{log:(level,event,metadata)=>logs.push({level,event,...metadata}),safeError:()=>({type:'Error'})},
  './failures':require('../failures.ts'),
  '@prisma/client':require('@prisma/client'),'node:crypto':require('node:crypto'),'node:util':require('node:util'),'zod':require('zod'),
  '../../../config/prisma':{prisma:db},'../../../config/env':{ENV:{LUNA:{enabled:true,model:'gpt-6-luna',maxCalls,preparationTimeoutMs:600000,maxPending:32}}},
  '../../../security/errors':{PublicError:class extends Error{constructor(message,code,status){super(message);this.code=code;this.status=status;}}},
  '../../social/friends.service':{lockUsers:async()=>{}},'../../question/services/fingerprint.service':require('../../../question/services/fingerprint.service.ts'),'../services/ai-prompt.service':{aiPromptService:{getPublishedPromptSnapshot:async(_key,text)=>({text,version:'builtin'})}},
  './contracts':require('../contracts.ts'),'./references':{planSlots:async()=>{if(planFails)throw Error('REFERENCE_SCOPE_CHANGED');return slots;},referenceOptions:opts=>opts},'./prompts':prompts,'./workflow':{runLunaWorkflow},
  './provider':{lunaCall:async(request,_deadline,report)=>{calls.push(request);assert.equal(row.callCount,calls.length,'Call reserved before dispatch');if(providerError)throw providerError;if(providerFails)throw Error('provider failure');await report({stage:request.stage,inputTokens:100,outputTokens:200});return request.stage==='GENERATING'?{questions:slots.map(candidate)}:{verdicts:request.input.candidates.map(q=>({slotId:q.slotId,pass:true,code:'OK',detail:''}))};}},
 };
 const code=ts.transpileModule(fs.readFileSync(path.join(__dirname,'../preparations.ts'),'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText;
 const exports={};vm.runInNewContext(code,{exports,require:id=>{assert.ok(id in deps,`Unexpected dependency ${id}`);return deps[id];},Date,setTimeout,clearTimeout,console});
 return {service:exports,row,saved,allocations,calls,logs};
}
test('durable publication inserts ten fresh Luna rows with complete provenance and a frozen Practice session',async()=>{
 const s=fixture();await s.service.processPreparation(JOB);
 assert.equal(s.row.state,'READY');assert.equal(s.row.callCount,2);assert.equal(s.saved.length,10);assert.equal(s.row.resultSessionId,'session-result');
 for(const q of s.saved){assert.equal(q.sourceType,'LUNA');assert.equal(q.generationMethod,'AI_SYNTHETIC');assert.equal(q.generationModel,'gpt-6-luna');assert.equal(q.generationProfile,PROFILE);assert.equal(q.generationJobId,JOB);assert.ok(q.referenceQuestionId);assert.ok(q.referenceSnapshot);assert.equal(q.hints.length,2);assert.ok(q.explanation);assert.ok(q.method);assert.equal(q.estimatedTimeSeconds,12);assert.equal(q.pyq,undefined);}
 assert.equal(Object.keys(s.allocations[0].questionSnapshot).length,10);assert.equal(s.allocations[1].length,10);assert.equal(s.row.manifest.slots.length,10);assert.equal(s.row.usage.length,2);assert.equal(Object.keys(s.row.resultSnapshot).length,10);assert.equal(s.row.resultSnapshot['question-1'].hints.length,2);
});
test('cancel winning before publication cannot insert questions or admit a session',async()=>{
 const s=fixture({cancelAtSave:true});await s.service.processPreparation(JOB);assert.equal(s.row.state,'CANCELLED');assert.equal(s.saved.length,0);assert.equal(s.allocations.length,0);
});
test('deadline, provider failure and exhausted budget fail without partial session or extra dispatch',async()=>{
 for(const settings of [{deadline:Date.now()-1},{providerFails:true},{maxCalls:1}]){
  const s=fixture(settings);await s.service.processPreparation(JOB);assert.ok(['FAILED','EXPIRED'].includes(s.row.state));assert.equal(s.saved.length,0);assert.equal(s.allocations.length,0);assert.ok(s.calls.length<=1);
 }
});
test('stalled job cannot redispatch a paid call and stale worker loses its publication fence',async()=>{
 const s=fixture();s.row.state='REVIEWING';s.row.callCount=2;s.row.workerToken='00000000-0000-4000-8000-000000000003';await s.service.processPreparation(JOB);assert.equal(s.row.state,'FAILED');assert.equal(s.calls.length,0);
});
test('status is participant-only and never contains references, provider usage or solutions',async()=>{
 const s=fixture();s.row.state='READY';s.row.resultSessionId='session';
 assert.equal(await s.service.preparationStatus('00000000-0000-4000-8000-000000000099',JOB),null);
 const view=await s.service.preparationStatus(USER,JOB);assert.equal(view.sessionId,'session');
 for(const name of ['manifest','usage','workerToken','scope','userIds','resultSnapshot'])assert.equal(name in view,false);
});

test('an edited reference cannot publish candidates reviewed against its earlier instance',async()=>{
 const s=fixture({referenceChanged:true});await s.service.processPreparation(JOB);assert.equal(s.row.state,'FAILED');assert.equal(s.saved.length,0);assert.equal(s.allocations.length,0);
});

test('terminal preparation failure is logged with safe job/stage/provider metadata and persisted specific code',async()=>{
 const {LunaFailure}=require('../failures.ts');
 const s=fixture({providerError:new LunaFailure('LUNA_QUOTA_EXCEEDED',429,'insufficient_quota')});
 await s.service.processPreparation(JOB);
 assert.equal(s.row.state,'FAILED');assert.equal(s.row.errorCode,'LUNA_QUOTA_EXCEEDED');
 assert.equal(s.calls.length,1);assert.equal(s.saved.length,0);assert.equal(s.logs.length,1);
 assert.deepEqual(s.logs[0],{level:'error',event:'luna.preparation_failed',preparationId:JOB,mode:'PRACTICE',stage:'GENERATING',callCount:1,type:'Error',code:'LUNA_QUOTA_EXCEEDED',providerStatus:429,providerCode:'insufficient_quota'});
});
test('planning and publication failures report the correct stage and never include reference text',async()=>{
 for(const [options,stage] of [[{planFails:true},'PLANNING'],[{referenceChanged:true},'SAVING']]){
  const s=fixture(options);await s.service.processPreparation(JOB);
  assert.equal(s.row.errorCode,'REFERENCE_SCOPE_CHANGED');assert.equal(s.logs.length,1);
  assert.equal(s.logs[0].stage,stage);assert.ok(!JSON.stringify(s.logs).includes('Add positive integers'));
 }
});
test('unknown failures never log raw messages and cancellation races do not emit a false failure',async()=>{
 const s=fixture({providerError:new Error('SECRET_CANARY key=secret prompt=private')});await s.service.processPreparation(JOB);
 assert.equal(s.row.errorCode,'QUALITY_OR_PROVIDER_FAILURE');assert.equal(s.logs.length,1);assert.ok(!JSON.stringify(s.logs).includes('SECRET_CANARY'));
 const cancelled=fixture({cancelAtSave:true});await cancelled.service.processPreparation(JOB);assert.equal(cancelled.logs.length,0);
});
test('expired and interrupted jobs produce a single useful terminal record without more provider calls',async()=>{
 for(const expired of [true,false]){
  const s=fixture(expired?{deadline:Date.now()-1}:{});
  if(!expired){s.row.state='REVIEWING';s.row.callCount=2;}
  await s.service.processPreparation(JOB);await s.service.processPreparation(JOB);
  assert.equal(s.calls.length,0);assert.equal(s.logs.length,1);
  assert.equal(s.logs[0].code,expired?'PREPARATION_EXPIRED':'WORKER_INTERRUPTED');
 }
});
