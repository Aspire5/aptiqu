import { prisma } from '../../config/prisma';
import { XpPolicy } from './xp.policy';
import {
  AwardXpInput,
  AwardXpResult,
  LevelProgressCalculation,
  XpProgressSummary,
} from './xp.types';

export class XpService {
  private static instance: XpService;

  public static getInstance(): XpService {
    if (!XpService.instance) {
      XpService.instance = new XpService();
    }
    return XpService.instance;
  }

  /**
   * Retrieves or initializes the user's progress.
   */
  public async getUserProgress(userId: string): Promise<XpProgressSummary> {
    let progress = await prisma.userProgress.findUnique({
      where: { userId },
    });

    if (!progress) {
      // Lazy initialize user_progress with Level 1, 0 XP
      progress = await prisma.userProgress.create({
        data: {
          userId,
          totalXp: BigInt(0),
          level: 1,
        },
      });
    }

    const totalXp = Number(progress.totalXp);
    const metrics = XpPolicy.getLevelProgress(totalXp);

    return {
      earned: 0,
      previousTotal: totalXp,
      total: totalXp,
      level: metrics.currentLevel,
      ...metrics,
    };
  }

  /**
   * Atomically awards XP to a user with strict idempotency and concurrency protection.
   */
  public async awardXp(input: AwardXpInput): Promise<AwardXpResult> {
    const {
      userId,
      amount,
      sourceType,
      idempotencyKey,
      sourceId,
      roadmapId,
      subjectId,
      topicId,
      subtopicId,
      questionId,
      lessonSessionId,
      description,
      metadata,
    } = input;

    const numericAmount = Math.max(0, typeof amount === 'bigint' ? Number(amount) : amount);

    try {
      return await prisma.$transaction(async (tx) => {
        // 1. Check if an XP event with this idempotency key already exists
        const existingEvent = await tx.xpEvent.findUnique({
          where: { idempotencyKey },
        });

        if (existingEvent) {
          // Return existing progress without double-awarding
          const progress = await tx.userProgress.findUnique({
            where: { userId },
          });

          const totalXp = progress ? Number(progress.totalXp) : 0;
          const metrics = XpPolicy.getLevelProgress(totalXp);

          return {
            awarded: false,
            xp: {
              earned: 0,
              previousTotal: totalXp,
              total: totalXp,
              level: metrics.currentLevel,
              ...metrics,
            },
            levelUp: {
              occurred: false,
              fromLevel: metrics.currentLevel,
              toLevel: metrics.currentLevel,
              levelsGained: 0,
            },
          };
        }

        // 2. Fetch or create user progress record
        let progress = await tx.userProgress.findUnique({
          where: { userId },
        });

        if (!progress) {
          progress = await tx.userProgress.create({
            data: {
              userId,
              totalXp: BigInt(0),
              level: 1,
            },
          });
        }

        const previousTotal = Number(progress.totalXp);
        const previousLevel = progress.level || XpPolicy.getLevelFromXp(previousTotal);

        // 3. Insert immutable XP event
        await tx.xpEvent.create({
          data: {
            userId,
            amount: BigInt(numericAmount),
            sourceType,
            sourceId: sourceId || null,
            roadmapId: roadmapId || null,
            subjectId: subjectId || null,
            topicId: topicId || null,
            subtopicId: subtopicId || null,
            questionId: questionId || null,
            lessonSessionId: lessonSessionId || null,
            description: description || null,
            metadata: (metadata as any) || undefined,
            idempotencyKey,
          },
        });

        // 4. Calculate new totals
        const newTotal = previousTotal + numericAmount;
        const newLevel = XpPolicy.getLevelFromXp(newTotal);
        const levelsGained = Math.max(0, newLevel - previousLevel);
        const levelUpOccurred = levelsGained > 0;

        // 5. Update user_progress
        await tx.userProgress.update({
          where: { userId },
          data: {
            totalXp: BigInt(newTotal),
            level: newLevel,
          },
        });

        // 6. Sync gameStats.level for backwards compatibility
        await tx.gameStats.upsert({
          where: { userId },
          update: { level: newLevel },
          create: {
            userId,
            level: newLevel,
            streak: 0,
            coins: 0,
          },
        });

        const metrics = XpPolicy.getLevelProgress(newTotal);

        // 7. Structured observability log
        console.log(
          JSON.stringify({
            event: 'XP_AWARDED',
            userId,
            sourceType,
            amount: numericAmount,
            previousTotal,
            newTotal,
            previousLevel,
            newLevel,
            levelsGained,
            idempotencyKey,
            timestamp: new Date().toISOString(),
          })
        );

        return {
          awarded: true,
          xp: {
            earned: numericAmount,
            previousTotal,
            total: newTotal,
            level: newLevel,
            ...metrics,
          },
          levelUp: {
            occurred: levelUpOccurred,
            fromLevel: previousLevel,
            toLevel: newLevel,
            levelsGained,
          },
        };
      });
    } catch (err: any) {
      if (err?.code === 'P2002') {
        // Race condition safely caught: another simultaneous request committed this idempotency key
        const progress = await prisma.userProgress.findUnique({
          where: { userId },
        });

        const totalXp = progress ? Number(progress.totalXp) : 0;
        const metrics = XpPolicy.getLevelProgress(totalXp);

        return {
          awarded: false,
          xp: {
            earned: 0,
            previousTotal: totalXp,
            total: totalXp,
            level: metrics.currentLevel,
            ...metrics,
          },
          levelUp: {
            occurred: false,
            fromLevel: metrics.currentLevel,
            toLevel: metrics.currentLevel,
            levelsGained: 0,
          },
        };
      }
      throw err;
    }
  }

