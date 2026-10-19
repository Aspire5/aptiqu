import type { RankedPlayerSeason, RankedSeason } from '@prisma/client';
import { qualificationProgress, qualificationRequired, resolveLeague } from './ranked-policy';
import { PersistedRankedPolicy } from './ranked-config';
import { SeasonInterval, seasonBounds } from './ranked-season-time';

export function seasonDto(season: Omit<SeasonInterval, 'timezone'> & Partial<RankedSeason>, now: Date) {
  const bounds = seasonBounds(season.id);
  if ((season.timezone && season.timezone !== 'Asia/Kolkata') || +season.startsAt !== +bounds.startsAt || +season.endsAt !== +bounds.endsAt) throw new Error('Invalid season calendar.');
  return { id: season.id, timezone: 'Asia/Kolkata', startsAt: season.startsAt.toISOString(), endsAt: season.endsAt.toISOString(),
    policyId: season.policyId ?? null, status: !season.policyId ? 'NOT_STARTED' : season.settlementState === 'FINALIZED' ? 'FINALIZED'
      : now < season.startsAt ? 'UPCOMING' : now >= season.endsAt ? 'CLOSING' : 'ACTIVE',
    finalizedAt: season.finalizedAt?.toISOString() ?? null, eligibleCount: season.eligibleCount ?? null };
}
export function nextLeague(rating: number, qualified: boolean, policy: PersistedRankedPolicy) {
  if (!qualified || rating >= policy.thresholds.DIAMOND) return null;
  const bands = Object.entries(policy.thresholds) as [keyof typeof policy.thresholds, number][];
  const index = bands.findIndex(([, threshold]) => rating < threshold);
  const [league, threshold] = bands[index];
  const lower = index === 0 ? null : bands[index - 1][1];
  return { league, rating: threshold, remaining: threshold - rating, progress: lower === null ? null : Math.max(0, Math.min(1, (rating - lower) / (threshold - lower))) };
}
export function standingDto(row: RankedPlayerSeason | null, policy: PersistedRankedPolicy,
  preview: { rating: number; career: number }, position: number | null, archived: boolean) {
  const rating = archived && row?.finalRating != null ? row.finalRating : row?.rating ?? preview.rating;
  const played = row?.played ?? 0;
  const placements = qualificationProgress(played, row?.placementsRequired ?? qualificationRequired(preview.career, policy));
  const career = (row?.careerRatedBefore ?? preview.career) + played;
  return { league: archived && row?.finalLeague ? row.finalLeague : resolveLeague(rating, placements.qualified, policy),
    rating, ratingIsProvisional: career < policy.provisionalMatches, position: placements.qualified ? position : null,
    positionKind: 'ORDINAL', qualified: placements.qualified, placements,
    played, wins: row?.wins ?? 0, losses: row?.losses ?? 0, draws: row?.draws ?? 0,
    peakRating: archived ? row?.finalPeakRating ?? null : row?.qualifiedPeakRating ?? null,
    version: row?.version ?? 0, hasRecord: row !== null, nextLeague: nextLeague(rating, placements.qualified, policy) };
}
