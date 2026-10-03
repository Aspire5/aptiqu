import Redis from 'ioredis';
import { ENV } from '../../../config/env';

export class RedisService {
  private static instance: RedisService;
  private client: Redis | null = null;
  private isConnected = false;
  private memoryFallback = new Map<string, { value: string; expiresAt: number }>();

  private constructor() {
    this.init();
  }

  public static getInstance(): RedisService {
    if (!RedisService.instance) {
      RedisService.instance = new RedisService();
    }
    return RedisService.instance;
  }

  private init() {
    try {
      this.client = new Redis(ENV.REDIS_URL, {
        maxRetriesPerRequest: 1,
        enableOfflineQueue: false,
        connectTimeout: 2000,
        retryStrategy: (times) => {
          if (times > 3) return 30000;
          return Math.min(times * 1000, 5000);
        },
      });

      this.client.on('connect', () => {
        this.isConnected = true;
      });

      this.client.on('error', (_err) => {
        this.isConnected = false;
      });
    } catch {
      this.isConnected = false;
    }
  }

  public getClient(): Redis | null {
    return this.client;
  }

  public getIsConnected(): boolean {
    return this.isConnected;
  }

  public async get(key: string): Promise<string | null> {
    if (this.isConnected && this.client) {
      try {
        return await this.client.get(key);
      } catch {
        // Fallback to memory
      }
    }

    const item = this.memoryFallback.get(key);
    if (!item) return null;
    if (item.expiresAt > 0 && Date.now() > item.expiresAt) {
      this.memoryFallback.delete(key);
      return null;
    }
    return item.value;
  }

  public async set(key: string, value: string, ttlSeconds?: number): Promise<void> {
    if (this.isConnected && this.client) {
      try {
        if (ttlSeconds && ttlSeconds > 0) {
          await this.client.set(key, value, 'EX', ttlSeconds);
        } else {
          await this.client.set(key, value);
        }
        return;
      } catch {
        // Fallback to memory
      }
    }

    const expiresAt = ttlSeconds && ttlSeconds > 0 ? Date.now() + ttlSeconds * 1000 : 0;
    this.memoryFallback.set(key, { value, expiresAt });
  }

  public async setNx(key: string, value: string, ttlMs: number): Promise<boolean> {
    return this.setNxToken(key, value, ttlMs);
  }

  /**
   * Distributed lock acquisition with unique token.
   * If Redis is disconnected, falls back to in-memory lock.
   */
  public async setNxToken(key: string, token: string, ttlMs: number): Promise<boolean> {
    if (this.isConnected && this.client) {
      try {
        const res = await this.client.set(key, token, 'PX', ttlMs, 'NX');
        return res === 'OK';
      } catch {
        // Fallback to memory
      }
    }
    const existing = this.memoryFallback.get(key);
    if (!existing || (existing.expiresAt > 0 && Date.now() > existing.expiresAt)) {
      this.memoryFallback.set(key, { value: token, expiresAt: Date.now() + ttlMs });
      return true;
    }
    return false;
  }

  /**
   * Executes a Lua script atomically against Redis.
   */
  public async evalLua(script: string, keys: string[], args: string[]): Promise<any> {
    if (this.isConnected && this.client) {
      try {
        return await this.client.eval(script, keys.length, ...keys, ...args);
      } catch {
        return null;
      }
    }
    return null;
  }

  public async del(key: string): Promise<void> {
    if (this.isConnected && this.client) {
      try {
        await this.client.del(key);
      } catch {
        // Fallback
      }
    }
    this.memoryFallback.delete(key);
  }
}

export const redisService = RedisService.getInstance();
