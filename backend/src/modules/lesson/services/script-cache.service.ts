import { prisma } from '../../../config/prisma';
import { redisService } from './redis.service';
import { ScriptDefinition } from '../interfaces/script-dsl.interface';

export class ScriptCacheService {
  private static instance: ScriptCacheService;

  public static getInstance(): ScriptCacheService {
    if (!ScriptCacheService.instance) {
      ScriptCacheService.instance = new ScriptCacheService();
    }
    return ScriptCacheService.instance;
  }

  public async getPublishedScriptBySlug(slug: string): Promise<{
    scriptId: string;
    scriptVersionId: string;
    definition: ScriptDefinition;
  } | null> {
    const slugKey = `script:slug:published:${slug}`;
    let versionId = await redisService.get(slugKey);

    if (versionId) {
      const def = await this.getScriptVersionDefinition(versionId);
      if (def) {
        return {
          scriptId: def.scriptId,
          scriptVersionId: versionId,
          definition: def,
        };
      }
    }

    // Cache miss or definition missing -> query database
    const script = await prisma.lessonScript.findUnique({
      where: { slug },
      include: {
        versions: {
          where: { status: 'PUBLISHED' },
          orderBy: { versionNumber: 'desc' },
          take: 1,
        },
      },
    });

    if (!script || !script.versions || script.versions.length === 0) {
      return null;
    }

    const latestPublished = script.versions[0];
    versionId = latestPublished.id;
    const definition = latestPublished.definition as unknown as ScriptDefinition;

    // Cache in Redis
    await redisService.set(slugKey, versionId, 86400); // 24 hours
    await redisService.set(`script:def:${versionId}`, JSON.stringify(definition), 604800); // 7 days

    return {
      scriptId: script.id,
      scriptVersionId: versionId,
      definition,
    };
  }

  public async getScriptVersionDefinition(versionId: string): Promise<ScriptDefinition | null> {
    const defKey = `script:def:${versionId}`;
    const cached = await redisService.get(defKey);

    if (cached) {
      try {
        return JSON.parse(cached) as ScriptDefinition;
      } catch {
        // Fallthrough
      }
    }

    // Stampede lock
    const lockKey = `lock:script_load:${versionId}`;
    const acquired = await redisService.setNx(lockKey, '1', 2000);

    if (!acquired) {
      // Small backoff and re-check cache
      await new Promise((resolve) => setTimeout(resolve, 60));
      const retry = await redisService.get(defKey);
      if (retry) {
        return JSON.parse(retry) as ScriptDefinition;
      }
    }

    try {
      const versionRow = await prisma.lessonScriptVersion.findUnique({
        where: { id: versionId },
      });

      if (!versionRow) return null;

      const definition = versionRow.definition as unknown as ScriptDefinition;
      await redisService.set(defKey, JSON.stringify(definition), 604800);
      return definition;
    } finally {
      await redisService.del(lockKey);
    }
  }
}

export const scriptCacheService = ScriptCacheService.getInstance();
