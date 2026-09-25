import { ScriptDefinition, LessonNode } from '../interfaces/script-dsl.interface';

export interface ValidationError {
  field: string;
  message: string;
}

export class ScriptValidator {
  public static validate(def: ScriptDefinition): { valid: boolean; errors: ValidationError[] } {
    const errors: ValidationError[] = [];

    if (!def.schemaVersion || typeof def.schemaVersion !== 'number') {
      errors.push({ field: 'schemaVersion', message: 'schemaVersion must be a positive integer.' });
    }
    if (!def.scriptId || typeof def.scriptId !== 'string') {
      errors.push({ field: 'scriptId', message: 'scriptId must be a valid non-empty string.' });
    }
    if (!def.version || typeof def.version !== 'number') {
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

    const nodeIds = new Set(Object.keys(def.nodes));
    let hasCompletionNode = false;

    for (const [id, node] of Object.entries(def.nodes)) {
      if (node.id !== id) {
        errors.push({
          field: `nodes.${id}.id`,
          message: `Node key "${id}" does not match its internal id "${node.id}".`,
        });
      }

      if (node.type === 'COMPLETION') {
        hasCompletionNode = true;
      }

      if (node.type === 'QUESTION') {
        if (!node.questionReference) {
          errors.push({
            field: `nodes.${id}.questionReference`,
            message: 'QUESTION node requires questionReference configuration.',
          });
        } else if (node.questionReference.mode === 'INLINE') {
          const inline = node.questionReference.inlineData;
          if (!inline || !inline.prompt || !inline.options || inline.options.length < 2) {
            errors.push({
              field: `nodes.${id}.questionReference.inlineData`,
              message: 'INLINE question must have a prompt and at least 2 options.',
            });
          }
          if (inline && !inline.options.some((o) => o.id === inline.correctOptionId)) {
            errors.push({
              field: `nodes.${id}.questionReference.inlineData.correctOptionId`,
              message: `correctOptionId "${inline?.correctOptionId}" not found in provided options.`,
            });
          }
        }
      }

      if (node.transitions && Array.isArray(node.transitions)) {
        for (const edge of node.transitions) {
          if (!nodeIds.has(edge.targetNodeId)) {
            errors.push({
              field: `nodes.${id}.transitions`,
              message: `Transition targetNodeId "${edge.targetNodeId}" does not exist in script nodes.`,
            });
          }
        }
      }
    }

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
