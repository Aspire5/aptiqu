import { PrismaClient } from '@prisma/client';
import { prisma } from '../../../config/prisma';
import { PvpError } from '../pvp.errors';
import { rankedQueryService } from './ranked-query.service';
import { databaseNow } from './ranked-transaction';
export class RankedHistoryService {
  constructor(private readonly db: PrismaClient = prisma, private readonly registered: (userId: string) => Promise<void> = userId => rankedQueryService.assertRegistered(userId)) {}
  async history(userId: string, options: { page: number; limit: number; seasonId?: string; includeVoids?: boolean }) {
    await this.registered(userId);
    return this.db.$transaction(async tx => {
      const now = await databaseNow(tx);
      if (options.seasonId && !await tx.rankedSeason.findUnique({ where: { id: options.seasonId }, select: { id: true } })) throw new PvpError('Season not found.', 'SEASON_NOT_FOUND', 404);
      const match = { ...(options.seasonId ? { seasonId: options.seasonId } : {}), OR: [
        { status: 'COMPLETED' as const }, ...(options.includeVoids ? [{ status: 'CANCELLED' as const, outcomeReason: 'SYSTEM_VOID' }] : []),
      ] };
      const where = { userId, match };
      const rows = await tx.pvpMatchPlayer.findMany({ where, include: {
        ratingChanges: { select: { id: true, ratingBefore: true, delta: true, ratingAfter: true, leagueBefore: true, leagueAfter: true, changeKind: true, seasonVersionAfter: true } },
        match: { select: { status: true, totalQuestions: true, isTie: true, seasonId: true, ratingMode: true, outcomeReason: true,
          settlement: { select: { disposition: true, settledAt: true } }, players: { select: { userId: true, score: true, user: { select: {
            profile: { select: { firstName: true, lastName: true, avatarUrl: true } }, gameStats: { select: { level: true } },
          } } } } } },
      }, orderBy: [{ joinedAt: 'desc' }, { id: 'desc' }], skip: (options.page - 1) * options.limit, take: options.limit });
      const totalCount = await tx.pvpMatchPlayer.count({ where });
      const history = rows.map(p => {
        const opponent = p.match.players.find(op => op.userId !== userId);
        const profile = opponent?.user.profile;
        const change = p.ratingChanges[0];
        const disposition = p.match.settlement?.disposition ?? (p.match.ratingMode === 'RATED' ? 'PENDING' : 'LEGACY_UNRATED');
        return { matchId: p.matchId, score: p.score, opponentScore: opponent?.score ?? 0, totalQuestions: p.match.totalQuestions,
          isWinner: p.isWinner, isTie: p.match.isTie, xpAwarded: p.xpAwarded, joinedAt: p.joinedAt, status: p.match.status,
          avgResponseTimeMs: Math.round(p.totalResponseTimeMs / Math.max(1, p.match.totalQuestions)), seasonId: p.match.seasonId,
          disposition, outcomeReason: p.match.outcomeReason, settledAt: p.match.settlement?.settledAt ?? null,
          rating: change && disposition === 'RATED' ? { eventId: change.id, before: change.ratingBefore, delta: change.delta, after: change.ratingAfter,
            leagueBefore: change.leagueBefore, leagueAfter: change.leagueAfter, changeKind: change.changeKind, seasonVersionAfter: change.seasonVersionAfter } : null,
          opponent: { userId: opponent?.userId, name: [profile?.firstName, profile?.lastName].filter(Boolean).join(' ') || 'Opponent', avatarUrl: profile?.avatarUrl ?? null, level: opponent?.user.gameStats?.level ?? 1 } };
      });
      return { serverNow: now.toISOString(), asOf: now.toISOString(), timezone: 'Asia/Kolkata', history,
        pagination: { page: options.page, limit: options.limit, totalCount, totalPages: Math.ceil(totalCount / options.limit) } };
    }, { isolationLevel: 'RepeatableRead' });
  }
}
export const rankedHistoryService = new RankedHistoryService();
