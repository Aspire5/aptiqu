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
        connectTimeout: 1500,
        retryStrategy: () => null, // Do not spam reconnects if not running
      });

      this.client.on('connect', () => {
        this.isConnected = true;
      });

      this.client.on('error', () => {
        this.isConnected = false;
      });
    } catch {
      this.isConnected = false;
    }
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
    if (this.isConnected && this.client) {
      try {
        const res = await this.client.set(key, value, 'PX', ttlMs, 'NX');
        return res === 'OK';
      } catch {
        // Fallback to memory
      }
    }

    const item = this.memoryFallback.get(key);
    if (item && (item.expiresAt === 0 || item.expiresAt > Date.now())) {
      return false; // Already locked
    }
    this.memoryFallback.set(key, { value, expiresAt: Date.now() + ttlMs });
    return true;
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
