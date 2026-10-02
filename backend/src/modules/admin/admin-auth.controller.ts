import { Request, Response } from 'express';
import crypto from 'crypto';
import { ENV } from '../../config/env';
import { signAdminToken, AdminAuthenticatedRequest } from './admin.middleware';

// In-memory rate limiting map for admin login: ip -> { count: number, resetTime: number }
const loginAttempts = new Map<string, { count: number; resetTime: number }>();
const MAX_ATTEMPTS = 5;
const WINDOW_MS = 15 * 60 * 1000; // 15 minutes

export class AdminAuthController {
  /**
   * POST /api/v1/admin/auth/login
   */
  public static async login(req: Request, res: Response): Promise<void> {
    const ip = req.ip || req.socket.remoteAddress || 'unknown_ip';
    const now = Date.now();

    // Check rate limit
    const attempt = loginAttempts.get(ip);
    if (attempt) {
      if (now < attempt.resetTime) {
        if (attempt.count >= MAX_ATTEMPTS) {
          const waitMinutes = Math.ceil((attempt.resetTime - now) / 60000);
          res.status(429).json({
            success: false,
            message: `Too many login attempts. Please try again after ${waitMinutes} minutes.`,
            code: 'RATE_LIMIT_EXCEEDED',
          });
          return;
        }
      } else {
        // Expired window, reset
        loginAttempts.set(ip, { count: 0, resetTime: now + WINDOW_MS });
      }
    } else {
      loginAttempts.set(ip, { count: 0, resetTime: now + WINDOW_MS });
    }

    const { username, password } = req.body;

    if (!username || !password) {
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
      // Increment failed attempt count
      const current = loginAttempts.get(ip);
      if (current) {
        current.count += 1;
      }
      res.status(401).json({
        success: false,
        message: 'Invalid admin credentials',
        code: 'INVALID_CREDENTIALS',
      });
      return;
    }

    // Success: reset attempts for this IP
    loginAttempts.delete(ip);

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
