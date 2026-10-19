import { seasonBounds } from './ranked-season-time';
export interface RankedRuntime { reads: boolean; skillMatchmaking: boolean; drain?: boolean }
export function rankedRuntime(): RankedRuntime {
  return { reads: process.env.RANKED_LEAGUES_READ_ENABLED === 'true', skillMatchmaking: process.env.RANKED_SKILL_MATCHMAKING_ENABLED === 'true', drain: process.env.RANKED_ADMISSION_DRAIN === 'true' };
}

export function ratedAdmissionAvailable(now: Date, runtime: RankedRuntime, activation: import('./ranked-config').RankedActivation) {
  if (!activation.enabled || !activation.launchSeason || !runtime.reads || !runtime.skillMatchmaking || runtime.drain) return false;
  try { return now >= seasonBounds(activation.launchSeason).startsAt; } catch { return false; }
}
