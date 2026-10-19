import { Response } from 'express';
import { z } from 'zod';
import { AuthenticatedRequest } from '../../../middleware/auth.middleware';
import { PvpError } from '../pvp.errors';
import { seasonKey, boundedInteger } from './ranked-cursor';
import { RankedRateLimit } from './ranked-rate-limit';
import { rankedQueryService } from './ranked-query.service';
const meSchema = z.object({ seasonId: seasonKey.optional(), fresh: z.enum(['0', '1']).optional() }).strict();
const boardSchema = z.object({ seasonId: seasonKey.optional(), limit: boundedInteger(25, 50), cursor: z.string().min(1).max(2048).optional() }).strict();
const seasonsSchema = z.object({ limit: boundedInteger(12, 24), before: seasonKey.optional() }).strict();
export async function rankedResponse(res: Response, action: () => Promise<unknown>) {
  res.setHeader('Cache-Control', 'private, no-store');
  try { res.status(200).json({ success: true, data: await action() }); }
  catch (error) {
    const validation = error instanceof z.ZodError;
    const status = error instanceof PvpError ? error.status : validation ? 400 : 503;
    if (status === 503 || status === 429) res.setHeader('Retry-After', String(error instanceof PvpError ? error.retryAfterSeconds ?? 5 : 5));
    res.status(status).json({ success: false, code: error instanceof PvpError ? error.code : validation ? 'INVALID_QUERY' : 'RANKED_UNAVAILABLE',
      message: error instanceof PvpError ? error.message : validation ? 'Invalid Ranked query.' : 'Ranked temporarily unavailable. Please retry.' });
  }
}
const readBudget = new RankedRateLimit(60, 60000);
export function rankedOwner(req: AuthenticatedRequest) {
  if (!req.userId) throw new PvpError('Authentication required.', 'UNAUTHORIZED', 401);
  readBudget.take(req.userId);
  return req.userId;
}
export class RankedController {
  static me(req: AuthenticatedRequest, res: Response) { return rankedResponse(res, () => {
    const userId = rankedOwner(req), query = meSchema.parse(req.query);
    return rankedQueryService.me(userId, { seasonId: query.seasonId, fresh: query.fresh === '1' });
  }); }
  static leaderboard(req: AuthenticatedRequest, res: Response) { return rankedResponse(res, () => rankedQueryService.leaderboard(rankedOwner(req), boardSchema.parse(req.query))); }
  static seasons(req: AuthenticatedRequest, res: Response) { return rankedResponse(res, () => rankedQueryService.seasons(rankedOwner(req), seasonsSchema.parse(req.query))); }
}
