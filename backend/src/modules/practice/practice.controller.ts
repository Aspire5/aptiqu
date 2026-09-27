import { Response } from 'express';
import { AuthenticatedRequest } from '../../middleware/auth.middleware';
import { practiceSessionService } from './services/practice-session.service';
import { LiveCurriculumService } from '../curriculum/services/live-curriculum.service';

export class PracticeController {
  /**
   * GET /api/v1/practice/topics/live
   * Returns only LIVE topics and subtopics for practice selection.
   */
  public static async getLiveTopics(_req: AuthenticatedRequest, res: Response) {
    try {
      const liveUniverse = await LiveCurriculumService.getAllLiveCurriculumUniverse();
      res.status(200).json({
        success: true,
        data: liveUniverse,
      });
    } catch (err: any) {
      res.status(500).json({
        success: false,
        message: err.message || 'Failed to retrieve live practice topics.',
      });
    }
  }

  /**
   * POST /api/v1/practice/sessions
   * Creates an active 10-Question Practice Session.
   */
  public static async createSession(req: AuthenticatedRequest, res: Response) {
    const userId = req.userId;
    if (!userId) {
      res.status(401).json({ success: false, message: 'Unauthorized' });
      return;
    }

    const { topicId, subtopicIds } = req.body;
    if (!topicId || !Array.isArray(subtopicIds) || subtopicIds.length === 0) {
      res.status(400).json({
        success: false,
        message: 'Invalid payload. "topicId" and non-empty "subtopicIds" array are required.',
      });
      return;
    }

    try {
      const session = await practiceSessionService.createSession(userId, topicId, subtopicIds);
      res.status(201).json({
        success: true,
        data: session,
      });
    } catch (err: any) {
      res.status(400).json({
        success: false,
        message: err.message || 'Failed to create practice session.',
      });
    }
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
      res.status(404).json({
        success: false,
        message: err.message || 'Practice session not found.',
      });
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

    if (!questionId || !selectedOptionId) {
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
      res.status(400).json({
        success: false,
        message: err.message || 'Failed to submit practice answer.',
      });
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
      res.status(400).json({
        success: false,
        message: err.message || 'Failed to abandon practice session.',
      });
    }
  }
}
