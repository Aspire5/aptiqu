const test=require('node:test');
const assert=require('node:assert/strict');
const {difficultyQuota,matchTier,checkCandidate,fingerprint,TIERS}=require('../contracts.ts');
const {runLunaWorkflow}=require('../workflow.ts');
const {readLunaConfig}=require('../../../../config/runtime-config.ts');
const {referenceContext}=require('../contracts.ts');
const slots=()=>Array.from({length:10},(_,i)=>({id:`s${i+1}`,difficulty:'EASY',answerPosition:'B',reference:{
 id:`00000000-0000-4000-8000-${String(i+1).padStart(12,'0')}`,subjectId:'math',topicId:'numbers',subtopicId:`sub${i}`,subtopicName:'Addition',scope:'Add two positive integers.',
 pattern:`ADD${i}`,prompt:`What is ${i+1} plus 10?`,options:[{id:'A',text:'10'},{id:'B',text:String(i+11)},{id:'C',text:'90'},{id:'D',text:'100'}],correctAnswer:'B',method:'Addition',explanation:'Add both numbers.',pyq:null,sourceType:i%2?'AI_GENERATED':'MANUAL'}}));
const candidate=(slot,repair=false)=>({slotId:slot.id,pattern:slot.reference.pattern,prompt:`Find the sum of ${20+Number(slot.id.slice(1))} and ${repair?7:5}.`,
 options:[{id:'A',text:'10'},{id:'B',text:String(20+Number(slot.id.slice(1))+(repair?7:5))},{id:'C',text:'50'},{id:'D',text:'90'}],correctAnswer:'B',hints:['Add the tens first.','Then add the remaining units.'],
 explanation:'Add the two values, then subtract one to check the sum.',method:'Addition of tens and units',alternativeExplanation:'Start with the next ten and adjust the remaining units.',difficulty:slot.difficulty,estimatedTimeSeconds:15});
