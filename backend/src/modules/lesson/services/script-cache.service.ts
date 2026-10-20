import { SingleFlight } from './bounded-cache';
import { PublicError } from '../../../security/errors';
import { prisma, learningTransaction } from './learning-transaction';
import { redisService } from './redis.service';
import { ScriptDefinition } from '../interfaces/script-dsl.interface';
import { questionHydrationService } from './question-hydration.service';

export class ScriptCacheService {
  private static instance: ScriptCacheService;
  private readonly loads=new SingleFlight<string|null>();

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

    if (!script || script.status !== 'PUBLISHED' || !script.versions || script.versions.length === 0) {
      return null;
    }

    const latestPublished = script.versions[0];
    const versionId = latestPublished.id;
    await this.assertPublished(script.id, versionId);
    let definition = this.normalizeScriptDefinition(latestPublished.definition, script.title);
    definition = await questionHydrationService.hydrateScriptDefinition(definition,{preferPinned:true});

    return {
      scriptId: script.id,
      scriptVersionId: versionId,
      definition,
    };
  }

  public async assertPublished(scriptId: string, versionId: string) {
    const script = await prisma.lessonScript.findFirst({where:{id:scriptId,status:'PUBLISHED'},select:{subjectId:true,topicId:true,subtopicId:true}});
    const version = await prisma.lessonScriptVersion.findFirst({where:{id:versionId,scriptId,status:'PUBLISHED'},select:{id:true}});
    if (!script || !version) throw new PublicError('Published lesson not available','SCRIPT_NOT_PUBLISHED',404);
    for (const [model,id] of [[prisma.subject,script.subjectId],[prisma.topic,script.topicId],[prisma.subtopic,script.subtopicId]] as const) {
      if (id && !await (model as any).findFirst({where:{id,isActive:true},select:{id:true}})) throw new PublicError('Published lesson not available','SCRIPT_NOT_PUBLISHED',404);
    }
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

    // Book-authored scripts use "1.0" for the same schema version as numeric 1.
    const rawSchemaVersion = def.schemaVersion;
    const schemaVersion = typeof rawSchemaVersion === 'string' && /^[1-9]\d*(?:\.0+)?$/.test(rawSchemaVersion.trim())
      ? Number(rawSchemaVersion)
      : rawSchemaVersion ?? 1;

    return {
      schemaVersion,
      scriptId: def.scriptId || 'script-default',
      version: def.version ?? 1,
      entryNodeId,
      nodes: nodesMap,
      metadata: def.metadata || { title: fallbackTitle || def.title || 'Lesson Script' },
    } as ScriptDefinition;
  }

  public async getScriptVersionDefinition(versionId:string,fallbackTitle?:string):Promise<ScriptDefinition|null> {
    if(learningTransaction()) {
      const row=await prisma.lessonScriptVersion.findUnique({where:{id:versionId},select:{definition:true}});
      return row?questionHydrationService.hydrateScriptDefinition(this.normalizeScriptDefinition(row.definition,fallbackTitle),{preferPinned:true}):null;
    }
    // Cache immutable stored definitions, never a live hydrated replacement or a session DTO.
    // v2 avoids legacy entries whose questions were refreshed in place. Auth/publication
    // checks remain at the caller; this internal key never grants access.
    const key=`script:def:v2:${versionId}`;
    const serialized=await this.loads.run(versionId,async()=>{
      const cached=await redisService.get(key);
      if(cached){try{JSON.parse(cached);return cached;}catch{/* Replace a corrupt cache entry. */}}
      const row=await prisma.lessonScriptVersion.findUnique({where:{id:versionId},select:{definition:true}});
      if(!row)return null;
      const value=JSON.stringify(row.definition);await redisService.set(key,value,3600);return value;
    });
    if(!serialized)return null;
    // A separate object per caller prevents mastery overlays from changing another response.
    return questionHydrationService.hydrateScriptDefinition(this.normalizeScriptDefinition(JSON.parse(serialized),fallbackTitle),{preferPinned:true});
  }

  public async invalidateScriptCache(slug?: string, versionId?: string): Promise<void> {
    if (slug) {
      await redisService.del(`script:slug:published:${slug}`);
    }
    if (versionId) {
      await redisService.del(`script:def:${versionId}`);
      await redisService.del(`script:def:v2:${versionId}`);
    }
  }

  public async invalidateAllScriptCaches(): Promise<void> {
    await redisService.delByPattern('script:*');
  }
}

export const scriptCacheService = ScriptCacheService.getInstance();
