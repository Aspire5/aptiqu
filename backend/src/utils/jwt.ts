import jwt, { SignOptions } from 'jsonwebtoken';
import { ENV } from '../config/env';
import { generateRandomToken, hashToken } from './crypto';

export interface JwtPayload {
  userId: string;
  email: string;
}

export function signAccessToken(payload: JwtPayload): string {
  const options: SignOptions = {
    expiresIn: ENV.JWT_ACCESS_EXPIRATION as SignOptions['expiresIn'],
  };
  return jwt.sign(payload, ENV.JWT_ACCESS_SECRET, options);
}

export function verifyAccessToken(token: string): JwtPayload {
  return jwt.verify(token, ENV.JWT_ACCESS_SECRET) as JwtPayload;
}

/**
 * Creates an opaque refresh token and its hash to store in DB.
 * Valid for 7 days (604800 seconds).
 */
export function createRefreshTokenData(days = 7): {
  rawToken: string;
  tokenHash: string;
  expiresAt: Date;
} {
  const rawToken = generateRandomToken(48);
  const tokenHash = hashToken(rawToken);
  const expiresAt = new Date(Date.now() + days * 24 * 60 * 60 * 1000);

  return { rawToken, tokenHash, expiresAt };
}
