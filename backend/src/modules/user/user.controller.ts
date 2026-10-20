import { publicFailure } from '../../security/public-error';
import { Response } from 'express';
import { UserService } from './user.service';
import { AuthenticatedRequest } from '../../middleware/auth.middleware';

const userService = new UserService();

export class UserController {
  async getProfile(req: AuthenticatedRequest, res: Response): Promise<void> {
    try {
      const userId = req.userId;
      if (!userId) {
        res.status(401).json({ success: false, message: 'Unauthorized' });
        return;
      }

      const profile = await userService.getProfile(userId, req.query.summary !== 'true');

      res.status(200).json({
        success: true,
        data: profile,
      });
    } catch (error: any) { publicFailure(res,error); }
  }

  async getProgress(req: AuthenticatedRequest, res: Response): Promise<void> {
    try {
      const userId = req.userId;
      if (!userId) {
        res.status(401).json({ success: false, message: 'Unauthorized' });
        return;
      }

      const progress = await userService.getProgress(userId);

      res.status(200).json({
        success: true,
        data: progress,
      });
    } catch (error: any) { publicFailure(res,error); }
  }

  async getStats(req: AuthenticatedRequest, res: Response): Promise<void> {
    try {
      const userId = req.userId;
      if (!userId) {
        res.status(401).json({ success: false, message: 'Unauthorized' });
        return;
      }

      const stats = await userService.getUserStats(userId);

      res.status(200).json({
        success: true,
        data: stats,
      });
    } catch (error: any) { publicFailure(res,error); }
  }
}
