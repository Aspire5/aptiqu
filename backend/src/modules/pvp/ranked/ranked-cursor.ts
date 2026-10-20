import { readRankedConfig } from '../../../config/runtime-config';
import { createHmac, timingSafeEqual } from 'node:crypto';
import { z } from 'zod';
import { PvpError } from '../pvp.errors';
import { seasonBounds } from './ranked-season-time';

export const seasonKey = z.string().regex(/^\d{4}-(0[1-9]|1[0-2])$/).refine(value => { try { seasonBounds(value); return true; } catch { return false; } });
const payloadSchema = z.object({
  v: z.literal(1), kind: z.literal('RANKED_BOARD'), mode: z.enum(['LIVE', 'FINAL']),
  seasonId: seasonKey, policyId: z.string().min(1).max(64), rating: z.number().int().min(-2147483648).max(2147483647),
  userId: z.string().uuid(), positionAtIssue: z.number().int().positive(), issuedAt: z.number().int().nonnegative(),
}).strict();
export type BoardCursor = z.infer<typeof payloadSchema>;
export class RankedCursor {
  constructor(private readonly secret: () => string = () => readRankedConfig().secret) {}
  private sign(encoded: string) {
    const secret = this.secret();
    if (secret.length < 32) throw new PvpError('Leaderboard temporarily unavailable.', 'CURSOR_CONFIGURATION', 503);
    return createHmac('sha256', secret).update(`aptiqu:ranked:cursor:v1:${encoded}`).digest('base64url');
  }
  ready() { this.sign('configuration-check'); }
  encode(value: BoardCursor): string {
    const encoded = Buffer.from(JSON.stringify(payloadSchema.parse(value))).toString('base64url');
    return `${encoded}.${this.sign(encoded)}`;
  }
  decode(value: string, seasonId: string, policyId: string, mode: BoardCursor['mode'], now: Date): BoardCursor {
    try {
      if (value.length > 2048 || !/^[\w-]+\.[\w-]+$/.test(value)) throw new Error();
      const [encoded, signature] = value.split('.');
      const expected = Buffer.from(this.sign(encoded));
      const actual = Buffer.from(signature);
      if (expected.length !== actual.length || !timingSafeEqual(expected, actual)) throw new Error();
      if (Buffer.from(encoded, 'base64url').toString('base64url') !== encoded) throw new Error();
      const cursor = payloadSchema.parse(JSON.parse(Buffer.from(encoded, 'base64url').toString('utf8')));
      if (cursor.seasonId !== seasonId || cursor.policyId !== policyId || cursor.mode !== mode || cursor.issuedAt > +now || +now - cursor.issuedAt > 300000) throw new Error();
      return cursor;
    } catch (error) {
      if (error instanceof PvpError && error.status === 503) throw error;
      throw new PvpError('Leaderboard changed or cursor expired. Refresh the leaderboard.', 'CURSOR_RESET', 400);
    }
  }
}

export function boundedInteger(fallback: number, maximum: number) {
  return z.preprocess(value => typeof value === 'string' && /^\d+$/.test(value) ? Number(value) : value,
    z.number().int().min(1).max(maximum).default(fallback));
}
