const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const ts=require('typescript');
const path=require('node:path');
function setup(overrides={}){
 const reservations=[];
 const cfg={enabled:true,key:'fixture-key',model:'gpt-6-luna',reasoning:'medium',requestTimeoutMs:1000,generationOutputTokens:24576,reviewOutputTokens:12288,inputPricePerMillion:.1,outputPricePerMillion:.5,...overrides};
 const code=ts.transpileModule(fs.readFileSync(path.join(__dirname,'../provider.ts'),'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText;
 const exports={};
 vm.runInNewContext(code,{exports,require:id=>{
  if(id==='../../../config/env')return {ENV:{LUNA:cfg}};
  if(id==='../../../security/errors')return {PublicError:class extends Error{}};
  if(id==='../provider-budget')return {reserveProvider:async(...args)=>{reservations.push(args);return async()=>{};}};
  throw Error(`Unexpected module ${id}`);
 },Buffer,Date,AbortController,setTimeout,clearTimeout,fetch:()=>{throw Error('Real fetch forbidden');}});
 return {...exports,cfg,reservations};
}
const call={stage:'GENERATING',instruction:'Generate full questions.',input:{slots:[]},schema:{type:'object'}};
test('Luna requests use exact model, medium/high, strict Responses output and generous caps',()=>{
 for(const reasoning of ['medium','high']){
  const s=setup({reasoning});const body=s.makeLunaRequest(call);
  assert.equal(body.model,'gpt-6-luna');assert.equal(body.reasoning.effort,reasoning);assert.equal(body.store,false);assert.equal(body.text.format.strict,true);assert.equal(body.max_output_tokens,24576);
  assert.equal(s.makeLunaRequest({...call,stage:'REVIEWING'}).max_output_tokens,12288);assert.equal('temperature' in body,false);assert.equal('tools' in body,false);
 }
});
test('real token accounting includes reasoning within output, with no credential-bearing diagnostics',async()=>{
 const s=setup(),reports=[];let requests=0;
 const out=await s.lunaCall(call,new Date(Date.now()+10000),async u=>reports.push(u),async(url,args)=>{
  requests++;assert.equal(url,'https://api.openai.com/v1/responses');assert.equal(args.headers.Authorization,'Bearer fixture-key');
  return {ok:true,json:async()=>({status:'completed',usage:{input_tokens:1000,output_tokens:2000,output_tokens_details:{reasoning_tokens:750}},output:[{type:'reasoning'},{type:'message',content:[{type:'output_text',text:'{"questions":[]}'}]}]})};
 });
 assert.equal(requests,1);assert.deepEqual(JSON.parse(JSON.stringify(out)),{questions:[]});assert.equal(reports[0].reasoningTokens,750);assert.equal(reports[0].actualCostUsd,.0011);assert.equal(reports[0].outcome,'COMPLETED');assert.equal(s.reservations[0][2],'luna');
 assert.equal(JSON.stringify(reports).includes('fixture-key'),false);
});
test('timeout, non-2xx, incomplete output and refusal fail with one dispatch, never automatic retries',async()=>{
 for(const kind of ['timeout','http','incomplete','refusal']){
  const s=setup({requestTimeoutMs:10}),reports=[];let calls=0;
  await assert.rejects(()=>s.lunaCall(call,new Date(Date.now()+1000),async u=>reports.push(u),async(_url,args)=>{
   calls++;
   if(kind==='timeout')return new Promise((_,reject)=>args.signal.addEventListener('abort',()=>reject(Error('aborted'))));
   if(kind==='http')return {ok:false,status:429};
   return {ok:true,json:async()=>({status:kind==='incomplete'?'incomplete':'completed',output:[{type:'message',content:[{type:'refusal'}]}]})};
  }));assert.equal(calls,1);assert.equal(reports.length,1);assert.equal(reports[0].outcome,'FAILED');
 }
});
test('expired deadline and disabled provider never dispatch',async()=>{
 for(const cfg of [{enabled:false},{}]){const s=setup(cfg);let calls=0;await assert.rejects(()=>s.lunaCall(call,new Date(Date.now()-1),async()=>{},async()=>{calls++;}));assert.equal(calls,0);}
});
