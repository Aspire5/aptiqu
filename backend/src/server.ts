import { assertSupportedRuntime } from './runtime/node-version';
import { assertDatabaseContract } from './runtime/schema-contract';
import http from 'node:http';
import { setTimeout as sleep } from 'node:timers/promises';
import { createApp } from './app';
import { ENV } from './config/env';
import { prisma } from './config/prisma';
import { redisService } from './modules/lesson/services/redis.service';
import { socialTransport } from './modules/social/social.transport';
import { socialSocketServer } from './modules/social/social.socket';
import { pvpSocketServer } from './modules/pvp/pvp.socket';
import { startSocialWorker } from './modules/social/social.worker';
import { startRankedWorker } from './modules/pvp/ranked/ranked-worker';
import { contentGenQueue, startContentGenWorker } from './queues/content-generation.queue';
import { bookIngestionQueue, startBookIngestionWorker } from './queues/book-ingestion.queue';
import { startDailyPreparationRecovery } from './queues/daily-preparation';
import { startScheduler } from './runtime/scheduler';
import { RuntimeState, roleCapabilities, deadline, shutdownOnce } from './runtime/lifecycle';
import { acquireRuntimeOwner } from './runtime/single-owner';
import { startTelemetry } from './runtime/telemetry';
import { log, safeError } from './observability/logger';
import { prepareStorage, startTempCleanup } from './runtime/storage';
import { syncRsAggarwalOnStartup } from './modules/admin/services/rs-aggarwal-startup-sync.service';

