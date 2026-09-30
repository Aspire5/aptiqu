import { Router } from 'express';
import { authenticateJwt } from '../../middleware/auth.middleware';
import { PvpController } from './pvp.controller';

const router = Router();

router.use(authenticateJwt);

router.get('/matches/:matchId', PvpController.getMatch);
router.get('/history', PvpController.getPlayerHistory);
router.post('/replay/:matchId', PvpController.replayMatch);

export default router;
