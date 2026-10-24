import { ENV } from '../../../config/env';
import { PublicError } from '../../../security/errors';
import { reserveProvider } from '../provider-budget';
import type { Call } from './workflow';

export interface LunaUsage {stage:string;model:string;reasoning:string;outputTokenCap:number;estimatedInputTokens:number;inputTokens:number|null;cachedInputTokens:number|null;outputTokens:number|null;reasoningTokens:number|null;estimatedCostUsd:number;actualCostUsd:number|null;durationMs:number;outcome:string}
export function makeLunaRequest(call:Call){
  const cfg=ENV.LUNA;
  return {model:cfg.model,reasoning:{effort:cfg.reasoning},store:false,
    input:[{role:'developer',content:call.instruction},{role:'user',content:JSON.stringify(call.input)}],
    text:{format:{type:'json_schema',name:call.stage==='REVIEWING'||call.stage==='REREVIEWING'?'luna_review_v1':'luna_variations_v1',strict:true,schema:call.schema}},
    max_output_tokens:call.stage==='REVIEWING'||call.stage==='REREVIEWING'?cfg.reviewOutputTokens:cfg.generationOutputTokens};
}
export async function lunaCall(call:Call, deadline:Date, report:(usage:LunaUsage)=>Promise<void>, fetcher:typeof fetch=fetch):Promise<unknown>{
  const cfg=ENV.LUNA;
  if(!cfg.enabled||!cfg.key)throw new PublicError('Question preparation is temporarily unavailable.','LUNA_UNAVAILABLE',503);
  const timeoutMs=Math.min(cfg.requestTimeoutMs,+deadline-Date.now());
  if(timeoutMs<=0)throw new Error('PREPARATION_EXPIRED');
  const request=makeLunaRequest(call), body=JSON.stringify(request);
  const inputBytes=Buffer.byteLength(body,'utf8'),estimatedInputTokens=Math.ceil(inputBytes/4);
  const release=await reserveProvider(inputBytes+request.max_output_tokens,timeoutMs,'luna');
  const started=Date.now(), abort=new AbortController(), timer=setTimeout(()=>abort.abort(),timeoutMs);
  let usage:LunaUsage={stage:call.stage,model:cfg.model,reasoning:cfg.reasoning,outputTokenCap:request.max_output_tokens,estimatedInputTokens,inputTokens:null,cachedInputTokens:null,outputTokens:null,reasoningTokens:null,
    estimatedCostUsd:(estimatedInputTokens*cfg.inputPricePerMillion+request.max_output_tokens*cfg.outputPricePerMillion)/1e6,actualCostUsd:null,durationMs:0,outcome:'FAILED'};
  try{
    // Native REST adapter, no automatic retries. Every dispatched call is durably counted by the orchestrator.
    const response=await fetcher('https://api.openai.com/v1/responses',{method:'POST',headers:{Authorization:`Bearer ${cfg.key}`,'Content-Type':'application/json'},body,signal:abort.signal});
    if(!response.ok)throw new Error('LUNA_REQUEST_FAILED'); // Never log provider bodies or credentials.
    const result=await response.json() as {status?:string;usage?:{input_tokens?:number;input_tokens_details?:{cached_tokens?:number};output_tokens?:number;output_tokens_details?:{reasoning_tokens?:number}};output?:Array<{type:string;content?:Array<{type:string;text?:string}>}>};
    const input=result.usage?.input_tokens,output=result.usage?.output_tokens,reasoning=result.usage?.output_tokens_details?.reasoning_tokens;
    const cached=Math.min(input??0,Math.max(0,result.usage?.input_tokens_details?.cached_tokens??0));
    usage={...usage,inputTokens:typeof input==='number'?input:null,cachedInputTokens:typeof input==='number'?cached:null,outputTokens:typeof output==='number'?output:null,reasoningTokens:typeof reasoning==='number'?reasoning:null,
      actualCostUsd:typeof input==='number'&&typeof output==='number'?((input-cached)*cfg.inputPricePerMillion+cached*(cfg.cachedInputPricePerMillion??cfg.inputPricePerMillion)+output*cfg.outputPricePerMillion)/1e6:null};
    if(result.status!=='completed')throw new Error('LUNA_INCOMPLETE_RESPONSE');
    const content=(result.output??[]).filter(o=>o.type==='message').flatMap(o=>o.content??[]);
    if(content.some(c=>c.type==='refusal'))throw new Error('LUNA_REFUSAL');
    const text=content.filter(c=>c.type==='output_text').map(c=>c.text??'').join('');
    const parsed=JSON.parse(text);usage.outcome='COMPLETED';return parsed;
  } finally {
    clearTimeout(timer);await release();usage.durationMs=Date.now()-started;await report(usage);
  }
}
