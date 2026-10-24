import { Prisma } from '@prisma/client';
import { prisma } from '../../../config/prisma';
import { ENV } from '../../../config/env';
import { PublicError } from '../../../security/errors';
import { LiveCurriculumService } from '../../curriculum/services/live-curriculum.service';
import { Reference, Slot, Tier, difficultyQuota, shuffle, normalize } from './contracts';

const key=(v:string)=>v.toLowerCase().replace(/\band\b/g,'').replace(/[^a-z0-9]/g,'');
export function pilotTopic(topic:{topicId:string;topicName:string}, configured=ENV.LUNA.topics){
  return configured.some(v=>key(v)===key(topic.topicId)||key(v)===key(topic.topicName));
}
export interface Scope {subtopicIds:string[];topicId?:string;smartPicks:boolean;duelId?:string}
export async function referenceCatalog(){
  const live=(await LiveCurriculumService.getAllLiveCurriculumUniverse()).filter(t=>pilotTopic(t));
  const ids=live.flatMap(t=>t.subtopics.map(s=>s.id));
  if(!ids.length)return [];
  const usable=await prisma.question.findMany({where:{sourceType:{in:['MANUAL','AI_GENERATED']},OR:[{generationModel:null},{generationModel:{not:'gpt-6-luna'}}],status:'PUBLISHED',subtopicId:{in:ids},pattern:{not:null},
    subtopic:{isActive:true},topic:{isActive:true},subject:{isActive:true}},select:{id:true,subtopicId:true,pattern:true,prompt:true,options:true,correctAnswer:true,explanation:true,method:true}});
  const supported=new Set(usable.filter(usableReference).map(q=>q.subtopicId));
  return live.map(t=>({...t,subtopics:t.subtopics.filter(s=>supported.has(s.id))})).filter(t=>t.subtopics.length);
}
export function referenceOptions(value:unknown){
  if(!Array.isArray(value))return [];
  return value.flatMap(o=>{if(!o||typeof o!=='object')return [];const r=o as Record<string,unknown>;const text=r.text??r.label;return typeof r.id==='string'&&typeof text==='string'?[{id:r.id.toUpperCase(),text}]:[];});
}
function usableReference(q:{pattern:string|null;prompt:string;options:unknown;correctAnswer:string;explanation:string;method:string}){
  const options=referenceOptions(q.options);
  return !!q.pattern?.trim()&&q.pattern.length<=100&&!!q.prompt.trim()&&!!q.explanation.trim()&&!!q.method.trim()&&options.length===4
    &&new Set(options.map(o=>o.id)).size===4&&['A','B','C','D'].every(id=>options.some(o=>o.id===id))&&options.some(o=>o.id===q.correctAnswer.toUpperCase())&&new Set(options.map(o=>normalize(o.text))).size===4;
}
export async function resolveScope(input:{topicId?:string;subtopicIds?:string[];smartPicks?:boolean}):Promise<Scope>{
  const catalog=await referenceCatalog(), supported=new Set(catalog.flatMap(t=>t.subtopics.map(s=>s.id)));
  if(!supported.size)throw new PublicError('No supported questions are available in this pilot.','LUNA_SCOPE_UNAVAILABLE',409);
  const topic=input.topicId?await prisma.topic.findFirst({where:{OR:[{id:input.topicId},{slug:input.topicId}]},select:{id:true}}):null;
  if(input.topicId&&(!topic||!catalog.some(t=>t.topicId===topic.id)))throw new PublicError('This topic is not available in the question pilot.','LUNA_SCOPE_UNAVAILABLE',409);
  let ids=input.subtopicIds;
  if(ids?.length){
    const uuid=ids.filter(id=>/^[0-9a-f-]{36}$/i.test(id));
    const [subtopics,scripts,assignments]=await Promise.all([
      prisma.subtopic.findMany({where:{OR:[{id:{in:ids}},{slug:{in:ids}}]},select:{id:true,slug:true}}),
      prisma.lessonScript.findMany({where:{OR:[{slug:{in:ids}},...(uuid.length?[{id:{in:uuid}}]:[])]},select:{id:true,slug:true,subtopicId:true}}),
      uuid.length?prisma.scriptAssignment.findMany({where:{id:{in:uuid}},include:{script:{select:{subtopicId:true}}}}):Promise.resolve([]),
    ]);
    ids=[...new Set(ids.map(id=>subtopics.find(s=>s.id===id||s.slug===id)?.id??scripts.find(s=>s.id===id||s.slug===id)?.subtopicId??assignments.find(a=>a.id===id)?.script.subtopicId??id))];
    if(ids.some(id=>!supported.has(id)) || topic&&ids.some(id=>!catalog.find(t=>t.topicId===topic.id)?.subtopics.some(s=>s.id===id)))throw new PublicError('Some selected subtopics are unavailable. Update your selection.','LUNA_SCOPE_UNAVAILABLE',409);
  }else ids=catalog.filter(t=>!topic||t.topicId===topic.id).flatMap(t=>t.subtopics.map(s=>s.id));
  return {subtopicIds:ids, ...(topic?{topicId:topic.id}:{}),smartPicks:input.smartPicks??false};
}
export async function planSlots(scope:Scope,tier:Tier,users:string[]):Promise<Slot[]>{
  const catalog=await referenceCatalog();
  const permitted=new Set(catalog.flatMap(t=>t.subtopics.map(s=>s.id)));
  if(!scope.subtopicIds.length||scope.subtopicIds.some(id=>!permitted.has(id)))throw new Error('REFERENCE_SCOPE_CHANGED');
  // Original manual/AI references only. Never seed recursively from this feature's Luna outputs.
  const rows=await prisma.question.findMany({where:{sourceType:{in:['MANUAL','AI_GENERATED']},OR:[{generationModel:null},{generationModel:{not:'gpt-6-luna'}}],status:'PUBLISHED',subtopicId:{in:scope.subtopicIds},pattern:{not:null},subtopic:{isActive:true},topic:{isActive:true},subject:{isActive:true}},include:{subtopic:true}});
  const groups=new Map<string,Reference[]>();
  for(const q of rows.filter(usableReference)){
    const ref:Reference={id:q.id,subjectId:q.subjectId,topicId:q.topicId,subtopicId:q.subtopicId,subtopicName:q.subtopic.name,scope:q.subtopic.description??q.subtopic.name,
      pattern:q.pattern!,prompt:q.prompt,options:referenceOptions(q.options),correctAnswer:q.correctAnswer.toUpperCase(),explanation:q.explanation,method:q.method,pyq:q.pyq,sourceType:q.sourceType};
    const groupKey=JSON.stringify([q.subtopicId,q.pattern]);groups.set(groupKey,[...(groups.get(groupKey)??[]),ref]);
  }
  if(scope.subtopicIds.some(id=>![...groups.values()].some(g=>g[0].subtopicId===id)))throw new Error('REFERENCE_SCOPE_CHANGED');
  const weakByUser: string[][]=[];
  if(scope.smartPicks){
    for(const user of users){
      const evidence=await prisma.$queryRaw<{subtopicId:string;pattern:string}[]>(Prisma.sql`
        WITH performance AS (
          SELECT question_id,times_seen AS seen,times_correct AS correct FROM learning.user_question_progress WHERE user_id=${user}::uuid
          UNION ALL SELECT question_id,1,is_correct::int FROM learning.question_attempts WHERE user_id=${user}::uuid
          UNION ALL SELECT question_id,1,is_correct::int FROM learning.pvp_match_answers WHERE user_id=${user}::uuid
        ) SELECT q.subtopic_id AS "subtopicId",q.pattern FROM performance p JOIN learning.questions q ON q.id=p.question_id
        WHERE q.subtopic_id IN (${Prisma.join(scope.subtopicIds)}) GROUP BY q.subtopic_id,q.pattern
        HAVING sum(p.correct)<sum(p.seen) ORDER BY sum(p.correct)::float/NULLIF(sum(p.seen),0),sum(p.seen) DESC LIMIT 6`);
      weakByUser.push(evidence.map(e=>JSON.stringify([e.subtopicId,e.pattern])).filter(k=>groups.has(k)));
    }
  }
  const chosen:string[]=[];
  // Round-robin subtopics, then patterns; shuffled once and persisted with difficulty/answer assignment.
  const bySub=shuffle(scope.subtopicIds).map(id=>shuffle([...groups.keys()].filter(k=>groups.get(k)![0].subtopicId===id)));
  const breadth:string[]=[];
  for(let i=0;bySub.some(keys=>i<keys.length);i++)for(const keys of bySub)if(keys[i])breadth.push(keys[i]);
  const contributions=users.length===2?2:1,perUser=10/contributions;
  for(let u=0;u<contributions;u++){
    const contribution:string[]=[],focusLimit=contributions===2?3:6;
    for(const group of weakByUser[u]??[]){for(let n=0;n<3&&contribution.length<focusLimit;n++)contribution.push(group);if(contribution.length>=focusLimit)break;}
    for(let i=0;contribution.length<perUser;i++)contribution.push(breadth[(u*perUser+i)%breadth.length]);
    chosen.push(...contribution);
  }
  const letters=shuffle(['A','B','C','D']);
  const positions=shuffle(letters.flatMap((letter,i)=>Array<string>(i<2?3:2).fill(letter)));
  const difficulties=shuffle(difficultyQuota(tier));
  const used=new Set<string>();
  return shuffle(chosen).map((g,i)=>{
    const refs=groups.get(g)!;
    const isPyq=(r:Reference)=>!!r.pyq&&/[a-z]/i.test(r.pyq)&&/\b(?:19|20)\d{2}\b/.test(r.pyq);
    const pyq=refs.filter(isPyq), preferred=pyq.length?pyq:refs, fresh=preferred.filter(r=>!used.has(r.id)),ref=shuffle(fresh.length?fresh:preferred)[0];used.add(ref.id);
    return {id:`s${i+1}`,difficulty:difficulties[i],answerPosition:positions[i],reference:ref};
  });
}
