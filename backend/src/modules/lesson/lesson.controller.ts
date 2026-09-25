import { Response } from 'express';
import { AuthenticatedRequest } from '../../middleware/auth.middleware';
import { lessonSessionService } from './services/lesson-session.service';
import { roadmapProgressionService } from '../roadmap/services/roadmap-progression.service';
import { StartSessionDto } from './dtos/lesson-session.dto';
import { SubmitActionDto, InterruptDto } from './dtos/lesson-action.dto';

export class LessonController {
  public static async startSession(req: AuthenticatedRequest, res: Response): Promise<void> {
    try {
      const userId = req.userId!;
      const parsed = StartSessionDto.parse(req.body);

      let roadmapStepId = parsed.roadmapStepId;
      let scriptSlug = parsed.scriptSlug;

      if (!roadmapStepId && !scriptSlug) {
        const roadmap = await roadmapProgressionService.getUserActiveRoadmap(userId);
        const nextStep = await roadmapProgressionService.getNextStepOrScript(userId, roadmap.id);
        if (nextStep.available && nextStep.roadmapStepId) {
          roadmapStepId = nextStep.roadmapStepId;
        } else if (nextStep.scriptSlug) {
          scriptSlug = nextStep.scriptSlug;
        } else {
          throw new Error('No active learning step available on your current roadmap.');
        }
      }

      const result = roadmapStepId
        ? await lessonSessionService.startOrResumeSessionByStep(
            userId,
            roadmapStepId,
            parsed.clientActionId
          )
        : await lessonSessionService.startOrResumeSession(
            userId,
            scriptSlug!,
            parsed.clientActionId
          );

      res.status(200).json({
        success: true,
        data: result,
      });
    } catch (err: any) {
      res.status(err.status || 400).json({
        success: false,
        message: err.message || 'Failed to start or resume lesson session.',
      });
    }
  }

  public static async getSession(req: AuthenticatedRequest, res: Response): Promise<void> {
    try {
      const userId = req.userId!;
      const id = req.params.id as string;

      const result = await lessonSessionService.getSession(userId, id);
      res.status(200).json({
        success: true,
        data: result,
      });
    } catch (err: any) {
      res.status(err.status || 404).json({
        success: false,
        message: err.message || 'Failed to retrieve session.',
      });
    }
  }

  public static async submitAction(req: AuthenticatedRequest, res: Response): Promise<void> {
    try {
      const userId = req.userId!;
      const id = req.params.id as string;
      const parsed = SubmitActionDto.parse(req.body);

      const result = await lessonSessionService.submitAction(userId, id, parsed);
      res.status(200).json({
        success: true,
        data: result,
      });
    } catch (err: any) {
      if (err.code === 'STALE_STATE_VERSION') {
        res.status(409).json({
          success: false,
          error: {
            code: 'STALE_STATE_VERSION',
            message: err.message,
            expectedVersion: err.expectedVersion,
            authoritativeNodeId: err.authoritativeNodeId,
          },
        });
        return;
      }

      res.status(err.status || 400).json({
        success: false,
        message: err.message || 'Failed to process lesson action.',
      });
    }
  }

  public static async handleInterrupt(req: AuthenticatedRequest, res: Response): Promise<void> {
    try {
      const userId = req.userId!;
      const id = req.params.id as string;
      const parsed = InterruptDto.parse(req.body);

      const result = await lessonSessionService.handleInterrupt(userId, id, parsed);
      res.status(200).json({
        success: true,
        data: result,
      });
    } catch (err: any) {
      res.status(err.status || 400).json({
        success: false,
        message: err.message || 'Failed to process doubt interrupt.',
      });
    }
  }

  public static async pauseSession(req: AuthenticatedRequest, res: Response): Promise<void> {
    try {
      const userId = req.userId!;
      const id = req.params.id as string;

      await lessonSessionService.pauseSession(userId, id);
      res.status(200).json({ success: true, message: 'Session paused.' });
    } catch (err: any) {
      res.status(err.status || 400).json({
        success: false,
        message: err.message || 'Failed to pause session.',
      });
    }
  }

  public static async resumeSession(req: AuthenticatedRequest, res: Response): Promise<void> {
    try {
      const userId = req.userId!;
      const id = req.params.id as string;

      await lessonSessionService.resumeSession(userId, id);
      res.status(200).json({ success: true, message: 'Session resumed.' });
    } catch (err: any) {
      res.status(err.status || 400).json({
        success: false,
        message: err.message || 'Failed to resume session.',
      });
    }
  }
}
