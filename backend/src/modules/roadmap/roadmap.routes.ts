import { Router } from 'express';
import { authenticateJwt } from '../../middleware/auth.middleware';
import { RoadmapController } from './roadmap.controller';

const router = Router();

// All roadmap routes require authentication
router.use(authenticateJwt);

router.get('/', RoadmapController.listRoadmaps);
router.get('/active', RoadmapController.getActiveRoadmap);
router.post('/steps/:stepId/start', RoadmapController.startStepSession);
router.post('/:roadmapId/select', RoadmapController.selectRoadmap);
router.get('/:roadmapId', RoadmapController.getRoadmap);
router.get('/:roadmapId/subjects/:subjectId/map', RoadmapController.getSubjectMap);

export default router;
