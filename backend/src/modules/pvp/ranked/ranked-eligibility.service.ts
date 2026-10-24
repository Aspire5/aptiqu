import { Prisma, PrismaClient } from '@prisma/client';
import { prisma } from '../../../config/prisma';
import { PvpError } from '../pvp.errors';
import { databaseNow } from './ranked-transaction';
import { RankedActivation, rankedActivation, RANKED_POLICY, readPersistedPolicy } from './ranked-config';
import { RankedRuntime, rankedRuntime } from './ranked-runtime';
import { seasonAt, seasonBounds } from './ranked-season-time';
import { resolveLeague } from './ranked-policy';
import { QueueCandidate } from './ranked-matchmaking-policy';

export class RankedEligibilityService {
  constructor(private readonly db: PrismaClient = prisma, private readonly activation: () => RankedActivation = rankedActivation,
    private readonly runtime: () => RankedRuntime = rankedRuntime) {}
  async inspect(userId: string, capability = 0, tx?: Prisma.TransactionClient): Promise<QueueCandidate> {
    if (!tx) return this.db.$transaction(inner => this.inspect(userId, capability, inner), { isolationLevel: 'RepeatableRead' });
    if (this.runtime().drain) throw new PvpError('Ranked admission is paused.', 'ADMISSION_PAUSED', 503);
    const user = await tx.user.findUnique({ where: { id: userId }, select: { isRegistrationComplete: true } });
    if (!user) throw new PvpError('Authentication required.', 'UNAUTHORIZED', 401);
    if (!user.isRegistrationComplete) throw new PvpError('Complete registration to play Ranked.', 'REGISTRATION_REQUIRED', 403);
    if (await tx.friendlyDuelSeat.count({ where: { userId } })) throw new PvpError('Finish or cancel your friendly duel first.', 'FRIENDLY_DUEL_ACTIVE');
    if (await tx.questionPreparation.count({where:{userIds:{has:userId},mode:{in:['PRACTICE','FRIENDLY']},state:{in:['QUEUED','GENERATING','REVIEWING','REPAIRING','REREVIEWING','SAVING']},deadline:{gt:new Date()}}})) throw new PvpError('Finish preparing your questions first.','PREPARATION_ACTIVE');
    const active = await tx.pvpMatchPlayer.findFirst({ where: { userId, match: { OR: [
      { status: { in: ['STARTING','IN_PROGRESS','QUESTION_ACTIVE','QUESTION_TRANSITION'] } }, { ratingMode: 'RATED', settlement: null },
    ] } }, select: { matchId: true } });
    if (active) throw new PvpError('Resume your existing match or wait for its result.', 'MATCH_PENDING');
    const now = await databaseNow(tx), calendar = seasonAt(now), activation = this.activation();
    if (activation.enabled && (!activation.launchSeason || !this.runtime().skillMatchmaking || !this.runtime().reads)) throw new PvpError('Ranked admission is paused.', 'ADMISSION_PAUSED', 503);
    let rated = false;
    try { rated = activation.enabled && now >= seasonBounds(activation.launchSeason!).startsAt; }
    catch { throw new PvpError('Ranked admission is paused.', 'ADMISSION_PAUSED', 503); }
    if (rated && capability < 1) throw new PvpError('Update the app to enter rated matches.', 'RANKED_CLIENT_UPDATE_REQUIRED', 409);
    if (!rated) return { userId, rating: RANKED_POLICY.initialRating, standingVersion: 0, seasonId: calendar.id, policyId: null, ratingMode: 'LEGACY_UNRATED', capability, league: 'UNRANKED' };
    const season = await tx.rankedSeason.findUnique({ where: { id: calendar.id }, include: { policy: true } });
    if (!season || season.settlementState !== 'OPEN') throw new PvpError('Season is being prepared. Please retry.', 'SEASON_UNAVAILABLE', 503);
    const policy = readPersistedPolicy(season.policy);
    const row = await tx.rankedPlayerSeason.findUnique({ where: { seasonId_userId: { seasonId: calendar.id, userId } } });
    const previous = row ? null : await tx.rankedPlayerSeason.findFirst({ where: { userId, seasonId: { lt: calendar.id } }, orderBy: { seasonId: 'desc' } });
    const recent = await tx.pvpMatchPlayer.findFirst({ where: { userId, match: { status: 'COMPLETED', endedAt: { gte: new Date(+now - 300000) } } },
      orderBy: { joinedAt: 'desc' }, select: { match: { select: { endedAt: true, players: { select: { userId: true } } } } } });
    const opponent = recent?.match.players.find(p => p.userId !== userId);
    return { userId, rating: row?.rating ?? previous?.rating ?? policy.initialRating, standingVersion: row?.version ?? 0,
      seasonId: calendar.id, policyId: season.policyId, ratingMode: 'RATED', capability, league: resolveLeague(row?.rating ?? previous?.rating ?? policy.initialRating, row?.qualifiedAt != null, policy),
      ...(opponent && recent?.match.endedAt ? { recentOpponentId: opponent.userId, recentOpponentUntil: +recent.match.endedAt + 300000 } : {}) };
  }
  async validate(tx: Prisma.TransactionClient, expected: QueueCandidate) {
    const current = await this.inspect(expected.userId, expected.capability, tx);
    if (current.ratingMode !== expected.ratingMode || current.seasonId !== expected.seasonId || current.policyId !== expected.policyId
      || current.rating !== expected.rating || current.standingVersion !== expected.standingVersion) throw new PvpError('Ranked standing changed. Search again.', 'QUEUE_STALE');
  }
}
export const rankedEligibilityService = new RankedEligibilityService();
