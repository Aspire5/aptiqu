import { redisService } from '../lesson/services/redis.service';

export class ConcurrencyLockService {
  /**
   * Attempts to acquire an atomic lock for a shortage scope key.
   * Returns true if lock was acquired, false if another request is currently generating.
   */
  public static async acquireLock(scopeKey: string, ttlMs = 60000): Promise<boolean> {
    const lockKey = `LOCK:SHORTAGE_GEN:${scopeKey}`;
    return await redisService.setNx(lockKey, 'locked', ttlMs);
  }

  /**
   * Releases an acquired shortage lock.
   */
  public static async releaseLock(scopeKey: string): Promise<void> {
    const lockKey = `LOCK:SHORTAGE_GEN:${scopeKey}`;
    await redisService.del(lockKey);
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
