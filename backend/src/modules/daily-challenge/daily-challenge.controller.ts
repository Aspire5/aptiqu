import { z } from 'zod';
import { publicFailure } from '../../security/public-error';
import { Response } from 'express';
import { AuthenticatedRequest } from '../../middleware/auth.middleware';
import { dailyChallengeService } from './daily-challenge.service';

export class DailyChallengeController {
  /**
   * GET /api/v1/daily-challenge/status
   * Returns due status, user streak, tier, question breakdown, and today's summary if done.
   */
  public static async getStatus(req: AuthenticatedRequest, res: Response) {
    const userId = req.userId;
    if (!userId) {
      res.status(401).json({ success: false, message: 'Unauthorized' });
      return;
    }

    try {
      const status = await dailyChallengeService.getStatus(userId);
      res.status(200).json({
        success: true,
        data: status,
      });
    } catch (err: any) {
      publicFailure(res, err);
    }
  }

  /**
   * POST /api/v1/daily-challenge/start
   * Lazily generates/fetches today's tier script, creates participation, returns sanitized questions.
   */
  public static async startChallenge(req: AuthenticatedRequest, res: Response) {
    const userId = req.userId;
    if (!userId) {
      res.status(401).json({ success: false, message: 'Unauthorized' });
      return;
    }

    try {
      const challenge = await dailyChallengeService.startDailyChallenge(userId);
      res.status(200).json({
        success: true,
        data: challenge,
      });
    } catch (err: any) {
      publicFailure(res, err);
    }
  }

  /**
   * POST /api/v1/daily-challenge/answer
   * Submits an answer for a question in today's daily challenge.
   */
  public static async submitAnswer(req: AuthenticatedRequest, res: Response) {
    const userId = req.userId;
    if (!userId) {
      res.status(401).json({ success: false, message: 'Unauthorized' });
      return;
    }

    const { participationId, questionId, selectedOptionId } = req.body;

    if (!z.object({participationId:z.string().uuid(),questionId:z.string().uuid(),selectedOptionId:z.string().min(1).max(64)}).safeParse(req.body).success) {
      res.status(400).json({
        success: false,
        message: 'participationId, questionId, and selectedOptionId are required.',
      });
      return;
    }

    try {
      const result = await dailyChallengeService.submitAnswer({
        userId,
        participationId,
        questionId,
        selectedOptionId,
        receivedAt: res.locals.receivedAt ?? new Date(),
      });

      res.status(200).json({
        success: true,
        data: result,
      });
    } catch (err: any) {
      publicFailure(res, err);
    }
  }

  /**
   * GET /api/v1/daily-challenge/history
   * Returns paginated daily challenge attempts and streak statistics.
   */
  public static async getHistory(req: AuthenticatedRequest, res: Response) {
    const userId = req.userId;
    if (!userId) {
      res.status(401).json({ success: false, message: 'Unauthorized' });
      return;
    }

    const page = Math.max(1, Math.min(100000,parseInt(req.query.page as string, 10) || 1));
    const limit = Math.max(1,Math.min(50,parseInt(req.query.limit as string, 10) || 10));

    try {
      const history = await dailyChallengeService.getHistory(userId, page, limit);
      res.status(200).json({
        success: true,
        data: history,
      });
    } catch (err: any) {
      publicFailure(res, err);
    }
  }
}
