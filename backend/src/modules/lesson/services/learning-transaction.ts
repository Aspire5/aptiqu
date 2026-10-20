import { AsyncLocalStorage } from 'node:async_hooks';
import { createHash } from 'node:crypto';
import { Prisma } from '@prisma/client';
import { prisma as root } from '../../../config/prisma';
import { PublicError } from '../../../security/errors';

// Only learning helpers opt into this context. Nested XP/progression work must share the caller's commit.
const context = new AsyncLocalStorage<Prisma.TransactionClient>();
export const learningTransaction = () => context.getStore();
export const prisma = new Proxy(root, {
  get(target, property) {
    const db = context.getStore() ?? target;
    if (property === '$transaction' && context.getStore()) {
      return (work: any) => typeof work === 'function' ? work(db) : Promise.all(work);
    }
    const value = Reflect.get(db, property);
    return typeof value === 'function' ? value.bind(db) : value;
  },
});
function canonical(value: any): any {
  if (Array.isArray(value)) return value.map(canonical);
  if (value && typeof value === 'object') return Object.fromEntries(Object.keys(value).sort().filter(k => value[k] !== undefined).map(k => [k,canonical(value[k])]));
  return value;
}
export const actionHash = (value: unknown) => createHash('sha256').update(JSON.stringify(canonical(value))).digest('hex');
export async function learningAction(userId: string, operation: string, resource: string, clientActionId: string,
  payload: unknown, work: (scopedActionId: string) => Promise<any>, sessionId?: string): Promise<any> {
  const key = actionHash([userId, operation, resource, clientActionId]);
  const requestHash = actionHash(payload);
  return root.$transaction(tx => context.run(tx, async () => {
    // Follow Ranked/friendly user -> session -> progression lock order. This also serializes
    // mastery and concurrent lesson starts across processes without a Redis/memory lock.
    const user = await tx.$queryRaw<Array<{id:string}>>`SELECT id FROM auth.users WHERE id=${userId}::uuid FOR NO KEY UPDATE`;
    if (!user.length) throw new PublicError('User not found','NOT_FOUND',404);
    if (sessionId) {
      const owned = await tx.$queryRaw<Array<{id:string}>>`SELECT id FROM learning.lesson_sessions WHERE id = ${sessionId}::uuid AND user_id = ${userId}::uuid FOR UPDATE`;
      if (!owned.length) throw new PublicError('Lesson session not found', 'NOT_FOUND',404);
    }
    const receipt = await tx.lessonActionReceipt.findUnique({where:{key}});
    if (receipt) {
      if (receipt.requestHash !== requestHash) throw new PublicError('Action identifier was reused with a different request', 'IDEMPOTENCY_CONFLICT',409);
      if (receipt.sessionId && !await tx.lessonSession.findFirst({where:{id:receipt.sessionId,userId},select:{id:true}})) throw new PublicError('Lesson session not found','NOT_FOUND',404);
      return receipt.response;
    }
    const result = await work(key);
    const response = JSON.parse(JSON.stringify(result));
    await tx.lessonActionReceipt.create({data:{key,userId,sessionId:sessionId ?? result.sessionId,operation,requestHash,response}});
    return response;
  }), {maxWait:5000,timeout:15000});
}

// Catalog mutations opt into the same transaction-aware data helpers as lesson operations.
export function withDataTransaction<T>(tx: Prisma.TransactionClient, work: () => Promise<T>): Promise<T> {
  return context.run(tx, work);
}
