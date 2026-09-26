import { Router } from 'express';
import { UserController } from './user.controller';
import { authenticateJwt } from '../../middleware/auth.middleware';

const router = Router();
const controller = new UserController();

router.get('/profile', authenticateJwt, controller.getProfile.bind(controller));
router.get('/progress', authenticateJwt, controller.getProgress.bind(controller));

export default router;
