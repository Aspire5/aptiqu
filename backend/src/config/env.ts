import dotenv from 'dotenv';
import path from 'node:path';
import { parseRuntimeConfig, parseAiLimits } from './runtime-config';

// src/config and dist/config both resolve the backend's own .env, regardless of
// the supervisor's working directory. Explicit process ENV still takes precedence.
dotenv.config({path:process.env.DOTENV_CONFIG_PATH || path.resolve(__dirname, '../../.env')});
export const ENV = parseRuntimeConfig(process.env, process.cwd());
export const AI_LIMITS = parseAiLimits(process.env);
