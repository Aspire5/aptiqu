import { prisma as root } from '../../../config/prisma';
import { learningTransaction, withDataTransaction } from '../../lesson/services/learning-transaction';
import { roadmapProgressionService } from './roadmap-progression.service';

// Content and its derived graph publish together. A failure leaves the previous complete graph visible.
// No queue acknowledgement gap, background repair requirement, or mutable GET self-healing.
export async function catalogMutation<T>(work: () => Promise<T>,reconcile=true): Promise<T> {
  if (learningTransaction()) return work();
  return root.$transaction(tx => withDataTransaction(tx, async () => {
    await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext('aptiqu:catalog'))`;
    const result = await work();
    if(reconcile) await roadmapProgressionService.syncRoadmapWithSyllabus(undefined, true);
    return result;
  }), {timeout:60000});
}
