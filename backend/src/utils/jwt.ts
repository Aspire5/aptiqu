import jwt from 'jsonwebtoken';
import { z } from 'zod';
import { ENV } from '../config/env';
import { generateRandomToken, hashToken } from './crypto';

export function durationMs(value: string): number {
  const match = /^(\d+)(s|m|h|d)$/.exec(value);
  if (!match) throw new Error('Token expiration must use a positive integer and s/m/h/d');
  const ms = Number(match[1]) * ({s:1000,m:60000,h:3600000,d:86400000}[match[2]]!);
  if (!Number.isSafeInteger(ms) || ms <= 0 || ms > 366 * 86400000) throw new Error('Invalid token expiration');
  return ms;
}
const accessSeconds = durationMs(ENV.JWT_ACCESS_EXPIRATION) / 1000;
const refreshMs = durationMs(ENV.JWT_REFRESH_EXPIRATION);
const claims = z.object({
  userId: z.string().uuid(), email: z.string().email(), purpose: z.literal('access'),
  iat: z.number().int().nonnegative(), exp: z.number().int().positive(),
  iss: z.literal(ENV.JWT_ISSUER), aud: z.literal(ENV.JWT_AUDIENCE),
}).strict();
export interface JwtPayload { userId: string; email: string }
export function signAccessToken(payload: JwtPayload): string {
  z.object({userId:z.string().uuid(),email:z.string().email()}).strict().parse(payload);
  return jwt.sign({...payload,purpose:'access'}, ENV.JWT_ACCESS_SECRET, {
    algorithm:'HS256', expiresIn:accessSeconds, issuer:ENV.JWT_ISSUER, audience:ENV.JWT_AUDIENCE,
  });
}
export function verifyAccessToken(token: string) {
  const payload = claims.parse(jwt.verify(token, ENV.JWT_ACCESS_SECRET, {
    algorithms:['HS256'], issuer:ENV.JWT_ISSUER, audience:ENV.JWT_AUDIENCE,
  }));
  if (payload.iat > Math.floor(Date.now()/1000) || payload.exp <= payload.iat) throw new Error('Invalid claims');
  return payload;
}
export function createRefreshTokenData() {
  const rawToken = generateRandomToken(48);
  return {rawToken, tokenHash:hashToken(rawToken), expiresAt:new Date(Date.now()+refreshMs)};
}
