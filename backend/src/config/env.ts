import dotenv from 'dotenv';
import { parseRuntimeConfig, parseAiLimits } from './runtime-config';

dotenv.config({path:process.env.DOTENV_CONFIG_PATH || '.env'});
export const ENV = parseRuntimeConfig(process.env, process.cwd());
export const AI_LIMITS = parseAiLimits(process.env);
