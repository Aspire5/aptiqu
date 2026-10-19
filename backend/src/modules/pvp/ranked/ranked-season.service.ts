import { Prisma, PrismaClient, RankedPlayerSeason } from '@prisma/client';
import { PvpError } from '../pvp.errors';
import { digest, PersistedRankedPolicy, readPersistedPolicy, RANKED_POLICY, RANKED_POLICY_ID, RankedActivation, rankedActivation } from './ranked-config';
import { qualificationRequired } from './ranked-policy';
import { seasonAt, seasonBounds } from './ranked-season-time';
import { databaseNow, rankedTransaction } from './ranked-transaction';

export class RankedSeasonService {
  constructor(private readonly db: PrismaClient, private readonly activation: () => RankedActivation = rankedActivation) {}

  async ensureCalendar(tx: Prisma.TransactionClient, now: Date) {
    const activation = this.activation();
    if (!activation.enabled) return;
    if (!activation.launchSeason) throw new Error('RANKED_LAUNCH_SEASON is required for rated admission.');
    const launch = seasonBounds(activation.launchSeason);
    const current = seasonAt(now);
    if (launch.startsAt > current.startsAt) return;
    // One transaction-scoped lock serializes policy/calendar creation, never a
    // session lock on a pooled connection. No OS/process/session TZ changes.
    await tx.$queryRaw`SELECT 1::int AS locked FROM (SELECT pg_advisory_xact_lock(7240192601::bigint)) AS ranked_calendar_lock`;
    const policy = await tx.rankedPolicy.findUnique({ where: { id: RANKED_POLICY_ID } }) ?? await tx.rankedPolicy.create({ data: {
      id: RANKED_POLICY_ID, eloVersion: 'elo-integer-v1', leagueVersion: 'league-v1', outcomeVersion: 'score-time-v1',
      config: RANKED_POLICY, configHash: digest(RANKED_POLICY), approvedAt: now,
    } });
    if (!policy.approvedAt || policy.configHash !== digest(RANKED_POLICY) || digest(policy.config) !== policy.configHash) throw new Error('Ranked policy mismatch; create a new policy version.');
    const end = seasonAt(seasonAt(current.endsAt).endsAt).endsAt;
    const existing = new Map((await tx.rankedSeason.findMany({ where: { id: { gte: launch.id }, startsAt: { lt: end } } })).map(s => [s.id, s]));
    let next = launch;
    let count = 0;
    while (next.startsAt < end) {
      if (++count > 1200) throw new Error('Ranked calendar catch-up exceeds supported range.');
      const row = existing.get(next.id) ?? await tx.rankedSeason.create({ data: { ...next, policyId: policy.id } });
      if (row.timezone !== next.timezone || +row.startsAt !== +next.startsAt || +row.endsAt !== +next.endsAt) throw new Error('Stored season boundaries do not match the IST calendar.');
      next = seasonAt(next.endsAt);
    }
  }

  /** Caller holds both user locks; capture admission AFTER season lock waits. */
  async admit(tx: Prisma.TransactionClient, users: string[]) {
    let now = await databaseNow(tx);
    const activation = this.activation();
    if (!activation.enabled) return { ratingMode: 'LEGACY_UNRATED' as const, admittedAt: now };
    if (!activation.launchSeason) throw new Error('RANKED_LAUNCH_SEASON is required for rated admission.');
    if (!await tx.rankedSeason.findUnique({ where: { id: seasonAt(now).id } })) await this.ensureCalendar(tx, now);
    const launch = seasonBounds(activation.launchSeason);
    if (now < launch.startsAt) return { ratingMode: 'LEGACY_UNRATED' as const, admittedAt: now };
    for (let attempt = 0; attempt < 3; attempt++) {
      const interval = seasonAt(now);
      await tx.$queryRaw`SELECT id FROM learning.ranked_seasons WHERE id=${interval.id} FOR SHARE`;
      now = await databaseNow(tx);
      if (seasonAt(now).id !== interval.id) continue;
      const season = await tx.rankedSeason.findUniqueOrThrow({ where: { id: interval.id }, include: { policy: true } });
      if (season.settlementState !== 'OPEN' || !season.policy.approvedAt) throw new PvpError('Season unavailable.', 'SEASON_UNAVAILABLE');
      const policy = this.readPolicy(season.policy);
      for (const userId of [...users].sort()) await this.ensureStanding(tx, userId, season.id, policy);
      return { ratingMode: 'RATED' as const, seasonId: season.id, seasonAssignedAt: now, admittedAt: now, policy };
    }
    throw new PvpError('Season boundary changed. Please retry.', 'SEASON_RETRY');
  }

