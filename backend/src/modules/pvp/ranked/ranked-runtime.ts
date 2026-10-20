import { readRankedConfig } from '../../../config/runtime-config';
import { seasonBounds } from './ranked-season-time';
export interface RankedRuntime { reads: boolean; skillMatchmaking: boolean; drain?: boolean }
export function rankedRuntime(): RankedRuntime {
  const config=readRankedConfig(); return {reads:config.reads,skillMatchmaking:config.skill,drain:config.drain};
}

export function ratedAdmissionAvailable(now: Date, runtime: RankedRuntime, activation: import('./ranked-config').RankedActivation) {
  if (!activation.enabled || !activation.launchSeason || !runtime.reads || !runtime.skillMatchmaking || runtime.drain) return false;
  try { return now >= seasonBounds(activation.launchSeason).startsAt; } catch { return false; }
}
