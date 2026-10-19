import { createHash } from 'node:crypto';
import { z } from 'zod';
import { DEFAULT_RANKED_POLICY, validateRankedPolicy } from './ranked-policy';

const integer = z.number().int().safe();
export const persistedPolicySchema = z.object({
  initialRating: integer, provisionalMatches: integer.nonnegative(),
  provisionalK: integer.positive(), establishedK: integer.positive(),
  initialQualification: integer.positive(), seasonalQualification: integer.positive(),
  thresholds: z.object({ SILVER: integer, GOLD: integer, PLATINUM: integer, DIAMOND: integer }).strict(),
  rounding: z.literal('HALF_AWAY_FROM_ZERO'), reset: z.literal('CARRY'),
  roundMs: z.literal(60000), transitionMs: z.literal(3000), hardExpiryMs: integer.min(633000).max(3600000),
  systemFailure: z.literal('VOID_NO_REWARDS'), disconnect: z.literal('CONTINUE_TIMED_GAME'),
  repeatOpponents: z.literal('ORDINARY_ELO'),
}).strict().superRefine((policy, ctx) => {
  try { validateRankedPolicy(policy); }
  catch { ctx.addIssue({ code: 'custom', message: 'Invalid ranked policy.' }); }
});
export type PersistedRankedPolicy = z.infer<typeof persistedPolicySchema>;
// Approved in the Phase 2 conversation on 19 October 2026. New versions require
// a new ID/config; existing seasons always use their persisted, frozen policy.
export const RANKED_POLICY_ID = 'ranked-v1';
export const RANKED_POLICY = persistedPolicySchema.parse({
  ...DEFAULT_RANKED_POLICY, rounding: 'HALF_AWAY_FROM_ZERO', reset: 'CARRY',
  roundMs: 60000, transitionMs: 3000, hardExpiryMs: 900000,
  systemFailure: 'VOID_NO_REWARDS', disconnect: 'CONTINUE_TIMED_GAME', repeatOpponents: 'ORDINARY_ELO',
});
export function canonicalJson(value: unknown): string {
  if (value === undefined) return 'null';
  if (Array.isArray(value)) return `[${value.map(canonicalJson).join(',')}]`;
  if (value !== null && typeof value === 'object') return `{${Object.entries(value).filter(([, v]) => v !== undefined).sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0)).map(([k, v]) => `${JSON.stringify(k)}:${canonicalJson(v)}`).join(',')}}`;
  return JSON.stringify(value);
}
export function digest(value: unknown): string { return createHash('sha256').update(canonicalJson(value)).digest('hex'); }
export interface RankedActivation { enabled: boolean; launchSeason?: string }
export function rankedActivation(): RankedActivation {
  return { enabled: process.env.RANKED_ADMISSION_ENABLED === 'true', launchSeason: process.env.RANKED_LAUNCH_SEASON };
}

export function readPersistedPolicy(row: { config: unknown; configHash: string; approvedAt: Date | null }): PersistedRankedPolicy {
  if (!row.approvedAt || digest(row.config) !== row.configHash) throw new Error('Invalid persisted ranked policy.');
  return persistedPolicySchema.parse(row.config);
}