  /**
   * Helper to award XP for a question attempt.
   */
  public async awardQuestionXp(params: {
    userId: string;
    clientActionId: string;
    questionType?: string | null;
    difficulty?: string | number | null;
    questionId?: string | null;
    nodeId?: string | null;
    sessionId?: string | null;
  }): Promise<AwardXpResult> {
    const amount = XpPolicy.calculateQuestionXp(params.questionType, params.difficulty);
    const normType = XpPolicy.normalizeQuestionType(params.questionType);
    const normDiff = XpPolicy.normalizeQuestionDifficulty(params.difficulty);

    const idempotencyKey = `question_attempt:${params.userId}:${params.clientActionId}`;

    return this.awardXp({
      userId: params.userId,
      amount,
      sourceType: 'QUESTION_COMPLETION',
      sourceId: params.questionId || params.nodeId || undefined,
      questionId: params.questionId || undefined,
      lessonSessionId: params.sessionId || undefined,
      idempotencyKey,
      description: `Question completed: ${normType} (${normDiff}) +${amount} XP`,
      metadata: {
        questionType: normType,
        difficulty: normDiff,
        typeXp: XpPolicy.QUESTION_TYPE_XP[normType],
        difficultyXp: XpPolicy.QUESTION_DIFFICULTY_XP[normDiff],
        nodeId: params.nodeId,
        clientActionId: params.clientActionId,
      },
    });
  }

  /**
   * Helper to award XP for subtopic script completion.
   */
  public async awardSubtopicCompletionXp(params: {
    userId: string;
    roadmapId?: string | null;
    roadmapStepId?: string | null;
    topicId?: string | null;
    subtopicId?: string | null;
    scriptId: string;
    scriptVersionId: string;
    sessionId: string;
  }): Promise<AwardXpResult> {
    const amount = XpPolicy.SUBTOPIC_SCRIPT_COMPLETION_XP;
    const roadmapKey = params.roadmapId || 'noroadmap';
    const idempotencyKey = `subtopic_completion:${params.userId}:${roadmapKey}:${params.scriptId}:${params.scriptVersionId}`;

    return this.awardXp({
      userId: params.userId,
      amount,
      sourceType: 'SUBTOPIC_SCRIPT_COMPLETION',
      sourceId: params.scriptId,
      roadmapId: params.roadmapId,
      topicId: params.topicId,
      subtopicId: params.subtopicId,
      lessonSessionId: params.sessionId,
      idempotencyKey,
      description: `Subtopic script completed: +${amount} XP`,
      metadata: {
        roadmapId: params.roadmapId,
        roadmapStepId: params.roadmapStepId,
        topicId: params.topicId,
        subtopicId: params.subtopicId,
        scriptId: params.scriptId,
        scriptVersionId: params.scriptVersionId,
        sessionId: params.sessionId,
      },
    });
  }

  /**
   * Helper to award XP for completing an entire topic in a roadmap.
   */
  public async awardTopicCompletionXp(params: {
    userId: string;
    roadmapId: string;
    topicId: string;
    requiredSubtopicCount: number;
    subjectId?: string | null;
  }): Promise<AwardXpResult> {
    const requiredCount = Math.max(1, params.requiredSubtopicCount);
    const amount = requiredCount * XpPolicy.TOPIC_COMPLETION_XP_PER_REQUIRED_SUBTOPIC;
    const idempotencyKey = `topic_completion:${params.userId}:${params.roadmapId}:${params.topicId}`;

    return this.awardXp({
      userId: params.userId,
      amount,
      sourceType: 'TOPIC_COMPLETION',
      sourceId: params.topicId,
      roadmapId: params.roadmapId,
      subjectId: params.subjectId,
      topicId: params.topicId,
      idempotencyKey,
      description: `Topic completed: +${amount} XP (${requiredCount} required subtopics)`,
      metadata: {
        requiredSubtopicCount: requiredCount,
        formula: '10 * requiredSubtopicCount',
        roadmapId: params.roadmapId,
        topicId: params.topicId,
      },
    });
  }
}

export const xpService = XpService.getInstance();
