const test=require('node:test');const assert=require('node:assert/strict');const fs=require('node:fs');const path=require('node:path');const vm=require('node:vm');const ts=require('typescript');
function setup({answered=false}={}){
 const questions=Array.from({length:10},(_,i)=>({id:'sq'+i,questionId:'q'+i,isAnswered:i===0&&answered,isCorrect:false,responseTimeMs:null,question:{id:'q'+i,prompt:'Add 2 and 2',options:[{id:'A',text:'3'},{id:'B',text:'4'},{id:'C',text:'5'},{id:'D',text:'6'}],correctAnswer:'B',explanation:'2 + 2 = 4.',method:'Add.',alternativeExplanation:'Check 4 - 2 = 2.',preferredSolution:'BOOK',preferredReason:'Simple addition.',hints:[],subtopicId:'s1',difficulty:'EASY'}}));
 const session={id:'session',userId:'user',status:'ACTIVE',currentIndex:0,totalQuestions:10,questions,isReplay:true,totalTimeMs:0,correctCount:0};
 const writes=[], lookups=[];let transactions=0;
 const tx={$queryRaw:async()=>[],practiceSession:{findUnique:async()=>session,update:async args=>{writes.push(args);return session}},practiceSessionQuestion:{findUnique:async()=>({isAnswered:answered}),update:async args=>{Object.assign(questions[0],args.data);return questions[0]},findMany:async()=>questions}};
 const prisma={practiceSession:{findFirst:async args=>{lookups.push(args);return args.where.userId==='other'?null:session}},$transaction:async fn=>{transactions++;return fn(tx)}};
 const deps={'../../../config/prisma':{prisma},'./practice-selection.service':{practiceSelectionService:{}},'../../xp/xp.service':{XpService:{}},'../../xp/xp.policy':{XpPolicy:{}}};
 const code=ts.transpileModule(fs.readFileSync(path.join(__dirname,'../services/practice-session.service.ts'),'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText;const exports={};vm.runInNewContext(code,{exports,require:id=>deps[id],console,Date,Set,Math});
 return {service:exports.practiceSessionService,session,writes,lookups,transactions:()=>transactions};
}
const params={sessionId:'session',userId:'user',questionId:'q0',selectedOptionId:'TIMEOUT',responseTimeMs:60000};
test('unanswered session masks every solution channel',async()=>{
 const s=setup();const result=await s.service.getSession('session','user');const q=result.questions[0].question;
 assert.equal(q.correctAnswer,undefined);assert.equal(q.explanation,undefined);assert.equal(q.method,undefined);assert.equal(q.alternativeExplanation,undefined);assert.equal(q.preferredReason,undefined);
});
test('timeout records one wrong answer and advances a replay without rewards',async()=>{
 const s=setup();const result=await s.service.submitAnswer(params);assert.equal(result.isCorrect,false);assert.equal(result.correctAnswer,'B');assert.equal(result.xpAwarded,0);assert.equal(s.writes[0].data.currentIndex,1);assert.equal(s.writes[0].data.totalTimeMs,60000);
});
test('invalid options, time, out-of-order and duplicate answers cannot mutate progress',async()=>{
 for(const payload of [{selectedOptionId:'Z'},{responseTimeMs:-1},{responseTimeMs:NaN},{questionId:'q1'}]){const s=setup();await assert.rejects(()=>s.service.submitAnswer({...params,...payload}));assert.equal(s.transactions(),0)}
 const s=setup({answered:true});await assert.rejects(()=>s.service.submitAnswer(params),/already been answered/);assert.equal(s.transactions(),0);
});
test('practice replay is scoped to its owner before any writes',async()=>{
 const s=setup();await assert.rejects(()=>s.service.replayPracticeSession('other','session'),/not found for replay/);assert.equal(s.lookups[0].where.userId,'other');assert.equal(s.transactions(),0);
});
