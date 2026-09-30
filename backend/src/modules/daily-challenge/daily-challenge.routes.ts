import { Router } from 'express';
import { DailyChallengeController } from './daily-challenge.controller';
import { authenticateJwt } from '../../middleware/auth.middleware';

const router = Router();

// All daily challenge routes are authenticated
router.use(authenticateJwt);

router.get('/status', DailyChallengeController.getStatus);
router.post('/start', DailyChallengeController.startChallenge);
router.post('/answer', DailyChallengeController.submitAnswer);
router.get('/history', DailyChallengeController.getHistory);

export default router;
