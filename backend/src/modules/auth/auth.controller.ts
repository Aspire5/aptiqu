import { Request, Response } from 'express';
import { AuthService } from './auth.service';
import {
  GoogleLoginSchema,
  OnboardingSchema,
  RefreshTokenSchema,
} from './auth.validation';
import { AuthenticatedRequest } from '../../middleware/auth.middleware';

const authService = new AuthService();

export class AuthController {
  async googleLogin(req: Request, res: Response): Promise<void> {
    try {
      const parsed = GoogleLoginSchema.safeParse(req.body);
      if (!parsed.success) {
        res.status(400).json({
          success: false,
          message: 'Validation failed',
          errors: parsed.error.flatten().fieldErrors,
        });
        return;
      }

      const result = await authService.loginWithGoogle(parsed.data.idToken);

      res.status(200).json({
        success: true,
        message: 'Google authentication successful',
        data: result,
      });
    } catch (error: any) {
      res.status(400).json({
        success: false,
        message: error.message || 'Google authentication failed',
      });
    }
  }

  async completeOnboarding(req: AuthenticatedRequest, res: Response): Promise<void> {
    try {
      const userId = req.userId;
      if (!userId) {
        res.status(401).json({ success: false, message: 'Unauthorized' });
        return;
      }

      const parsed = OnboardingSchema.safeParse(req.body);
      if (!parsed.success) {
        res.status(422).json({
          success: false,
          message: 'All onboarding fields are mandatory. Please provide valid inputs.',
          errors: parsed.error.flatten().fieldErrors,
        });
        return;
      }

      const result = await authService.completeOnboarding(userId, parsed.data);

      res.status(200).json({
        success: true,
        message: 'Onboarding completed successfully',
        data: result,
      });
    } catch (error: any) {
      res.status(400).json({
        success: false,
        message: error.message || 'Onboarding failed',
      });
    }
  }

  async refreshToken(req: Request, res: Response): Promise<void> {
    try {
      const parsed = RefreshTokenSchema.safeParse(req.body);
      if (!parsed.success) {
        res.status(400).json({
          success: false,
          message: 'Refresh token is required',
          errors: parsed.error.flatten().fieldErrors,
        });
        return;
      }

      const tokens = await authService.refreshSession(parsed.data.refreshToken);

      res.status(200).json({
        success: true,
        message: 'Session refreshed successfully',
        data: tokens,
      });
    } catch (error: any) {
      res.status(401).json({
        success: false,
        message: error.message || 'Failed to refresh session',
      });
    }
  }

  async logout(req: Request, res: Response): Promise<void> {
    try {
      const { refreshToken } = req.body;
      if (refreshToken) {
        await authService.logout(refreshToken);
      }
      res.status(200).json({
        success: true,
        message: 'Logged out successfully',
      });
    } catch (error: any) {
      res.status(500).json({
        success: false,
        message: 'Logout failed',
      });
    }
  }
}
