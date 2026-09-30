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
router.post('/sessions/:sessionId/answer', PracticeController.submitAnswer);
router.post('/sessions/:sessionId/abandon', PracticeController.abandonSession);
router.post('/replay/:sessionId', PracticeController.replaySession);

export default router;
