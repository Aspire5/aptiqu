const test=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),ts=require('typescript');
function setup(){
 const queries=[];
 const options=[{id:'A',text:'1'},{id:'B',text:'4'},{id:'C',text:'8'},{id:'D',text:'10'}];
 const row=(id,subtopicId,sourceType,pyq=null)=>({id:`00000000-0000-4000-8000-${String(id).padStart(12,'0')}`,subjectId:'math',topicId:'numbers',subtopicId,sourceType,pyq,generationModel:sourceType==='MANUAL'?null:sourceType==='LUNA'?'gpt-6-luna':'gemini',pattern:subtopicId==='sub-a'?'ADDITION':'SUBTRACTION',prompt:'What is 2 plus 2?',options,correctAnswer:'B',method:'Addition',explanation:'2 + 2 = 4.',subtopic:{name:subtopicId,description:'An approved skill.'}});
 const rows=[row(1,'sub-a','MANUAL','Example Exam (2020)'),row(2,'sub-a','AI_GENERATED'),row(3,'sub-b','AI_GENERATED'),row(4,'sub-a','LUNA')];
 const db={question:{findMany:async args=>{queries.push(args);return rows.filter(q=>args.where.sourceType.in.includes(q.sourceType)&&args.where.subtopicId.in.includes(q.subtopicId));}},
  subtopic:{findMany:async()=>[{id:'sub-a',slug:'alias-a'},{id:'sub-b',slug:'alias-b'}]},lessonScript:{findMany:async()=>[]},$queryRaw:async()=>[{subtopicId:'sub-a',pattern:'ADDITION'}]};
 const deps={'@prisma/client':require('@prisma/client'),'../../../config/prisma':{prisma:db},'../../../config/env':{ENV:{LUNA:{topics:['number-system']}}},'../../../security/errors':{PublicError:class extends Error{}},
  '../../curriculum/services/live-curriculum.service':{LiveCurriculumService:{getAllLiveCurriculumUniverse:async()=>[{topicId:'numbers',topicName:'Number System',subtopics:[{id:'sub-a',name:'Addition'},{id:'sub-b',name:'Subtraction'}]},{topicId:'ages',topicName:'Problems on Ages',subtopics:[{id:'outside',name:'Ages'}]}]}},'./contracts':require('../contracts.ts')};
 const code=ts.transpileModule(fs.readFileSync(path.join(__dirname,'../references.ts'),'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText;
 const exports={};vm.runInNewContext(code,{exports,require:id=>{assert.ok(id in deps,id);return deps[id];},Date,Map,Set,console});return {...exports,queries,rows};
}
test('pilot catalog excludes unsupported topics and accepts original manual AND AI references',async()=>{
 const s=setup(),catalog=await s.referenceCatalog();assert.equal(catalog.length,1);assert.equal(catalog[0].topicId,'numbers');assert.equal(catalog[0].subtopics.length,2);
 assert.equal(s.queries[0].where.sourceType.in.join(','),'MANUAL,AI_GENERATED');
 assert.equal(s.pilotTopic({topicId:'new',topicName:'Simplification'}),false);
});
test('stable ten-slot manifest uses exact tier quota, PYQ preference and never recursive Luna references',async()=>{
 const s=setup(),slots=await s.planSlots({subtopicIds:['sub-a','sub-b'],smartPicks:false},'PLATINUM',['user']);
 assert.equal(slots.length,10);assert.equal(new Set(slots.map(s=>s.id)).size,10);
 assert.deepEqual(['A','B','C','D'].map(id=>slots.filter(s=>s.answerPosition===id).length).sort(),[2,2,3,3]);
 assert.deepEqual(['EASY','MEDIUM','HARD'].map(d=>slots.filter(s=>s.difficulty===d).length),[6,2,2]);
 for(const slot of slots){assert.notEqual(slot.reference.sourceType,'LUNA');if(slot.reference.subtopicId==='sub-a')assert.equal(slot.reference.id,s.rows[0].id,'Prefer genuine PYQ even when repeated pattern needs the same reference again');}
 assert.ok(slots.some(s=>s.reference.sourceType==='AI_GENERATED'));
 await assert.rejects(s.planSlots({subtopicIds:['outside'],smartPicks:false},'UNRANKED',['user']),/REFERENCE_SCOPE_CHANGED/);
});
