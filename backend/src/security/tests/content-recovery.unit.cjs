// Inert regression fixture: no environment file, database, Redis or app bootstrap.
const test=require('node:test'),assert=require('node:assert/strict'),path=require('node:path');
const {loader}=require('../../modules/pvp/tests/pvp-test-fixture.cjs');
const source=path.join(__dirname,'../../modules/admin/services/rs-aggarwal-startup-sync.service.ts');
function fixture({missing=false,inactive=false}={}) {
 const state={subject:inactive?{id:'existing',isActive:false}:null,topics:[],subtopics:[],scripts:[],reconciles:0,imports:0};
 const definition=(id,title)=>({scriptId:id,metadata:{title}});
 const files={
  '/source/SBT-RSA-01-Number_System/Scripts/legacy.json':definition('script-legacy','Saved legacy lesson'),
  '/source/SBT-RSA-15-Chain-Rule/subtopics.json':[{name:'Approved lesson',externalSubTopicKey:'approved',position:0}],
  '/source/SBT-RSA-15-Chain-Rule/Scripts/approved.json':definition('approved','Approved lesson'),
 };
 const db={
  subject:{findFirst:async()=>state.subject,create:async({data})=>state.subject={...data,isActive:true}},
  topic:{findFirst:async({where})=>state.topics.find(t=>t.name===where.OR[0].name),create:async({data})=>{state.topics.push(data);return data;}},
  subjectTopic:{updateMany:async()=>({count:0})},
  subtopic:{findMany:async({where})=>state.subtopics.filter(s=>s.topicId===where.topicId),upsert:async({where,create})=>{let s=state.subtopics.find(s=>s.id===where.id);if(!s){s=create;state.subtopics.push(s);}return s;}},
  lessonScript:{findUnique:async({where})=>state.scripts.find(s=>s.slug===where.slug),findFirst:async({where})=>state.scripts.find(s=>s.topicId===where.topicId&&s.subtopicId===where.subtopicId)},
 };
 const load=loader({
  '../../../config/env':{ENV:{CURRICULUM_SOURCE_ROOT:'/source'}},'../../../config/prisma':{prisma:db},
  '../../../observability/logger':{log:()=>{},safeError:()=>({})},path:{default:path},
  'fs/promises':{readdir:async p=>{if(missing)throw new Error('Missing source');if(p==='/source')return ['SBT-RSA-01-Number_System','SBT-RSA-15-Chain-Rule'].map(name=>({name,isDirectory:()=>true}));return p.includes('01-')?['legacy.json']:['approved.json'];},readFile:async p=>{if(!files[p])throw Object.assign(new Error('No legacy manifest'),{code:'ENOENT'});return JSON.stringify(files[p]);}},
  '../../lesson/engines/script-validator':{ScriptValidator:{validate:()=>({valid:true})}},
  '../../lesson/services/script-cache.service':{scriptCacheService:{normalizeScriptDefinition:d=>d}},
  '../../roadmap/services/catalog-mutation':{catalogMutation:async(work,reconcile)=>{assert.equal(reconcile,false);return work();}},
  '../../roadmap/services/roadmap-progression.service':{roadmapProgressionService:{syncRoadmapWithSyllabus:async()=>state.reconciles++}},
  '../admin-syllabus.service':{AdminSyllabusService:{importSubtopics:async(topicId,items)=>{state.subtopics.push(...items.map(s=>({id:s.externalSubTopicKey,slug:s.externalSubTopicKey,topicId,name:s.name,description:'',sequence:0,importance:'medium',isActive:true})));},importScript:async d=>{state.imports++;state.scripts.push({...d,slug:d.definition.scriptId});}}},
 });
 return {state,sync:load(source).syncRsAggarwalOnStartup};
}
test('empty DB recovers subject, legacy parents and later approved chapters; rerun retains scripts and reconciles once per batch',async()=>{
 const {state,sync}=fixture();const first=await sync();
 assert.equal(first.scripts,2);assert.equal(first.failedScripts,0);assert.equal(state.topics.length,2);assert.equal(state.reconciles,1);
 assert.equal(state.subject.name,'RS Aggarwal - Quantitative Aptitude');assert.equal(state.topics[1].name,'Chain Rule');
 const second=await sync();assert.equal(second.scripts,0);assert.equal(second.skippedScripts,2);assert.equal(state.imports,2);assert.equal(state.reconciles,2);
});
test('missing source does not manufacture an empty subject and inactive subjects remain inactive',async()=>{
 const missing=fixture({missing:true});assert.equal((await missing.sync()).sourceAvailable,false);assert.equal(missing.state.subject,null);
 const inactive=fixture({inactive:true});await inactive.sync();assert.equal(inactive.state.topics.length,0);assert.equal(inactive.state.subject.isActive,false);
});
test('an empty roadmap catalog returns an actionable temporary-unavailable error',async()=>{
 const db={user:{findUnique:async()=>null},roadmap:{findFirst:async()=>null}};
 const load=loader({'../../../config/prisma':{prisma:db},'../../lesson/services/learning-transaction':{prisma:db},'../../xp/xp.service':{xpService:{}}});
 const {roadmapProgressionService}=load(path.join(__dirname,'../../modules/roadmap/services/roadmap-progression.service.ts'));
 await assert.rejects(()=>roadmapProgressionService.getUserActiveRoadmap('fixture'),e=>e.status===503&&e.code==='CURRICULUM_NOT_READY');
});
test('missing saved question references are reported explicitly without publishing substitutes',async()=>{
 const load=loader({'./learning-transaction':{prisma:{question:{findMany:async()=>[]}}}});
 const {questionHydrationService}=load(path.join(__dirname,'../../modules/lesson/services/question-hydration.service.ts'));
 for(const questionReference of [{mode:'QUESTION_EXTERNAL_ID',externalId:'missing'},{mode:'REPOSITORY',questionId:'missing'}])
  await assert.rejects(()=>questionHydrationService.hydrateScriptDefinition({nodes:{q:{id:'q',type:'QUESTION',questionReference}}}),e=>e.code==='QUESTION_REFERENCE_MISSING'&&e.status===409);
});
