import { Prisma } from '@prisma/client';

/** Per-user mutex shared by competitive admission/settlement. NO KEY UPDATE
 * preserves mutual exclusion while permitting FK KEY SHARE checks, avoiding
 * cycles with XP rows inserted by unrelated learning transactions. */
export async function lockUsers(tx: Prisma.TransactionClient, ids: string[]) {
  const sorted = [...new Set(ids)].sort();
  if (!sorted.length) return;
  await tx.$queryRaw(Prisma.sql`SELECT id FROM auth.users WHERE id IN (${Prisma.join(sorted.map(id => Prisma.sql`${id}::uuid`))}) ORDER BY id FOR NO KEY UPDATE`);
}
