import { Request, Response } from 'express';
import { ENV } from '../../config/env';
import { signAdminToken, AdminAuthenticatedRequest } from './admin.middleware';

export class AdminAuthController {
  /**
   * POST /api/v1/admin/auth/login
   */
  public static async login(req: Request, res: Response): Promise<void> {
    const { username, password } = req.body;

    if (!username || !password) {
      res.status(400).json({
        success: false,
        message: 'Username and password are required',
      });
      return;
    }

    if (username !== ENV.ADMIN_USERNAME || password !== ENV.ADMIN_PASSWORD) {
      res.status(401).json({
        success: false,
        message: 'Invalid admin credentials',
      });
      return;
    }

    const token = signAdminToken(username);

    res.status(200).json({
      success: true,
      message: 'Admin authentication successful',
      data: {
        token,
        user: {
          username,
          role: 'ADMIN',
          displayName: 'Administrator',
        },
      },
    });
  }

  /**
   * GET /api/v1/admin/auth/me
   */
  public static async me(req: AdminAuthenticatedRequest, res: Response): Promise<void> {
    res.status(200).json({
      success: true,
      data: {
        username: req.adminUser?.username || ENV.ADMIN_USERNAME,
        role: 'ADMIN',
      },
    });
  }
}
