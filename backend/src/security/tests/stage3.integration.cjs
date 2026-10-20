// Explicit opt-in; existing disposable loopback fixtures only. Never loads dotenv.
const test=require('node:test'),assert=require('node:assert/strict'),path=require('node:path'),fs=require('node:fs/promises'),os=require('node:os'),net=require('node:net');
const {spawn}=require('node:child_process'),{once}=require('node:events'),Redis=require('ioredis');
const root=path.resolve(__dirname,'../../..'),delay=ms=>new Promise(resolve=>setTimeout(resolve,ms));
async function eventually(check,timeout=10000){const end=Date.now()+timeout;let last;while(Date.now()<end){try{if(await check())return;}catch(error){last=error;}await delay(50);}throw last??new Error('Condition timed out');}
async function port(){const server=net.createServer();server.listen(0,'127.0.0.1');await once(server,'listening');const value=server.address().port;await new Promise(resolve=>server.close(resolve));return value;}
test('Stage 3 isolated runtime roles, ownership, readiness and bounded shutdown',{skip:process.env.STAGE3_ALLOW_LOCAL_TESTS!=='true',timeout:60000},async t=>{
 const raw=process.env.STAGE3_TEST_DATABASE_URL;assert.ok(raw);const dbUrl=new URL(raw);assert.equal(dbUrl.hostname,'127.0.0.1');assert.equal(dbUrl.port,'55439');assert.match(dbUrl.pathname,/^\/aptiqu_stage[23]_test_[a-z0-9_]+$/);
 const redisUrl=new URL(process.env.STAGE3_TEST_REDIS_URL);assert.equal(redisUrl.hostname,'127.0.0.1');assert.equal(redisUrl.port,'56439');assert.equal(redisUrl.pathname,'/7');
 const temp=await fs.mkdtemp(path.join(os.tmpdir(),'aptiqu-stage3-runtime-'));await fs.writeFile(path.join(temp,'empty.env'),'');dbUrl.searchParams.set('connection_limit','2');dbUrl.searchParams.set('pool_timeout','2');dbUrl.searchParams.set('connect_timeout','1');
 const {PrismaClient}=require('@prisma/client');const db=new PrismaClient({datasources:{db:{url:dbUrl.href}},log:[]});
 const redis=new Redis(redisUrl.href,{maxRetriesPerRequest:1});redis.on('error',()=>{});const children=new Set();
 const start=async role=>{
  const childPort=await port();const child=spawn(process.execPath,['--import','tsx','src/server.ts'],{cwd:root,env:{PATH:process.env.PATH,NODE_ENV:'test',DOTENV_CONFIG_PATH:path.join(temp,'empty.env'),DATABASE_URL:dbUrl.href,REDIS_URL:redisUrl.href,GOOGLE_AUTH_ENABLED:'false',AI_GENERATION_ENABLED:'false',JWT_ACCESS_SECRET:'fixture-access-key',ADMIN_JWT_SECRET:'fixture-admin-key',ADMIN_USERNAME:'fixture',ADMIN_PASSWORD:'fixture-password',BACKEND_ROLE:role,HOST:'127.0.0.1',PORT:String(childPort),BOOK_STORAGE_ROOT:path.join(temp,'books'),BOOK_TEMP_ROOT:path.join(temp,'uploads'),READINESS_TIMEOUT_MS:'1000',SHUTDOWN_TIMEOUT_MS:'3000',LOG_LEVEL:'warn'},stdio:['ignore','pipe','pipe','ipc']});
  children.add(child);let output='';child.stdout.on('data',chunk=>{output=(output+chunk).slice(-20000);});child.stderr.on('data',chunk=>{output=(output+chunk).slice(-20000);});const exited=once(child,'exit').then(([code,signal])=>({code,signal}));let ready=false;child.on('message',message=>{if(message==='ready')ready=true;});await eventually(()=>ready||child.exitCode!==null);return {child,ready,exited,output:()=>output,url:`http://127.0.0.1:${childPort}`};
 };
 const stop=async run=>{run.child.kill('SIGTERM');run.child.kill('SIGINT');const result=await run.exited;children.delete(run.child);assert.equal(result.code,0,run.output());};
 try{
  await t.test('HTTP-only starts ready, declines WebSocket upgrades, and survives a dependency pause',async()=>{
   const run=await start('http');assert.equal(run.ready,true,run.output());assert.equal((await fetch(run.url+'/ready')).status,200);const {WebSocket}=require('ws');const ws=new WebSocket(run.url.replace('http:','ws:')+'/ws/pvp');await new Promise(resolve=>{ws.once('error',resolve);ws.once('open',()=>assert.fail('HTTP-only accepted realtime'));});ws.terminate();await redis.call('CLIENT','PAUSE','4000','ALL');await eventually(async()=>(await fetch(run.url+'/ready')).status===503,6000);assert.equal((await fetch(run.url+'/health')).status,200);await eventually(async()=>(await fetch(run.url+'/ready')).status===200,6000);await stop(run);
  });
  await t.test('one realtime owner survives a rejected overlapping owner and double shutdown signals',async()=>{
   const first=await start('realtime');assert.equal(first.ready,true,first.output());const second=await start('realtime');assert.equal(second.ready,false);assert.equal((await second.exited).code,1);children.delete(second.child);assert.equal((await fetch(first.url+'/ready')).status,200);await stop(first);
  });
  await t.test('jobs role owns workers/schedules, publishes expiry updates, exposes no API and rejects overlap',async()=>{
   const {randomUUID}=require('node:crypto');const users=[];for(let i=0;i<2;i++)users.push(await db.user.create({data:{email:randomUUID()+'@stage3.invalid',googleId:randomUUID(),isRegistrationComplete:true}}));
   const [lowId,highId]=users.map(user=>user.id).sort();const friend=await db.friendship.create({data:{lowId,highId,senderId:lowId,status:'ACCEPTED'}});
   const duel=await db.friendlyDuel.create({data:{requesterId:lowId,recipientId:highId,friendshipId:friend.id,requestKey:randomUUID(),subtopicIds:[],expiresAt:new Date(Date.now()-1000)}});await db.friendlyDuelSeat.createMany({data:[{userId:lowId,duelId:duel.id},{userId:highId,duelId:duel.id}]});
   const subscriber=redis.duplicate();const messages=[];subscriber.on('message',(_channel,text)=>messages.push(JSON.parse(text)));await subscriber.subscribe('social:user:'+lowId);
   const first=await start('jobs');await eventually(()=>messages.some(message=>message.event==='DUEL_CHANGED'&&message.id===duel.id));subscriber.disconnect();assert.equal((await db.friendlyDuel.findUnique({where:{id:duel.id}})).status,'EXPIRED');assert.equal(await db.friendlyDuelSeat.count({where:{duelId:duel.id}}),0);assert.equal(first.ready,true,first.output());assert.equal((await fetch(first.url+'/api/v1/auth/google',{method:'POST'})).status,404);const second=await start('jobs');assert.equal(second.ready,false);assert.equal((await second.exited).code,1);children.delete(second.child);await stop(first);
  });
  await t.test('a realtime owner exits on lost exclusivity and a replacement starts safely',async()=>{
   const first=await start('realtime');assert.equal(first.ready,true,first.output());await redis.del('aptiqu:runtime-owner:realtime');await eventually(()=>first.child.exitCode!==null,8000);assert.equal((await first.exited).code,1);children.delete(first.child);const replacement=await start('realtime');assert.equal(replacement.ready,true,replacement.output());await stop(replacement);
  });
  await t.test('old runtime lease release cannot delete its replacement',async()=>{
   const {loader}=require('../../modules/pvp/tests/pvp-test-fixture.cjs');const {acquireRuntimeOwner}=loader({})(path.join(root,'src/runtime/single-owner.ts'));const first=await acquireRuntimeOwner(redis,'realtime',()=>{});await redis.del('aptiqu:runtime-owner:realtime');const second=await acquireRuntimeOwner(redis,'realtime',()=>{});await first();assert.ok(await redis.get('aptiqu:runtime-owner:realtime'));await second();
  });
 }finally{const live=[...children].filter(child=>child.exitCode===null&&child.signalCode===null);const exits=live.map(child=>once(child,'exit'));for(const child of live)child.kill('SIGKILL');await Promise.allSettled(exits);redis.disconnect();await db.$disconnect();await fs.rm(temp,{recursive:true,force:true});}
});
