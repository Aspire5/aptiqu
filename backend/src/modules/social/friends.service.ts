import { Prisma } from '@prisma/client';
import { prisma } from '../../config/prisma';
import { HomeService } from '../home/home.service';
import { dateKey } from '../home/home.metrics';
import { XpPolicy } from '../xp/xp.policy';
import { socialError, socialTransport } from './social.transport';
export function friendPair(a: string, b: string) {
  a = a.toLowerCase(); b = b.toLowerCase();
  if (a === b) throw socialError('You cannot add or invite yourself.');
  return a < b ? { lowId: a, highId: b } : { lowId: b, highId: a };
}
export async function lockUsers(tx: Prisma.TransactionClient, ids: string[]) {
  await tx.$queryRaw(Prisma.sql`SELECT id FROM auth.users WHERE id IN (${Prisma.join([...new Set(ids)].sort().map(id => Prisma.sql`${id}::uuid`))}) ORDER BY id FOR UPDATE`);
}
export const publicUserSelect = { id: true, profile: { select: { firstName: true, lastName: true, avatarUrl: true } },
  progress: { select: { totalXp: true } }, gameStats: { select: { highestStreak: true, streak: true, lastDailyDate: true, coins: true } } };
export function publicUser(user: any) {
  const xp = Number(user.progress?.totalXp ?? 0);
  return { id: user.id, name: [user.profile?.firstName, user.profile?.lastName].filter(Boolean).join(' ') || 'Learner',
    avatarUrl: user.profile?.avatarUrl || null, totalXp: xp, level: XpPolicy.getLevelFromXp(xp),
    highestStreak: user.gameStats?.highestStreak ?? 0,
    currentStreak: [dateKey(new Date()),dateKey(new Date(Date.now()-86400000))].includes(user.gameStats?.lastDailyDate) ? user.gameStats?.streak ?? 0 : 0,
    coins: user.gameStats?.coins ?? 0, ...XpPolicy.getLevelProgress(xp) };
}
export const membership = (user: string) => ({ OR: [{ lowId: user }, { highId: user }] });
export class FriendsService {
  async list(user: string, cursor?: string, search = '') {
    const rows = await prisma.friendship.findMany({ where: { ...membership(user), status: 'ACCEPTED',
      ...(search ? { OR: [{ lowId: user, high: { profile: { searchName: { startsWith: search } } } },
        { highId: user, low: { profile: { searchName: { startsWith: search } } } }] } : {}) },
      orderBy: { id: 'asc' }, take: 51, ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
      include: { low: { select: publicUserSelect }, high: { select: publicUserSelect } } });
    const items = rows.slice(0, 50).map(r => ({ ...publicUser(r.lowId === user ? r.high : r.low), friendshipId: r.id, relation: 'FRIEND' }));
    const online = await socialTransport.presence(items.map(r => r.id));
    return { items: items.map((r, i) => ({ ...r, online: online[i].online })), nextCursor: rows.length > 50 ? items.at(-1)?.friendshipId : null };
  }
  async search(user: string, query: string, cursor?: string) {
    await socialTransport.limit(user, 'search', 60, 60);
    const rows = await prisma.user.findMany({ where: { id: { not: user }, isRegistrationComplete: true,
      profile: { searchName: { startsWith: query } } }, orderBy: { id: 'asc' }, take: 21,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}), select: publicUserSelect });
    const relations = await prisma.friendship.findMany({ where: { ...membership(user), OR: rows.length ?
      [{ lowId: { in: rows.map(r => r.id) }, highId: user }, { highId: { in: rows.map(r => r.id) }, lowId: user }] : [{ id: '00000000-0000-0000-0000-000000000000' }] } });
    const items = rows.slice(0, 20).map(r => {
      const link = relations.find(f => f.lowId === r.id || f.highId === r.id);
      return { ...publicUser(r), friendshipId: link?.id, relation: link?.status === 'ACCEPTED' ? 'FRIEND'
        : link?.status === 'PENDING' ? link.senderId === user ? 'INVITED' : 'INCOMING' : 'NONE' };
    });
    return { items, nextCursor: rows.length > 20 ? items.at(-1)?.id : null };
  }
  async profile(user: string, target: string) {
    const found = await prisma.user.findFirst({ where: { id: target, isRegistrationComplete: true }, select: publicUserSelect });
    if (!found) throw socialError('Learner not found.', 404);
    const relation = user === target ? null : await prisma.friendship.findUnique({ where: { lowId_highId: friendPair(user, target) } });
    const home = await new HomeService().getHome(target);
    return { ...publicUser(found), online: (await socialTransport.presence([target]))[0].online,
      friendshipId: relation?.id, friendshipVersion: relation?.updatedAt.toISOString(), relation: relation?.status === 'ACCEPTED' ? 'FRIEND' : relation?.status === 'PENDING'
        ? relation.senderId === user ? 'INVITED' : 'INCOMING' : 'NONE',
      performance: home.performance, difficulty: home.difficulty, activity: home.activity, badges: home.badges, ranked: home.ranked };
  }
  async invite(user: string, target: string) {
    const pair = friendPair(user, target);
    await socialTransport.limit(user, 'friend-invite', 30, 3600);
    const result = await prisma.$transaction(async tx => {
      await lockUsers(tx, [user, target]);
      const other = await tx.user.findFirst({ where: { id: target, isRegistrationComplete: true } });
      if (!other) throw socialError('Learner not found.', 404);
      const existing = await tx.friendship.findUnique({ where: { lowId_highId: pair } });
      if (existing?.status === 'ACCEPTED' || existing?.status === 'PENDING') return existing;
      if (await tx.friendship.count({ where: { ...membership(user), status:'PENDING', senderId:user } }) >= 100) throw socialError('Resolve your pending invitations before sending more.', 429);
      if (await tx.friendship.count({ where: { ...membership(target), status:'PENDING', senderId:{not:target} } }) >= 200) throw socialError('This learner has too many pending invitations. Please try later.', 429);
      if (existing?.status === 'REJECTED' && Date.now() - existing.updatedAt.getTime() < 86400000) throw socialError('Please wait before inviting this learner again.', 429);
      return tx.friendship.upsert({ where: { lowId_highId: pair }, create: { ...pair, senderId: user },
        update: { senderId: user, status: 'PENDING' } });
    });
    await socialTransport.notify([user, target], 'INBOX_CHANGED'); return { id: result.id, relation: result.status === 'ACCEPTED' ? 'FRIEND' : result.senderId === user ? 'INVITED' : 'INCOMING' };
  }
  async respond(user: string, id: string, accept: boolean, version: string) {
    const link = await prisma.friendship.findUnique({ where: { id } });
    if (!link || ![link.lowId, link.highId].includes(user) || link.senderId === user) throw socialError('Invitation not found.', 404);
    await prisma.$transaction(async tx => {
      await lockUsers(tx, [link.lowId, link.highId]);
      if (accept) {
        for (const member of [link.lowId, link.highId]) {
          if (await tx.friendship.count({ where: { ...membership(member), status: 'ACCEPTED' } }) >= 1000) throw socialError('The friend limit has been reached.', 409);
        }
      }
      const changed = await tx.friendship.updateMany({ where: { id, status: 'PENDING', updatedAt: new Date(version) }, data: { status: accept ? 'ACCEPTED' : 'REJECTED' } });
      if (!changed.count) throw socialError('This invitation was already handled.', 409);
    });
    await socialTransport.notify([link.lowId, link.highId], 'INBOX_CHANGED');
  }
  async remove(user: string, target: string) {
    const pair = friendPair(user, target);
    await prisma.$transaction(async tx => {
      await lockUsers(tx, [user, target]);
      await tx.friendship.updateMany({ where: { ...pair }, data: { status: 'REMOVED' } });
      const pending = await tx.friendlyDuel.findMany({ where: { requesterId: { in: [user, target] }, recipientId: { in: [user, target] }, status: 'PENDING' }, select: { id: true } });
      await tx.friendlyDuel.updateMany({ where: { id: { in: pending.map(d => d.id) }, status: 'PENDING' }, data: { status: 'CANCELLED' } });
      await tx.friendlyDuelSeat.deleteMany({ where: { duelId: { in: pending.map(d => d.id) } } });
    });
    await socialTransport.notify([user, target], 'INBOX_CHANGED');
  }
}
export const friendsService = new FriendsService();
