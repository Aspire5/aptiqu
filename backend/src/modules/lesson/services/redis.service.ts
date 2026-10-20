import { BoundedCache } from './bounded-cache';
import Redis from 'ioredis';
import { ENV } from '../../../config/env';

export class RedisService {
  private static instance: RedisService;
  private client: Redis | null = null;
  private isConnected = false;
  private memoryFallback = new BoundedCache(ENV.LOCAL_CACHE_MAX_ENTRIES,ENV.LOCAL_CACHE_MAX_BYTES);

  private constructor() {}
  private started = false;

  public static getInstance(): RedisService {
    if (!RedisService.instance) {
      RedisService.instance = new RedisService();
    }
    return RedisService.instance;
  }

  private init() {
    if(this.started)return;
    this.started=true;
    try {
      this.client = new Redis(ENV.REDIS_URL, {
        maxRetriesPerRequest: 1,
        enableOfflineQueue: false,
        connectTimeout: 2000, commandTimeout:ENV.READINESS_TIMEOUT_MS??3000,
        retryStrategy: (times) => {
          if (times > 3) return 30000;
          return Math.min(times * 1000, 5000);
        },
      });

      this.client.on('ready', () => {
        this.isConnected = true;
      });

      this.client.on('close',()=>{this.isConnected=false;});
      this.client.on('error', (_err) => {
        this.isConnected = false;
      });
    } catch {
      this.isConnected = false;
    }
  }

  public async connect():Promise<void> {
    this.init();const client=this.client;
    if(!client)throw new Error('Redis unavailable');
    if(client.status==='ready')return;
    await new Promise<void>((resolve,reject)=>{
      const finish=(error?:Error)=>{clearTimeout(timer);client.off('ready',ready);client.off('error',fail);error?reject(error):resolve();};
      const ready=()=>finish(),fail=()=>finish(new Error('Redis unavailable'));
      const timer=setTimeout(()=>finish(new Error('Redis connection timed out')),3000);
      client.once('ready',ready);client.once('error',fail);
    });
  }
  public async close(){this.client?.disconnect();this.client=null;this.isConnected=false;this.started=false;this.memoryFallback.clear();}

  public getClient(): Redis | null {
    this.init();
    return this.client;
  }

  public getIsConnected(): boolean {
    this.init();
    return this.client?.status==='ready';
  }

  public async get(key: string): Promise<string | null> {
    this.init();
    if (this.isConnected && this.client) {
      try {
        return await this.client.get(key);
      } catch {
        // Fallback to memory
      }
    }

    return this.memoryFallback.get(key);
  }

  public async set(key: string, value: string, ttlSeconds?: number): Promise<void> {
    this.init();
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

    this.memoryFallback.set(key,value,ttlSeconds);
  }

  public async setNx(key: string, value: string, ttlMs: number): Promise<boolean> {
    return this.setNxToken(key, value, ttlMs);
  }

  // Locks fail closed; only ordinary cache reads/writes have a bounded fallback.
  public async setNxToken(key:string,token:string,ttlMs:number):Promise<boolean> {
    this.init();
    if(this.client?.status!=='ready')return false;
    try{return await this.client.set(key,token,'PX',ttlMs,'NX')==='OK';}catch{return false;}
  }
  public async releaseNxToken(key:string,token:string):Promise<boolean> {
    if(this.client?.status!=='ready')return false;
    try{return await this.client.eval("if redis.call('GET',KEYS[1])==ARGV[1] then return redis.call('DEL',KEYS[1]) else return 0 end",1,key,token)===1;}catch{return false;}
  }

  /**
   * Executes a Lua script atomically against Redis.
   */
  public async evalLua(script: string, keys: string[], args: string[]): Promise<any> {
    this.init();
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
    this.init();
    if (this.isConnected && this.client) {
      try {
        await this.client.del(key);
      } catch {
        // Fallback
      }
    }
    this.memoryFallback.delete(key);
  }

  public async delByPattern(pattern: string): Promise<void> {
    this.init();
    if (this.isConnected && this.client) {
      try {
        const stream = this.client.scanStream({ match: pattern, count: 100 });
        for await (const keys of stream) {
          if (keys && keys.length > 0) {
            const pipeline = this.client.pipeline();
            keys.forEach((k: string) => pipeline.del(k));
            await pipeline.exec();
          }
        }
      } catch {
        // Fallback
      }
    }
    const prefix = pattern.replace(/\*/g, '');
    for (const k of Array.from(this.memoryFallback.keys())) {
      if (k.startsWith(prefix)) {
        this.memoryFallback.delete(k);
      }
    }
  }
}

export const redisService = RedisService.getInstance();
