const test=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),ts=require('typescript');
function load(relative,deps){const exports={};const code=ts.transpileModule(fs.readFileSync(path.join(__dirname,relative),'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText;vm.runInNewContext(code,{exports,Date,require:id=>{assert.ok(id in deps,`Unexpected dependency: ${id}`);return deps[id];}});return exports;}
const socialError=message=>new Error(message);
test('friendly admission creates two sessions with the same ten reviewed IDs/order/snapshot and no early reward',async()=>{
 const writes=[],now=new Date();
 const duel={id:'duel',status:'PREPARING',expiresAt:new Date(+now+600000),requesterId:'a',recipientId:'b',friendshipId:'friend',subtopicIds:['sub'],timerEnabled:true};
 const tx={friendlyDuel:{findUnique:async()=>duel,update:async({data})=>writes.push(data)},friendship:{findUnique:async()=>({status:'ACCEPTED'})},friendlyDuelSeat:{count:async()=>2},practiceSession:{create:async({data})=>{writes.push(data);return {id:`session-${data.userId}`};}},practiceSessionQuestion:{createMany:async({data})=>writes.push(data)}};
 const {finalizePreparedDuel}=load('../../../social/luna-duel.ts',{'./social.transport':{socialError}});
 const qs=Array.from({length:10},(_,i)=>({id:`q${i}`,subjectId:'math',topicId:'numbers'})),snapshot={q0:{hints:['one','two'],explanation:'Full explanation'}};
 await finalizePreparedDuel(tx,'duel',qs,snapshot,now);
 assert.equal(writes[0].status,'ACTIVE');
 const sessions=writes.filter(w=>w.userId);assert.equal(sessions.length,2);for(const s of sessions){assert.equal(s.totalQuestions,10);assert.equal(s.questionSnapshot,snapshot);assert.equal(s.isFriendlyDuel,true);assert.equal(s.xpAwarded,undefined);}
 const allocations=writes.filter(Array.isArray);assert.equal(allocations.length,2);assert.equal(allocations[0].map(q=>q.questionId).join(','),allocations[1].map(q=>q.questionId).join(','));
});
test('expired, abandoned or unfriended friendly preparations cannot publish',async()=>{
 const {finalizePreparedDuel}=load('../../../social/luna-duel.ts',{'./social.transport':{socialError}});
 for(const change of [{status:'ABANDONED'},{expiresAt:new Date(Date.now()-1)},{unfriended:true}]){
  const duel={status:'PREPARING',expiresAt:new Date(Date.now()+600000),...change};let writes=0;
  const tx={friendlyDuel:{findUnique:async()=>duel,update:async()=>{writes++;}},friendship:{findUnique:async()=>({status:change.unfriended?'REMOVED':'ACCEPTED'})},friendlyDuelSeat:{count:async()=>2}};
  await assert.rejects(finalizePreparedDuel(tx,'duel',[],{},new Date()));assert.equal(writes,0);
 }
});
test('friendly status reconnect recovers the dispatch gap and ends expired preparation',async()=>{
 for(const state of ['MISSING','QUEUED','EXPIRED']){
  const duel={id:'duel',status:'PREPARING',requesterId:'a',recipientId:'b',expiresAt:new Date(Date.now()+600000),subtopicIds:['sub'],smartPicks:false,timerEnabled:true,selectionNotes:[],requester:{id:'a'},recipient:{id:'b'},sessions:[]};
  let started=0,polled=0,abandoned=0;
  const db={friendlyDuel:{findFirst:async()=>duel,findUnique:async()=>duel},questionPreparation:{findFirst:async()=>state==='MISSING'?null:{id:'job',state,deadline:new Date(Date.now()+600000)}},$transaction:async fn=>fn({$queryRaw:async()=>[]})};
  const deps={'@prisma/client':require('@prisma/client'),'../../config/prisma':{prisma:db},'./friends.service':{publicUser:u=>u,publicUserSelect:{}},'./duel.selection':{resolveDuelScope:async ids=>ids},'../../config/env':{ENV:{LUNA:{preparationTimeoutMs:600000}}},'../ai/luna/preparations':{ACTIVE_STATES:[],startPreparation:async()=>{started++;},preparationStatus:async()=>{polled++;}},'./social.transport':{socialError,socialTransport:{notify:async()=>{}}},'../xp/xp.service':{XpService:{}}};
  const {DuelsService}=load('../../../social/duels.service.ts',deps),service=new DuelsService();
  service.abandon=async()=>{abandoned++;duel.status='ABANDONED';};
  const result=await service.get('a','duel');
  assert.equal(started,state==='MISSING'?1:0);assert.equal(polled,state==='QUEUED'?1:0);assert.equal(abandoned,state==='EXPIRED'?1:0);assert.equal(result.status,state==='EXPIRED'?'ABANDONED':'PREPARING');
 }
});