  readPolicy(row: { config: Prisma.JsonValue; configHash: string; approvedAt: Date | null }): PersistedRankedPolicy {
    return readPersistedPolicy(row);
  }

  private async ensureStanding(tx: Prisma.TransactionClient, userId: string, seasonId: string, policy: PersistedRankedPolicy): Promise<RankedPlayerSeason> {
    const existing = await tx.rankedPlayerSeason.findUnique({ where: { seasonId_userId: { seasonId, userId } } });
    if (existing) return existing;
    const previous = await tx.rankedPlayerSeason.findFirst({ where: { userId, seasonId: { lt: seasonId } }, orderBy: { seasonId: 'desc' } });
    const rating = previous?.rating ?? policy.initialRating;
    const career = previous ? previous.careerRatedBefore + previous.played : 0;
    return tx.rankedPlayerSeason.create({ data: {
      seasonId, userId, seedSourceSeasonId: previous?.seasonId, seedRating: rating, rating, peakRating: rating,
      careerRatedBefore: career, placementsRequired: qualificationRequired(career, policy),
    } });
  }

  async maintain() {
    const now = await rankedTransaction(this.db, async tx => { const now = await databaseNow(tx); await this.ensureCalendar(tx, now); return now; });
    const seasons = await this.db.rankedSeason.findMany({ where: { settlementState: { not: 'FINALIZED' }, endsAt: { lte: now } }, select: { id: true }, orderBy: { id: 'asc' }, take: 24 });
    for (const season of seasons) await this.finalize(season.id);
  }

  async finalize(seasonId: string): Promise<boolean> {
    return rankedTransaction(this.db, async tx => {
      await tx.$queryRaw`SELECT id FROM learning.ranked_seasons WHERE id=${seasonId} FOR UPDATE`;
      const season = await tx.rankedSeason.findUniqueOrThrow({ where: { id: seasonId }, include: { policy: true } });
      if (season.settlementState === 'FINALIZED') return true;
      const now = await databaseNow(tx);
      if (now < season.endsAt) return false;
      // Every assigned match must have committed its terminal outcome AND header.
      if (await tx.pvpMatch.count({ where: { seasonId, OR: [{ status: { notIn: ['COMPLETED', 'CANCELLED'] } }, { settlement: null }] } })) return false;
      const policy = this.readPolicy(season.policy);
      await tx.rankedSeason.update({ where: { id: seasonId }, data: { settlementState: 'FINALIZING' } });
      // A set-based, deterministic ordinal; final positions have no live API yet.
      await tx.$executeRaw`WITH positions AS (
        SELECT user_id, row_number() OVER (ORDER BY rating DESC, user_id ASC)::integer AS position
        FROM learning.ranked_player_seasons WHERE season_id=${seasonId} AND qualified_at IS NOT NULL
      ) UPDATE learning.ranked_player_seasons p SET final_position=positions.position
        FROM positions WHERE p.season_id=${seasonId} AND p.user_id=positions.user_id`;
      // Numeric league bands are pinned to this season's policy, not today's.
      await tx.$executeRaw`UPDATE learning.ranked_player_seasons SET
        final_rating=rating, final_peak_rating=qualified_peak_rating,
        final_league=(CASE WHEN qualified_at IS NULL THEN 'UNRANKED'
          WHEN rating>=${policy.thresholds.DIAMOND} THEN 'DIAMOND' WHEN rating>=${policy.thresholds.PLATINUM} THEN 'PLATINUM'
          WHEN rating>=${policy.thresholds.GOLD} THEN 'GOLD' WHEN rating>=${policy.thresholds.SILVER} THEN 'SILVER' ELSE 'BRONZE' END)::learning."RankedLeague",
        finalized_at=${now}, updated_at=${now} WHERE season_id=${seasonId}`;
      const eligibleCount = await tx.rankedPlayerSeason.count({ where: { seasonId, qualifiedAt: { not: null } } });
      await tx.rankedSeason.update({ where: { id: seasonId }, data: { settlementState: 'FINALIZED', finalizedAt: now, eligibleCount } });
      return true;
    });
  }
}
