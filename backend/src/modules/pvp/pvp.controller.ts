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

    try {
      const match = await pvpMatchService.getMatchDetails(matchId);
      res.status(200).json({ success: true, data: match });
    } catch (err: any) {
      res.status(404).json({ success: false, message: err.message || 'Match not found' });
    }
  }

  /**
   * GET /api/v1/pvp/history
   */
  public static async getPlayerHistory(req: AuthenticatedRequest, res: Response) {
    const userId = req.userId;
    if (!userId) {
      res.status(401).json({ success: false, message: 'Unauthorized' });
      return;
    }

    try {
      const participations = await prisma.pvpMatchPlayer.findMany({
        where: { userId },
        include: {
          match: {
            include: {
              players: {
                include: { user: { include: { profile: true } } },
              },
            },
          },
        },
        orderBy: { joinedAt: 'desc' },
        take: 20,
      });

      res.status(200).json({
        success: true,
        data: participations.map((p) => ({
          matchId: p.matchId,
          score: p.score,
          isWinner: p.isWinner,
          xpAwarded: p.xpAwarded,
          joinedAt: p.joinedAt,
          status: p.match.status,
          opponent: p.match.players.find((op) => op.userId !== userId)?.user?.profile?.firstName || 'Opponent',
        })),
      });
    } catch (err: any) {
      res.status(500).json({ success: false, message: err.message });
    }
  }
}
