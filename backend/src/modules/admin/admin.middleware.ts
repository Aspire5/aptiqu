import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { z } from 'zod';
import { durationMs } from '../../utils/jwt';
import { ENV } from '../../config/env';

export interface AdminAuthenticatedRequest extends Request {
  adminUser?: {
    username: string;
    role: string;
  };
}

export function signAdminToken(username: string): string {
  return jwt.sign(
    { username, role: 'ADMIN', purpose: 'admin' },
    ENV.ADMIN_JWT_SECRET,
    { algorithm: 'HS256', expiresIn: durationMs(ENV.ADMIN_JWT_EXPIRATION) / 1000, issuer: ENV.JWT_ISSUER, audience: 'aptiqu-admin' }
  );
}

export function verifyAdminToken(token: string): { username: string; role: string } {
  return z.object({
    username: z.literal(ENV.ADMIN_USERNAME), role: z.literal('ADMIN'), purpose: z.literal('admin'),
    iat: z.number().int().nonnegative().max(Math.floor(Date.now()/1000)), exp: z.number().int().positive(),
    iss: z.literal(ENV.JWT_ISSUER), aud: z.literal('aptiqu-admin'),
  }).strict().refine(p => p.exp > p.iat).parse(jwt.verify(token, ENV.ADMIN_JWT_SECRET, {
    algorithms: ['HS256'], issuer: ENV.JWT_ISSUER, audience: 'aptiqu-admin',
  }));
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
