export type NodeType = 'CONTENT' | 'CHOICE' | 'QUESTION' | 'TEXT_INPUT' | 'COMPLETION';
export type InputType = 'NONE' | 'CHOICE' | 'TEXT' | 'VOICE' | 'IMAGE';

export interface TransitionCondition {
  field: 'actionId' | 'isCorrect' | 'conceptScore';
  operator: 'EQUALS' | 'NOT_EQUALS' | 'GREATER_THAN' | 'LESS_THAN';
  value: string | number | boolean;
}

export interface TransitionEdge {
  targetNodeId: string;
  condition?: TransitionCondition;
}

export interface ChoiceOption {
  id: string;
  label: string;
  payload?: Record<string, unknown>;
}

export interface QuestionInlineData {
  prompt: string;
  options: Array<{ id: string; label: string }>;
  correctOptionId: string;
  explanation: string;
}

export interface LessonNode {
  id: string;
  type: NodeType;
  content: {
    text: string;
    mediaUrl?: string;
    avatarPersona?: 'TUTOR' | 'SYSTEM' | 'PEER';
  };
  input?: {
    type: InputType;
    options?: ChoiceOption[];
    placeholder?: string;
  };
  questionReference?: {
    mode: 'INLINE' | 'REPOSITORY';
    questionId?: string;
    inlineData?: QuestionInlineData;
  };
  transitions: TransitionEdge[];
  interruptible?: boolean;
}

export interface ScriptDefinition {
  schemaVersion: number;
  scriptId: string;
  version: number;
  entryNodeId: string;
  metadata: {
    title: string;
    subjectId: string;
    topicId: string;
    subtopicId?: string;
    targetDurationMinutes: number;
  };
  nodes: Record<string, LessonNode>;
}
