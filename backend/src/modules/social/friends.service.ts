import { friendSearchQuery } from './friend-search';
import { Prisma } from '@prisma/client';
import { prisma } from '../../config/prisma';
import { HomeService } from '../home/home.service';
import { dateKey } from '../home/home.metrics';
import { homeSubmissions } from '../home/home.queries';
import { XpPolicy } from '../xp/xp.policy';
import { socialError, socialTransport } from './social.transport';
export function friendPair(a: string, b: string) {
  a = a.toLowerCase(); b = b.toLowerCase();
  if (a === b) throw socialError('You cannot add or invite yourself.');
  return a < b ? { lowId: a, highId: b } : { lowId: b, highId: a };
}
export { lockUsers } from './user-lock';
import { lockUsers } from './user-lock';
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
    const items = rows.slice(0, 50).map(r => ({ ...publicUser(r.lowId === user ? r.high : r.low), friendshipId: r.id, friendsSince: r.updatedAt.toISOString(), relation: 'FRIEND' }));
    const online = await socialTransport.presence(items.map(r => r.id));
    return { items: items.map((r, i) => ({ ...r, online: online[i].online })), nextCursor: rows.length > 50 ? items.at(-1)?.friendshipId : null };
  }
  async search(user: string, query: string) {
    await socialTransport.limit(user, 'search', 60, 60);
    const matches = await prisma.$queryRaw<{id: string}[]>(friendSearchQuery(user, query));
    const ids = matches.map(r => r.id);
    if (!ids.length) return { items: [], nextCursor: null };
    const [rows, relations] = await prisma.$transaction([
      prisma.user.findMany({ where: { id: { in: ids }, isRegistrationComplete: true }, select: publicUserSelect }),
      prisma.friendship.findMany({ where: { OR: [
        { lowId: user, highId: { in: ids } }, { highId: user, lowId: { in: ids } } ] } }),
    ]);
    const byId = new Map(rows.map(r => [r.id, r]));
    const links = new Map(relations.map(r => [r.lowId === user ? r.highId : r.lowId, r]));
    const friends = relations.filter(r => r.status === 'ACCEPTED').map(r => r.lowId === user ? r.highId : r.lowId);
    const presence = new Map((await socialTransport.presence(friends)).map(r => [r.id, r.online]));
    const items = ids.filter(id => byId.has(id)).map(id => {
      const link = links.get(id);
      return { ...publicUser(byId.get(id)), friendshipId: link?.id, friendshipVersion: link?.updatedAt.toISOString(),
        friendsSince: link?.status === 'ACCEPTED' ? link.updatedAt.toISOString() : null,
        online: link?.status === 'ACCEPTED' ? presence.get(id) ?? null : null,
        relation: link?.status === 'ACCEPTED' ? 'FRIEND'
          : link?.status === 'PENDING' ? link.senderId === user ? 'INVITED' : 'INCOMING' : 'NONE' };
    });
    return { items, nextCursor: null };
  }
  async profile(user: string, target: string) {
    const found = await prisma.user.findFirst({ where: { id: target, isRegistrationComplete: true }, select: publicUserSelect });
    if (!found) throw socialError('Learner not found.', 404);
    const relation = user === target ? null : await prisma.friendship.findUnique({ where: { lowId_highId: friendPair(user, target) } });
    const home = await new HomeService().getHome(target);
    return { ...publicUser(found), online: (await socialTransport.presence([target]))[0].online,
      friendshipId: relation?.id, friendshipVersion: relation?.updatedAt.toISOString(), relation: relation?.status === 'ACCEPTED' ? 'FRIEND' : relation?.status === 'PENDING'
        ? relation.senderId === user ? 'INVITED' : 'INCOMING' : 'NONE',
      today: home.today, performance: home.performance, difficulty: home.difficulty,
      activity: home.activity.filter(day => day.date.startsWith(home.today.slice(0, 7))),
      badges: home.badges, ranked: home.ranked };
  }

  async activity(target: string, month: string) {
    const found = await prisma.user.findFirst({ where: { id: target, isRegistrationComplete: true }, select: { id: true } });
    if (!found) throw socialError('Learner not found.', 404);
    const start = `${month}-01`;
    const first = new Date(`${start}T00:00:00+05:30`);
    const [year, number] = month.split('-').map(Number);
    const nextMonth = number === 12 ? `${year + 1}-01` : `${year}-${String(number + 1).padStart(2, '0')}`;
    const next = new Date(`${nextMonth}-01T00:00:00+05:30`);
    const [rows, challenges] = await prisma.$transaction([
      prisma.$queryRaw<{ date: string; attempted: number; correct: number }[]>(Prisma.sql`
        WITH submissions AS (${homeSubmissions(target)})
        SELECT (happened_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Kolkata')::date::text AS date,
          count(*)::float8 AS attempted, sum(correct)::float8 AS correct
        FROM submissions
        WHERE happened_at >= ${first.toISOString()}::timestamp AND happened_at < ${next.toISOString()}::timestamp
        GROUP BY 1 ORDER BY 1`),
      prisma.dailyChallengeParticipation.findMany({ where: { userId: target, status: 'COMPLETED',
        dateString: { gte: start, lt: `${nextMonth}-01` } }, select: { dateString: true } }),
    ]);
    const byDate = new Map(rows.map(row => [row.date, row]));
    const completed = new Set(challenges.map(row => row.dateString));
    return { activity: Array.from({ length: new Date(Date.UTC(year, number, 0)).getUTCDate() }, (_, index) => {
      const date = `${month}-${String(index + 1).padStart(2, '0')}`;
      return { date, attempted: byDate.get(date)?.attempted ?? 0, correct: byDate.get(date)?.correct ?? 0,
        dailyChallengeCompleted: completed.has(date) };
    }) };
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
