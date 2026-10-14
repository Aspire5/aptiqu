import { userAchievements } from '../achievements/achievement.service';
import { z } from 'zod';
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

router.get('/achievements', authenticateJwt, async (req: AuthenticatedRequest, res, next) => {
  try {
    if (!req.userId) { res.status(401).json({ success: false, message: 'Unauthorized' }); return; }
    const parsed = z.object({ page: z.coerce.number().int().min(1).max(1000000).default(1),
      limit: z.coerce.number().int().min(1).max(50).default(20) }).safeParse(req.query);
    if (!parsed.success) { res.status(400).json({ success: false, message: 'Invalid achievement pagination.' }); return; }
    res.json({ success: true, data: await userAchievements(req.userId, parsed.data.page, parsed.data.limit) });
  } catch (error) { next(error); }
});

router.get('/profile' , authenticateJwt, controller.getProfile.bind(controller));
router.get('/progress', authenticateJwt, controller.getProgress.bind(controller));
router.get('/stats', authenticateJwt, controller.getStats.bind(controller));

export default router;
