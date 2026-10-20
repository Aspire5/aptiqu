// Loopback HTTP only; inert routers and no env/DB/Redis workers.
const test=require('node:test'),assert=require('node:assert/strict'),path=require('node:path');const express=require('express');
const {loader}=require('../../modules/pvp/tests/pvp-test-fixture.cjs');
test('HTTP readiness, CORS, safe errors and disconnected in-flight drain',{timeout:15000},async()=>{
 let entered,release;const started=new Promise(resolve=>{entered=resolve;}),gate=new Promise(resolve=>{release=resolve;});let completed=false;const records=[];
 const ENV={NODE_ENV:'test',BACKEND_ROLE:'http',CORS_ALLOWED_ORIGINS:['https://admin.example.invalid'],TRUST_PROXY:''};
 const deps={'./config/env':{ENV},express:{default:express},cors:{default:require('cors')},'./security/trusted-peer':{trustedProxy:()=>false},'./middleware/auth.middleware':{authenticateJwt:(_req,_res,next)=>next()},'./modules/admin/admin.middleware':{authenticateAdmin:(_req,_res,next)=>next()}};
 for(const feature of ['auth','user','lesson','roadmap','practice','pvp','daily-challenge','admin','social']){
  const router=express.Router();if(feature==='auth')router.post('/google',async(req,res)=>{if(req.body.wait){entered();await gate;completed=true;}res.json({success:true});});
  deps[`./modules/${feature}/${feature}.routes`]={default:router};
 }
 const load=loader(deps,{console:{log:v=>records.push(v),warn:v=>records.push(v),error:v=>records.push(v)}}),source=p=>path.join(__dirname,'../../',p);
 const {PublicError}=load(source('security/errors.ts'));deps['./security/request-policy']={PublicError,requestBudget:(_req,_res,next)=>next()};
 const {RuntimeState}=load(source('runtime/lifecycle.ts')),state=new RuntimeState();const {createApp}=load(source('app.ts'));
 const server=createApp(state).listen(0,'127.0.0.1');await new Promise(resolve=>server.once('listening',resolve));const base=`http://127.0.0.1:${server.address().port}`;
 const post=(body,headers={},signal)=>fetch(base+'/api/v1/auth/google?token=SECRET_CANARY',{method:'POST',headers:{'content-type':'application/json',...headers},body:JSON.stringify(body),signal});
 try {
  assert.equal((await fetch(base+'/health')).status,200);assert.equal((await fetch(base+'/ready')).status,503);assert.equal((await post({})).status,503);
  state.phase='ready';state.dependenciesReady=true;assert.equal((await fetch(base+'/ready')).status,200);
  let response=await post({},{origin:'https://admin.example.invalid'});assert.equal(response.status,200);assert.equal(response.headers.get('access-control-allow-origin'),'https://admin.example.invalid');assert.equal(response.headers.get('x-powered-by'),null);assert.equal(response.headers.get('x-content-type-options'),'nosniff');assert.ok(response.headers.get('x-request-id'));
  response=await post({},{origin:'https://blocked.example.invalid'});assert.equal(response.status,403);assert.ok(!(await response.text()).includes('SECRET_CANARY'));
  assert.equal((await post({text:'x'.repeat(30000)})).status,413);
  const abort=new AbortController();const pending=post({wait:true},{},abort.signal).catch(()=>{});await started;abort.abort();await pending;
  state.drain();let idle=false;const drain=state.waitForIdle().then(()=>{idle=true;});await new Promise(resolve=>setTimeout(resolve,10));assert.equal(idle,false);assert.equal(completed,false);
  response=await post({});assert.equal(response.status,503);assert.equal(response.headers.get('retry-after'),'3');assert.equal((await fetch(base+'/health')).status,200);assert.equal((await fetch(base+'/ready')).status,503);
  release();await drain;assert.equal(completed,true);assert.ok(!records.join('\n').includes('SECRET_CANARY'));
 }finally{release();server.closeAllConnections();await new Promise(resolve=>server.close(resolve));}
});
