import { Request, Response } from 'express';
import crypto from 'crypto';
import { ENV } from '../../config/env';
import { signAdminToken, AdminAuthenticatedRequest } from './admin.middleware';

export class AdminAuthController {
  /**
   * POST /api/v1/admin/auth/login
   */
  public static async login(req: Request, res: Response): Promise<void> {
    const { username, password } = req.body;

    if (typeof username !== 'string' || typeof password !== 'string' || !username || !password || username.length > 128 || password.length > 1024) {
      res.status(400).json({
        success: false,
        message: 'Username and password are required',
        code: 'MISSING_CREDENTIALS',
      });
      return;
    }

    // Constant-time timingSafeEqual comparison over sha256 hashes
    const userHash = crypto.createHash('sha256').update(String(username)).digest();
    const expectedUserHash = crypto.createHash('sha256').update(ENV.ADMIN_USERNAME).digest();
    const passHash = crypto.createHash('sha256').update(String(password)).digest();
    const expectedPassHash = crypto.createHash('sha256').update(ENV.ADMIN_PASSWORD).digest();

    const isUserValid = crypto.timingSafeEqual(userHash, expectedUserHash);
    const isPassValid = crypto.timingSafeEqual(passHash, expectedPassHash);

    if (!isUserValid || !isPassValid) {
      res.status(401).json({
        success: false,
        message: 'Invalid admin credentials',
        code: 'INVALID_CREDENTIALS',
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
