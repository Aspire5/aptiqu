export type QuestionOptionId = 'A' | 'B' | 'C' | 'D';

export interface QuestionOption {
  id: QuestionOptionId;
  text: string;
}

export type QuestionDifficulty = 'EASY' | 'MEDIUM' | 'HARD';
export type CalculationMode = 'MENTAL' | 'LIGHT_PEN_AND_PAPER' | 'PEN_AND_PAPER';
export type QuestionSourceType = 'MANUAL' | 'AI_GENERATED';
export type QuestionStatus = 'DRAFT' | 'REVIEW' | 'PUBLISHED' | 'ARCHIVED';

export interface NormalizedQuestionInput {
  pattern?: string;
  prompt: string;
  options: QuestionOption[];
  correctAnswer: QuestionOptionId;
  difficulty: QuestionDifficulty;
  estimatedTimeSeconds: number;
  calculationMode: CalculationMode;
  hints: string[];
  method: string;
  explanation: string;
  subjectId: string;
  topicId: string;
  subtopicId: string;
  conceptId?: string;
  sourceType?: QuestionSourceType;
  status?: QuestionStatus;
  generationModel?: string;
  generationPromptVersion?: string;
  generationJobId?: string;
}
