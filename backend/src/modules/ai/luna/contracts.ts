import { createHash, randomInt } from 'node:crypto';
import { z } from 'zod';

export const PROFILE = 'luna-fresh-v1';
export const TIERS = ['UNRANKED','BRONZE','SILVER','GOLD','PLATINUM','DIAMOND'] as const;
export type Tier = typeof TIERS[number];
export type Difficulty = 'EASY' | 'MEDIUM' | 'HARD';
export type Mode = 'PRACTICE' | 'RANKED' | 'UNRANKED' | 'FRIENDLY';
export function shuffle<T>(input: readonly T[], pick = randomInt): T[] {
  const output = [...input];
  for (let i = output.length - 1; i > 0; i--) { const j = pick(i + 1); [output[i], output[j]] = [output[j], output[i]]; }
  return output;
}
export function matchTier(a: Tier, b: Tier): Tier { return TIERS[Math.min(TIERS.indexOf(a), TIERS.indexOf(b))]; }
export function difficultyQuota(tier: Tier, coin = () => randomInt(2)): Difficulty[] {
  const counts: Record<Tier, [number,number,number]> = { UNRANKED:[10,0,0], BRONZE:[10,0,0], SILVER:coinForSilver(tier,coin), GOLD:[8,1,1], PLATINUM:[6,2,2], DIAMOND:[4,3,3] };
  return counts[tier].flatMap((count,i) => Array<Difficulty>(count).fill((['EASY','MEDIUM','HARD'] as const)[i]));
}
function coinForSilver(tier: Tier, coin: () => number): [number,number,number] { return tier === 'SILVER' && coin() === 1 ? [8,1,1] : [9,1,0]; }
export interface Reference {
  id: string; subjectId: string; topicId: string; subtopicId: string; subtopicName: string; scope: string;
  pattern: string; prompt: string; options: {id:string;text:string}[]; correctAnswer: string;
  explanation: string; method: string; pyq: string | null; sourceType: string;
}
export interface Slot { id: string; difficulty: Difficulty; answerPosition: string; reference: Reference }
export const slotSchema = z.object({
  id:z.string(), difficulty:z.enum(['EASY','MEDIUM','HARD']), answerPosition:z.enum(['A','B','C','D']),
  reference:z.object({id:z.string().uuid(),subjectId:z.string(),topicId:z.string(),subtopicId:z.string(),subtopicName:z.string(),scope:z.string(),pattern:z.string(),prompt:z.string(),options:z.array(z.object({id:z.string(),text:z.string()})).length(4),correctAnswer:z.string(),explanation:z.string(),method:z.string(),pyq:z.string().nullable(),sourceType:z.string()})
});
export const candidateSchema = z.object({
  slotId:z.string().min(1).max(32), pattern:z.string().min(1).max(100),
  prompt:z.string().min(10).max(1600),
  options:z.array(z.object({id:z.enum(['A','B','C','D']),text:z.string().min(1).max(400)}).strict()).length(4),
  correctAnswer:z.enum(['A','B','C','D']), hints:z.array(z.string().min(5).max(400)).length(2),
  explanation:z.string().min(10).max(2400), method:z.string().min(3).max(600),
  alternativeExplanation:z.string().min(10).max(1600).nullable(),
  difficulty:z.enum(['EASY','MEDIUM','HARD']), estimatedTimeSeconds:z.number().int().min(1).max(60),
}).strict();
export type Candidate = z.infer<typeof candidateSchema>;
export interface Issue { slotId: string; code: string; detail: string }
export const verdictSchema = z.object({verdicts:z.array(z.object({slotId:z.string(),pass:z.boolean(),code:z.enum(['OK','MATH','AMBIGUOUS','PATTERN','SCOPE','TIME','DIFFICULTY','SUPPORT','LANGUAGE','DUPLICATE','REFERENCE']),detail:z.string().max(500)}).strict()).max(10)}).strict();
export const normalize = (value:string) => value.normalize('NFKC').trim().toLowerCase().replace(/\s+/g,' ');
export function fingerprint(q: Pick<Candidate,'prompt'|'options'>) {
  return createHash('sha256').update(JSON.stringify([normalize(q.prompt),q.options.map(o=>normalize(o.text)).sort()])).digest('hex');
}
const forbidden = /\bmental(?:ly)?\b|without\s+(?:pen|paper)|no\s+pen\s+and\s+paper|easy\s+numbers|\b(?:Luna|AI.generated)\b/i;
export function checkCandidate(raw: unknown, slot: Slot): {question?:Candidate; issue?:Issue} {
  const bad = (code:string, detail:string) => ({issue:{slotId:slot.id,code,detail}});
  const parsed = candidateSchema.safeParse(raw);
  if (!parsed.success) return bad('STRUCTURE','Required question fields, four options, two hints, explanations or timing are invalid.');
  const q = parsed.data;
  if (q.slotId !== slot.id || q.pattern !== slot.reference.pattern || q.difficulty !== slot.difficulty) return bad('MAPPING','Slot, exact pattern or assigned difficulty changed.');
  if (q.correctAnswer !== slot.answerPosition) return bad('ANSWER_POSITION','Use the assigned answer position.');
  if (new Set(q.options.map(o=>o.id)).size !== 4 || new Set(q.options.map(o=>normalize(o.text))).size !== 4) return bad('OPTIONS','Four distinguishable options A-D are required.');
  if (forbidden.test([q.prompt,...q.options.map(o=>o.text),...q.hints,q.method,q.explanation,q.alternativeExplanation??''].join('\n'))) return bad('LANGUAGE','Remove internal authoring labels from learner text.');
  if (normalize(q.prompt) === normalize(slot.reference.prompt)) return bad('DUPLICATE','Create a fresh instance, not the original reference.');
  return {question:q};
}
const str = (minLength:number,maxLength:number) => ({type:'string',minLength,maxLength});
const object = (properties:Record<string,unknown>) => ({type:'object',additionalProperties:false,required:Object.keys(properties),properties});
export const QUESTION_OUTPUT_SCHEMA = object({questions:{type:'array',maxItems:10,items:object({
  slotId:str(1,32),pattern:str(1,100),prompt:str(10,1600),
  options:{type:'array',minItems:4,maxItems:4,items:object({id:{type:'string',enum:['A','B','C','D']},text:str(1,400)})},
  correctAnswer:{type:'string',enum:['A','B','C','D']},hints:{type:'array',minItems:2,maxItems:2,items:str(5,400)},
  method:str(3,600),explanation:str(10,2400),alternativeExplanation:{anyOf:[str(10,1600),{type:'null'}]},
  difficulty:{type:'string',enum:['EASY','MEDIUM','HARD']},estimatedTimeSeconds:{type:'integer',minimum:1,maximum:60}
})}});
export const REVIEW_OUTPUT_SCHEMA = object({verdicts:{type:'array',maxItems:10,items:object({slotId:str(1,32),pass:{type:'boolean'},code:{type:'string',enum:['OK','MATH','AMBIGUOUS','PATTERN','SCOPE','TIME','DIFFICULTY','SUPPORT','LANGUAGE','DUPLICATE','REFERENCE']},detail:{type:'string',maxLength:500}})}});

// Only context useful to the model crosses the provider boundary. Taxonomy/source/provenance stay server-side.
export function referenceContext(slots: Slot[]) {
  return slots.map(s => ({slotId:s.id,difficulty:s.difficulty,answerPosition:s.answerPosition,subtopic:s.reference.subtopicName,scope:s.reference.scope,pattern:s.reference.pattern,
    reference:{prompt:s.reference.prompt,options:s.reference.options,correctAnswer:s.reference.correctAnswer,method:s.reference.method,explanation:s.reference.explanation}}));
}
