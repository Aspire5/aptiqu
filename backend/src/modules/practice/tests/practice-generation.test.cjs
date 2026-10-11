const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const ts=require('typescript');
function load(relative,deps){
 const code=ts.transpileModule(fs.readFileSync(path.join(__dirname,relative),'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText;
 const exports={}; vm.runInNewContext(code,{exports,require:id=>{assert.ok(id in deps,'Unexpected dependency '+id);return deps[id]},console,Set,Map,Date});return exports;
}
const raw={pattern:'addition',prompt:'What is the sum of 12 and 18?',options:[{id:'A',text:'28'},{id:'B',text:'30'},{id:'C',text:'32'},{id:'D',text:'36'}],correctAnswer:'B',difficulty:'EASY',estimatedTimeSeconds:40,calculationMode:'MENTAL',hints:['Add the two numbers.','Add the tens first, then the units.'],method:'Add tens and units.',explanation:'12 + 18 = 30. Check: 30 - 18 = 12.'};
function setup({examples=[raw],review=[raw]}={}){
 const calls=[], saved=[]; let locks=0;
 const validator=load('../../question/validators/question-structural.validator.ts',{'zod':require('zod'),'../../../config/inventory.config':{TIME_CONFIG:{GLOBAL_MIN_SECONDS:30,GLOBAL_MAX_SECONDS:120,PVP_MAX_SECONDS:60}}});
 const prisma={subtopic:{findUnique:async()=>({id:'s1',name:'Addition',isActive:true,topic:{id:'t1',name:'Numbers',isActive:true,subject:{id:'subject',name:'Math',isActive:true}}})},question:{findMany:async args=>args.where.sourceType?examples:[],findUnique:async()=>null,create:async args=>{saved.push(args.data);return {...args.data,id:'new'}}}};
 const deps={
  '../../../config/prisma':{prisma}, '../gemini.provider':{geminiProvider:{generateStructuredContent:async params=>{calls.push(params);return calls.length===1?{questions:[raw]}:{acceptedQuestions:review}}}},
  '../prompts/practice-generation.prompt':{PRACTICE_GENERATION_SYSTEM_INSTRUCTION:'generator',QUESTION_ARRAY_JSON_SCHEMA:{}},
  '../prompts/practice-review.prompt':{PRACTICE_REVIEW_SYSTEM_INSTRUCTION:'reviewer',QUESTION_REVIEW_JSON_SCHEMA:{}},
  './ai-prompt.service':{aiPromptService:{getPublishedPrompt:async()=> 'published prompt'}},
  '../../question/validators/question-structural.validator':validator,
  '../../question/services/fingerprint.service':{FingerprintService:{computeFingerprint:q=>q}},
  '../../curriculum/services/live-curriculum.service':{LiveCurriculumService:{isSubtopicLive:async()=>true}},
  '../../../config/inventory.config':{INVENTORY_CONFIG:{DEFAULT_BATCH_GENERATION_UNIT:5}},
  '../../concurrency/concurrency-lock.service':{ConcurrencyLockService:{acquireLock:async()=>{locks++;return 'token'},releaseLock:async()=>{}}},
  '@prisma/client':{},
 };
 return {service:load('../../ai/services/question-generation.service.ts',deps).questionGenerationService,calls,saved,locks:()=>locks};
}
test('generation requires approved examples before calling AI',async()=>{
 const s=setup({examples:[]});await assert.rejects(()=>s.service.generateQuestionsForSubtopic('s1',1,'addition'),/approved source examples/);assert.equal(s.calls.length,0);assert.equal(s.locks(),0);
});
test('generation supplies exact examples and variation limits and publishes only reviewed output',async()=>{
 const s=setup();const result=await s.service.generateQuestionsForSubtopic('s1',1,'addition');
 assert.equal(s.calls.length,2);assert.ok(s.calls[0].prompt.includes(raw.prompt));assert.match(s.calls[0].prompt,/Allowed variations/);assert.match(s.calls[0].prompt,/Exact target pattern: addition/);
 assert.equal(s.calls[1].systemInstruction,'reviewer');assert.match(s.calls[1].prompt,/approvedExamples/);assert.equal(result.length,1);assert.equal(s.saved[0].pattern,'addition');assert.equal(s.saved[0].status,'PUBLISHED');assert.equal(s.saved[0].generationPromptVersion,'v2.0.0-exemplar');
});
test('review rejection or invented patterns cannot enter published inventory',async()=>{
 for(const review of [[],[{...raw,pattern:'invented'}],[{...raw,correctAnswer:'Z'}]]){
  const s=setup({review});assert.equal((await s.service.generateQuestionsForSubtopic('s1',1,'addition')).length,0);assert.equal(s.saved.length,0);
 }
});
