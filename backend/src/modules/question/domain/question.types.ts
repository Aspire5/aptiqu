export type QuestionOptionId = 'A' | 'B' | 'C' | 'D';

export interface QuestionOption {
  id: QuestionOptionId;
  text: string;
}

export type QuestionDifficulty = 'EASY' | 'MEDIUM' | 'HARD';
export type CalculationMode = 'MENTAL' | 'LIGHT_PEN_AND_PAPER' | 'PEN_AND_PAPER';
export type QuestionSourceType = 'MANUAL' | 'AI_GENERATED';
export type QuestionStatus = 'DRAFT' | 'REVIEW' | 'PUBLISHED' | 'ARCHIVED';
export type QuestionGenerationMethod = 'HUMAN_MANUAL' | 'AI_EXTRACTED' | 'AI_SYNTHETIC';
export type PreferredSolution = 'BOOK' | 'ALTERNATIVE';

export interface NormalizedQuestionInput {
  externalKey?: string;
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
  pyq?: string | null;
  alternativeExplanation?: string | null;
  preferredSolution?: PreferredSolution | null;
  preferredReason?: string | null;
  generationMethod?: QuestionGenerationMethod;
  sourceBook?: string | null;
  sourceEdition?: string | null;
  sourceChapter?: string | null;
  sourcePageRange?: string | null;
  generationModel?: string;
  generationPromptVersion?: string;
  generationJobId?: string;
}
