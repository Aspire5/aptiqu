import { z } from 'zod';
import { RequestHandler } from 'express';
import { publicFailure } from '../../security/public-error';
const id=z.string().trim().min(1).max(160);
const name=z.string().trim().min(1).max(300);
const description=z.string().max(20000).optional();
const order=z.number().int().min(0).max(100000);
const teaching={importance:z.string().max(40).optional(),teachingDepth:z.number().int().min(1).max(10).optional(),teachingMinutes:z.number().int().min(1).max(300).optional()};
const subject=z.object({id:id.optional(),slug:id.optional(),name,description,displayOrder:order.optional()}).strict();
const topic=z.object({id:id.optional(),subjectId:id,slug:id.optional(),name,description,defaultImportance:z.string().max(40).optional(),defaultTeachingDepth:teaching.teachingDepth,defaultTeachingMinutes:teaching.teachingMinutes}).strict();
const subtopic=z.object({id:id.optional(),topicId:id,slug:id.optional(),name,description,sequence:order.optional(),...teaching}).strict();
const subtopicImport=subtopic.omit({topicId:true}).extend({externalSubTopicKey:id.optional(),externalSubtopicKey:id.optional()});
export const questionFields=z.object({
  subtopicId:id,subjectId:id.optional(),topicId:id.optional(),pattern:z.string().max(100).nullable().optional(),prompt:z.string().trim().min(1).max(10000),
  options:z.array(z.object({id:z.enum(['A','B','C','D']),text:z.string().trim().min(1).max(2000)}).strict()).length(4),correctAnswer:z.enum(['A','B','C','D']),
  hints:z.array(z.string().max(2000)).max(5).optional(),explanation:z.string().max(20000),method:z.string().max(3000).optional(),
  difficulty:z.enum(['EASY','MEDIUM','HARD']).optional(),estimatedTimeSeconds:z.number().int().min(1).max(120).optional(),calculationMode:z.enum(['MENTAL','LIGHT_PEN_AND_PAPER','PEN_AND_PAPER']).optional(),
  status:z.enum(['DRAFT','REVIEW','PUBLISHED','ARCHIVED']).optional(),sourceType:z.enum(['MANUAL','AI_GENERATED','LUNA']).optional(),externalKey:id.nullable().optional(),pyq:z.string().max(500).nullable().optional(),
  alternativeExplanation:z.string().max(20000).nullable().optional(),preferredSolution:z.enum(['BOOK','ALTERNATIVE']).nullable().optional(),preferredReason:z.string().max(3000).nullable().optional(),
  generationMethod:z.enum(['HUMAN_MANUAL','AI_EXTRACTED','AI_SYNTHETIC']).optional(),sourceBook:z.string().max(500).nullable().optional(),sourceEdition:z.string().max(200).nullable().optional(),sourceChapter:z.string().max(500).nullable().optional(),sourcePageRange:z.string().max(100).nullable().optional(),
}).strict();
function optionIdentity(value:string):string {
  const normalized=value.normalize('NFKC').replace(/\s+/g,'').toLowerCase();
  if(/^[+-]?\d+(?:\.\d+)?$/.test(normalized)) {
    // Compare decimal text exactly; Number() can merge distinct large integers.
    const negative=normalized.startsWith('-');
    const [whole,fraction='']=normalized.replace(/^[+-]/,'').split('.');
    const integer=whole.replace(/^0+(?=\d)/,'');
    const decimal=fraction.replace(/0+$/,'');
    const sign=negative&&(integer!=='0'||decimal)?'-':'';
    return `number:${sign}${integer}${decimal?'.'+decimal:''}`;
  }
  return normalized;
}
export function validateAdminQuestion(value:unknown) {
  const data=questionFields.parse(value);
  if(data.estimatedTimeSeconds!==undefined && (data.sourceType==='LUNA'?data.estimatedTimeSeconds>60:data.estimatedTimeSeconds<30))throw new z.ZodError([{code:'custom',path:['estimatedTimeSeconds'],message:'Luna estimates must be 1–60 seconds; other question timing remains 30–120 seconds'}]);
  if(new Set(data.options.map(o=>o.id)).size!==4 || new Set(data.options.map(o=>optionIdentity(o.text))).size!==4)throw new z.ZodError([{code:'custom',path:['options'],message:'Options must have distinct IDs and distinct answers'}]);
  if((data.status??'PUBLISHED')==='PUBLISHED'&&!data.explanation.trim())throw new z.ZodError([{code:'custom',path:['explanation'],message:'Published questions require an explanation'}]);
  return data;
}
const script=z.object({title:name,subjectId:id,topicId:id,subtopicId:id.nullable().optional(),definition:z.record(z.unknown()),status:z.enum(['DRAFT','REVIEW','PUBLISHED']).optional()}).strict();
const scriptImport=z.object({subjectId:id.optional(),topicId:id,subtopicId:id.optional(),externalSubtopicKey:id.optional(),definition:z.record(z.unknown()).optional(),scriptDefinition:z.record(z.unknown()).optional(),status:z.enum(['DRAFT','REVIEW','PUBLISHED']).optional()}).strict();
const ids=z.array(id).max(1000).refine(values=>new Set(values).size===values.length,'IDs must be unique');
const schemas:Array<[string,RegExp,z.ZodTypeAny]>=[
 ['POST',/^\/syllabus\/subjects$/,subject],['PUT',/^\/syllabus\/subjects\/[^/]+$/,subject.pick({name:true,description:true,displayOrder:true}).partial().extend({isActive:z.boolean().optional()})],
 ['POST',/^\/syllabus\/topics$/,topic],['PUT',/^\/syllabus\/topics\/[^/]+$/,topic.omit({id:true,slug:true,subjectId:true}).partial().extend({isActive:z.boolean().optional()})],
 ['POST',/^\/syllabus\/subtopics$/,subtopic],['PUT',/^\/syllabus\/subtopics\/[^/]+$/,subtopic.omit({id:true,topicId:true}).partial().extend({isActive:z.boolean().optional()})],
 ['POST',/^\/syllabus\/topics\/[^/]+\/subtopics\/import$/,z.object({subtopics:z.array(subtopicImport).min(1).max(1000)}).strict()],
 ['POST',/^\/syllabus\/scripts$/,script],['POST',/^\/syllabus\/scripts\/import$/,scriptImport],
 ['PUT',/^\/syllabus\/scripts\/[^/]+$/,script.pick({title:true,subtopicId:true,definition:true}).partial().extend({status:z.enum(['DRAFT','REVIEW','PUBLISHED','ARCHIVED']).optional(),expectedVersion:z.number().int().positive()}).strict()],
 ['PUT',/^\/syllabus\/subjects\/[^/]+\/reorder-topics$/,z.object({topicIds:ids}).strict()],['PUT',/^\/syllabus\/topics\/[^/]+\/reorder-subtopics$/,z.object({subtopicIds:ids}).strict()],
 ['POST',/^\/syllabus\/subjects\/[^/]+\/link-topic$/,z.object({topicId:id}).strict()],['POST',/^\/syllabus\/topics\/[^/]+\/link-subtopic$/,z.object({subtopicId:id}).strict()],
 ['POST',/^\/questions(?:\/manual)?$/,questionFields],['PUT',/^\/questions\/[^/]+\/link$/,z.object({newSubtopicId:id}).strict()],['PUT',/^\/questions\/[^/]+$/,questionFields.partial()],
 ['POST',/^\/questions\/bulk-import$/,z.object({questions:z.array(z.record(z.unknown())).min(1).max(5000),defaultSubtopicId:id.optional()}).strict()],
 ['POST',/^\/questions\/generate$/,z.object({subtopicId:id,count:z.number().int().min(1).max(50).default(10)}).strict()],
 ['PUT',/^\/ai-prompts\/[^/]+$/,z.object({draftPrompt:z.string().min(1).max(100000),expectedRevision:z.number().int().positive()}).strict()],
 ['POST',/^\/ai-prompts\/[^/]+\/(?:publish|reset-default)$/,z.object({expectedRevision:z.number().int().positive()}).strict()],
 ['PUT',/^\/books\/[^/]+\/topics$/,z.object({topics:z.array(z.object({id,name,description}).strict()).max(1000)}).strict()],
 ['POST',/^\/books\/[^/]+\/retry$/,z.object({stage:z.enum(['process-full-book','parse-pages','detect-topics','discover-subtopics','extract-questions','classify-questions','generate-scripts','validate-content']).optional()}).strict()],
 ['PUT',/^\/config\/timing$/,z.object({practiceMin:z.number().int().min(30).max(120).optional(),practiceMax:z.number().int().min(30).max(120).optional(),pvpFixed:z.literal(60).optional(),expectedVersion:z.number().int().nonnegative()}).strict().refine(v=>v.practiceMin===undefined||v.practiceMax===undefined||v.practiceMin<=v.practiceMax,'Minimum must not exceed maximum')],
];
export const validateAdminInput:RequestHandler=(req,res,next)=>{
  if(req.method==='GET'||req.method==='DELETE'){next();return;}
  const schema=schemas.find(([method,path])=>method===req.method&&path.test(req.path))?.[2];
  if(!schema){next();return;}
  try{req.body=schema.parse(req.body);next();}catch(error){publicFailure(res,error);}
};
