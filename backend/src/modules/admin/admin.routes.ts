import { Router } from 'express';
import { authenticateJwt } from '../../middleware/auth.middleware';
import { AdminController } from './admin.controller';

const router = Router();

// Require authentication for admin endpoints
router.use(authenticateJwt);

router.post('/questions/generate', AdminController.triggerQuestionGeneration);
router.post('/pvp-sets/generate', AdminController.triggerPvpSetGeneration);
router.post('/questions/manual', AdminController.createManualQuestion);
router.put('/config/timing', AdminController.updateTimingConfig);

export default router;
