import crypto from 'crypto';
import { redisService } from '../lesson/services/redis.service';

export class ConcurrencyLockService {
  /**
   * Attempts to acquire an atomic lock for a shortage scope key using a unique UUID token.
   * Returns token string if lock was acquired, null if another request is currently holding it.
   */
  public static async acquireLock(scopeKey: string, ttlMs = 60000): Promise<string | null> {
    const lockKey = `LOCK:SHORTAGE_GEN:${scopeKey}`;
    const token = crypto.randomUUID();
    const ok = await redisService.setNxToken(lockKey, token, ttlMs);
    return ok ? token : null;
  }

  /**
   * Releases an acquired shortage lock only if the token matches, preventing lock stomping.
   */
  public static async releaseLock(scopeKey: string, token?: string | null): Promise<void> {
    const lockKey = `LOCK:SHORTAGE_GEN:${scopeKey}`;
    if (token) {
      const lua = `
        if redis.call("get", KEYS[1]) == ARGV[1] then
          return redis.call("del", KEYS[1])
        else
          return 0
        end
      `;
      await redisService.evalLua(lua, [lockKey], [token]);
    } else {
      await redisService.del(lockKey);
    }
  }

  /**
   * Polling helper for concurrent requests waiting on another generation task to complete.
   * Checks the condition callback every intervalMs until it returns true or maxWaitMs expires.
   */
  public static async waitForCondition(
    condition: () => Promise<boolean>,
    maxWaitMs = 12000,
    intervalMs = 1500
  ): Promise<boolean> {
    const startTime = Date.now();
    while (Date.now() - startTime < maxWaitMs) {
      const satisfied = await condition();
      if (satisfied) return true;
      await new Promise((resolve) => setTimeout(resolve, intervalMs));
    }
    return await condition();
  }
}
