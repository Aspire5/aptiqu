const test=require('node:test'),assert=require('node:assert/strict'),path=require('node:path'),fs=require('node:fs/promises'),os=require('node:os');
const {loader}=require('../../modules/pvp/tests/pvp-test-fixture.cjs');
const source=p=>path.join(__dirname,'../../',p);
const load=loader({});
const {parseRuntimeConfig,readRankedConfig}=load(source('config/runtime-config.ts'));
const base=()=>({DATABASE_URL:'postgresql://fixture:SECRET_CANARY@127.0.0.1:55439/aptiqu_stage3_test',JWT_ACCESS_SECRET:'access-fixture',ADMIN_JWT_SECRET:'admin-fixture',ADMIN_USERNAME:'fixture',ADMIN_PASSWORD:'password-canary',GOOGLE_AUTH_ENABLED:'false'});
test('operational configuration validates roles, numeric bounds, URLs and only reports key names',()=>{
 const config=parseRuntimeConfig(base(),'/release');assert.equal(config.BACKEND_ROLE,'combined');assert.equal(new URL(config.DATABASE_URL).searchParams.get('connection_limit'),'5');assert.equal(config.GEMINI_THINKING_BUDGET,0);
 for(const changed of [{PORT:'NaN'},{PORT:'5001oops'},{NODE_ENV:'preview'},{BACKEND_ROLE:'cluster'},{REDIS_URL:'https://SECRET_CANARY.invalid'},{DATABASE_URL:'not-SECRET_CANARY'},{JWT_REFRESH_EXPIRATION:'0d'},{TRUST_PROXY:'true'},{HOST:''},{CONTENT_WORKER_CONCURRENCY:'50'},{AI_GENERATION_ENABLED:'true'},{DATABASE_PROCESS_COUNT:'100'}]){
  assert.throws(()=>parseRuntimeConfig({...base(),...changed},'/release'),error=>!error.message.includes('SECRET_CANARY') && /configuration/.test(error.message));
 }
});
test('production requires private roots, explicit pool budget and feature secrets without exposing values',()=>{
 const prod={...base(),NODE_ENV:'production',DATABASE_URL:base().DATABASE_URL+'?connection_limit=5&pool_timeout=10',DATABASE_CONNECTION_BUDGET:'15',DATABASE_PROCESS_COUNT:'3',REDIS_URL:'rediss://user:SECRET_CANARY@127.0.0.1:56439/7',JWT_ACCESS_SECRET:'a'.repeat(40),ADMIN_JWT_SECRET:'b'.repeat(40),BOOK_STORAGE_ROOT:'/private/books',BOOK_TEMP_ROOT:'/private/uploads',CORS_ALLOWED_ORIGINS:'https://admin.example.invalid'};
 assert.equal(parseRuntimeConfig(prod,'/release').DATABASE_PROCESS_COUNT,3);
 for(const changed of [{BOOK_STORAGE_ROOT:'/release/storage'},{BOOK_TEMP_ROOT:'/private/books/temp'},{DATABASE_CONNECTION_BUDGET:'10'},{DATABASE_URL:base().DATABASE_URL},{JWT_ACCESS_SECRET:'replace_with_a_random_32_byte_access_key'},{GOOGLE_AUTH_ENABLED:'true'},{CORS_ALLOWED_ORIGINS:'*'}])assert.throws(()=>parseRuntimeConfig({...prod,...changed},'/release'));
});
test('Ranked configuration stays default-off and validates activation, cursor separation and queue relationships',()=>{
 assert.equal(readRankedConfig({}).admission,false);
 for(const value of [{RANKED_ADMISSION_ENABLED:'yes'},{RANKED_ADMISSION_ENABLED:'true'},{RANKED_LAUNCH_SEASON:'2026-13'},{RANKED_LEAGUES_READ_ENABLED:'true'},{RANKED_QUEUE_NARROW_WINDOW:'400',RANKED_QUEUE_MAXIMUM_WINDOW:'100'}])assert.throws(()=>readRankedConfig(value));
 const ranked=readRankedConfig({RANKED_ADMISSION_ENABLED:'true',RANKED_LAUNCH_SEASON:'2026-10',RANKED_LEAGUES_READ_ENABLED:'true',RANKED_SKILL_MATCHMAKING_ENABLED:'true',RANKED_CURSOR_SECRET:'c'.repeat(40)});assert.equal(ranked.admission,true);assert.equal(ranked.narrowWindow,100);
});
test('role capabilities keep workers and realtime out of HTTP-only processes',()=>{
 const {roleCapabilities}=load(source('runtime/lifecycle.ts'));
 assert.deepEqual({...roleCapabilities('http')},{api:true,realtime:false,jobs:false});assert.deepEqual({...roleCapabilities('jobs')},{api:false,realtime:false,jobs:true});assert.deepEqual({...roleCapabilities('realtime')},{api:true,realtime:true,jobs:false});
});
test('drain retains async handler work after a disconnected response and shutdown runs once',async()=>{
 const {RuntimeState,shutdownOnce,trackAsyncHandlers}=load(source('runtime/lifecycle.ts'));
 const state=new RuntimeState();state.phase='ready';state.dependenciesReady=true;
 let release,finished=false;const gate=new Promise(resolve=>{release=resolve;});
 const stack=[{handle:async()=>{await gate;finished=true;}}];trackAsyncHandlers(stack,state);stack[0].handle({}, {},()=>{});
 let idle=false;const waiting=state.waitForIdle().then(()=>{idle=true;});await Promise.resolve();assert.equal(idle,false);
 release();await waiting;assert.equal(finished,true);
 let calls=0;const stop=shutdownOnce(state,[async()=>{calls++;}],50,()=>assert.fail('Unexpected timeout'));
 await Promise.all([stop(),stop(),stop()]);assert.equal(calls,1);assert.equal(state.phase,'stopped');
});
test('shutdown enforces one global deadline while slow work is still running',async()=>{
 const {RuntimeState,shutdownOnce}=load(source('runtime/lifecycle.ts'));const state=new RuntimeState();
 let release,forced=0;const work=new Promise(resolve=>{release=resolve;});
 const timed=new Promise(resolve=>{const stop=shutdownOnce(state,[()=>work],10,()=>{forced++;resolve();});stop();stop();});
 await timed;assert.equal(forced,1);assert.equal(state.phase,'draining');release();
});
test('bounded cache evicts by capacity/bytes, sweeps expiry and never retains oversized values',()=>{
 const {BoundedCache}=load(source('modules/lesson/services/bounded-cache.ts'));let now=0;const cache=new BoundedCache(2,20,()=>now);
 cache.set('a','111',10);cache.set('b','222',10);cache.get('a');cache.set('c','333',10);assert.equal(cache.get('b'),null);cache.set('huge','x'.repeat(30),10);assert.equal(cache.size,2);now=10001;assert.equal(cache.size,0);
});
test('single-flight shares a load, releases failures and preserves independent result copies',async()=>{
 const {SingleFlight}=load(source('modules/lesson/services/bounded-cache.ts'));const flight=new SingleFlight();let calls=0;
 const [a,b]=await Promise.all([flight.run('key',async()=>{calls++;return'one';}),flight.run('key',async()=>{calls++;return'two';})]);assert.equal(a,b);assert.equal(calls,1);
 await assert.rejects(()=>flight.run('bad',async()=>{throw new Error('fixture')}));assert.equal(await flight.run('bad',async()=> 'recovered'),'recovered');
});
test('script cache keeps reviewed pinned question data, isolates callers and still checks publication',async()=>{
 let definitions=0,questions=0,cache=null;
 const definition={schemaVersion:1,scriptId:'fixture',version:1,entryNodeId:'q',nodes:{q:{id:'q',type:'QUESTION',content:{text:'Pinned'},questionReference:{mode:'REPOSITORY',questionId:'q1',inlineData:{prompt:'Pinned',options:[{id:'A',label:'1'},{id:'B',label:'2'}],correctOptionId:'A'}},transitions:[{targetNodeId:'done'}]},done:{id:'done',type:'COMPLETION',content:{text:'Done'},transitions:[]}}};
 const db={lessonScriptVersion:{findUnique:async()=>{definitions++;return{definition};},findFirst:async()=>null},lessonScript:{findFirst:async()=>null},question:{findMany:async()=>{questions++;return[];}}};
 const l=loader({'./learning-transaction':{prisma:db,learningTransaction:()=>undefined},'./redis.service':{redisService:{get:async()=>cache,set:async(_key,value)=>{cache=value;},del:async()=>{},delByPattern:async()=>{}}}});
 const {scriptCacheService}=l(source('modules/lesson/services/script-cache.service.ts'));
 const [a,b]=await Promise.all([scriptCacheService.getScriptVersionDefinition('v1'),scriptCacheService.getScriptVersionDefinition('v1')]);a.nodes.q.content.text='Changed';assert.equal(b.nodes.q.content.text,'Pinned');assert.equal(definitions,1);assert.equal(questions,0);
 await scriptCacheService.getScriptVersionDefinition('v1');assert.equal(definitions,1);await assert.rejects(()=>scriptCacheService.assertPublished('s1','v1'),e=>e.status===404);
});
test('Redis lock acquisition fails closed and never uses its local cache as ownership',async()=>{
 const l=loader({'../../../config/env':{ENV:{REDIS_URL:'redis://unavailable'}},ioredis:{default:class{status='end';on(){return this;}disconnect(){}}}});
 const {redisService}=l(source('modules/lesson/services/redis.service.ts'));assert.equal(await redisService.setNxToken('key','token',1000),false);assert.equal(await redisService.releaseNxToken('key','token'),false);await redisService.close();
});
test('structured logs reject payload metadata and raw errors containing secrets, paths and SQL',()=>{
 const records=[];const l=loader({}, {console:{log:v=>records.push(v),warn:v=>records.push(v),error:v=>records.push(v)}});
 const {log,safeError}=l(source('observability/logger.ts'));const error=Object.assign(new Error('SECRET_CANARY SELECT * FROM /private/source'),{name:'SECRET_CANARY',code:'SECRET_CANARY'});
 log('error','fixture.failure',{...safeError(error),payload:'SECRET_CANARY',headers:{authorization:'SECRET_CANARY'},token:'SECRET_CANARY',status:500});assert.equal(records.length,1);assert.ok(!records[0].includes('SECRET_CANARY'));assert.equal(JSON.parse(records[0]).status,500);
});
test('temporary cleanup removes only owned expired uploads and preserves sources and symlinks',async t=>{
 const root=await fs.mkdtemp(path.join(os.tmpdir(),'aptiqu-stage3-'));t.after(()=>fs.rm(root,{recursive:true,force:true}));
 const owned=path.join(root,'upload-11111111-1111-1111-1111-111111111111.pdf'),sourceFile=path.join(root,'source.pdf'),link=path.join(root,'upload-22222222-2222-2222-2222-222222222222.pdf');
 await fs.writeFile(owned,'fixture');await fs.writeFile(sourceFile,'preserve');await fs.symlink(sourceFile,link);await fs.utimes(owned,new Date(0),new Date(0));
 const l=loader({'../config/env':{ENV:{BOOK_TEMP_ROOT:root,BOOK_TEMP_RETENTION_HOURS:1}}});const {cleanExpiredUploads}=l(source('runtime/storage.ts'));
 assert.equal(await cleanExpiredUploads(),1);assert.equal(await fs.readFile(sourceFile,'utf8'),'preserve');assert.ok((await fs.lstat(link)).isSymbolicLink());
});
test('runtime owner loss invokes admission shutdown once and stale release remains token checked',async()=>{
 let tick,lost=0,token;
 const client={set:async(_key,value)=>{token=value;return'OK';},eval:async(script,_n,_key,value)=>script.includes('PEXPIRE')?0:value===token?1:0};
 const l=loader({}, {setInterval:fn=>{tick=fn;return{unref(){}};},clearInterval:()=>{}});
 const {acquireRuntimeOwner}=l(source('runtime/single-owner.ts'));const release=await acquireRuntimeOwner(client,'jobs',()=>{lost++;});tick();await new Promise(resolve=>setTimeout(resolve,0));tick();assert.equal(lost,1);await release();
});
test('startup refuses missing schema/Ranked guard metadata and production requires patched supported Node',async()=>{
 const {assertDatabaseContract}=load(source('runtime/schema-contract.ts'));await assert.rejects(()=>assertDatabaseContract({$queryRaw:async()=>[{kind:'trigger'}]}),error=>error.code==='SCHEMA_INCOMPATIBLE');await assertDatabaseContract({$queryRaw:async()=>[]});
 const {assertSupportedRuntime}=load(source('runtime/node-version.ts'));for(const version of ['20.19.5','24.5.0','22.23.2','25.0.0'])assert.throws(()=>assertSupportedRuntime(version));assert.doesNotThrow(()=>assertSupportedRuntime('24.22.0'));assert.doesNotThrow(()=>assertSupportedRuntime('22.23.3'));
});
test('PDF preflight rejects excessive pages and extracted text before persisting content',async t=>{
 const root=await fs.mkdtemp(path.join(os.tmpdir(),'aptiqu-stage3-pdf-'));t.after(()=>fs.rm(root,{recursive:true,force:true}));const file=path.join(root,'fixture.pdf');await fs.writeFile(file,'%PDF-fixture');
 let pages=11,textCalls=0,destroyed=0;
 const l=loader({'../../../config/env':{ENV:{BOOK_UPLOAD_MAX_BYTES:1024,BOOK_MAX_PAGES:10,BOOK_MAX_EXTRACTED_TEXT_BYTES:100}},fs:{default:require('node:fs')},path:{default:require('node:path')},'./book-run':{prisma:{bookSource:{findUnique:async()=>({id:'fixture',title:'Fixture',storagePath:file}),update:async()=>{}},bookPage:{createMany:async()=>assert.fail('Persisted rejected PDF')}}},'./book-storage.service':{bookStorageService:{getPagesDirForBook:()=>root}},'./book-cancellation.service':{bookCancellationService:{checkAndThrowIfCancelled:async()=>{}}},'pdf-parse':{PDFParse:class{async getInfo(){return{total:pages};}async getText(){textCalls++;return{pages:[{text:'x'.repeat(101)}]};}async destroy(){destroyed++;}}}});
 const {pdfParserService}=l(source('modules/admin/services/pdf-parser.service.ts'));await assert.rejects(()=>pdfParserService.parseBookPdf('fixture'),/page limit/);assert.equal(textCalls,0);pages=1;await assert.rejects(()=>pdfParserService.parseBookPdf('fixture'),/extracted text limit/);assert.equal(destroyed,2);
});
test('legacy integration scripts reject execution before loading application configuration',()=>{
 const {spawnSync}=require('node:child_process');const backend=path.resolve(__dirname,'../../..');
 const result=spawnSync(process.execPath,['--import','tsx','src/modules/roadmap/tests/roadmap-progression.test.ts'],{cwd:backend,env:{PATH:process.env.PATH},encoding:'utf8',timeout:3000});
 assert.notEqual(result.status,0);assert.match(result.stderr,/Legacy integration disabled/);assert.ok(!result.stderr.includes('Missing required environment'));assert.ok(!result.stdout.includes('Environment variables loaded'));
});
