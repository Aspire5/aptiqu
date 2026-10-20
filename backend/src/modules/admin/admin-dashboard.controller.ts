import { publicFailure } from '../../security/public-error';
import { Request, Response } from 'express';
import { AdminDashboardService } from './admin-dashboard.service';

export class AdminDashboardController {
  /**
   * GET /api/v1/admin/dashboard/stats
   */
  // CACHE_CANDIDATE ref=C15 scope=admin-role layer=redis ttl=15-60s owner=analytics
  public static async getStats(_req: Request, res: Response): Promise<void> {
    try {
      const [overview, growthTrends, dailyStreakHistory, activityTrends] = await Promise.all([
        AdminDashboardService.getOverviewStats(),
        AdminDashboardService.getUserGrowthTrends(),
        AdminDashboardService.getDailyStreakHistory(10),
        AdminDashboardService.getActivityTrends(),
      ]);

      res.status(200).json({
        success: true,
        data: {
          overview,
          growthTrends,
          dailyStreakHistory,
          activityTrends,
        },
      });
    } catch (err: any) {
      publicFailure(res,err);
    }
  }
}
