import { AsyncLocalStorage } from 'node:async_hooks';
import { randomUUID } from 'node:crypto';
import { Prisma } from '@prisma/client';
import { prisma as root } from '../../../config/prisma';

const run = new AsyncLocalStorage<{bookId:string;token:string;epoch:number}>();
const writes = new Set(['create','createMany','createManyAndReturn','update','updateMany','updateManyAndReturn','upsert','delete','deleteMany']);
const cancelled = () => new Error('BOOK_INGESTION_CANCELLED: processing ownership changed');
async function guard(tx: Prisma.TransactionClient) {
  const owner = run.getStore();
  if (!owner) return;
  const rows = await tx.$queryRaw<Array<{processing_token:string;processing_epoch:number;processing_cancelled:boolean}>>`SELECT processing_token,processing_epoch,processing_cancelled FROM learning.book_sources WHERE id=${owner.bookId}::uuid FOR UPDATE`;
  const row = rows[0];
  if (!row || row.processing_cancelled || row.processing_token !== owner.token || row.processing_epoch !== owner.epoch) throw cancelled();
}
// External AI/PDF work stays outside transactions. Every content write rechecks the durable
// owner under the book-row lock; cancellation/replacement cannot race the resulting commit.
export const prisma = new Proxy(root, {get(target, key) {
  const value = Reflect.get(target,key);
  if (!run.getStore()) return typeof value === 'function' ? value.bind(target) : value;
  if (key === '$transaction') return (work: (tx: Prisma.TransactionClient)=>Promise<unknown>) => root.$transaction(async tx => {await guard(tx); return work(tx);},{timeout:30000});
  if (typeof key === 'string' && !key.startsWith('$') && value && typeof value === 'object') {
    return new Proxy(value,{get(model,method) {
      if (writes.has(String(method))) return (args: unknown) => root.$transaction(async tx => {await guard(tx);return (tx as any)[key][method](args);});
      const fn=Reflect.get(model,method);return typeof fn==='function'?fn.bind(model):fn;
    }});
  }
  return typeof value === 'function' ? value.bind(target) : value;
}});
export async function withBookRun<T>(bookId: string, work: ()=>Promise<T>,expectedEpoch?:number): Promise<T> {
  const token=randomUUID();
  const epoch=await root.$transaction(async tx=>{
    await tx.$queryRaw`SELECT id FROM learning.book_sources WHERE id=${bookId}::uuid FOR UPDATE`;
    const book=await tx.bookSource.findUniqueOrThrow({where:{id:bookId}});
    if (book.processingCancelled || expectedEpoch!==undefined && book.processingEpoch!==expectedEpoch) throw cancelled();
    if (book.processingToken && book.processingHeartbeat && +book.processingHeartbeat>Date.now()-180000) throw new Error('Book already has an active processing owner');
    await tx.bookSource.update({where:{id:bookId},data:{processingToken:token,processingHeartbeat:new Date()}});
    return book.processingEpoch;
  });
  const heartbeat=setInterval(()=>void root.bookSource.updateMany({where:{id:bookId,processingToken:token,processingEpoch:epoch,processingCancelled:false},data:{processingHeartbeat:new Date()}}).catch(()=>{}),20000);
  heartbeat.unref();
  try {return await run.run({bookId,token,epoch},work);}
  finally {clearInterval(heartbeat);await root.bookSource.updateMany({where:{id:bookId,processingToken:token},data:{processingToken:null,processingHeartbeat:null}});}
}
