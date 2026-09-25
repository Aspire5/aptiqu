import { LessonNode } from '../interfaces/script-dsl.interface';
import { SessionStateData } from '../interfaces/session-state.interface';

export interface ActionPayload {
  actionId?: string;
  answer?: string;
  isCorrect?: boolean;
}

export class TransitionEngine {
  public static resolveNextNode(
    currentNode: LessonNode,
    actionPayload: ActionPayload,
    allNodes: Record<string, LessonNode>,
    _stateData?: SessionStateData
  ): string {
    if (currentNode.type === 'COMPLETION') {
      return currentNode.id;
    }

    if (!currentNode.transitions || currentNode.transitions.length === 0) {
      throw new Error(`Node "${currentNode.id}" has no outgoing transitions.`);
    }

    for (const edge of currentNode.transitions) {
      if (!edge.condition) {
        // Unconditional / default transition
        if (!allNodes[edge.targetNodeId]) {
          throw new Error(`Orphaned target node reference: ${edge.targetNodeId}`);
        }
        return edge.targetNodeId;
      }

      const { field, operator, value } = edge.condition;
      let actualValue: unknown;

      if (field === 'actionId') actualValue = actionPayload.actionId;
      if (field === 'isCorrect') actualValue = actionPayload.isCorrect;

      if (this.evaluateCondition(actualValue, operator, value)) {
        if (!allNodes[edge.targetNodeId]) {
          throw new Error(`Target node "${edge.targetNodeId}" not found in script definition.`);
        }
        return edge.targetNodeId;
      }
    }

    // If no conditioned edge matched, check if there's any fallback edge (one without conditions)
    const fallbackEdge = currentNode.transitions.find((e) => !e.condition);
    if (fallbackEdge && allNodes[fallbackEdge.targetNodeId]) {
      return fallbackEdge.targetNodeId;
    }

    throw new Error(
      `No matching transition found for node "${currentNode.id}" with action: ${JSON.stringify(actionPayload)}`
    );
  }

  private static evaluateCondition(
    actual: unknown,
    operator: string,
    expected: unknown
  ): boolean {
    switch (operator) {
      case 'EQUALS':
        return actual === expected;
      case 'NOT_EQUALS':
        return actual !== expected;
      case 'GREATER_THAN':
        return Number(actual) > Number(expected);
      case 'LESS_THAN':
        return Number(actual) < Number(expected);
      default:
        return false;
    }
  }
}
