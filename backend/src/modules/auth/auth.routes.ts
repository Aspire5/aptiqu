import { Router } from 'express';
import { AuthController } from './auth.controller';
import { authenticateJwt } from '../../middleware/auth.middleware';

const router = Router();
const controller = new AuthController();

// Public auth endpoints
router.post('/google', controller.googleLogin.bind(controller));
router.post('/refresh', controller.refreshToken.bind(controller));
router.post('/logout', controller.logout.bind(controller));

// Protected onboarding endpoint
router.post('/onboarding', authenticateJwt, controller.completeOnboarding.bind(controller));

export default router;
