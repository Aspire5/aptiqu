// Pure policy defaults, approved for Phase 2 v1. Persisted versions and activation
// are owned by ranked-config/season services; this module has no side effects.
export interface RankedPolicy {
  initialRating: number;
  provisionalMatches: number;
  provisionalK: number;
  establishedK: number;
  initialQualification: number;
  seasonalQualification: number;
  thresholds: Readonly<{ SILVER: number; GOLD: number; PLATINUM: number; DIAMOND: number }>;
}

export const DEFAULT_RANKED_POLICY: Readonly<RankedPolicy> = Object.freeze({
  initialRating: 1200,
  provisionalMatches: 20,
  provisionalK: 64,
  establishedK: 32,
  initialQualification: 10,
  seasonalQualification: 3,
  thresholds: Object.freeze({ SILVER: 1000, GOLD: 1200, PLATINUM: 1450, DIAMOND: 1700 }),
});

export type League = 'UNRANKED' | 'BRONZE' | 'SILVER' | 'GOLD' | 'PLATINUM' | 'DIAMOND';
const LEAGUES: readonly League[] = ['UNRANKED', 'BRONZE', 'SILVER', 'GOLD', 'PLATINUM', 'DIAMOND'];

export function nonnegativeCount(value: number): void {
  if (!Number.isSafeInteger(value) || value < 0) throw new RangeError('Invalid match count.');
}

export function validateRankedPolicy(policy: RankedPolicy): void {
  if (!Number.isSafeInteger(policy.initialRating)) throw new RangeError('Invalid initial rating.');
  nonnegativeCount(policy.provisionalMatches);
  for (const value of [policy.provisionalK, policy.establishedK, policy.initialQualification, policy.seasonalQualification]) {
    if (!Number.isSafeInteger(value) || value <= 0) throw new RangeError('Policy counts and K must be positive integers.');
  }
  const limits = [policy.thresholds.SILVER, policy.thresholds.GOLD, policy.thresholds.PLATINUM, policy.thresholds.DIAMOND];
  if (limits.some((value, i) => !Number.isSafeInteger(value) || (i > 0 && value <= limits[i - 1]))) {
    throw new RangeError('League thresholds must be strictly increasing integers.');
  }
}

export function qualificationRequired(careerBeforeSeason: number, policy = DEFAULT_RANKED_POLICY): number {
  nonnegativeCount(careerBeforeSeason);
  validateRankedPolicy(policy);
  return Math.max(policy.seasonalQualification, policy.initialQualification - careerBeforeSeason);
}

export function qualificationProgress(played: number, required: number) {
  nonnegativeCount(played);
  if (!Number.isSafeInteger(required) || required <= 0) throw new RangeError('Invalid qualification target.');
  return { completed: Math.min(played, required), required, remaining: Math.max(0, required - played), qualified: played >= required };
}

export function resolveLeague(rating: number, qualified: boolean, policy = DEFAULT_RANKED_POLICY): League {
  if (!Number.isSafeInteger(rating)) throw new RangeError('Rating must be an integer.');
  validateRankedPolicy(policy);
  if (!qualified) return 'UNRANKED';
  const t = policy.thresholds;
  if (rating >= t.DIAMOND) return 'DIAMOND';
  if (rating >= t.PLATINUM) return 'PLATINUM';
  if (rating >= t.GOLD) return 'GOLD';
  if (rating >= t.SILVER) return 'SILVER';
  return 'BRONZE';
}

export function classifyLeagueTransition(before: League, after: League) {
  if (before === after) return 'NONE';
  if (after === 'UNRANKED') return 'NONE'; // Seasonal requalification is not a competitive demotion.
  if (before === 'UNRANKED') return 'PLACEMENT_COMPLETE';
  return LEAGUES.indexOf(after) > LEAGUES.indexOf(before) ? 'PROMOTION' : 'DEMOTION';
}
