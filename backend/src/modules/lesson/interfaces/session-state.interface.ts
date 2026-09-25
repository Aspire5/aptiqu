import { LessonNode } from './script-dsl.interface';

export interface SessionStateData {
  variables: Record<string, string | number | boolean>;
  visitedNodeIds: string[];
  currentQuestionId?: string;
  lastAttemptCorrect?: boolean;
}

export interface TransitionResult {
  nextNode: LessonNode;
  isCompleted: boolean;
  evaluation?: {
    isCorrect: boolean;
    score: number;
    explanation?: string;
  };
}
