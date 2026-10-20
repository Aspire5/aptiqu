import { publicFailure } from '../../../security/public-error';
import { PublicError } from '../../../security/errors';
import { log, safeError } from '../../../observability/logger';
import { Response } from 'express';
import { z } from 'zod';
import { AuthenticatedRequest } from '../../../middleware/auth.middleware';
import { PvpError } from '../pvp.errors';
import { seasonKey, boundedInteger } from './ranked-cursor';
import { rankedQueryService } from './ranked-query.service';
const meSchema = z.object({ seasonId: seasonKey.optional(), fresh: z.enum(['0', '1']).optional() }).strict();
const boardSchema = z.object({ seasonId: seasonKey.optional(), limit: boundedInteger(25, 50), cursor: z.string().min(1).max(2048).optional() }).strict();
const seasonsSchema = z.object({ limit: boundedInteger(12, 24), before: seasonKey.optional() }).strict();
export async function rankedResponse(res: Response, action: () => Promise<unknown>) {
  res.setHeader('Cache-Control', 'private, no-store');
  try { res.status(200).json({ success: true, data: await action() }); }
  catch (error) {
    if(error instanceof PvpError || error instanceof PublicError || error instanceof z.ZodError)publicFailure(res,error);
    else {log('error','ranked.read_unavailable',safeError(error));publicFailure(res,new PvpError('Ranked temporarily unavailable. Retry shortly.','RANKED_UNAVAILABLE',503,5));}
  }
}
export function rankedOwner(req: AuthenticatedRequest) {
  if (!req.userId) throw new PvpError('Authentication required.', 'UNAUTHORIZED', 401);
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
