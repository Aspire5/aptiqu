import { randomUUID } from 'node:crypto';
import { AsyncLocalStorage } from 'node:async_hooks';
import { Prisma } from '@prisma/client';
import { prisma as root } from '../../config/prisma';
const context=new AsyncLocalStorage<{scope:string;token:string}>();
const timers=new Map<string,NodeJS.Timeout>();
const writes=new Set(['create','createMany','upsert','update','updateMany','delete','deleteMany']);
async function guard(tx:Prisma.TransactionClient) {
  const owner=context.getStore(); if(!owner)return;
  const valid=await tx.$queryRaw<{scope:string}[]>`SELECT scope FROM learning.generation_leases WHERE scope=${owner.scope} AND token=${owner.token} AND expires_at>NOW() FOR UPDATE`;
  if(!valid.length)throw new Error('Generation lease expired or was replaced; result discarded');
}
export const generationDb=new Proxy(root,{get(target,key){
  const value=Reflect.get(target,key);
  if(!context.getStore())return typeof value==='function'?value.bind(target):value;
  if(key==='$transaction')return (work:(tx:Prisma.TransactionClient)=>Promise<unknown>)=>root.$transaction(async tx=>{await guard(tx);return work(tx);},{timeout:30000});
  if(typeof key==='string'&&!key.startsWith('$')&&value&&typeof value==='object')return new Proxy(value,{get(model,method){
    if(writes.has(String(method)))return (args:unknown)=>root.$transaction(async tx=>{await guard(tx);return (tx as any)[key][method](args);});
    const fn=Reflect.get(model,method);return typeof fn==='function'?fn.bind(model):fn;
  }});
  return typeof value==='function'?value.bind(target):value;
}});
export class ConcurrencyLockService {
  static async acquireLock(scopeKey:string,ttlMs=60000):Promise<string|null> {
    const token=randomUUID();
    const rows=await root.$queryRaw<{scope:string}[]>`INSERT INTO learning.generation_leases(scope,token,expires_at) VALUES (${scopeKey},${token},NOW()+${ttlMs}*interval '1 millisecond') ON CONFLICT(scope) DO UPDATE SET token=EXCLUDED.token,expires_at=EXCLUDED.expires_at WHERE generation_leases.expires_at<=NOW() RETURNING scope`;
    if(!rows.length)return null;
    const timer=setInterval(()=>void root.$executeRaw`UPDATE learning.generation_leases SET expires_at=NOW()+${ttlMs}*interval '1 millisecond' WHERE scope=${scopeKey} AND token=${token} AND expires_at>NOW()`.catch(()=>{}),Math.max(1000,Math.floor(ttlMs/3)));
    timer.unref();timers.set(token,timer);return token;
  }
  static async runWithLease<T>(scope:string,token:string,work:()=>Promise<T>):Promise<T>{return context.run({scope,token},work);}
  static async releaseLock(scopeKey:string,token?:string|null){
    if(!token)return;clearInterval(timers.get(token));timers.delete(token);
    await root.generationLease.deleteMany({where:{scope:scopeKey,token}});
  }
  static async waitForCondition(condition:()=>Promise<boolean>,maxWaitMs=12000,intervalMs=1500){
    const end=Date.now()+maxWaitMs;while(Date.now()<end){if(await condition())return true;await new Promise(resolve=>setTimeout(resolve,intervalMs));}return condition();
  }
}