function harness({reject=[],repairReject=[],missing=[],duplicate=[]}={}){
 const manifest=slots(),calls=[];
 return {manifest,calls,run:()=>runLunaWorkflow(manifest,{
  call:async call=>{calls.push(call);const ids=call.input.slots.map(s=>s.slotId);
   if(call.stage==='GENERATING'||call.stage==='REPAIRING')return {questions:manifest.filter(s=>ids.includes(s.id)&&!(call.stage==='GENERATING'&&missing.includes(s.id))).map(s=>candidate(s,call.stage==='REPAIRING'))};
   const rejected=call.stage==='REVIEWING'?reject:repairReject;
   return {verdicts:ids.map(id=>({slotId:id,pass:!rejected.includes(id),code:rejected.includes(id)?'MATH':'OK',detail:rejected.includes(id)?'The proposed answer is wrong.':''}))};
  },duplicates:async qs=>new Set(qs.filter(q=>duplicate.includes(q.slotId)&&!q.prompt.endsWith('7.')).map(q=>q.slotId)),
 })};
}
test('exact quotas, single persisted Silver choice and lower-tier authority',()=>{
 const expected={UNRANKED:[10,0,0],BRONZE:[10,0,0],GOLD:[8,1,1],PLATINUM:[6,2,2],DIAMOND:[4,3,3]};
 for(const [tier,counts] of Object.entries(expected)){const q=difficultyQuota(tier,()=>{throw Error('No non-Silver coin');});assert.deepEqual(['EASY','MEDIUM','HARD'].map(d=>q.filter(v=>v===d).length),counts);}
 for(const bit of [0,1]){let coins=0;const q=difficultyQuota('SILVER',()=>{coins++;return bit;});assert.equal(coins,1);assert.equal(q.length,10);assert.equal(q.filter(d=>d==='HARD').length,bit);assert.equal(q.filter(d=>d==='MEDIUM').length,1);}
 for(const a of TIERS)for(const b of TIERS)assert.equal(matchTier(a,b),TIERS[Math.min(TIERS.indexOf(a),TIERS.indexOf(b))]);
});
test('medium default, high supported, low and malformed deadlines rejected',()=>{
 const cfg=readLunaConfig({OPEN_AI_API_KEY:'fixture-key'});assert.equal(cfg.reasoning,'medium');assert.equal(cfg.requestTimeoutMs,120000);assert.equal(cfg.preparationTimeoutMs,600000);assert.equal(cfg.maxCalls,4);
 assert.equal(readLunaConfig({LUNA_REASONING_EFFORT:'high'}).reasoning,'high');
 for(const effort of ['low','none','xhigh'])assert.throws(()=>readLunaConfig({LUNA_REASONING_EFFORT:effort}),/LUNA_REASONING_EFFORT/);
 assert.throws(()=>readLunaConfig({LUNA_REQUEST_TIMEOUT_MS:'120000',LUNA_PREPARATION_TIMEOUT_MS:'1000'}));
});
test('short estimates accepted; complete support required; labels/options/source copying rejected',()=>{
 const s=slots()[0],q=candidate(s);assert.equal(checkCandidate(q,s).question.estimatedTimeSeconds,15);
 for(const bad of [{...q,estimatedTimeSeconds:0},{...q,hints:[]},{...q,explanation:''},{...q,pattern:'UNTAUGHT'},{...q,prompt:s.reference.prompt},{...q,prompt:'A mental maths question with 10 and 20.'},{...q,method:'Mental-only addition'},{...q,options:q.options.map((o,i)=>({...o,text:i===1?'10':o.text}))}])assert.ok(checkCandidate(bad,s).issue);
 assert.notEqual(fingerprint({...q,prompt:'Compute 4 × 5.'}),fingerprint({...q,prompt:'Compute 4 ÷ 5.'}));
 const compact=referenceContext([s])[0];assert.equal(compact.reference.explanation,s.reference.explanation);assert.equal(compact.reference.method,s.reference.method);assert.equal('sourceType' in compact.reference,false);assert.equal('id' in compact.reference,false);
});
test('clean batch uses exactly generation + independent review and retains full metadata',async()=>{
 const h=harness();const result=await h.run();assert.deepEqual(h.calls.map(c=>c.stage),['GENERATING','REVIEWING']);assert.equal(result.length,10);
 for(const q of result){assert.equal(q.hints.length,2);assert.ok(q.explanation);assert.ok(q.method);assert.ok(q.alternativeExplanation);}
 assert.equal(h.calls[1].input.slots.length,10);assert.equal(h.calls[1].input.candidates.length,10);
});
test('first/middle/last failures repair only rejected slots without shifting mappings',async()=>{
 const h=harness({reject:['s1','s5','s10']});const result=await h.run();assert.equal(h.calls.length,4);assert.deepEqual(h.calls[2].input.slots.map(s=>s.slotId),['s1','s5','s10']);
 assert.deepEqual(h.calls[3].input.candidates.map(s=>s.slotId),['s1','s5','s10']);
 result.forEach((q,i)=>{assert.equal(q.slotId,`s${i+1}`);assert.equal(q.pattern,`ADD${i}`);assert.equal(q.difficulty,'EASY');assert.equal(q.prompt.endsWith('7.'),[0,4,9].includes(i));});
});
test('missing and already-existing content is repaired, never replaced from a pool',async()=>{
 for(const config of [{missing:['s1']},{duplicate:['s3']}]){const h=harness(config);assert.equal((await h.run()).length,10);assert.equal(h.calls.length,4);assert.equal(h.calls[2].input.slots.length,1);}
});
test('repair review failure cannot publish an incomplete batch or request a fifth call',async()=>{
 const h=harness({reject:['s2'],repairReject:['s2']});await assert.rejects(h.run(),/QUALITY_REVIEW_FAILED/);assert.equal(h.calls.length,4);
});
test('duplicate slots or missing reviewer verdicts fail closed',async()=>{
 for(const badReview of [false,true]){
  let calls=0;const manifest=slots();
  await assert.rejects(()=>runLunaWorkflow(manifest,{duplicates:async()=>new Set(),call:async()=>{
   calls++;if(calls===1)return {questions:badReview?manifest.map(s=>candidate(s)):[candidate(manifest[0]),candidate(manifest[0])]};
   return {verdicts:[]};
  }}));assert.equal(calls,badReview?2:1);
 }
});

test('PvP immutable snapshots retain full supporting metadata without exposing solutions during an active question',()=>{
 const {freezeQuestions,matchQuestions}=require('../../../pvp/ranked/ranked-questions.ts');
 const {publicQuestion,roundFeedback}=require('../../../pvp/pvp.dto.ts');
 const questions=slots().map((s,i)=>({...candidate(s),id:`q${i}`,pyq:null,subjectId:'math',topicId:'numbers',subtopicId:'sub',sourceType:'LUNA',generationModel:'gpt-6-luna'}));
 const snapshot=freezeQuestions(questions),match={questionSnapshot:snapshot,ratingMode:'RATED',questionSet:{setQuestions:[]},status:'QUESTION_TRANSITION',currentQuestionIndex:0,players:[],answers:[]};
 questions[0].explanation='Edited after admission';
 const frozen=matchQuestions(match)[0];assert.notEqual(frozen.explanation,questions[0].explanation);assert.equal(frozen.hints.length,2);assert.ok(frozen.alternativeExplanation);assert.equal(frozen.sourceType,'LUNA');
 const current=publicQuestion(frozen);for(const key of ['correctAnswer','explanation','method','hints'])assert.equal(key in current,false);
 const feedback=roundFeedback(match,0);assert.equal(feedback.hints.length,2);assert.equal(feedback.explanation,frozen.explanation);assert.equal(feedback.alternativeExplanation,frozen.alternativeExplanation);
});
