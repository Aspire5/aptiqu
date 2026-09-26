import { Router } from 'express';
import { authenticateJwt } from '../../middleware/auth.middleware';
import { LessonController } from './lesson.controller';

const router = Router();

// All lesson routes require authentication
router.use(authenticateJwt);

router.get('/active', LessonController.getActiveSession);
router.post('/sessions', LessonController.startSession);
router.get('/sessions/:id', LessonController.getSession);
router.post('/sessions/:id/actions', LessonController.submitAction);
router.post('/sessions/:id/interrupts', LessonController.handleInterrupt);
router.post('/sessions/:id/pause', LessonController.pauseSession);
router.post('/sessions/:id/resume', LessonController.resumeSession);

export default router;
