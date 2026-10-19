import { Prisma, PrismaClient, RankedPlayerSeason } from '@prisma/client';
import { prisma } from '../../../config/prisma';
import { PvpError } from '../pvp.errors';
import { RANKED_POLICY, rankedActivation, readPersistedPolicy } from './ranked-config';
import { seasonAt } from './ranked-season-time';
import { databaseNow } from './ranked-transaction';
import { rankedRuntime, RankedRuntime, ratedAdmissionAvailable } from './ranked-runtime';
import { RankedCursor } from './ranked-cursor';
import { RankedReadCache, rankedReadCache } from './ranked-cache';
import { seasonDto, standingDto } from './ranked-contract';
import { resolveLeague } from './ranked-policy';
import { leaderboardQuery } from './ranked-queries';

export class RankedQueryService {
  constructor(private readonly db: PrismaClient = prisma, private readonly runtime: () => RankedRuntime = rankedRuntime,
    private readonly cache: RankedReadCache = rankedReadCache, private readonly cursors = new RankedCursor()) {}
  private enabled() {
    if (!this.runtime().reads) throw new PvpError('Ranked leagues are not available yet.', 'RANKED_DISABLED', 503);
  }
  async assertRegistered(userId: string, tx: Prisma.TransactionClient = this.db) {
    const user = await tx.user.findUnique({ where: { id: userId }, select: { isRegistrationComplete: true } });
    if (!user) throw new PvpError('Authentication required.', 'UNAUTHORIZED', 401);
    if (!user.isRegistrationComplete) throw new PvpError('Complete registration to use Ranked.', 'REGISTRATION_REQUIRED', 403);
  }
  private async context(tx: Prisma.TransactionClient, seasonId?: string) {
    const now = await databaseNow(tx);
    const current = seasonAt(now);
    const id = seasonId ?? current.id;
    const stored = await tx.rankedSeason.findUnique({ where: { id }, include: { policy: true } });
    if (!stored && seasonId) throw new PvpError('Season not found.', 'SEASON_NOT_FOUND', 404);
    const policy = stored ? readPersistedPolicy(stored.policy) : RANKED_POLICY;
    return { now, current, stored, policy, season: seasonDto(stored ?? current, now) };
  }
  private async activeMatch(tx: Prisma.TransactionClient, userId: string) {
    const seat = await tx.pvpMatchPlayer.findFirst({ where: { userId, match: { OR: [
      { status: { in: ['STARTING', 'IN_PROGRESS', 'QUESTION_ACTIVE', 'QUESTION_TRANSITION'] } },
      { ratingMode: 'RATED', settlement: null },
    ] } }, orderBy: { joinedAt: 'desc' }, select: { match: { select: { id: true, seasonId: true, status: true, stateVersion: true } } } });
    return seat ? { matchId: seat.match.id, seasonId: seat.match.seasonId, status: seat.match.status,
      stateVersion: seat.match.stateVersion, recoveryState: ['COMPLETED', 'CANCELLED'].includes(seat.match.status) ? 'RESULT_PENDING' : 'RESUMABLE' } : null;
  }
  private async preview(tx: Prisma.TransactionClient, userId: string, seasonId: string, initialRating: number) {
    const previous = await tx.rankedPlayerSeason.findFirst({ where: { userId, seasonId: { lt: seasonId } }, orderBy: { seasonId: 'desc' } });
    return { rating: previous?.rating ?? initialRating, career: previous ? previous.careerRatedBefore + previous.played : 0 };
  }
  async me(userId: string, options: { seasonId?: string; fresh?: boolean } = {}) {
    this.enabled();
    await this.assertRegistered(userId);
    const load = () => this.db.$transaction(async tx => {
      const ctx = await this.context(tx, options.seasonId);
      const row = ctx.stored ? await tx.rankedPlayerSeason.findUnique({ where: { seasonId_userId: { seasonId: ctx.season.id, userId } } }) : null;
      const preview = row ? { rating: row.seedRating, career: row.careerRatedBefore } : await this.preview(tx, userId, ctx.season.id, ctx.policy.initialRating);
      const archived = ctx.stored?.settlementState === 'FINALIZED';
      const position = !row?.qualifiedAt ? null : archived ? row.finalPosition : 1 + await tx.rankedPlayerSeason.count({ where: {
        seasonId: ctx.season.id, qualifiedAt: { not: null }, OR: [{ rating: { gt: row.rating } }, { rating: row.rating, userId: { lt: userId } }],
      } });
      const activeMatch = await this.activeMatch(tx, userId);
      const last = await tx.rankedPlayerSeason.findFirst({ where: { userId, finalizedAt: { not: null }, played: { gt: 0 } }, orderBy: { seasonId: 'desc' } });
      const standing = standingDto(row, ctx.policy, preview, position, archived);
      return { serverNow: ctx.now.toISOString(), asOf: ctx.now.toISOString(), timezone: 'Asia/Kolkata', currentSeasonId: ctx.current.id,
        season: ctx.season, activeMatch, seedPending: !row && activeMatch !== null,
        capabilities: { reads: true, skillMatchmaking: this.runtime().skillMatchmaking,
          admissionPaused: this.runtime().drain ?? false,
          ratedAdmission: ratedAdmissionAvailable(ctx.now, this.runtime(), rankedActivation()) && ctx.season.status === 'ACTIVE' },
        standing: { ...standing, positionAsOf: position === null ? null : archived ? ctx.season.finalizedAt : ctx.now.toISOString() },
        lastFinalSeason: last ? { seasonId: last.seasonId, league: last.finalLeague, rating: last.finalRating, position: last.finalPosition, peakRating: last.finalPeakRating } : null };
    }, { isolationLevel: 'RepeatableRead' });
    return options.fresh ? load() : this.cache.get(`me:${userId}:${options.seasonId ?? 'current'}`, load,
      value => value.season.status === 'ACTIVE' ? Math.min(5000, Math.max(0, +new Date(value.season.endsAt) - +new Date(value.asOf))) : 5000);
  }
  async compact(userId: string) {
    try { return { status: 'AVAILABLE', ...await this.me(userId) }; }
    catch (error) { return { status: error instanceof PvpError && error.code === 'RANKED_DISABLED' ? 'DISABLED' : 'UNAVAILABLE', retryable: !(error instanceof PvpError && error.code === 'RANKED_DISABLED') }; }
  }
  async leaderboard(userId: string, options: { seasonId?: string; limit: number; cursor?: string }) {
    this.enabled();
    await this.assertRegistered(userId);
    this.cursors.ready();
    const load = () => this.db.$transaction(async tx => {
      const ctx = await this.context(tx, options.seasonId);
      const finalized = ctx.stored?.settlementState === 'FINALIZED';
      const cursor = options.cursor ? this.cursors.decode(options.cursor, ctx.season.id, ctx.season.policyId ?? '', finalized ? 'FINAL' : 'LIVE', ctx.now) : undefined;
      const rows = !ctx.stored ? [] : await tx.$queryRaw<{ userId: string; rating: number; position: number; firstName: string | null; lastName: string | null; avatarUrl: string | null }[]>(leaderboardQuery(ctx.season.id, options.limit, finalized, cursor));
      const entries = rows.slice(0, options.limit).map(row => ({ userId: row.userId, name: [row.firstName, row.lastName].filter(Boolean).join(' ') || 'Learner',
        avatarUrl: row.avatarUrl, rating: row.rating, league: resolveLeague(row.rating, true, ctx.policy), position: row.position }));
      const last = entries[entries.length - 1];
      const nextCursor = rows.length > options.limit && last && ctx.season.policyId ? this.cursors.encode({
        v: 1, kind: 'RANKED_BOARD', mode: finalized ? 'FINAL' : 'LIVE', seasonId: ctx.season.id, policyId: ctx.season.policyId,
        rating: last.rating, userId: last.userId, positionAtIssue: last.position, issuedAt: +ctx.now,
      }) : null;
      return { serverNow: ctx.now.toISOString(), asOf: ctx.now.toISOString(), timezone: 'Asia/Kolkata', season: ctx.season,
        entries, nextCursor, positionKind: 'ORDINAL', tieBreak: 'RATING_DESC_USER_ID_ASC', pagination: finalized ? 'FINALIZED_STABLE' : 'LIVE_MAY_MOVE' };
    }, { isolationLevel: 'RepeatableRead' });
    // Only identity-independent top pages are shared. Private summaries never enter this cache.
    return options.cursor ? load() : this.cache.get(`board:${options.seasonId ?? 'current'}:${options.limit}`, load,
      value => value.season.status === 'ACTIVE' ? Math.min(5000, Math.max(0, +new Date(value.season.endsAt) - +new Date(value.asOf))) : 5000);
  }
  async seasons(userId: string, options: { before?: string; limit: number }) {
    this.enabled();
    await this.assertRegistered(userId);
    return this.db.$transaction(async tx => {
      const ctx = await this.context(tx);
      const rows = await tx.rankedPlayerSeason.findMany({ where: { userId, played: { gt: 0 }, ...(options.before ? { seasonId: { lt: options.before } } : {}) },
        include: { season: { include: { policy: true } } }, orderBy: { seasonId: 'desc' }, take: options.limit + 1 });
      const entries = rows.slice(0, options.limit).map(row => {
        const archived = row.season.settlementState === 'FINALIZED';
        return { season: seasonDto(row.season, ctx.now), resultsFinalizing: +ctx.now >= +row.season.endsAt && !archived,
          standing: standingDto(row, readPersistedPolicy(row.season.policy), { rating: row.seedRating, career: row.careerRatedBefore }, archived ? row.finalPosition : null, archived) };
      });
      return { serverNow: ctx.now.toISOString(), asOf: ctx.now.toISOString(), timezone: 'Asia/Kolkata', currentSeason: ctx.season,
        entries, nextBefore: rows.length > options.limit ? entries[entries.length - 1].season.id : null };
    }, { isolationLevel: 'RepeatableRead' });
  }
}
export const rankedQueryService = new RankedQueryService();
