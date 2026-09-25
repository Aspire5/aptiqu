import crypto from 'crypto';

export function hashToken(token: string): string {
  return crypto.createHash('sha256').update(token).digest('hex');
}

export function generateRandomToken(bytes = 64): string {
  return crypto.randomBytes(bytes).toString('hex');
}
