import { z } from 'zod';
import { Candidate, Issue, Slot, checkCandidate, fingerprint, normalize, verdictSchema, QUESTION_OUTPUT_SCHEMA, REVIEW_OUTPUT_SCHEMA } from './contracts';
import { GENERATION_INSTRUCTION, REVIEW_INSTRUCTION, REPAIR_INSTRUCTION, REREVIEW_INSTRUCTION, generationInput, reviewInput, repairInput } from './prompts';

export type Stage = 'GENERATING'|'REVIEWING'|'REPAIRING'|'REREVIEWING';
export interface Call { stage:Stage; instruction:string; input:unknown; schema:Record<string,unknown> }
export interface WorkflowDependencies {
  call(request:Call):Promise<unknown>;
  duplicates(questions:Candidate[]):Promise<Set<string>>;
}
const outputSchema = z.object({questions:z.array(z.unknown()).max(10)}).strict();

/** Independent review is the pilot correctness gate; no symbolic solver or content reuse. */
export async function runLunaWorkflow(slots:Slot[], deps:WorkflowDependencies,
  instructions={generation:GENERATION_INSTRUCTION,review:REVIEW_INSTRUCTION}):Promise<Candidate[]> {
  if(slots.length!==10 || new Set(slots.map(s=>s.id)).size!==10) throw new Error('INVALID_MANIFEST');
  const accepted=new Map<string,Candidate>();
  async function assess(raw:unknown, target:Slot[], repaired:boolean):Promise<Issue[]> {
    const parsed=outputSchema.parse(raw);
    const byId=new Map<string,unknown>();
    for(const value of parsed.questions){
      const id=z.object({slotId:z.string()}).parse(value).slotId;
      if(!target.some(s=>s.id===id) || byId.has(id))throw new Error('INVALID_SLOT_MAPPING');
      byId.set(id,value);
    }
    const issues:Issue[]=[], candidates:Candidate[]=[], hashes=new Set([...accepted.values()].map(fingerprint));
    const prompts=new Set([...accepted.values()].map(q=>normalize(q.prompt)));
    for(const slot of target){
      const result=checkCandidate(byId.get(slot.id),slot);
      if(result.issue){issues.push(result.issue);continue;}
      const q=result.question!;
      if(hashes.has(fingerprint(q))||prompts.has(normalize(q.prompt))){issues.push({slotId:slot.id,code:'DUPLICATE',detail:'Create a distinct question instance.'});continue;}
      hashes.add(fingerprint(q));prompts.add(normalize(q.prompt));candidates.push(q);
    }
    const duplicateIds=await deps.duplicates(candidates);
    const reviewable=candidates.filter(q=>!duplicateIds.has(q.slotId));
    for(const id of duplicateIds)issues.push({slotId:id,code:'DUPLICATE',detail:'This content already exists; create a fresh instance.'});
    if(reviewable.length){
      const reviewSlots=target.filter(s=>reviewable.some(q=>q.slotId===s.id));
      const response=verdictSchema.parse(await deps.call({stage:repaired?'REREVIEWING':'REVIEWING',instruction:instructions.review+(repaired?'\n'+REREVIEW_INSTRUCTION:''),
        input:reviewInput(reviewSlots,reviewable,[...accepted.values()]),schema:REVIEW_OUTPUT_SCHEMA}));
      if(response.verdicts.length!==reviewable.length||new Set(response.verdicts.map(v=>v.slotId)).size!==reviewable.length||response.verdicts.some(v=>!reviewable.some(q=>q.slotId===v.slotId)))throw new Error('INVALID_REVIEW_MAPPING');
      for(const verdict of response.verdicts){
        if(verdict.pass && verdict.code==='OK' && !verdict.detail) accepted.set(verdict.slotId,reviewable.find(q=>q.slotId===verdict.slotId)!);
        else issues.push({slotId:verdict.slotId,code:verdict.code,detail:verdict.detail||'Independent review rejected this question.'});
      }
    }
    return issues;
  }
  const initial=await deps.call({stage:'GENERATING',instruction:instructions.generation,input:generationInput(slots),schema:QUESTION_OUTPUT_SCHEMA});
  const issues=await assess(initial,slots,false);
  if(issues.length){
    const failed=slots.filter(s=>issues.some(i=>i.slotId===s.id));
    const repair=await deps.call({stage:'REPAIRING',instruction:instructions.generation+'\n'+REPAIR_INSTRUCTION,input:repairInput(failed,issues,[...accepted.values()]),schema:QUESTION_OUTPUT_SCHEMA});
    const remaining=await assess(repair,failed,true);
    if(remaining.length)throw new Error('QUALITY_REVIEW_FAILED');
  }
  if(accepted.size!==10)throw new Error('INCOMPLETE_BATCH');
  return slots.map(s=>accepted.get(s.id)!);
}
