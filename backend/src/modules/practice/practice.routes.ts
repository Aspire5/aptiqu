import { practiceSessionService } from './services/practice-session.service';
import { AuthenticatedRequest } from '../../middleware/auth.middleware';
import { z } from 'zod';
import { Router } from 'express';
import { authenticateJwt } from '../../middleware/auth.middleware';
import { PracticeController } from './practice.controller';

const router = Router();

// All Practice routes require authentication
router.use(authenticateJwt);

router.get('/topics/live', PracticeController.getLiveTopics);
router.get('/history', PracticeController.getHistory);
router.post('/sessions', PracticeController.createSession);
router.get('/sessions/:sessionId', PracticeController.getSession);
router.post('/sessions/:sessionId/start-question', async (req: AuthenticatedRequest, res, next) => {
  try {
    const id = z.string().uuid().parse(req.params.sessionId);
    res.json({ success: true, data: await practiceSessionService.startFriendlyQuestion(id, req.userId!) });
  } catch (error) { next(error); }
});
router.post('/sessions/:sessionId/answer' , PracticeController.submitAnswer);
router.post('/sessions/:sessionId/abandon', PracticeController.abandonSession);
router.post('/replay/:sessionId', PracticeController.replaySession);

export default router;