export async function bootstrap() {
  if(ENV.NODE_ENV==='production')assertSupportedRuntime(process.versions.node);
  const state=new RuntimeState(),capabilities=roleCapabilities(ENV.BACKEND_ROLE);
  const server=http.createServer(createApp(state));
  server.requestTimeout=ENV.HTTP_REQUEST_TIMEOUT_MS;
  server.headersTimeout=Math.min(10000,ENV.HTTP_REQUEST_TIMEOUT_MS);
  server.keepAliveTimeout=5000;
  const owners:Array<()=>Promise<void>>=[],schedules:Array<()=>Promise<unknown>>=[];
  const workers:Array<ReturnType<typeof startContentGenWorker>>=[];
  const closeSockets:Array<()=>Promise<void>>=[];
  let stopRanked:(()=>Promise<void>)|undefined,stopTelemetry:(()=>void)|undefined;
  let probeTimer:NodeJS.Timeout|undefined,probe:Promise<void>|undefined;
  let stopping=false,shutdown:()=>Promise<void>;
  const force=()=>{log('error','runtime.drain_timeout',{role:ENV.BACKEND_ROLE});server.closeAllConnections();process.exit(1);};
  // Do not spend the normal game/job drain interval after exclusivity is lost.
  // Exit before a replacement can continue scheduling; durable transactions,
  // receipts and per-operation fences handle interrupted accepted work.
  const lost=()=>{state.dependenciesReady=false;state.drain();pvpSocketServer.beginDrain();log('error','runtime.ownership_lost',{role:ENV.BACKEND_ROLE});process.exit(1);};
  const check=async()=>{
    await deadline(Promise.all([prisma.$queryRaw`SELECT 1`,redisService.getClient()!.ping()]),ENV.READINESS_TIMEOUT_MS,'Dependencies');
    if(socialTransport.client?.status!=='ready')throw new Error('Social transport unavailable');
    if(capabilities.realtime && socialTransport.subscriber?.status!=='ready')throw new Error('Social subscriber unavailable');
    if(workers.some(worker=>!worker.isReady()))throw new Error('Worker unavailable');
  };
  shutdown=shutdownOnce(state,[
    async()=>{
      stopping=true;clearInterval(probeTimer);pvpSocketServer.beginDrain();
      await Promise.all(workers.map(worker=>worker.pause()));
      // Close the listener immediately. Existing accepted requests retain dependencies.
      server.close();server.closeIdleConnections();
      await Promise.all(schedules.map(stop=>stop()));
    },
    ()=>state.waitForIdle(),
    async()=>{
      // Let already admitted games finish within the shared shutdown deadline.
      if(capabilities.realtime)while(await prisma.pvpMatch.count({where:{status:{notIn:['COMPLETED','CANCELLED']}}}))await sleep(250);
      await Promise.all(closeSockets.map(close=>close()));
      await stopRanked?.();
    },
    async()=>{await Promise.all(workers.map(worker=>worker()));await contentGenQueue.close();await bookIngestionQueue.close();},
    async()=>{await probe;stopTelemetry?.();await socialTransport.close();for(const release of owners.reverse())await release();await redisService.close();await prisma.$disconnect();},
  ],ENV.SHUTDOWN_TIMEOUT_MS,force);
  const signal=()=>{void shutdown().then(()=>process.exit(0),error=>{log('error','runtime.shutdown_failed',safeError(error));force();});};
  process.on('SIGINT',signal);process.on('SIGTERM',signal);
  try {
    await deadline(Promise.all([prisma.$connect(),redisService.connect(),prepareStorage()]),ENV.READINESS_TIMEOUT_MS,'Startup');
    await deadline(assertDatabaseContract(prisma,ENV.DATABASE_CONNECTION_BUDGET),ENV.READINESS_TIMEOUT_MS,'Schema contract');
    if(capabilities.realtime)owners.push(await acquireRuntimeOwner(redisService.getClient()!,'realtime',lost));
    if(capabilities.jobs)owners.push(await acquireRuntimeOwner(redisService.getClient()!,'jobs',lost));
    await socialTransport.connect(capabilities.realtime);
    if(capabilities.realtime) {
      pvpSocketServer.init(server,()=>state.ready);socialSocketServer.init(server,()=>state.ready);
      if(ENV.RANKED.drain)pvpSocketServer.beginDrain();
      closeSockets.push(()=>pvpSocketServer.close(),()=>socialSocketServer.close());
      stopRanked=startRankedWorker();
    } else server.on('upgrade',(_req,socket)=>socket.destroy());
    server.on('upgrade',(req,socket)=>{if(!['/ws/pvp','/ws/social'].includes(req.url?.split('?')[0]??'')||!state.ready)socket.destroy();});
    if(capabilities.jobs) {
      workers.push(startContentGenWorker(),startBookIngestionWorker(),startSocialWorker());
      await deadline(Promise.all(workers.map(worker=>worker.ready())),ENV.READINESS_TIMEOUT_MS,'Workers');
      schedules.push(startScheduler(),startDailyPreparationRecovery(),startTempCleanup());
    }
    await check();state.dependenciesReady=true;
    await deadline(new Promise<void>((resolve,reject)=>{server.once('error',reject);server.listen(ENV.PORT,ENV.HOST,()=>{server.off('error',reject);resolve();});}),ENV.READINESS_TIMEOUT_MS,'Listener');
    state.phase='ready';
    probeTimer=setInterval(()=>{
      if(stopping||probe)return;
      probe=check().then(()=>{state.dependenciesReady=true;},error=>{state.dependenciesReady=false;log('warn','runtime.dependencies_unavailable',safeError(error));}).finally(()=>{probe=undefined;});
    },2000);probeTimer.unref();
    stopTelemetry=startTelemetry(state,ENV.BACKEND_ROLE);
    if(process.send)process.send('ready');
    log('info','runtime.ready',{role:ENV.BACKEND_ROLE});
    if(capabilities.api)log('info','cors.configured',{origins:ENV.CORS_ALLOWED_ORIGINS.join(',')});
    // The jobs lease guarantees a single automatic importer. Track it for shutdown
    // without delaying PM2 readiness while hundreds of repository files publish.
    if(capabilities.jobs && ENV.CURRICULUM_SYNC_ON_STARTUP)
      void state.track(syncRsAggarwalOnStartup()).catch(error=>log('error','curriculum.sync.failed',safeError(error)));
    return {state,server,shutdown};
  } catch(error) {
    // Partial startup owns the same bounded cleanup path; never report ready.
    log('error','runtime.startup_failed',safeError(error));
    await shutdown();throw error;
  }
}
if(require.main===module)void bootstrap().catch(error=>{log('error','runtime.failed',safeError(error));process.exit(1);});
