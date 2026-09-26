import { Response } from 'express';
import { AuthenticatedRequest } from '../../middleware/auth.middleware';
import { roadmapProgressionService } from './services/roadmap-progression.service';
import { lessonSessionService } from '../lesson/services/lesson-session.service';

export class RoadmapController {
  /**
   * GET /roadmaps
   * List all available roadmaps
   */
  public static async listRoadmaps(req: AuthenticatedRequest, res: Response): Promise<void> {
    try {
      const userId = req.userId!;
      const roadmaps = await roadmapProgressionService.listRoadmaps(userId);
      res.status(200).json({
        success: true,
        data: roadmaps,
      });
    } catch (err: any) {
      res.status(err.status || 500).json({
        success: false,
        message: err.message || 'Failed to list roadmaps.',
      });
    }
  }

  /**
   * GET /roadmaps/active
   * Get user's current active roadmap with subjects
   */
  public static async getActiveRoadmap(req: AuthenticatedRequest, res: Response): Promise<void> {
    try {
      const userId = req.userId!;
      const roadmap = await roadmapProgressionService.getUserActiveRoadmap(userId);
      res.status(200).json({
        success: true,
        data: roadmap,
      });
    } catch (err: any) {
      res.status(err.status || 500).json({
        success: false,
        message: err.message || 'Failed to get active roadmap.',
      });
    }
  }

  /**
   * POST /roadmaps/:roadmapId/select
   * Select an active roadmap for user
   */
  public static async selectRoadmap(req: AuthenticatedRequest, res: Response): Promise<void> {
    try {
      const userId = req.userId!;
      const roadmapId = req.params.roadmapId as string;
      const roadmap = await roadmapProgressionService.setActiveRoadmap(userId, roadmapId);
      res.status(200).json({
        success: true,
        data: roadmap,
        message: `Active roadmap set to ${roadmap.name}`,
      });
    } catch (err: any) {
      res.status(err.status || 400).json({
        success: false,
        message: err.message || 'Failed to select active roadmap.',
      });
    }
  }

  /**
   * GET /roadmaps/:roadmapId
   * Get roadmap details by ID or slug
   */
  public static async getRoadmap(req: AuthenticatedRequest, res: Response): Promise<void> {
    try {
      const roadmapId = req.params.roadmapId as string;
      const roadmaps = await roadmapProgressionService.listRoadmaps(req.userId!);
      const target = roadmaps.find((r) => r.id === roadmapId || r.slug === roadmapId);

      if (!target) {
        res.status(404).json({
          success: false,
          message: `Roadmap "${roadmapId}" not found.`,
        });
        return;
      }

      res.status(200).json({
        success: true,
        data: target,
      });
    } catch (err: any) {
      res.status(err.status || 500).json({
        success: false,
        message: err.message || 'Failed to get roadmap.',
      });
    }
  }

  /**
   * GET /roadmaps/:roadmapId/subjects/:subjectId/map
   * Returns authoritative learning map with topic order and completion states
   */
  public static async getSubjectMap(req: AuthenticatedRequest, res: Response): Promise<void> {
    try {
      const userId = req.userId!;
      const roadmapId = req.params.roadmapId as string;
      const subjectId = req.params.subjectId as string;

      const mapResult = await roadmapProgressionService.getSubjectLearningMap(
        userId,
        roadmapId,
        subjectId
      );

      res.status(200).json({
        success: true,
        data: mapResult,
      });
    } catch (err: any) {
      res.status(err.status || 404).json({
        success: false,
        message: err.message || 'Failed to get subject learning map.',
      });
    }
  }

  /**
   * POST /roadmaps/steps/:stepId/start
   * Start or resume lesson for a specific roadmap step
   */
  public static async startStepSession(req: AuthenticatedRequest, res: Response): Promise<void> {
    try {
      const userId = req.userId!;
      const stepId = req.params.stepId as string;
      const clientActionId = (req.body.clientActionId as string) || '';

      if (!clientActionId) {
        res.status(400).json({
          success: false,
          message: 'clientActionId is required.',
        });
        return;
      }

      const scriptSlug = req.body.scriptSlug as string | undefined;

      const result = await lessonSessionService.startOrResumeSessionByStep(
        userId,
        stepId,
        clientActionId,
        scriptSlug
      );

      res.status(200).json({
        success: true,
        data: result,
      });
    } catch (err: any) {
      res.status(err.status || 400).json({
        success: false,
        message: err.message || 'Failed to start lesson for roadmap step.',
      });
    }
  }
}
