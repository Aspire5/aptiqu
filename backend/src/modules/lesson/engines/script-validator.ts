import { ScriptDefinition, LessonNode } from '../interfaces/script-dsl.interface';

export interface ValidationError {
  field: string;
  message: string;
}

export class ScriptValidator {
  public static validate(def: ScriptDefinition): { valid: boolean; errors: ValidationError[] } {
    const errors: ValidationError[] = [];

    if (!def || typeof def!=='object') return {valid:false,errors:[{field:'definition',message:'Script must be an object'}]};
    if (!Number.isInteger(def.schemaVersion) || def.schemaVersion < 1) {
      errors.push({ field: 'schemaVersion', message: 'schemaVersion must be a positive integer.' });
    }
    if (!def.scriptId || typeof def.scriptId !== 'string') {
      errors.push({ field: 'scriptId', message: 'scriptId must be a valid non-empty string.' });
    }
    if (!Number.isInteger(def.version) || def.version < 1) {
      errors.push({ field: 'version', message: 'version must be a positive integer.' });
    }
    if (!def.entryNodeId || typeof def.entryNodeId !== 'string') {
      errors.push({ field: 'entryNodeId', message: 'entryNodeId must be specified.' });
    }

    if (!def.nodes || typeof def.nodes !== 'object' || Object.keys(def.nodes).length === 0) {
      errors.push({ field: 'nodes', message: 'nodes map must contain at least one node.' });
      return { valid: errors.length === 0, errors };
    }

    if (!def.nodes[def.entryNodeId]) {
      errors.push({
        field: 'entryNodeId',
        message: `entryNodeId "${def.entryNodeId}" does not exist in nodes dictionary.`,
      });
    }

    if(Object.keys(def.nodes).length>1000)return {valid:false,errors:[{field:'nodes',message:'Script exceeds 1000 nodes'}]};
    const nodeIds = new Set(Object.keys(def.nodes));
    let hasCompletionNode = false;

    for (const [id, node] of Object.entries(def.nodes)) {
      if(!node || typeof node!=='object'){errors.push({field:`nodes.${id}`,message:'Node must be an object'});continue;}
      if(!Array.isArray(node.transitions)){errors.push({field:`nodes.${id}.transitions`,message:'Transitions must be an array'});continue;}
      if (!['CONTENT','CHOICE','QUESTION','TEXT_INPUT','COMPLETION'].includes(node.type)) errors.push({field:`nodes.${id}.type`,message:'Unsupported node type'});
      if (node.id !== id) {
        errors.push({
          field: `nodes.${id}.id`,
          message: `Node key "${id}" does not match its internal id "${node.id}".`,
        });
      }

      if (node.type === 'COMPLETION') {
        hasCompletionNode = true;
      }

      if (node.type === 'QUESTION' || node.questionReference) {
        if (!node.questionReference) {
          errors.push({
            field: `nodes.${id}.questionReference`,
            message: 'QUESTION node requires questionReference configuration.',
          });
        } else if (node.questionReference.mode === 'INLINE') {
          const inline = node.questionReference.inlineData;
          if (!inline || typeof inline.prompt!=='string' || !inline.prompt.trim() || !Array.isArray(inline.options) || inline.options.length < 2 || inline.options.length > 10) {
            errors.push({
              field: `nodes.${id}.questionReference.inlineData`,
              message: 'INLINE question must have a prompt and at least 2 options.',
            });
          }
          if (inline && Array.isArray(inline.options)) {
            const validOptions=inline.options.every(o=>o && typeof o.id==='string' && o.id.trim() && typeof o.label==='string' && o.label.trim());
            if (!validOptions || new Set(inline.options.map(o=>o?.id)).size!==inline.options.length || new Set(inline.options.map(o=>typeof o?.label==='string'?o.label.normalize('NFKC').replace(/\s+/g,'').toLowerCase():null)).size!==inline.options.length) errors.push({field:`nodes.${id}.options`,message:'Question options must have distinct non-empty IDs and labels'});
          }
          if (inline && Array.isArray(inline.options) && !inline.options.some((o) => o?.id === inline.correctOptionId)) {
            errors.push({
              field: `nodes.${id}.questionReference.inlineData.correctOptionId`,
              message: `correctOptionId "${inline?.correctOptionId}" not found in provided options.`,
            });
          }
        } else if (node.questionReference.mode === 'QUESTION_EXTERNAL_ID') {
          if (!node.questionReference.externalId || typeof node.questionReference.externalId !== 'string' || !node.questionReference.externalId.trim()) {
            errors.push({
              field: `nodes.${id}.questionReference.externalId`,
              message: 'QUESTION_EXTERNAL_ID mode requires a valid non-empty externalId string.',
            });
          }
        } else if (node.questionReference.mode === 'REPOSITORY') {
          if(typeof node.questionReference.questionId!=='string' || !node.questionReference.questionId.trim()) errors.push({field:`nodes.${id}.questionReference.questionId`,message:'Repository questions require an ID'});
        } else {
          errors.push({field:`nodes.${id}.questionReference.mode`,message:'Unsupported question reference mode'});
        }
      }

      if (node.transitions && Array.isArray(node.transitions)) {
        for (const edge of node.transitions) {
          if (!edge || !nodeIds.has(edge.targetNodeId)) {
            errors.push({
              field: `nodes.${id}.transitions`,
              message: 'Transition must target an existing script node.',
            });
          }
        }
      }
    }

    if(errors.length)return {valid:false,errors};
    const reachable=new Set<string>();
    const visit=(id:string)=>{if(reachable.has(id)||!def.nodes[id])return;reachable.add(id);for(const edge of def.nodes[id].transitions??[])visit(edge.targetNodeId);};
    visit(def.entryNodeId);
    if(reachable.size!==nodeIds.size)errors.push({field:'nodes',message:'Script contains unreachable nodes'});
    const canFinish=new Set(Object.values(def.nodes).filter(n=>n.type==='COMPLETION').map(n=>n.id));
    let changed=true;while(changed){changed=false;for(const node of Object.values(def.nodes))if(!canFinish.has(node.id)&&node.transitions?.some(edge=>canFinish.has(edge.targetNodeId))){canFinish.add(node.id);changed=true;}}
    if([...reachable].some(id=>!canFinish.has(id)))errors.push({field:'transitions',message:'Every reachable node needs a path to completion'});
    if (!hasCompletionNode) {
      errors.push({
        field: 'nodes',
        message: 'Script must define at least one COMPLETION node.',
      });
    }

    return {
      valid: errors.length === 0,
      errors,
    };
  }
}
