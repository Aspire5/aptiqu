import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { ENV } from '../../config/env';

export interface AdminAuthenticatedRequest extends Request {
  adminUser?: {
    username: string;
    role: string;
  };
}

export function signAdminToken(username: string): string {
  return jwt.sign(
    { username, role: 'ADMIN' },
    ENV.ADMIN_JWT_SECRET,
    { expiresIn: '24h' }
  );
}

export function verifyAdminToken(token: string): { username: string; role: string } {
  try {
    return jwt.verify(token, ENV.ADMIN_JWT_SECRET) as { username: string; role: string };
  } catch (err) {
    // Fallback to JWT_ACCESS_SECRET if secret was shared
    return jwt.verify(token, ENV.JWT_ACCESS_SECRET) as { username: string; role: string };
  }
}

export function authenticateAdmin(
  req: AdminAuthenticatedRequest,
  res: Response,
  next: NextFunction
): void {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    res.status(401).json({
      success: false,
      message: 'Admin authorization token required',
      code: 'UNAUTHORIZED',
    });
    return;
  }

  const token = authHeader.split(' ')[1];
  try {
    const payload = verifyAdminToken(token);
    if (payload.role !== 'ADMIN') {
      res.status(403).json({
        success: false,
        message: 'Forbidden: Admin privilege required',
        code: 'FORBIDDEN',
      });
      return;
    }
    req.adminUser = payload;
    next();
  } catch (err: any) {
    res.status(401).json({
      success: false,
      message: 'Invalid or expired admin token',
      code: 'TOKEN_INVALID',
    });
  }
}
