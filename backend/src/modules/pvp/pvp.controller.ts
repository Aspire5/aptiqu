import { Response } from 'express';
import { AuthenticatedRequest } from '../../middleware/auth.middleware';
import { pvpMatchService } from './services/pvp-match.service';
import { prisma } from '../../config/prisma';

export class PvpController {
  /**
   * GET /api/v1/pvp/matches/:matchId
   */
  public static async getMatch(req: AuthenticatedRequest, res: Response) {
    const matchId = req.params.matchId as string;
    const userId = req.userId;

    try {
      const match = await pvpMatchService.getMatchDetails(matchId);
      const isParticipant = match.players?.some((p: any) => p.userId === userId);
      if (!isParticipant) {
        res.status(403).json({
          success: false,
          message: 'Access denied: You are not a participant in this match',
          code: 'FORBIDDEN_MATCH_ACCESS',
        });
        return;
      }
      res.status(200).json({ success: true, data: match });
    } catch (err: any) {
      res.status(404).json({
        success: false,
        message: err.message || 'Match not found',
        code: 'MATCH_NOT_FOUND',
      });
    }
  }

  /**
   * GET /api/v1/pvp/history
   * Retrieves paginated actual PvP match history with opponent details, score comparison, and stats.
   */
  public static async getPlayerHistory(req: AuthenticatedRequest, res: Response) {
    const userId = req.userId;
    if (!userId) {
      res.status(401).json({ success: false, message: 'Unauthorized' });
      return;
    }

    const page = parseInt(req.query.page as string, 10) || 1;
    const limit = parseInt(req.query.limit as string, 10) || 10;
    const skip = (page - 1) * limit;

    try {
      const [participations, totalCount] = await Promise.all([
        prisma.pvpMatchPlayer.findMany({
          where: {
            userId,
            match: { status: 'COMPLETED' },
          },
          include: {
            match: {
              include: {
                players: {
                  include: {
                    user: {
                      include: {
                        profile: true,
                        gameStats: true,
                      },
                    },
                  },
                },
              },
            },
          },
          orderBy: { joinedAt: 'desc' },
          skip,
          take: limit,
        }),
        prisma.pvpMatchPlayer.count({
          where: {
            userId,
            match: { status: 'COMPLETED' },
          },
        }),
      ]);

      const history = participations.map((p) => {
        const opponentPlayer = p.match.players.find((op) => op.userId !== userId);
        const opponentProfile = opponentPlayer?.user?.profile;
        const opponentStats = opponentPlayer?.user?.gameStats;

        const opponentName = opponentProfile
          ? `${opponentProfile.firstName} ${opponentProfile.lastName}`.trim()
          : 'Opponent';

        const avgResponseTimeMs =
          p.score > 0 || p.totalResponseTimeMs > 0
            ? Math.round(p.totalResponseTimeMs / p.match.totalQuestions)
            : 0;

        return {
          matchId: p.matchId,
          score: p.score,
          opponentScore: opponentPlayer?.score ?? 0,
          totalQuestions: p.match.totalQuestions,
          isWinner: p.isWinner,
          isTie: p.match.isTie,
          xpAwarded: p.xpAwarded,
          joinedAt: p.joinedAt,
          status: p.match.status,
          avgResponseTimeMs,
          opponent: {
            userId: opponentPlayer?.userId,
            name: opponentName,
            avatarUrl: opponentProfile?.avatarUrl,
            level: opponentStats?.level ?? 1,
          },
        };
      });

      res.status(200).json({
        success: true,
        data: {
          history,
          pagination: {
            page,
            limit,
            totalCount,
            totalPages: Math.ceil(totalCount / limit),
          },
        },
      });
    } catch (err: any) {
      res.status(500).json({ success: false, message: err.message });
    }
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
      const { practiceSessionService } = await import(
        '../practice/services/practice-session.service'
      );
      const practiceSession = await practiceSessionService.replayPvpMatch(userId, matchId);

      res.status(201).json({
        success: true,
        data: practiceSession,
      });
    } catch (err: any) {
      res.status(400).json({
        success: false,
        message: err.message || 'Failed to replay PvP match in practice mode.',
      });
    }
  }
}

