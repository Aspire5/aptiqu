import { BookProcessingStatus, QuestionDifficultyEnum, CalculationMode } from '@prisma/client';

export type QuestionType = 'MCQ' | 'NUMERICAL';

export interface BookUploadInput {
  title: string;
  author?: string;
  edition?: string;
  isbn?: string;
}

export interface DetectedTopicCandidate {
  code: string;
  name: string;
  suggestedSlug: string;
  startPage: number;
  endPage: number;
  description?: string;
  confidence: number;
}

export interface DiscoveredSubtopicCandidate {
  sequence: number;
  code: string;
  name: string;
  suggestedSlug: string;
  startPage: number;
  endPage: number;
  description: string;
  teachingMinutes?: number;
  importance?: 'CORE' | 'ADVANCED' | 'PRACTICE';
  keyConcepts: string[];
  keyFormulas?: string[];
  speedTricks?: string[];
}

export interface ExtractedQuestionCandidate {
  externalQuestionKey: string;
  externalSubtopicKey: string;
  pattern: string;
  prompt: string;
  questionType: string; // "MCQ"
  inputType: 'SINGLE_SELECT' | 'CHOICE';
  calculationMode: CalculationMode;
  difficulty: QuestionDifficultyEnum;
  estimatedTimeSeconds: number;
  options: Array<{ id: 'A' | 'B' | 'C' | 'D'; text: string }>;
  correctAnswer: 'A' | 'B' | 'C' | 'D';
  hints: string[];
  pyq?: string | null;
  method: string;
  explanation: string;
  alternativeExplanation?: string | null;
  preferredSolution?: 'BOOK' | 'ALTERNATIVE' | null;
  preferredReason?: string | null;
  sourceType: 'MANUAL';
  status: 'PUBLISHED' | 'DRAFT' | 'REVIEW';
  provenance: {
    sourceBook: string;
    sourceEdition?: string | null;
    sourceChapter?: string | null;
    sourcePageRange?: string | null;
  };
}

export interface BookIngestionProgress {
  bookId: string;
  subjectId: string;
  title: string;
  status: BookProcessingStatus;
  overallProgressPercent: number;
  stages: {
    pdfProcessing: { status: 'PENDING' | 'IN_PROGRESS' | 'COMPLETED' | 'FAILED'; progress: number; totalPages: number };
    topicDetection: { status: 'PENDING' | 'IN_PROGRESS' | 'COMPLETED' | 'FAILED'; progress: number; totalTopics: number };
    subtopicDiscovery: { status: 'PENDING' | 'IN_PROGRESS' | 'COMPLETED' | 'FAILED'; progress: number; totalSubtopics: number };
    questionExtraction: { status: 'PENDING' | 'IN_PROGRESS' | 'COMPLETED' | 'FAILED'; progress: number; totalQuestions: number };
    scriptGeneration: { status: 'PENDING' | 'IN_PROGRESS' | 'COMPLETED' | 'FAILED'; progress: number; completed: number; total: number };
    validation: { status: 'PENDING' | 'IN_PROGRESS' | 'COMPLETED' | 'FAILED'; progress: number; passed: number; flagged: number };
  };
  currentActivity?: string;
  reviewFlags: {
    ambiguousQuestions: number;
    lowConfidenceMappings: number;
  };
  errorMessage?: string | null;
}
