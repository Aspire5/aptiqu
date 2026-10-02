import dotenv from 'dotenv';
dotenv.config();

function requiredEnv(key: string): string {
  const value = process.env[key];
  if (!value || value.trim() === '') {
    throw new Error(`[FATAL] Missing required environment variable: ${key}`);
  }
  return value.trim();
}

export const ENV = {
  PORT: parseInt(process.env.PORT || '5001', 10),
  NODE_ENV: process.env.NODE_ENV || 'development',
  DATABASE_URL: requiredEnv('DATABASE_URL'),

  JWT_ACCESS_SECRET: requiredEnv('JWT_ACCESS_SECRET'),
  JWT_REFRESH_SECRET: requiredEnv('JWT_REFRESH_SECRET'),
  JWT_ACCESS_EXPIRATION: process.env.JWT_ACCESS_EXPIRATION || '15m',
  JWT_REFRESH_EXPIRATION: process.env.JWT_REFRESH_EXPIRATION || '7d',

  GOOGLE_WEB_CLIENT_ID: process.env.GOOGLE_WEB_CLIENT_ID || '',
  GOOGLE_WEB_CLIENT_SECRET: process.env.GOOGLE_WEB_CLIENT_SECRET || '',
  GOOGLE_ANDROID_CLIENT_ID: process.env.GOOGLE_ANDROID_CLIENT_ID || '',
  GOOGLE_IOS_CLIENT_ID: process.env.GOOGLE_IOS_CLIENT_ID || '',
  REDIS_URL: process.env.REDIS_URL || 'redis://127.0.0.1:6379',

  // Gemini AI configuration
  GEMINI_API_KEY: process.env.GEMINI_API_KEY || '',
  GEMINI_MODEL: process.env.GEMINI_MODEL || 'gemini-3.5-flash-lite',
  GEMINI_THINKING_BUDGET: parseInt(process.env.GEMINI_THINKING_BUDGET || '0', 10),

  // Admin configuration
  ADMIN_USERNAME: requiredEnv('ADMIN_USERNAME'),
  ADMIN_PASSWORD: requiredEnv('ADMIN_PASSWORD'),
  ADMIN_JWT_SECRET: requiredEnv('ADMIN_JWT_SECRET'),
};

