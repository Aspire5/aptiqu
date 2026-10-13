import { HomeService } from '../home/home.service';
import { AuthenticatedRequest } from '../../middleware/auth.middleware';
import { Router } from 'express';
import { UserController } from './user.controller';
import { authenticateJwt } from '../../middleware/auth.middleware';

const router = Router();
const controller = new UserController();

router.get('/home', authenticateJwt, async (req: AuthenticatedRequest, res, next) => {
  try {
    if (!req.userId) { res.status(401).json({ success: false, message: 'Unauthorized' }); return; }
    res.json({ success: true, data: await new HomeService().getHome(req.userId) });
  } catch (error) { next(error); }
});

router.get('/profile', authenticateJwt, controller.getProfile.bind(controller));
router.get('/progress', authenticateJwt, controller.getProgress.bind(controller));
router.get('/stats', authenticateJwt, controller.getStats.bind(controller));

export default router;
