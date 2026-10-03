import { prisma } from '../../../config/prisma';
import { redisService } from './redis.service';
import { ScriptDefinition } from '../interfaces/script-dsl.interface';
import { questionHydrationService } from './question-hydration.service';

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
    let definition = this.normalizeScriptDefinition(latestPublished.definition, script.title);
    definition = await questionHydrationService.hydrateScriptDefinition(definition);

    // Cache in Redis
    await redisService.set(slugKey, versionId, 86400); // 24 hours
    await redisService.set(`script:def:${versionId}`, JSON.stringify(definition), 604800); // 7 days

    return {
      scriptId: script.id,
      scriptVersionId: versionId,
      definition,
    };
  }

  public normalizeScriptDefinition(raw: any, fallbackTitle?: string): ScriptDefinition {
    if (!raw) {
      throw new Error('Script definition is empty.');
    }

    let def = typeof raw === 'string' ? JSON.parse(raw) : raw;

    // 1. Unwrap if wrapped in topic -> subtopic -> script or just script
    if (def.script && typeof def.script === 'object') {
      def = def.script;
    } else if (def.subtopic?.script && typeof def.subtopic.script === 'object') {
      def = def.subtopic.script;
    }

    // 2. Normalize nodes into a dictionary map { [id: string]: LessonNode }
    const rawNodes = def.nodes;
    const nodesMap: Record<string, any> = {};

    if (Array.isArray(rawNodes)) {
      for (let i = 0; i < rawNodes.length; i++) {
        const n = rawNodes[i];
        const id = String(n.id || `node_${i + 1}`);
        nodesMap[id] = { ...n, id };
      }
    } else if (rawNodes && typeof rawNodes === 'object') {
      for (const [key, val] of Object.entries(rawNodes)) {
        const nodeVal = (val && typeof val === 'object' ? val : {}) as any;
        const id = String(nodeVal.id || key);
        nodesMap[id] = { ...nodeVal, id };
      }
    }

    const nodeKeys = Object.keys(nodesMap);
    if (nodeKeys.length === 0) {
      const defaultId = 'node_1';
      nodesMap[defaultId] = {
        id: defaultId,
        type: 'CONTENT',
        content: { text: `Welcome to ${fallbackTitle || 'this lesson'}.` },
        transitions: [],
      };
      nodeKeys.push(defaultId);
    }

    // 3. Resolve entryNodeId
    let entryNodeId = def.entryNodeId;
    if (!entryNodeId || !nodesMap[entryNodeId]) {
      entryNodeId = nodeKeys[0];
    }

    // 4. Ensure each node has proper content / text and transitions
    for (let i = 0; i < nodeKeys.length; i++) {
      const id = nodeKeys[i];
      const node = nodesMap[id];
      if (!node.content && node.text) {
        node.content = { text: String(node.text) };
      } else if (!node.content) {
        node.content = { text: String(node.prompt || '') };
      }

      // If not the last node and has no transitions, link to next sequential node
      if ((!node.transitions || node.transitions.length === 0) && i < nodeKeys.length - 1) {
        node.transitions = [{ targetNodeId: nodeKeys[i + 1] }];
      } else if (i === nodeKeys.length - 1 && (!node.transitions || node.transitions.length === 0)) {
        if (node.type !== 'COMPLETION') {
          node.type = 'COMPLETION';
        }
      }
    }

    return {
      schemaVersion: def.schemaVersion ?? 1,
      scriptId: def.scriptId || 'script-default',
      version: def.version ?? 1,
      entryNodeId,
      nodes: nodesMap,
      metadata: def.metadata || { title: fallbackTitle || def.title || 'Lesson Script' },
    } as ScriptDefinition;
  }

  public async getScriptVersionDefinition(versionId: string, fallbackTitle?: string): Promise<ScriptDefinition | null> {
    const defKey = `script:def:${versionId}`;
    const cached = await redisService.get(defKey);

    if (cached) {
      try {
        const parsed = JSON.parse(cached);
        const normalized = this.normalizeScriptDefinition(parsed, fallbackTitle);
        return await questionHydrationService.hydrateScriptDefinition(normalized);
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
        try {
          const parsed = JSON.parse(retry);
          const normalized = this.normalizeScriptDefinition(parsed, fallbackTitle);
          return await questionHydrationService.hydrateScriptDefinition(normalized);
        } catch {
          // Fallthrough
        }
      }
    }

    try {
      const versionRow = await prisma.lessonScriptVersion.findUnique({
        where: { id: versionId },
      });

      if (!versionRow) return null;

      let definition = this.normalizeScriptDefinition(versionRow.definition, fallbackTitle);
      definition = await questionHydrationService.hydrateScriptDefinition(definition);
      await redisService.set(defKey, JSON.stringify(definition), 604800);
      return definition;
    } finally {
      await redisService.del(lockKey);
    }
  }
}

export const scriptCacheService = ScriptCacheService.getInstance();
