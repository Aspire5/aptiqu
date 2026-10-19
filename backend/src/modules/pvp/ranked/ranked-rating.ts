import { DEFAULT_RANKED_POLICY, nonnegativeCount, RankedPolicy, validateRankedPolicy } from './ranked-policy';

export type EloOutcome = 'WIN' | 'LOSS' | 'DRAW';
export interface EloPlayer { rating: number; careerRatedMatches: number }

export function roundHalfAwayFromZero(value: number): number {
  if (!Number.isFinite(value)) throw new RangeError('Cannot round a nonfinite value.');
  // Round the nonnegative magnitude: adding 0.5 first can round an adjacent
  // representable value below 0.5 up to 1 before floor sees it.
  const result = Math.sign(value) * Math.round(Math.abs(value));
  return result === 0 ? 0 : result;
}

export function expectedScore(rating: number, opponentRating: number): number {
  if (!Number.isSafeInteger(rating) || !Number.isSafeInteger(opponentRating)) throw new RangeError('Ratings must be integers.');
  return 1 / (1 + 10 ** ((opponentRating - rating) / 400));
}

export function calculateEloMatch(a: EloPlayer, b: EloPlayer, outcomeA: EloOutcome, policy: Readonly<RankedPolicy> = DEFAULT_RANKED_POLICY) {
  validateRankedPolicy(policy);
  nonnegativeCount(a.careerRatedMatches);
  nonnegativeCount(b.careerRatedMatches);
  const scoreA = outcomeA === 'WIN' ? 1 : outcomeA === 'LOSS' ? 0 : outcomeA === 'DRAW' ? 0.5 : NaN;
  if (!Number.isFinite(scoreA)) throw new RangeError('Invalid Elo outcome.');
  const expectedA = expectedScore(a.rating, b.rating);
  const expectedB = 1 - expectedA;
  const kA = a.careerRatedMatches < policy.provisionalMatches ? policy.provisionalK : policy.establishedK;
  const kB = b.careerRatedMatches < policy.provisionalMatches ? policy.provisionalK : policy.establishedK;
  const deltaA = roundHalfAwayFromZero(kA * (scoreA - expectedA));
  // Same K conserves the pair exactly. Mixed K deliberately permits provisional transfers.
  const deltaB = kA === kB ? (deltaA === 0 ? 0 : -deltaA) : roundHalfAwayFromZero(kB * ((1 - scoreA) - expectedB));
  if (!Number.isSafeInteger(a.rating + deltaA) || !Number.isSafeInteger(b.rating + deltaB)) throw new RangeError('Rating exceeds integer precision.');
  return {
    a: { before: a.rating, expected: expectedA, score: scoreA, k: kA, delta: deltaA, after: a.rating + deltaA },
    b: { before: b.rating, expected: expectedB, score: 1 - scoreA, k: kB, delta: deltaB, after: b.rating + deltaB },
  };
}
