import { publicFailure } from '../../security/public-error';
import { Response } from 'express';
import { AuthenticatedRequest } from '../../middleware/auth.middleware';
import { practiceSessionService } from './services/practice-session.service';
import { referenceCatalog } from '../ai/luna/references';
import { preparationStatus, cancelPreparation } from '../ai/luna/preparations';

export class PracticeController {
  /**
   * GET /api/v1/practice/topics/live
   * Returns only LIVE topics and subtopics for practice selection.
   */
  // CACHE_CANDIDATE ref=C01 scope=catalog layer=redis ttl=30-60s owner=curriculum
  public static async getLiveTopics(_req: AuthenticatedRequest, res: Response) {
    try {
      const liveUniverse = await referenceCatalog();
      res.status(200).json({
        success: true,
        data: liveUniverse,
      });
    } catch (err: any) {
      publicFailure(res, err);
    }
  }

  /**
   * POST /api/v1/practice/sessions
   * Enqueues ten fresh questions and immediately returns a durable preparation handle.
   */
  public static async createSession(req: AuthenticatedRequest, res: Response) {
    const userId = req.userId;
    if (!userId) {
      res.status(401).json({ success: false, message: 'Unauthorized' });
      return;
    }

    const { topicId, subtopicIds, smartPicks = false } = req.body;
    if ((topicId !== undefined && typeof topicId !== 'string') ||
        (subtopicIds !== undefined && (!Array.isArray(subtopicIds) || !subtopicIds.length || subtopicIds.length > 500 || subtopicIds.some((id: unknown) => typeof id !== 'string'))) ||
        typeof smartPicks !== 'boolean') {
      res.status(400).json({ success: false, message: 'Invalid practice selection.' });
      return;
    }
    // Both specific selection and random drill modes are supported
    const resolvedSubtopics = Array.isArray(subtopicIds) ? subtopicIds : undefined;


    try {
      const requestKey = req.get('Idempotency-Key');
      if (requestKey && !/^[a-zA-Z0-9_-]{16,100}$/.test(requestKey)) {
        res.status(400).json({ success:false, message:'Invalid request key.' }); return;
      }
      const session = await practiceSessionService.createSession(userId, topicId, resolvedSubtopics, smartPicks, requestKey);
      res.status(202).json({
        success: true,
        data: session,
      });
    } catch (err: any) {
      publicFailure(res, err);
    }
  }

  public static async preparation(req: AuthenticatedRequest,res:Response) {
    try {
      const status=await preparationStatus(req.userId!,req.params.id as string|undefined);
      res.json({success:true,data:status});
    } catch(error){publicFailure(res,error);}
  }
  public static async cancelPreparation(req: AuthenticatedRequest,res:Response) {
    try {res.json({success:true,data:await cancelPreparation(req.userId!,req.params.id as string)});}
    catch(error){publicFailure(res,error);}
  }

  /**
   * GET /api/v1/practice/sessions/:sessionId
   * Retrieves active session state with safe question masking.
   */
  public static async getSession(req: AuthenticatedRequest, res: Response) {
    const userId = req.userId;
    const sessionId = req.params.sessionId as string;

    if (!userId) {
      res.status(401).json({ success: false, message: 'Unauthorized' });
      return;
    }

    try {
      const session = await practiceSessionService.getSession(sessionId, userId);
      res.status(200).json({
        success: true,
        data: session,
      });
    } catch (err: any) {
      publicFailure(res, err);
    }
  }

  /**
   * POST /api/v1/practice/sessions/:sessionId/answer
   * Submits an answer and awards XP upon full session completion.
   */
  public static async submitAnswer(req: AuthenticatedRequest, res: Response) {
    const userId = req.userId;
    const sessionId = req.params.sessionId as string;
    const { questionId, selectedOptionId, responseTimeMs } = req.body;

    if (!userId) {
      res.status(401).json({ success: false, message: 'Unauthorized' });
      return;
    }

    if (typeof questionId !== 'string' || typeof selectedOptionId !== 'string' || !questionId || !selectedOptionId) {
      res.status(400).json({
        success: false,
        message: 'Payload must contain "questionId" and "selectedOptionId".',
      });
      return;
    }

    try {
      const result = await practiceSessionService.submitAnswer({
        sessionId,
        userId,
        questionId,
        selectedOptionId,
        responseTimeMs: typeof responseTimeMs === 'number' ? responseTimeMs : 30000,
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
   * POST /api/v1/practice/sessions/:sessionId/abandon
   * Abandons session early without awarding completion XP.
   */
  public static async abandonSession(req: AuthenticatedRequest, res: Response) {
    const userId = req.userId;
    const sessionId = req.params.sessionId as string;

    if (!userId) {
      res.status(401).json({ success: false, message: 'Unauthorized' });
      return;
    }

    try {
      const result = await practiceSessionService.abandonSession(sessionId, userId);
      res.status(200).json({
        success: true,
        data: result,
      });
    } catch (err: any) {
      publicFailure(res, err);
    }
  }

  /**
   * GET /api/v1/practice/history
   * Retrieves paginated practice drill history including replays.
   */
  public static async getHistory(req: AuthenticatedRequest, res: Response) {
    const userId = req.userId;
    if (!userId) {
      res.status(401).json({ success: false, message: 'Unauthorized' });
      return;
    }

    const page = Math.max(1, parseInt(req.query.page as string, 10) || 1);
    const limit = Math.min(50, Math.max(1, parseInt(req.query.limit as string, 10) || 10));

    try {
      const history = await practiceSessionService.getHistory(userId, page, limit);
      res.status(200).json({
        success: true,
        data: history,
      });
    } catch (err: any) {
      publicFailure(res, err);
    }
  }

  /**
   * POST /api/v1/practice/replay/:sessionId
   * Starts a replay of a past practice drill with 0 rewards.
   */
  public static async replaySession(req: AuthenticatedRequest, res: Response) {
    const userId = req.userId;
    const sessionId = req.params.sessionId as string;

    if (!userId) {
      res.status(401).json({ success: false, message: 'Unauthorized' });
      return;
    }

    try {
      const session = await practiceSessionService.replayPracticeSession(userId, sessionId);
      res.status(201).json({
        success: true,
        data: session,
      });
    } catch (err: any) {
      publicFailure(res, err);
    }
  }
}

