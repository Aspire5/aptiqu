import { Prisma } from '@prisma/client';
import type { PvpInternalMatch } from '../pvp.dto';
import { PvpError } from '../pvp.errors';
import { digest } from './ranked-config';
import { calculateEloMatch } from './ranked-rating';
import { classifyLeagueTransition, qualificationProgress, resolveLeague } from './ranked-policy';
import { RankedSeasonService } from './ranked-season.service';

/** Runs ONLY in the existing outcome/XP transaction. The caller holds users in
 * UUID order, then the match. Lock season -> standings -> XP progress afterward. */
export async function prepareRatingSettlement(tx: Prisma.TransactionClient, match: PvpInternalMatch, winnerId: string | null, now: Date, seasons: RankedSeasonService) {
  if (match.ratingMode !== 'RATED') return null;
  if (!match.seasonId || match.players.length !== 2) throw new PvpError('Invalid rated match.', 'INVALID_MATCH_STATE');
  await tx.$queryRaw`SELECT id FROM learning.ranked_seasons WHERE id=${match.seasonId} FOR SHARE`;
  const season = await tx.rankedSeason.findUniqueOrThrow({ where: { id: match.seasonId }, include: { policy: true } });
  if (season.settlementState !== 'OPEN') throw new Error('A finalized season cannot receive results.');
  const policy = seasons.readPolicy(season.policy);
  const users = match.players.map(p => p.userId).sort();
  await tx.$queryRaw`SELECT user_id FROM learning.ranked_player_seasons WHERE season_id=${season.id} AND user_id IN (${Prisma.join(users.map(id => Prisma.sql`${id}::uuid`))}) ORDER BY user_id FOR UPDATE`;
  const rows = await Promise.all(users.map(userId => tx.rankedPlayerSeason.findUniqueOrThrow({ where: { seasonId_userId: { seasonId: season.id, userId } } })));
  if (rows.some(p => p.finalizedAt)) throw new Error('Standing is already archived.');
  const [a, b] = rows;
  const elo = calculateEloMatch(
    { rating: a.rating, careerRatedMatches: a.careerRatedBefore + a.played },
    { rating: b.rating, careerRatedMatches: b.careerRatedBefore + b.played },
    winnerId === null ? 'DRAW' : winnerId === a.userId ? 'WIN' : 'LOSS', policy,
  );
  const changes = rows.map((row, index) => {
    const result = index === 0 ? elo.a : elo.b;
    const played = row.played + 1;
    const qualified = played >= row.placementsRequired;
    const leagueBefore = resolveLeague(row.rating, row.qualifiedAt !== null, policy);
    const leagueAfter = resolveLeague(result.after, qualified, policy);
    const changeKind = classifyLeagueTransition(leagueBefore, leagueAfter);
    const qualifiedPeakRating = qualified ? Math.max(row.qualifiedPeakRating ?? result.after, result.after) : null;
    return { row, result, played, qualifiedAt: row.qualifiedAt ?? (qualified ? now : null), qualifiedPeakRating, leagueBefore, leagueAfter, changeKind,
      public: { userId: row.userId, seasonId: season.id, before: result.before, delta: result.delta, after: result.after,
        leagueBefore, leagueAfter, changeKind, qualification: qualificationProgress(played, row.placementsRequired), version: row.version + 1 } };
  });
  return { season, changes };
}

export async function commitSettlement(tx: Prisma.TransactionClient, match: PvpInternalMatch, now: Date,
  outcome: { winnerId: string | null; isTie: boolean; reason: string; xp: { userId: string; awarded: number; total: number }[] },
  rating: Awaited<ReturnType<typeof prepareRatingSettlement>>, disposition: 'RATED' | 'VOID' | 'LEGACY_UNRATED') {
  const snapshot = { schemaVersion: 1, matchId: match.id, seasonId: match.seasonId ?? null, disposition,
    winnerId: outcome.winnerId, isTie: outcome.isTie, reason: outcome.reason, xp: outcome.xp,
    ratings: rating?.changes.map(c => c.public) ?? [] };
  await tx.rankedMatchSettlement.create({ data: {
    matchId: match.id, seasonId: match.seasonId, policyId: rating?.season.policyId ?? (match.seasonId ? (await tx.rankedSeason.findUniqueOrThrow({ where: { id: match.seasonId } })).policyId : null),
    disposition, outcomeHash: digest({ snapshot, answers: match.answers.map(a => ({ userId: a.userId, questionIndex: a.questionIndex,
      selectedOptionId: a.selectedOptionId, isCorrect: a.isCorrect, responseTimeMs: a.responseTimeMs, isLate: a.isLate, serverReceivedAt: a.serverReceivedAt?.toISOString() ?? null })).sort((a, b) => a.userId.localeCompare(b.userId) || a.questionIndex - b.questionIndex), questions: match.questionSnapshot ?? null }),
    resultSnapshot: snapshot, settledAt: now,
  } });
  if (disposition !== 'RATED') {
    if (rating) throw new Error('Only rated settlements may change Elo.');
    return;
  }
  if (!rating || rating.changes.length !== 2) throw new Error('A rated result needs two changes.');
  for (let i = 0; i < rating.changes.length; i++) {
    const change = rating.changes[i];
    const { row, result } = change;
    await tx.rankedRatingChange.create({ data: {
      matchId: match.id, userId: row.userId, seasonId: row.seasonId, opponentId: rating.changes[1 - i].row.userId,
      ratingBefore: result.before, opponentRatingBefore: rating.changes[1 - i].result.before, delta: result.delta, ratingAfter: result.after,
      score: result.score, expectedScore: result.expected, kFactor: result.k,
      careerCountBefore: row.careerRatedBefore + row.played, seasonVersionAfter: row.version + 1,
      leagueBefore: change.leagueBefore, leagueAfter: change.leagueAfter, changeKind: change.changeKind, createdAt: now,
    } });
    await tx.rankedPlayerSeason.update({ where: { seasonId_userId: { seasonId: row.seasonId, userId: row.userId } }, data: {
      rating: result.after, peakRating: Math.max(row.peakRating, result.after), qualifiedPeakRating: change.qualifiedPeakRating,
      qualifiedAt: change.qualifiedAt, played: change.played, wins: row.wins + (result.score === 1 ? 1 : 0),
      losses: row.losses + (result.score === 0 ? 1 : 0), draws: row.draws + (result.score === .5 ? 1 : 0),
      version: row.version + 1, lastMatchId: match.id, lastPlayedAt: now,
    } });
  }
}
