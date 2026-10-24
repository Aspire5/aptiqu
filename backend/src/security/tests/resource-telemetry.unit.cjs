const test=require('node:test'),assert=require('node:assert/strict'),path=require('node:path');
const {loader}=require('../../modules/pvp/tests/pvp-test-fixture.cjs');
const source=p=>path.join(__dirname,'../../',p);
test('resource snapshots are quiet at normal log level, available at debug, and clean up monitoring',()=>{
 for(const level of ['info','debug']){
  const records=[];let sample,reset=0,disabled=0,cleared=0,unreferenced=0;
  const globals={console:{log:value=>records.push(value),warn:value=>records.push(value),error:value=>records.push(value)},
   process:{env:{LOG_LEVEL:level},memoryUsage:()=>({rss:300000000,heapUsed:30000000}),uptime:()=>300},
   setInterval:(fn,ms)=>{assert.equal(ms,60000);sample=fn;return{unref:()=>unreferenced++};},clearInterval:()=>cleared++};
  const load=loader({'node:perf_hooks':{monitorEventLoopDelay:()=>({enable:()=>{},disable:()=>disabled++,reset:()=>reset++,percentile:()=>21000000})}},globals);
  const stop=load(source('runtime/telemetry.ts')).startTelemetry({activeRequests:0},'combined');
  sample();assert.equal(reset,1);assert.equal(unreferenced,1);
  assert.equal(records.length,level==='debug'?1:0);
  if(records.length){const row=JSON.parse(records[0]);assert.equal(row.event,'runtime.resources');assert.equal(row.level,'debug');assert.equal(row.eventLoopDelayMs,21);}
  load(source('observability/logger.ts')).log('error','luna.preparation_failed',{code:'LUNA_AUTH_FAILED',preparationId:'fixture'});
  assert.equal(JSON.parse(records.at(-1)).event,'luna.preparation_failed');
  stop();assert.equal(cleared,1);assert.equal(disabled,1);
 }
});
