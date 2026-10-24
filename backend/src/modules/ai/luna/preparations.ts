import { createHash, randomUUID } from 'node:crypto';
import { isDeepStrictEqual } from 'node:util';
import { Prisma, QuestionPreparation } from '@prisma/client';
import { z } from 'zod';
import { prisma } from '../../../config/prisma';
import { ENV } from '../../../config/env';
import { PublicError } from '../../../security/errors';
import { FingerprintService } from '../../question/services/fingerprint.service';
import { lockUsers } from '../../social/friends.service';
import { aiPromptService } from '../services/ai-prompt.service';
import { Candidate, Mode, PROFILE, Slot, Tier, fingerprint, slotSchema } from './contracts';
import { Scope, planSlots, referenceOptions } from './references';
import { GENERATION_INSTRUCTION, GENERATION_VERSION, REVIEW_INSTRUCTION, REVIEW_VERSION } from './prompts';
import { lunaCall, LunaUsage } from './provider';
import { runLunaWorkflow } from './workflow';

export const ACTIVE_STATES=['QUEUED','GENERATING','REVIEWING','REPAIRING','REREVIEWING','SAVING'];
export const TERMINAL_STATES=['READY','FAILED','CANCELLED','EXPIRED'];
const json=(value:unknown)=>JSON.parse(JSON.stringify(value)) as Prisma.InputJsonValue;
const scopeSchema=z.object({subtopicIds:z.array(z.string()).min(1).max(500),topicId:z.string().optional(),smartPicks:z.boolean(),duelId:z.string().uuid().optional()});
const manifestSchema=z.object({slots:z.array(slotSchema).length(10),generation:z.object({text:z.string(),version:z.string()}),review:z.object({text:z.string(),version:z.string()})});
const unavailable=()=>new PublicError('We couldn’t prepare your questions. Please try again.','PREPARATION_FAILED',503);
export function publicPreparation(row:QuestionPreparation){
  return {id:row.id,mode:row.mode,state:row.state,version:row.version,deadline:row.deadline.toISOString(),
    sessionId:row.mode==='PRACTICE'?row.resultSessionId:null,errorCode:row.errorCode};
}
async function enqueue(id:string){
  const {contentGenQueue}=await import('../../../queues/content-generation.queue');
  await contentGenQueue.add('luna-preparation',{preparationId:id},{jobId:`luna-${id}`,attempts:1,removeOnComplete:{age:3600,count:1000}});
}
export async function startPreparation(input:{users:string[];mode:Mode;tier:Tier;requestKey:string;scope:Scope}){
  if(!ENV.LUNA.enabled)throw new PublicError('Question preparation is temporarily unavailable.','LUNA_UNAVAILABLE',503);
  const users=[...new Set(input.users)].sort();
  if(!users.length||users.length>2)throw unavailable();
  const requestKey=createHash('sha256').update(JSON.stringify([input.mode,users,input.requestKey])).digest('hex');
  const row=await prisma.$transaction(async tx=>{
    await lockUsers(tx,users);
    const existing=await tx.questionPreparation.findUnique({where:{requestKey}});
    if(existing){
      if(!isDeepStrictEqual(existing.scope,json(input.scope))||existing.tier!==input.tier)throw new PublicError('This request key belongs to another selection.','REQUEST_CONFLICT',409);
      return existing;
    }
    await tx.questionPreparation.updateMany({where:{userIds:{hasSome:users},state:{in:ACTIVE_STATES},deadline:{lte:new Date()}},data:{state:'EXPIRED',errorCode:'PREPARATION_EXPIRED',version:{increment:1}}});
    const active=await tx.questionPreparation.findFirst({where:{userIds:{hasSome:users},state:{in:ACTIVE_STATES},deadline:{gt:new Date()}},select:{id:true}});
    if(active)throw new PublicError('Your questions are already being prepared. Resume the active preparation.','PREPARATION_ACTIVE',409);
    // The advisory lock serializes the bounded global pending check across API hosts.
    await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext('aptiqu:luna-pending'))`;
    if(await tx.questionPreparation.count({where:{state:{in:ACTIVE_STATES},deadline:{gt:new Date()}}})>=ENV.LUNA.maxPending)throw new PublicError('Question preparation is busy. Please retry shortly.','PREPARATION_BUSY',429,10);
    if(input.mode==='PRACTICE'&&await tx.friendlyDuelSeat.count({where:{userId:{in:users}}}))throw new PublicError('Finish your friendly duel first.','FRIENDLY_DUEL_ACTIVE',409);
    return tx.questionPreparation.create({data:{requestKey,userIds:users,mode:input.mode,tier:input.tier,scope:json(input.scope),deadline:new Date(Date.now()+ENV.LUNA.preparationTimeoutMs)}});
  });
  if(row.state==='QUEUED')try{await enqueue(row.id);}catch{
    await prisma.questionPreparation.updateMany({where:{id:row.id,state:'QUEUED'},data:{state:'FAILED',errorCode:'QUEUE_UNAVAILABLE',version:{increment:1}}});throw unavailable();
  }
  return row;
}
export async function preparationStatus(userId:string,id?:string){
  if(id&&!z.string().uuid().safeParse(id).success)throw new PublicError('Preparation not found.','NOT_FOUND',404);
  let row=await prisma.questionPreparation.findFirst({where:{...(id?{id}:{state:{in:ACTIVE_STATES}}),userIds:{has:userId}},orderBy:{createdAt:'desc'}});
  if(!row)return null;
  if(ACTIVE_STATES.includes(row.state)&&+row.deadline<=Date.now()){
    await prisma.questionPreparation.updateMany({where:{id:row.id,state:{in:ACTIVE_STATES},deadline:{lte:new Date()}},data:{state:'EXPIRED',errorCode:'PREPARATION_EXPIRED',version:{increment:1}}});
    row=await prisma.questionPreparation.findUniqueOrThrow({where:{id:row.id}});
  }
  // Repair the durable-insert/queue-dispatch gap after a process interruption.
  if(row.state==='QUEUED')await enqueue(row.id).catch(()=>{});
  return publicPreparation(row);
}
export async function cancelPreparation(user:string,id:string){
  const row=await prisma.questionPreparation.findFirst({where:{id,userIds:{has:user}}});
  if(!row)throw new PublicError('Preparation not found.','NOT_FOUND',404);
  if(row.mode==='RANKED'||row.mode==='UNRANKED')throw new PublicError('This match is already pairing.','PAIRING',409);
  if(row.mode==='FRIENDLY'){
    const {duelsService}=await import('../../social/duels.service');
    const scope=scopeSchema.parse(row.scope);if(scope.duelId)await duelsService.abandon(user,scope.duelId);
  }
  await prisma.questionPreparation.updateMany({where:{id,state:{in:ACTIVE_STATES}},data:{state:'CANCELLED',version:{increment:1}}});
  return preparationStatus(user,id);
}
export async function waitForPreparation(row:QuestionPreparation,active:()=>boolean,notify?:(status:ReturnType<typeof publicPreparation>)=>void){
  let last=-1;
  while(active()){
    const status=await preparationStatus(row.userIds[0],row.id);
    if(!status)throw unavailable();
    if(status.version!==last){last=status.version;notify?.(status);}
    if(status.state==='READY')return prisma.questionPreparation.findUniqueOrThrow({where:{id:row.id}});
    if(TERMINAL_STATES.includes(status.state))throw unavailable();
    await new Promise(resolve=>setTimeout(resolve,1500));
  }
  await prisma.questionPreparation.updateMany({where:{id:row.id,state:{in:ACTIVE_STATES}},data:{state:'CANCELLED',errorCode:'OWNERSHIP_LOST',version:{increment:1}}});
  throw new PublicError('Match search expired. Please search again.','QUEUE_CLAIM_LOST',409);
}
export async function processPreparation(id:string){
  if(!z.string().uuid().safeParse(id).success)throw unavailable();
  await prisma.questionPreparation.updateMany({where:{id,state:{in:ACTIVE_STATES},deadline:{lte:new Date()}},data:{state:'EXPIRED',errorCode:'PREPARATION_EXPIRED',version:{increment:1}}});
  const token=randomUUID();
  const acquired=await prisma.questionPreparation.updateMany({where:{id,state:'QUEUED',deadline:{gt:new Date()}},data:{state:'GENERATING',workerToken:token,version:{increment:1}}});
  if(!acquired.count){
    const previous=await prisma.questionPreparation.findUnique({where:{id}});
    // BullMQ retries a stalled worker; never repeat an ambiguous paid call after a crash.
    if(previous&&ACTIVE_STATES.includes(previous.state))await prisma.questionPreparation.updateMany({where:{id,state:previous.state,workerToken:previous.workerToken},data:{state:'FAILED',errorCode:'WORKER_INTERRUPTED',version:{increment:1}}});
    return;
  }
  const row=await prisma.questionPreparation.findUniqueOrThrow({where:{id}});
  const scope=scopeSchema.parse(row.scope);
  const update=async(data:Prisma.QuestionPreparationUpdateManyMutationInput)=>{
    const changed=await prisma.questionPreparation.updateMany({where:{id,workerToken:token,state:{in:ACTIVE_STATES},deadline:{gt:new Date()}},data:{...data,version:{increment:1}}});
    if(!changed.count)throw new Error('PREPARATION_OWNERSHIP_LOST');
  };
  try{
    // Persist all randomness and exact prompts once. Repairs never re-plan Silver's coin/difficulty.
    const slots=await planSlots(scope,row.tier as Tier,row.userIds);
    const [gen,review]=await Promise.all([
      aiPromptService.getPublishedPromptSnapshot('LUNA_GENERATION_V1',GENERATION_INSTRUCTION),
      aiPromptService.getPublishedPromptSnapshot('LUNA_REVIEW_V1',REVIEW_INSTRUCTION),
    ]);
    const generation={text:gen.text,version:`${GENERATION_VERSION}:${gen.version}`}, reviewer={text:review.text,version:`${REVIEW_VERSION}:${review.version}`};
    await update({manifest:json({slots,generation,review:reviewer})});
    const manifest=manifestSchema.parse({slots,generation,review:reviewer});
    const usage:LunaUsage[]=[];
    const questions=await runLunaWorkflow(manifest.slots,{
      call:async request=>{
        const increment=await prisma.questionPreparation.updateMany({where:{id,workerToken:token,state:{in:ACTIVE_STATES},deadline:{gt:new Date()},callCount:{lt:ENV.LUNA.maxCalls}},data:{state:request.stage,callCount:{increment:1},version:{increment:1}}});
        if(!increment.count)throw new Error('PREPARATION_CALL_BUDGET');
        return lunaCall(request,row.deadline,async entry=>{usage.push(entry);await prisma.questionPreparation.updateMany({where:{id,workerToken:token},data:{usage:json(usage)}});});
      },
      duplicates:async candidates=>{
        const legacy=(q:Candidate)=>FingerprintService.computeFingerprint(q.prompt,q.options);
        const hashes=candidates.flatMap(q=>[fingerprint(q),legacy(q)]);
        const existing=hashes.length?await prisma.question.findMany({where:{fingerprint:{in:hashes}},select:{fingerprint:true}}):[];
        const found=new Set(existing.map(q=>q.fingerprint));return new Set(candidates.filter(q=>found.has(fingerprint(q))||found.has(legacy(q))).map(q=>q.slotId));
      },
    },{generation:manifest.generation.text,review:manifest.review.text});
    await update({state:'SAVING'});
    await publish(row,token,scope,manifest.slots,questions,manifest.generation.version,manifest.review.version);
  }catch{
    await prisma.questionPreparation.updateMany({where:{id,workerToken:token,state:{in:ACTIVE_STATES}},data:{state:+row.deadline<=Date.now()?'EXPIRED':'FAILED',errorCode:+row.deadline<=Date.now()?'PREPARATION_EXPIRED':'QUALITY_OR_PROVIDER_FAILURE',version:{increment:1}}});
    if(row.mode==='FRIENDLY'&&scope.duelId){const {duelsService}=await import('../../social/duels.service');await duelsService.abandon(row.userIds[0],scope.duelId).catch(()=>{});}
  }
}
async function publish(row:QuestionPreparation,token:string,scope:Scope,slots:Slot[],questions:Candidate[],generationVersion:string,reviewVersion:string){
  await prisma.$transaction(async tx=>{
    await lockUsers(tx,row.userIds);
    await tx.$queryRaw`SELECT id FROM learning.question_preparations WHERE id=${row.id}::uuid FOR UPDATE`;
    const fresh=await tx.questionPreparation.findUniqueOrThrow({where:{id:row.id}});
    const now=(await tx.$queryRaw<{now:Date}[]>`SELECT clock_timestamp() AT TIME ZONE 'UTC' AS now`)[0].now;
    if(fresh.state!=='SAVING'||fresh.workerToken!==token||fresh.deadline<=now)throw new Error('PREPARATION_OWNERSHIP_LOST');
    const referenceIds=[...new Set(slots.map(s=>s.reference.id))];
    await tx.$queryRaw(Prisma.sql`SELECT id FROM learning.questions WHERE id IN (${Prisma.join(referenceIds.map(id=>Prisma.sql`${id}::uuid`))}) ORDER BY id FOR SHARE`);
    const refs=await tx.question.findMany({where:{id:{in:referenceIds},status:'PUBLISHED',sourceType:{in:['MANUAL','AI_GENERATED']},subtopic:{isActive:true},topic:{isActive:true},subject:{isActive:true}},include:{subtopic:true}});
    for(const slot of slots){
      const current=refs.find(q=>q.id===slot.reference.id),ref=slot.reference;
      if(!current||current.subjectId!==ref.subjectId||current.topicId!==ref.topicId||current.subtopicId!==ref.subtopicId||current.pattern!==ref.pattern||current.prompt!==ref.prompt
        ||current.correctAnswer.toUpperCase()!==ref.correctAnswer||current.method!==ref.method||current.explanation!==ref.explanation
        ||!isDeepStrictEqual(referenceOptions(current.options),ref.options)||current.subtopic.name!==ref.subtopicName||(current.subtopic.description??current.subtopic.name)!==ref.scope)throw new Error('REFERENCE_SCOPE_CHANGED');
    }
    const saved=[];
    for(const slot of slots){
      const q=questions.find(q=>q.slotId===slot.id)!;
      // Always INSERT. A unique fingerprint conflict fails the batch; never reuses an old playable row.
      const question=await tx.question.create({data:{subjectId:slot.reference.subjectId,topicId:slot.reference.topicId,subtopicId:slot.reference.subtopicId,
        pattern:slot.reference.pattern,prompt:q.prompt,options:json(q.options),correctAnswer:q.correctAnswer,hints:json(q.hints),explanation:q.explanation,method:q.method,
        alternativeExplanation:q.alternativeExplanation,difficulty:q.difficulty,estimatedTimeSeconds:q.estimatedTimeSeconds,calculationMode:'MENTAL',sourceType:'LUNA',status:'PUBLISHED',
        fingerprint:fingerprint(q),generationMethod:'AI_SYNTHETIC',generationModel:ENV.LUNA.model,generationPromptVersion:`${generationVersion}|${reviewVersion}`,generationJobId:row.id,
        referenceQuestionId:slot.reference.id,referenceSnapshot:json(slot.reference),generationProfile:PROFILE,generatedAt:now,reviewedAt:now}});
      saved.push(question);
    }
    const snapshot=json(Object.fromEntries(saved.map(q=>[q.id,q])));
    let resultSessionId:string|undefined,resultSetId:string|undefined;
    if(row.mode==='PRACTICE'){
      if(await tx.friendlyDuelSeat.count({where:{userId:row.userIds[0]}}))throw new Error('ACTIVITY_CHANGED');
      const session=await tx.practiceSession.create({data:{userId:row.userIds[0],subjectId:saved[0].subjectId,topicId:scope.topicId??saved[0].topicId,subtopicIds:scope.subtopicIds,totalQuestions:10,questionSnapshot:snapshot}});
      await tx.practiceSessionQuestion.createMany({data:saved.map((q,i)=>({sessionId:session.id,questionId:q.id,sequence:i+1}))});resultSessionId=session.id;
    }else if(row.mode==='FRIENDLY'){
      const {finalizePreparedDuel}=await import('../../social/luna-duel');
      await finalizePreparedDuel(tx,scope.duelId!,saved,snapshot,now);
    }else{
      const set=await tx.pvpQuestionSet.create({data:{code:`luna_${row.id}`,sourceType:'LUNA',questionCount:10,status:'PUBLISHED',generationModel:ENV.LUNA.model,generationPromptVersion:generationVersion,generationJobId:row.id}});
      await tx.pvpQuestionSetQuestion.createMany({data:saved.map((q,i)=>({setId:set.id,questionId:q.id,sequence:i+1}))});resultSetId=set.id;
    }
    const finishedAt=(await tx.$queryRaw<{now:Date}[]>`SELECT clock_timestamp() AT TIME ZONE 'UTC' AS now`)[0].now;
    if(fresh.deadline<=finishedAt)throw new Error('PREPARATION_EXPIRED');
    await tx.questionPreparation.update({where:{id:row.id},data:{state:'READY',resultSessionId,resultSetId,resultSnapshot:snapshot,version:{increment:1}}});
  },{timeout:15000});
  if(row.mode==='FRIENDLY'&&scope.duelId){
    const {socialTransport}=await import('../../social/social.transport');
    const {duelsService}=await import('../../social/duels.service');
    if(duelsService.schedule)await duelsService.schedule(scope.duelId,86400000).catch(()=>{});
    await socialTransport.notify(row.userIds,'DUEL_CHANGED',scope.duelId).catch(()=>{});
  }
}
