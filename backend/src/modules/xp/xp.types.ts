export type QuestionType = 'PRACTICE' | 'UNRANKED' | 'RANKED';
export type QuestionDifficulty = 'EASY' | 'MEDIUM' | 'HARD';

export type XpSourceType =
  | 'SUBTOPIC_SCRIPT_COMPLETION'
  | 'TOPIC_COMPLETION'
  | 'QUESTION_COMPLETION';

export interface LevelProgressCalculation {
  currentLevel: number;
  currentLevelStartXp: number;
  nextLevel: number;
  nextLevelStartXp: number;
  xpIntoCurrentLevel: number;
  xpRequiredForNextLevel: number;
  xpRemainingToNextLevel: number;
  progress: number;
}

export interface XpProgressSummary extends LevelProgressCalculation {
  earned: number;
  previousTotal: number;
  total: number;
  level: number;
}

export interface LevelUpDetails {
  occurred: boolean;
  fromLevel: number;
  toLevel: number;
  levelsGained: number;
}

export interface AwardXpResult {
  awarded: boolean;
  xp: XpProgressSummary;
  levelUp: LevelUpDetails;
}

export interface AwardXpInput {
  userId: string;
  amount: number | bigint;
  sourceType: XpSourceType;
  idempotencyKey: string;
  sourceId?: string | null;
  roadmapId?: string | null;
  subjectId?: string | null;
  topicId?: string | null;
  subtopicId?: string | null;
  questionId?: string | null;
  lessonSessionId?: string | null;
  description?: string | null;
  metadata?: Record<string, unknown> | null;
}
