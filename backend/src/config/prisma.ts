import { PrismaClient } from '@prisma/client';
import { ENV } from './env';

// One explicitly bounded pool per process. Prisma error logs can contain SQL/values;
// application callers log only allowlisted error metadata.
export const prisma = new PrismaClient({datasources:{db:{url:ENV.DATABASE_URL}},log:[]});
