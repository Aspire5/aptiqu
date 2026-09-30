import { Request, Response } from 'express';
import { AdminDashboardService } from './admin-dashboard.service';

export class AdminDashboardController {
  /**
   * GET /api/v1/admin/dashboard/stats
   */
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
      console.error('[AdminDashboardController] Error fetching stats:', err);
      res.status(500).json({
        success: false,
        message: err.message || 'Failed to fetch dashboard statistics',
      });
    }
  }
}
