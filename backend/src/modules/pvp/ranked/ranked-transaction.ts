import { Prisma, PrismaClient } from '@prisma/client';

function retryable(error: unknown): boolean {
  if (!error || typeof error !== 'object') return false;
  const e = error as { code?: string; meta?: { code?: string } };
  return e.code === 'P2034' || ['40001', '40P01'].includes(e.code ?? '') || ['40001', '40P01'].includes(e.meta?.code ?? '');
}
/** Retry only known rollback failures. Unknown commit outcomes are resolved by
 * calling the idempotent operation again, never by assuming it failed. */
export async function rankedTransaction<T>(db: PrismaClient, work: (tx: Prisma.TransactionClient) => Promise<T>): Promise<T> {
  for (let attempt = 0; ; attempt++) {
    try { return await db.$transaction(work, { maxWait: 5000, timeout: 15000 }); }
    catch (error) {
      if (attempt >= 2 || !retryable(error)) throw error;
      await new Promise(resolve => setTimeout(resolve, 15 * (attempt + 1) + Math.floor(Math.random() * 20)));
    }
  }
}
export async function databaseNow(tx: Prisma.TransactionClient): Promise<Date> {
  const [row] = await tx.$queryRaw<{ now: Date }[]>`SELECT date_trunc('milliseconds', clock_timestamp()) AS now`;
  if (!(row?.now instanceof Date) || !Number.isFinite(row.now.getTime())) throw new Error('Database clock unavailable.');
  return row.now;
}
