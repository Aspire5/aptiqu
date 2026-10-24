export function friendlyResult(sessions: { userId: string; correctCount: number; totalTimeMs: number }[], timed: boolean, completed: boolean) {
  if (!completed || sessions.length !== 2) return { winnerId: null, isTie: false };
  const [a,b] = sessions;
  const tied = a.correctCount === b.correctCount && (!timed || a.totalTimeMs === b.totalTimeMs);
  if (tied) return { winnerId: null, isTie: true };
  const winner = a.correctCount !== b.correctCount ? a.correctCount > b.correctCount ? a : b
    : a.totalTimeMs < b.totalTimeMs ? a : b;
  return { winnerId: winner.userId, isTie: false };
}
import { Prisma } from '@prisma/client';
import { prisma } from '../../config/prisma';
import { lockUsers, friendPair, publicUser, publicUserSelect } from './friends.service';
import { resolveDuelScope } from './duel.selection';
import { ENV } from '../../config/env';
import { startPreparation, preparationStatus, ACTIVE_STATES } from '../ai/luna/preparations';
import { socialError, socialTransport } from './social.transport';
import { XpService } from '../xp/xp.service';

export class DuelsService {
  clearSchedule: ((id: string) => Promise<void>) | null = null;
  schedule: ((id: string, delay: number) => Promise<void>) | null = null;
  async expire(id: string) {
    const result = await prisma.$transaction(async tx => {
      const changed = await tx.$queryRaw<{ requester_id: string; recipient_id: string }[]>`
        UPDATE learning.friendly_duels SET status=CASE WHEN status='PENDING' THEN 'EXPIRED'::learning."FriendlyDuelStatus" ELSE 'ABANDONED'::learning."FriendlyDuelStatus" END
        WHERE id=${id}::uuid AND ((status IN ('PENDING','PREPARING') AND expires_at <= NOW()) OR (status='ACTIVE' AND match_expires_at <= NOW()))
        RETURNING requester_id,recipient_id`;
      if (changed.length) {
        await tx.friendlyDuelSeat.deleteMany({ where: { duelId: id } });
        await tx.practiceSession.updateMany({ where: { friendlyDuelId: id, status: 'ACTIVE' }, data: { status: 'ABANDONED' } });
      }
      return changed;
    });
    if (result[0]) await socialTransport.notify([result[0].requester_id, result[0].recipient_id], 'DUEL_CHANGED', id);
  }
  async invite(userId: string, targetId: string, input: { requestKey: string; subtopicIds: string[]; smartPicks: boolean; timerEnabled: boolean }) {
    const pair = friendPair(userId, targetId);
    await socialTransport.limit(userId, 'duel-invite', 10, 60);
    const existing = await prisma.friendlyDuel.findUnique({ where: { requestKey: input.requestKey } });
    if (existing) {
      if (existing.requesterId !== userId || existing.recipientId !== targetId) throw socialError('Invalid request key.', 409);
      return this.get(userId, existing.id);
    }
    const scope = await resolveDuelScope(input.subtopicIds);
    const duel = await prisma.$transaction(async tx => {
      await lockUsers(tx, [userId, targetId]);
      const retry = await tx.friendlyDuel.findUnique({ where: { requestKey: input.requestKey } });
      if (retry) return retry;
      if (await tx.pvpMatchPlayer.count({ where: { userId: { in: [userId, targetId] }, match: { OR: [{ status: { in: ['STARTING','IN_PROGRESS','QUESTION_ACTIVE','QUESTION_TRANSITION'] } }, { ratingMode: 'RATED', settlement: null }] } } })) throw socialError('One of you is playing Ranked. Please try later.', 409);
      const friendship = await tx.friendship.findUnique({ where: { lowId_highId: pair } });
      if (friendship?.status !== 'ACCEPTED') throw socialError('Only friends can be invited to a duel.', 403);
      if (await tx.questionPreparation.count({where:{userIds:{hasSome:[userId,targetId]},state:{in:ACTIVE_STATES},deadline:{gt:new Date()}}})) throw socialError('One of you is preparing questions. Please try later.',409);
      // Release expired reservations under the same pair locks. Database seats
      // enforce one outstanding/active duel per user across all API instances.
      const expired = await tx.$queryRaw<{ id: string }[]>(Prisma.sql`
        UPDATE learning.friendly_duels SET status='EXPIRED'
        WHERE status='PENDING' AND expires_at <= NOW() AND
          (requester_id IN (${Prisma.join([userId, targetId].map(v => Prisma.sql`${v}::uuid`))})
          OR recipient_id IN (${Prisma.join([userId, targetId].map(v => Prisma.sql`${v}::uuid`))})) RETURNING id`);
      await tx.friendlyDuelSeat.deleteMany({ where: { duelId: { in: expired.map(d => d.id) } } });
      if (await tx.friendlyDuelSeat.count({ where: { userId: { in: [userId, targetId] } } })) throw socialError('One of you already has a duel or invitation open.', 409);
      const created = await tx.friendlyDuel.create({ data: { requesterId: userId, recipientId: targetId, friendshipId: friendship.id,
        requestKey: input.requestKey, subtopicIds: scope, smartPicks: input.smartPicks, timerEnabled: input.timerEnabled } });
      await tx.friendlyDuelSeat.createMany({ data: [userId, targetId].map(userId => ({ userId, duelId: created.id })) });
      return created;
    });
    if (this.schedule) await this.schedule(duel.id, 60000).catch(() => {});
    await socialTransport.notify([userId, targetId], 'DUEL_CHANGED', duel.id);
    return this.get(userId, duel.id);
  }
  async get(user: string, id: string) {
    const allowed = await prisma.friendlyDuel.findFirst({ where: { id, OR: [{ requesterId: user }, { recipientId: user }] }, select: { id: true } });
    if (!allowed) throw socialError('Duel not found.', 404);
    await this.expire(id);
    const preparing=await prisma.friendlyDuel.findUnique({where:{id}});
    if(preparing?.status==='PREPARING'){
      const job=await prisma.questionPreparation.findFirst({where:{mode:'FRIENDLY',scope:{path:['duelId'],equals:id}},orderBy:{createdAt:'desc'}});
      if(job && (['FAILED','EXPIRED','CANCELLED'].includes(job.state)||job.state!=='READY'&&job.deadline<=new Date()))await this.abandon(user,id);
      else if(job?.state==='QUEUED')await preparationStatus(user,job.id);
      else if(!job){
        // Recover an accepted invitation interrupted between PREPARING and queue dispatch.
        try {
          const scope={subtopicIds:await resolveDuelScope(preparing.subtopicIds),smartPicks:preparing.smartPicks,duelId:id};
          await startPreparation({users:[preparing.requesterId,preparing.recipientId],mode:'FRIENDLY',tier:'UNRANKED',requestKey:`duel-${id}`,scope});
        }catch{await this.abandon(user,id);}
      }
    }
    const duel = await prisma.friendlyDuel.findFirst({ where: { id, OR: [{ requesterId: user }, { recipientId: user }] },
      include: { requester: { select: publicUserSelect }, recipient: { select: publicUserSelect },
        sessions: { select: { id: true, userId: true, status: true, correctCount: true, currentIndex: true, totalTimeMs: true, xpAwarded: true } } } });
    if (!duel) throw socialError('Duel not found.', 404);
    return { id: duel.id, status: duel.status, expiresAt: duel.expiresAt, remainingMs: Math.max(0, duel.expiresAt.getTime() - Date.now()),
      smartPicks: duel.smartPicks, timerEnabled: duel.timerEnabled, selectionNotes: duel.selectionNotes,
      requester: publicUser(duel.requester), recipient: publicUser(duel.recipient), sessions: duel.sessions,
      ...friendlyResult(duel.sessions, duel.timerEnabled, duel.status === 'COMPLETED'),
      sessionId: duel.sessions.find(s => s.userId === user)?.id ?? null };
  }
  async respond(user: string, id: string, action: 'accept' | 'reject' | 'cancel') {
    const initial = await prisma.friendlyDuel.findUnique({ where: { id } });
    if (!initial || ![initial.requesterId, initial.recipientId].includes(user)) throw socialError('Duel not found.', 404);
    if (action === 'cancel' ? initial.requesterId !== user : initial.recipientId !== user) throw socialError('This action is not permitted.', 403);
    await this.expire(id);
    const afterExpiry = await prisma.friendlyDuel.findUnique({where:{id}});
    if (!afterExpiry || !['PENDING','PREPARING','ACTIVE'].includes(afterExpiry.status)) throw socialError('This invitation expired or was already handled.',409);
    const duel = await prisma.$transaction(async tx => {
      await lockUsers(tx, [initial.requesterId, initial.recipientId]);
      const fresh = await tx.friendlyDuel.findUniqueOrThrow({ where: { id } });
      if (action === 'accept' && ['ACTIVE','PREPARING'].includes(fresh.status)) return fresh;
      if (fresh.status === 'ACTIVE' || fresh.status === 'PREPARING') {
        if (action !== 'cancel') throw socialError('This invitation was already handled.',409);
        await tx.friendlyDuel.update({where:{id},data:{status:'ABANDONED'}});
        await tx.practiceSession.updateMany({where:{friendlyDuelId:id,status:'ACTIVE'},data:{status:'ABANDONED'}});
        await tx.friendlyDuelSeat.deleteMany({where:{duelId:id}});
        await tx.questionPreparation.updateMany({where:{scope:{path:['duelId'],equals:id},state:{in:ACTIVE_STATES}},data:{state:'CANCELLED',version:{increment:1}}});
        return null;
      }
      if (fresh.status !== 'PENDING' || fresh.expiresAt <= new Date()) throw socialError('This invitation expired or was already handled.',409);
      if (action === 'accept') {
        const friend = await tx.friendship.findUnique({where:{id:initial.friendshipId}});
        if(friend?.status !== 'ACCEPTED') throw socialError('You are no longer friends.',403);
        return tx.friendlyDuel.update({where:{id},data:{status:'PREPARING',expiresAt:new Date(Date.now()+ENV.LUNA.preparationTimeoutMs+30000)}});
      }
      await tx.friendlyDuel.update({where:{id},data:{status:action === 'reject'?'REJECTED':'CANCELLED'}});
      await tx.friendlyDuelSeat.deleteMany({where:{duelId:id}});
      return null;
    });
    if (action === 'accept' && duel?.status === 'PREPARING') {
      try {
        const scope = {subtopicIds:await resolveDuelScope(initial.subtopicIds),smartPicks:initial.smartPicks,duelId:id};
        await startPreparation({users:[initial.requesterId,initial.recipientId],mode:'FRIENDLY',tier:'UNRANKED',requestKey:`duel-${id}`,scope});
        if(this.schedule) await this.schedule(id,ENV.LUNA.preparationTimeoutMs+30000).catch(()=>{});
      } catch(error) { await this.abandon(user,id); throw error; }
    } else if(this.clearSchedule) await this.clearSchedule(id).catch(()=>{});
    await socialTransport.notify([initial.requesterId, initial.recipientId], 'DUEL_CHANGED', id);
    return this.get(user,id);
  }
  async finalizeInTransaction(tx: Prisma.TransactionClient, id: string) {
    const duel = await tx.friendlyDuel.findUnique({ where: { id }, include: { sessions: true } });
    if (!duel || duel.status !== 'ACTIVE' || duel.sessions.length !== 2 || duel.sessions.some(s => s.status !== 'COMPLETED')) return;
    await tx.friendlyDuel.update({ where: { id }, data: { status: 'COMPLETED', completedAt: new Date() } });
    for (const session of [...duel.sessions].sort((a, b) => a.userId.localeCompare(b.userId))) {
      await XpService.getInstance().awardXp({ userId: session.userId, amount: 10, sourceType: 'FRIENDLY_DUEL', sourceId: id,
        idempotencyKey: `friendly-duel:${id}:${session.userId}`, description: 'Completed a friendly practice duel' }, tx);
      await tx.practiceSession.update({ where: { id: session.id }, data: { xpAwarded: 10 } });
    }
    await tx.friendlyDuelSeat.deleteMany({ where: { duelId: id } });
  }
  async abandon(user: string, id: string) {
    const initial = await prisma.friendlyDuel.findFirst({ where: { id, OR: [{ requesterId: user }, { recipientId: user }] } });
    if (!initial) throw socialError('Duel not found.', 404);
    await prisma.$transaction(async tx => {
      await lockUsers(tx, [initial.requesterId, initial.recipientId]);
      await tx.$queryRaw`SELECT id FROM learning.friendly_duels WHERE id=${id}::uuid FOR UPDATE`;
      const result = await tx.friendlyDuel.updateMany({ where: { id, status: { in: ['PENDING', 'PREPARING', 'ACTIVE'] } }, data: { status: 'ABANDONED' } });
      if (result.count) {
        await tx.questionPreparation.updateMany({where:{scope:{path:['duelId'],equals:id},state:{in:ACTIVE_STATES}},data:{state:'CANCELLED',version:{increment:1}}});
        await tx.practiceSession.updateMany({ where: { friendlyDuelId: id, status: 'ACTIVE' }, data: { status: 'ABANDONED' } });
        await tx.friendlyDuelSeat.deleteMany({ where: { duelId: id } });
      }
    });
    if (this.clearSchedule) await this.clearSchedule(id).catch(() => {});
    await socialTransport.notify([initial.requesterId, initial.recipientId], 'DUEL_CHANGED', id);
  }
}
export const duelsService = new DuelsService();
