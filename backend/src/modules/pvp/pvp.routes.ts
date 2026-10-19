import { Router } from 'express';
import { authenticateJwt } from '../../middleware/auth.middleware';
import { RankedController } from './ranked/ranked.controller';
import { PvpController } from './pvp.controller';

const router = Router();

router.use(authenticateJwt);

router.get('/ranked/me', RankedController.me);
router.get('/ranked/leaderboard', RankedController.leaderboard);
router.get('/ranked/seasons', RankedController.seasons);

router.get('/matches/:matchId', PvpController.getMatch);
router.get('/history', PvpController.getPlayerHistory);
router.post('/replay/:matchId', PvpController.replayMatch);

export default router;
