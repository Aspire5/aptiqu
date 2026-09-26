import {
  LevelProgressCalculation,
  QuestionDifficulty,
  QuestionType,
} from './xp.types';

export class XpPolicy {
  // Authoritative constants
  public static readonly SUBTOPIC_SCRIPT_COMPLETION_XP = 20;
  public static readonly TOPIC_COMPLETION_XP_PER_REQUIRED_SUBTOPIC = 10;

  public static readonly QUESTION_TYPE_XP: Record<QuestionType, number> = {
    PRACTICE: 5,
    UNRANKED: 5,
    RANKED: 10,
  };

  public static readonly QUESTION_DIFFICULTY_XP: Record<QuestionDifficulty, number> = {
    EASY: 5,
    MEDIUM: 10,
    HARD: 15,
  };

  /**
   * Normalizes question mode / type to canonical uppercase enum.
   */
  public static normalizeQuestionType(rawType?: string | null): QuestionType {
    if (!rawType) return 'PRACTICE';
    const upper = rawType.trim().toUpperCase();
    if (upper === 'RANKED') return 'RANKED';
    if (upper === 'UNRANKED') return 'UNRANKED';
    return 'PRACTICE';
  }

  /**
   * Normalizes difficulty string or integer to canonical uppercase enum.
   */
  public static normalizeQuestionDifficulty(rawDifficulty?: string | number | null): QuestionDifficulty {
    if (rawDifficulty === undefined || rawDifficulty === null) return 'EASY';

    if (typeof rawDifficulty === 'number') {
      if (rawDifficulty >= 3) return 'HARD';
      if (rawDifficulty === 2) return 'MEDIUM';
      return 'EASY';
    }

    const upper = rawDifficulty.toString().trim().toUpperCase();
    if (upper === 'HARD' || upper === '3') return 'HARD';
    if (upper === 'MEDIUM' || upper === 'MED' || upper === '2') return 'MEDIUM';
    return 'EASY';
  }

  /**
   * Central formula: Question Reward = Type XP + Difficulty XP
   */
  public static calculateQuestionXp(
    rawType?: string | null,
    rawDifficulty?: string | number | null
  ): number {
    const type = this.normalizeQuestionType(rawType);
    const difficulty = this.normalizeQuestionDifficulty(rawDifficulty);

    const typeXp = this.QUESTION_TYPE_XP[type] ?? 5;
    const difficultyXp = this.QUESTION_DIFFICULTY_XP[difficulty] ?? 5;

    return typeXp + difficultyXp;
  }

  /**
   * Returns cumulative total XP required to reach Level L:
   * Total XP(L) = 10 * L * (L - 1)
   */
  public static getLevelStartXp(level: number): number {
    if (level <= 1) return 0;
    return 10 * level * (level - 1);
  }

  /**
   * Derives current Level from Total XP in O(1):
   * L = floor((1 + sqrt(1 + 0.4 * totalXp)) / 2)
   */
  public static getLevelFromXp(totalXp: bigint | number): number {
    const numericXp = typeof totalXp === 'bigint' ? Number(totalXp) : totalXp;
    if (numericXp <= 0 || isNaN(numericXp)) {
      return 1;
    }

    const calculated = Math.floor((1 + Math.sqrt(1 + 0.4 * numericXp)) / 2);
    return Math.max(1, calculated);
  }

  /**
   * Calculates comprehensive level progress metrics from total XP.
   */
  public static getLevelProgress(totalXp: bigint | number): LevelProgressCalculation {
    const numericXp = Math.max(0, typeof totalXp === 'bigint' ? Number(totalXp) : totalXp);
    const currentLevel = this.getLevelFromXp(numericXp);
    const currentLevelStartXp = this.getLevelStartXp(currentLevel);
    const nextLevel = currentLevel + 1;
    const nextLevelStartXp = this.getLevelStartXp(nextLevel);

    const xpIntoCurrentLevel = numericXp - currentLevelStartXp;
    const xpRequiredForNextLevel = nextLevelStartXp - currentLevelStartXp; // Equal to currentLevel * 20
    const xpRemainingToNextLevel = Math.max(0, nextLevelStartXp - numericXp);

    const rawProgress =
      xpRequiredForNextLevel > 0 ? xpIntoCurrentLevel / xpRequiredForNextLevel : 0;
    const progress = Math.min(1, Math.max(0, parseFloat(rawProgress.toFixed(4))));

    return {
      currentLevel,
      currentLevelStartXp,
      nextLevel,
      nextLevelStartXp,
      xpIntoCurrentLevel,
      xpRequiredForNextLevel,
      xpRemainingToNextLevel,
      progress,
    };
  }
}
