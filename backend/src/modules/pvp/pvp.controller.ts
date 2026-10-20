import { publicFailure } from '../../security/public-error';
import { Response } from 'express';
import { AuthenticatedRequest } from '../../middleware/auth.middleware';
import { pvpMatchService } from './services/pvp-match.service';
import { rankedHistoryService } from './ranked/ranked-history.service';
import { rankedResponse, rankedOwner } from './ranked/ranked.controller';
import { seasonKey, boundedInteger } from './ranked/ranked-cursor';
import { z } from 'zod';
import { PvpError } from './pvp.errors';

export class PvpController {
  /**
   * GET /api/v1/pvp/matches/:matchId
   */
  public static async getMatch(req: AuthenticatedRequest, res: Response) {
    const matchId = req.params.matchId as string;
    const userId = req.userId;

    try {
      if (!userId) throw new PvpError('Unauthorized.', 'UNAUTHORIZED', 401);
      if (!z.string().uuid().safeParse(matchId).success) throw new PvpError('Invalid match ID.', 'INVALID_MATCH_ID', 400);
      const match = await pvpMatchService.getMatchSnapshot(matchId, userId);
      res.setHeader('Cache-Control', 'private, no-store');
      res.status(200).json({ success: true, data: match });
    } catch (err: any) { publicFailure(res,err); }
  }

  /**
   * GET /api/v1/pvp/history
   * Retrieves paginated actual PvP match history with opponent details, score comparison, and stats.
   */
  public static async getPlayerHistory(req: AuthenticatedRequest, res: Response) {
    return rankedResponse(res, () => {
      const userId = rankedOwner(req);
      const query = z.object({ page: boundedInteger(1, 1000),
        limit: boundedInteger(10, 50), seasonId: seasonKey.optional(),
        includeVoids: z.enum(['0','1']).optional(),
      }).strict().refine(q => (q.page - 1) * q.limit <= 10000, 'History offset exceeds limit.').parse(req.query);
      return rankedHistoryService.history(userId, { ...query, includeVoids: query.includeVoids === '1' });
    });
  }

  /**
   * POST /api/v1/pvp/replay/:matchId
   * Replays a PvP match's question set as a solo Practice drill (untimed, no opponent, 0 XP).
   * Note: The session is created as a PracticeSession, so its log will be recorded in Practice logs!
   */
  public static async replayMatch(req: AuthenticatedRequest, res: Response) {
    const userId = req.userId;
    const matchId = req.params.matchId as string;

    if (!userId) {
      res.status(401).json({ success: false, message: 'Unauthorized' });
      return;
    }

    try {
      if (!z.string().uuid().safeParse(matchId).success) throw new PvpError('Invalid match ID.', 'INVALID_MATCH_ID', 400);
      const { practiceSessionService } = await import(
        '../practice/services/practice-session.service'
      );
      const practiceSession = await practiceSessionService.replayPvpMatch(userId, matchId);

      res.status(201).json({
        success: true,
        data: practiceSession,
      });
    } catch (err: unknown) { publicFailure(res,err); }
  }
}

