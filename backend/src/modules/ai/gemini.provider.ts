import { GoogleGenAI } from '@google/genai';
import { ENV, AI_LIMITS } from '../../config/env';
import { reserveProvider } from './provider-budget';

export class GeminiProvider {
  private static instance:GeminiProvider;
  private ai:GoogleGenAI|null=null;
  private constructor(){if(ENV.AI_GENERATION_ENABLED!==false && ENV.GEMINI_API_KEY?.trim())this.ai=new GoogleGenAI({apiKey:ENV.GEMINI_API_KEY});}
  static getInstance(){return this.instance??=new GeminiProvider();}
  isConfigured(){return this.ai!==null;}
  async generateStructuredContent<T>(params:{systemInstruction:string;prompt:string;responseSchema:Record<string,any>;thinkingBudget?:number;timeoutMs?:number;maxRetries?:number}):Promise<T>{
    if(!this.ai)throw new Error('AI provider is not configured');
    const timeoutMs=Math.min(params.timeoutMs??AI_LIMITS.timeoutMs,AI_LIMITS.timeoutMs);
    const thinkingBudget=params.thinkingBudget??ENV.GEMINI_THINKING_BUDGET; // zero is deliberate
    const attempts=Math.min(3,Math.max(0,params.maxRetries??3));
    for(let attempt=0;;attempt++){
      const reserved=Buffer.byteLength(params.prompt+params.systemInstruction,'utf8')+AI_LIMITS.maxOutputTokens+Math.max(0,thinkingBudget);
      const release=await reserveProvider(reserved,timeoutMs);
      const abort=new AbortController();
      let timer:NodeJS.Timeout|undefined;
      try{
        const timeout=new Promise<never>((_,reject)=>{timer=setTimeout(()=>{abort.abort();reject(new Error('AI provider request timed out'));},timeoutMs);});
        const response=await Promise.race([this.ai.models.generateContent({model:ENV.GEMINI_MODEL,contents:params.prompt,config:{
          systemInstruction:params.systemInstruction,responseMimeType:'application/json',responseSchema:params.responseSchema,
          temperature:0.2,maxOutputTokens:AI_LIMITS.maxOutputTokens,abortSignal:abort.signal,
          thinkingConfig:{thinkingBudget},
        }}),timeout]);
        if(!response.text?.trim())throw new Error('AI provider returned an empty response');
        try{return JSON.parse(response.text) as T;}catch{throw new Error('AI provider returned invalid JSON');}
      }catch(error:any){
        // Never include provider payloads, generated solutions or credential-bearing messages in logs.
        const status=Number(error?.status??error?.code);
        if(attempt>=attempts||![429,503].includes(status))throw new Error(status?'AI provider unavailable':'AI generation failed');
      }finally{clearTimeout(timer);await release();}
      await new Promise(resolve=>setTimeout(resolve,Math.min(30000,4000*2**attempt)));
    }
  }
}
export const geminiProvider=GeminiProvider.getInstance();
