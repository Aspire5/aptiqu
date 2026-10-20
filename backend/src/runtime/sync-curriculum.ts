import { syncRsAggarwalOnStartup } from '../modules/admin/services/rs-aggarwal-startup-sync.service';
import { prisma } from '../config/prisma';
import { redisService } from '../modules/lesson/services/redis.service';
import { log, safeError } from '../observability/logger';

// Explicit operator command; run with the automatic importing owner stopped.
async function main() {
  try {
    const result = await syncRsAggarwalOnStartup();
    if (!result.sourceAvailable || result.failedScripts) process.exitCode = 1;
  } catch (error) {
    log('error','curriculum.sync.failed',safeError(error));
    process.exitCode = 1;
  } finally {
    await redisService.close();
    await prisma.$disconnect();
  }
}
if (require.main === module) void main();
