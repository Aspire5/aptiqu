// Loopback-only HTTP parsing/authentication contract test. Routers are inert; no app/DB workers start.
const test=require('node:test');const assert=require('node:assert/strict');const path=require('node:path');
const {loader}=require('../../modules/pvp/tests/pvp-test-fixture.cjs');const express=require('express');
test('HTTP authenticates before parsing, has differentiated JSON limits, no-store and Retry-After',async()=>{
 const ENV={TRUST_PROXY:'',JWT_ACCESS_SECRET:'http-access',ADMIN_JWT_SECRET:'http-admin',ADMIN_USERNAME:'admin',JWT_ACCESS_EXPIRATION:'15m',JWT_REFRESH_EXPIRATION:'7d',ADMIN_JWT_EXPIRATION:'24h',JWT_ISSUER:'aptiqu',JWT_AUDIENCE:'aptiqu-mobile'};
 const deps={express:{default:express},cors:{default:require('cors')},jsonwebtoken:{default:require('jsonwebtoken')},crypto:{default:require('crypto')},'./config/env':{ENV},'../config/env':{ENV},'../../config/env':{ENV},
  '../modules/lesson/services/redis.service':{redisService:{getClient:()=>({status:'ready',eval:async()=>[1,60000]})}},
  };
 for(const feature of ['auth','user','lesson','roadmap','practice','pvp','daily-challenge','admin','social']) {
  const router=express.Router();router.post(/.*/,(_req,res)=>res.json({success:true,receivedAt:res.locals.receivedAt}));deps[`./modules/${feature}/${feature==='roadmap'?'roadmap':feature}.routes`]={default:router};
 }
 const load=loader(deps);const source=p=>path.join(__dirname,'../../',p);
 const {createApp}=load(source('app.ts'));const {signAccessToken}=load(source('utils/jwt.ts'));const {signAdminToken}=load(source('modules/admin/admin.middleware.ts'));
 const app=createApp();const server=app.listen(0,'127.0.0.1');await new Promise(resolve=>server.once('listening',resolve));
 try{
  const base=`http://127.0.0.1:${server.address().port}/api/v1`;
  async function post(route,body,token){return fetch(base+route,{method:'POST',headers:{'content-type':'application/json',...(token?{authorization:'Bearer '+token}:{})},body:typeof body==='string'?body:JSON.stringify(body)});}
  const access=signAccessToken({userId:'00000000-0000-4000-8000-000000000001',email:'test@example.invalid'}),admin=signAdminToken('admin');
  assert.equal((await post('/lessons/start','{')).status,401); // Bad private JSON is never parsed before authorization.
  assert.equal((await post('/lessons/start',{text:'x'.repeat(100000)},access)).status,413);
  assert.equal((await post('/auth/google',{idToken:'x'.repeat(25000)})).status,413);
  assert.equal((await post('/admin/import',{text:'x'.repeat(100000)},admin)).status,200);
  assert.equal((await post('/admin/import',{},access)).status,401);
  const response=await post('/lessons/start',{},access);assert.equal(response.status,200);assert.equal(response.headers.get('cache-control'),'no-store');
  assert.equal((await post('/auth/google','{')).status,400);
  const http=require('node:http');
  let bodyCompletedAt;
  const streamed=await new Promise((resolve,reject)=>{
   const request=http.request(base+'/daily-challenge/answer',{method:'POST',headers:{'content-type':'application/json',authorization:'Bearer '+access}},response=>{
    let data='';response.on('data',chunk=>data+=chunk);response.on('end',()=>resolve(JSON.parse(data)));
   });
   request.on('error',reject);request.write('{"answer":"');
   setTimeout(()=>{bodyCompletedAt=Date.now();request.end('A"}');},20);
  });
  assert.ok(Date.parse(streamed.receivedAt)>=bodyCompletedAt,'Daily receipt time must follow full body receipt, not just headers');

  // Exercise the production Redis policy middleware's 429 and outage responses without a network Redis dependency.
  const rateLoad=loader({'../modules/lesson/services/redis.service':{redisService:{getClient:()=>({status:'ready',eval:async()=>[999,1500]})}}});
  const {requestBudget}=rateLoad(source('security/request-policy.ts'));let code,headers={},body;
  const res={setHeader:(k,v)=>headers[k]=v,status:v=>{code=v;return res},json:v=>{body=v}};
  await new Promise(resolve=>{res.json=v=>{body=v;resolve()};requestBudget({path:'/auth/google',method:'POST',ip:'127.0.0.1',socket:{}},res,()=>assert.fail('must throttle'));});
  assert.equal(code,429);assert.equal(headers['Retry-After'],'2');assert.equal(body.code,'RATE_LIMITED');
 }finally{server.closeAllConnections();await new Promise(resolve=>server.close(resolve));}
});
