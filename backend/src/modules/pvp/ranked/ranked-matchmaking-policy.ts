import { readRankedConfig } from '../../../config/runtime-config';
import { z } from 'zod';
const policySchema = z.object({ narrowWindow: z.number().int().min(1).max(400), narrowMs: z.literal(60000),
  expandEveryMs: z.number().int().min(5000).max(60000), expandBy: z.number().int().min(1).max(200),
  maximumWindow: z.number().int().min(100).max(1600), queueLeaseMs: z.literal(45000), claimLeaseMs: z.literal(120000),
}).refine(p => p.maximumWindow >= p.narrowWindow);
export type MatchmakingPolicy = z.infer<typeof policySchema>;
export const DEFAULT_MATCHMAKING_POLICY: MatchmakingPolicy = {
  narrowWindow: 100, narrowMs: 60000, expandEveryMs: 15000, expandBy: 50, maximumWindow: 600, queueLeaseMs: 45000, claimLeaseMs: 120000,
};
export function matchmakingPolicy(): MatchmakingPolicy {
  const config=readRankedConfig();
  return policySchema.parse({...DEFAULT_MATCHMAKING_POLICY,narrowWindow:config.narrowWindow,maximumWindow:config.maximumWindow,expandEveryMs:config.expandEveryMs,expandBy:config.expandBy});
}
export function ratingWindow(waitMs: number, p: MatchmakingPolicy = DEFAULT_MATCHMAKING_POLICY): number {
  if (!Number.isFinite(waitMs)) throw new RangeError('Invalid queue time.');
  return waitMs < p.narrowMs ? p.narrowWindow : Math.min(p.maximumWindow, p.narrowWindow + (1 + Math.floor((waitMs - p.narrowMs) / p.expandEveryMs)) * p.expandBy);
}
export interface QueueCandidate {
  userId: string; rating: number; standingVersion: number; seasonId: string; policyId: string | null;
  ratingMode: 'RATED' | 'LEGACY_UNRATED'; capability: number; league: import('./ranked-policy').League;
  recentOpponentId?: string; recentOpponentUntil?: number;
}
export interface QueueEntry extends QueueCandidate { token: string; joinedAt: number; expiresAt: number; state: 'QUEUED' | 'CLAIMED'; claimId?: string }
export interface QueueClaim { id: string; a: QueueEntry; b: QueueEntry }
export function candidatesCompatible(a: QueueEntry, b: QueueEntry, now: number, p = DEFAULT_MATCHMAKING_POLICY): boolean {
  return a.userId !== b.userId && a.ratingMode === b.ratingMode && a.seasonId === b.seasonId && a.policyId === b.policyId
    && a.state === 'QUEUED' && b.state === 'QUEUED' && a.expiresAt > now && b.expiresAt > now
    && Math.abs(a.rating - b.rating) <= Math.min(ratingWindow(now - a.joinedAt, p), ratingWindow(now - b.joinedAt, p));
}
