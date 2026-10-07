import { prisma } from '../../../config/prisma';
import { practiceSelectionService } from './practice-selection.service';
import { XpService } from '../../xp/xp.service';
import { XpPolicy } from '../../xp/xp.policy';

export class PracticeSessionService {
  private static instance: PracticeSessionService;

  public static getInstance(): PracticeSessionService {
    if (!PracticeSessionService.instance) {
      PracticeSessionService.instance = new PracticeSessionService();
    }
    return PracticeSessionService.instance;
  }

  /**
   * Initializes and persists a new 10-Question Practice Session.
   * Supports specific topic/subtopics or global random selection across live content.
   */
  public async createSession(userId: string, topicId?: string, subtopicIds?: string[]) {
    let resolvedSubtopicIds = subtopicIds;
    let resolvedTopicId = topicId;

    // 1. Resolve Topic by ID or slug
    if (resolvedTopicId) {
      const topicRecord = await prisma.topic.findFirst({
        where: {
          OR: [
            { id: resolvedTopicId },
            { slug: resolvedTopicId },
          ],
        },
      });
      if (topicRecord) {
        resolvedTopicId = topicRecord.id;
      }
    }

    // 2. If subtopicIds were provided, resolve any ScriptAssignment IDs or slugs to actual subtopic IDs
    if (resolvedSubtopicIds && resolvedSubtopicIds.length > 0) {
      const assignments = await prisma.scriptAssignment.findMany({
        where: {
          OR: [
            { id: { in: resolvedSubtopicIds } },
            { scriptId: { in: resolvedSubtopicIds } },
          ],
        },
        include: { script: true },
      });

      const candidateSubtopicIds = new Set<string>();
      for (const id of resolvedSubtopicIds) {
        const matchingSa = assignments.find((a) => a.id === id || a.scriptId === id);
        if (matchingSa?.script?.subtopicId) {
          candidateSubtopicIds.add(matchingSa.script.subtopicId);
        } else {
          candidateSubtopicIds.add(id);
        }
      }

      // Query active subtopics by ID or slug
      const foundSubtopics = await prisma.subtopic.findMany({
        where: {
          OR: [
            { id: { in: Array.from(candidateSubtopicIds) } },
            { slug: { in: Array.from(candidateSubtopicIds) } },
          ],
          isActive: true,
        },
        select: { id: true, topicId: true },
      });

      if (foundSubtopics.length > 0) {
        resolvedSubtopicIds = foundSubtopics.map((s) => s.id);
        if (!resolvedTopicId) {
          resolvedTopicId = foundSubtopics[0].topicId;
        }
      } else if (resolvedTopicId) {
        // Fallback: If passed IDs were not directly matched, find all active subtopics under this topic
        const topicSubs = await prisma.subtopic.findMany({
          where: {
            topicId: resolvedTopicId,
            isActive: true,
          },
          select: { id: true },
          orderBy: { sequence: 'asc' },
        });
        if (topicSubs.length > 0) {
          resolvedSubtopicIds = topicSubs.map((s) => s.id);
        }
      }
    }

    // 3. If no subtopicIds resolved yet, load all active subtopics for resolvedTopicId
    if (resolvedTopicId && (!resolvedSubtopicIds || resolvedSubtopicIds.length === 0)) {
      const topicSubtopics = await prisma.subtopic.findMany({
        where: {
          topicId: resolvedTopicId,
          isActive: true,
        },
        select: { id: true },
        orderBy: { sequence: 'asc' },
      });
      if (topicSubtopics.length > 0) {
        resolvedSubtopicIds = topicSubtopics.map((s) => s.id);
      }
    }

    // 4. Global live curriculum fallback if still empty
    if (!resolvedSubtopicIds || resolvedSubtopicIds.length === 0) {
      const { LiveCurriculumService } = await import('../../curriculum/services/live-curriculum.service');
      const liveUniverse = await LiveCurriculumService.getAllLiveCurriculumUniverse();
      const allSubtopics = liveUniverse.flatMap((u) => u.subtopics.map((s) => s.id));
      if (allSubtopics.length === 0) {
        throw new Error('No live topics or subtopics currently available for practice.');
      }
      resolvedSubtopicIds = allSubtopics;
      if (!resolvedTopicId && liveUniverse.length > 0) {
        resolvedTopicId = liveUniverse[0].topicId;
      }
    }

    if (!resolvedTopicId && resolvedSubtopicIds.length > 0) {
      const sub = await prisma.subtopic.findUnique({
        where: { id: resolvedSubtopicIds[0] },
      });
      resolvedTopicId = sub?.topicId;
    }

    if (!resolvedTopicId) {
      resolvedTopicId = 'qa-foundations';
    }

    // Resolve Topic and verify active
    const topic = await prisma.topic.findFirst({
      where: {
        OR: [
          { id: resolvedTopicId },
          { slug: resolvedTopicId },
        ],
      },
      include: { subject: true },
    });

    if (!topic || !topic.isActive || (topic.subject && !topic.subject.isActive)) {
      throw new Error(`Topic "${resolvedTopicId}" is inactive or not found.`);
    }

    resolvedTopicId = topic.id;

    console.log(
      `[PracticeSession] Initiating practice session creation for user "${userId}", topic "${resolvedTopicId}", subtopics [${resolvedSubtopicIds.join(', ')}]`
    );

    // 2. Select 10 Questions
    const questions = await practiceSelectionService.selectQuestionsForPractice(
      userId,
      resolvedSubtopicIds,
      10
    );

    console.log(
      `[PracticeSession] Selected ${questions.length} questions. Saving practice session to database...`
    );

    // 3. Create Session in PostgreSQL
    return await prisma.$transaction(async (tx) => {
      const session = await tx.practiceSession.create({
        data: {
          userId,
          subjectId: topic.subjectId,
          topicId: topic.id,
          subtopicIds: resolvedSubtopicIds,
          status: 'ACTIVE',
          currentIndex: 0,
          totalQuestions: questions.length,
          correctCount: 0,
          totalTimeMs: 0,
          xpAwarded: 0,
        },
      });

      for (let i = 0; i < questions.length; i++) {
        await tx.practiceSessionQuestion.create({
          data: {
            sessionId: session.id,
            questionId: questions[i].id,
            sequence: i + 1,
            isAnswered: false,
          },
        });
      }

      return await this.getSession(session.id, userId, tx);
    });
  }

  /**
   * Retrieves an active practice session and securely masks correct answers for unanswered questions.
   */
  public async getSession(sessionId: string, userId: string, txClient?: any) {
    const db = txClient || prisma;
    const session = await db.practiceSession.findFirst({
      where: { id: sessionId, userId },
      include: {
        questions: {
          include: { question: true },
          orderBy: { sequence: 'asc' },
        },
      },
    });

    if (!session) {
      throw new Error(`Practice session "${sessionId}" not found.`);
    }

    // Sanitize question data so correct answer is NOT leaked to client before answer
    const sanitizedQuestions = session.questions.map((sq: any) => {
      const isAnswered = sq.isAnswered;
      return {
        id: sq.id,
        sequence: sq.sequence,
        isAnswered: sq.isAnswered,
        userSelectedOptionId: sq.userSelectedOptionId,
        isCorrect: sq.isCorrect,
        responseTimeMs: sq.responseTimeMs,
        hintsRevealedCount: sq.hintsRevealedCount,
        question: {
          id: sq.question.id,
          prompt: sq.question.prompt,
          options: sq.question.options,
          difficulty: sq.question.difficulty,
          estimatedTimeSeconds: sq.question.estimatedTimeSeconds,
          calculationMode: sq.question.calculationMode,
          hints: sq.question.hints,
          pattern: sq.question.pattern,
          // Only reveal correct answer & explanation if user already answered
          correctAnswer: isAnswered ? sq.question.correctAnswer : undefined,
          explanation: isAnswered ? sq.question.explanation : undefined,
          method: isAnswered ? sq.question.method : undefined,
        },
      };
    });

    return {
      id: session.id,
      userId: session.userId,
      subjectId: session.subjectId,
      topicId: session.topicId,
      subtopicIds: session.subtopicIds,
      status: session.status,
      currentIndex: session.currentIndex,
      totalQuestions: session.totalQuestions,
      correctCount: session.correctCount,
      totalTimeMs: session.totalTimeMs,
      xpAwarded: session.xpAwarded,
      isReplay: session.isReplay,
      replaySourceType: session.replaySourceType,
      replaySourceId: session.replaySourceId,
      startedAt: session.startedAt,
      completedAt: session.completedAt,
      questions: sanitizedQuestions,
    };
  }

  /**
   * Submits an answer for a question in a practice session.
   * Enforces that XP is ONLY awarded when all required questions are answered.
   */
  public async submitAnswer(params: {
    sessionId: string;
    userId: string;
    questionId: string;
    selectedOptionId: string;
    responseTimeMs: number;
  }) {
    const { sessionId, userId, questionId, selectedOptionId, responseTimeMs } = params;

    const session = await prisma.practiceSession.findFirst({
      where: { id: sessionId, userId },
      include: {
        questions: {
          include: { question: true },
          orderBy: { sequence: 'asc' },
        },
      },
    });

    if (!session) {
      throw new Error(`Practice session "${sessionId}" not found.`);
    }

    if (session.status !== 'ACTIVE') {
      throw new Error(`Session is already ${session.status}. No further answers accepted.`);
    }

    const sessionQuestion = session.questions.find((sq) => sq.questionId === questionId);
    if (!sessionQuestion) {
      throw new Error(`Question "${questionId}" does not belong to this session.`);
    }

    if (sessionQuestion.isAnswered) {
      throw new Error(`Question "${questionId}" has already been answered.`);
    }

    const question = sessionQuestion.question;
    const isCorrect =
      selectedOptionId.trim().toUpperCase() === question.correctAnswer.trim().toUpperCase();

    // Perform database updates in a transaction
    return await prisma.$transaction(async (tx) => {
      // 1. Update PracticeSessionQuestion
      await tx.practiceSessionQuestion.update({
        where: { id: sessionQuestion.id },
        data: {
          isAnswered: true,
          userSelectedOptionId: selectedOptionId.trim().toUpperCase(),
          isCorrect,
          responseTimeMs,
          answeredAt: new Date(),
        },
      });

      // 2. Update UserQuestionProgress (history & mastery tracking) ONLY for regular drills (not replays)
      if (!session.isReplay) {
        const existingProg = await tx.userQuestionProgress.findUnique({
          where: {
            userId_questionId: {
              userId,
              questionId,
            },
          },
        });

        if (existingProg) {
          await tx.userQuestionProgress.update({
            where: { id: existingProg.id },
            data: {
              timesSeen: existingProg.timesSeen + 1,
              timesCorrect: existingProg.timesCorrect + (isCorrect ? 1 : 0),
              lastSeenAt: new Date(),
              lastIsCorrect: isCorrect,
              avgResponseTimeMs: Math.round(
                ((existingProg.avgResponseTimeMs || responseTimeMs) + responseTimeMs) / 2
              ),
            },
          });
        } else {
          await tx.userQuestionProgress.create({
            data: {
              userId,
              questionId,
              subtopicId: question.subtopicId,
              timesSeen: 1,
              timesCorrect: isCorrect ? 1 : 0,
              lastSeenAt: new Date(),
              lastIsCorrect: isCorrect,
              avgResponseTimeMs: responseTimeMs,
            },
          });
        }
      }

      // 3. Count remaining unanswered questions
      const updatedQuestions = await tx.practiceSessionQuestion.findMany({
        where: { sessionId: session.id },
        include: { question: true },
      });

      const answeredCount = updatedQuestions.filter((q) => q.isAnswered).length;
      const isComplete = answeredCount === session.totalQuestions;
      const newCorrectCount = updatedQuestions.filter((q) => q.isCorrect).length;
      const newTotalTimeMs = session.totalTimeMs + responseTimeMs;

      let xpResult: any = null;
      let totalXpToAward = 0;

      if (isComplete) {
        // Calculate XP for each correct question ONLY if NOT a replay
        if (!session.isReplay) {
          for (const sq of updatedQuestions) {
            if (sq.isCorrect) {
              const qXp = XpPolicy.calculateQuestionXp('PRACTICE', sq.question.difficulty);
              totalXpToAward += qXp;
            }
          }

          // Authoritatively award XP via centralized XpService
          if (totalXpToAward > 0) {
            xpResult = await XpService.getInstance().awardXp({
              userId,
              amount: totalXpToAward,
              sourceType: 'PRACTICE',
              sourceId: session.id,
              idempotencyKey: `practice:session:${session.id}`,
              subjectId: session.subjectId,
              topicId: session.topicId,
              description: `Completed 10-Question Practice Session on ${session.topicId}`,
            });
          }
        }

        // Mark session as COMPLETED
        await tx.practiceSession.update({
          where: { id: session.id },
          data: {
            status: 'COMPLETED',
            currentIndex: session.totalQuestions - 1,
            correctCount: newCorrectCount,
            totalTimeMs: newTotalTimeMs,
            xpAwarded: totalXpToAward,
            completedAt: new Date(),
            lastActivityAt: new Date(),
          },
        });
      } else {
        // Advance current index
        await tx.practiceSession.update({
          where: { id: session.id },
          data: {
            currentIndex: Math.min(session.currentIndex + 1, session.totalQuestions - 1),
            correctCount: newCorrectCount,
            totalTimeMs: newTotalTimeMs,
            lastActivityAt: new Date(),
          },
        });
      }

      return {
        isCorrect,
        correctAnswer: question.correctAnswer,
        explanation: question.explanation,
        method: question.method,
        alternativeExplanation: question.alternativeExplanation,
        preferredSolution: question.preferredSolution,
        preferredReason: question.preferredReason,
        isComplete,
        totalAnswered: answeredCount,
        correctCount: newCorrectCount,
        xpAwarded: totalXpToAward,
        xpResult,
      };
    });
  }

  /**
   * Abandons an active practice session.
   * Strictly awards 0 completion XP for unanswered questions.
   */
  public async abandonSession(sessionId: string, userId: string) {
    const session = await prisma.practiceSession.findFirst({
      where: { id: sessionId, userId },
    });

    if (!session) {
      throw new Error(`Practice session "${sessionId}" not found.`);
    }

    if (session.status === 'COMPLETED') {
      return { success: true, message: 'Session already completed.', xpAwarded: session.xpAwarded };
    }

    await prisma.practiceSession.update({
      where: { id: sessionId },
      data: {
        status: 'ABANDONED',
        lastActivityAt: new Date(),
      },
    });

    return {
      success: true,
      message: 'Session marked as abandoned. Zero completion XP awarded.',
      xpAwarded: 0,
    };
  }

  /**
   * Replays an existing practice session as an untimed practice drill with 0 rewards.
   */
  public async replayPracticeSession(userId: string, originalSessionId: string) {
    const original = await prisma.practiceSession.findFirst({
      where: { id: originalSessionId },
      include: {
        questions: {
          orderBy: { sequence: 'asc' },
        },
      },
    });

    if (!original) {
      throw new Error(`Practice session "${originalSessionId}" not found for replay.`);
    }

    return await prisma.$transaction(async (tx) => {
      const replaySession = await tx.practiceSession.create({
        data: {
          userId,
          subjectId: original.subjectId,
          topicId: original.topicId,
          subtopicIds: original.subtopicIds,
          status: 'ACTIVE',
          currentIndex: 0,
          totalQuestions: original.questions.length,
          correctCount: 0,
          totalTimeMs: 0,
          xpAwarded: 0,
          isReplay: true,
          replaySourceType: 'PRACTICE',
          replaySourceId: original.id,
        },
      });

      for (let i = 0; i < original.questions.length; i++) {
        await tx.practiceSessionQuestion.create({
          data: {
            sessionId: replaySession.id,
            questionId: original.questions[i].questionId,
            sequence: i + 1,
            isAnswered: false,
          },
        });
      }

      return await this.getSession(replaySession.id, userId, tx);
    });
  }

  /**
   * Replays a PvP Match as a solo Practice drill (no timer, no second user, 0 rewards).
   * Logs are recorded as Practice sessions so they automatically appear in Practice history!
   */
  public async replayPvpMatch(userId: string, matchId: string) {
    const match = await prisma.pvpMatch.findUnique({
      where: { id: matchId },
      include: {
        questionSet: {
          include: {
            setQuestions: {
              include: { question: true },
              orderBy: { sequence: 'asc' },
            },
          },
        },
      },
    });

    if (!match || !match.questionSet) {
      throw new Error(`PvP Match "${matchId}" not found for replay.`);
    }

    const setQuestions = match.questionSet.setQuestions;
    if (setQuestions.length === 0) {
      throw new Error('PvP match question set contains no questions.');
    }

    const firstQuestion = setQuestions[0].question;

    return await prisma.$transaction(async (tx) => {
      const replaySession = await tx.practiceSession.create({
        data: {
          userId,
          subjectId: firstQuestion.subjectId,
          topicId: firstQuestion.topicId,
          subtopicIds: [firstQuestion.subtopicId],
          status: 'ACTIVE',
          currentIndex: 0,
          totalQuestions: setQuestions.length,
          correctCount: 0,
          totalTimeMs: 0,
          xpAwarded: 0,
          isReplay: true,
          replaySourceType: 'PVP',
          replaySourceId: match.id,
        },
      });

      for (let i = 0; i < setQuestions.length; i++) {
        await tx.practiceSessionQuestion.create({
          data: {
            sessionId: replaySession.id,
            questionId: setQuestions[i].questionId,
            sequence: i + 1,
            isAnswered: false,
          },
        });
      }

      return await this.getSession(replaySession.id, userId, tx);
    });
  }

  /**
   * Retrieves paginated Practice history (including replays & PvP replays).
   * Replays do not inflate user average speed stats.
   */
  public async getHistory(userId: string, page = 1, limit = 10) {
    const skip = (page - 1) * limit;

    const [items, totalCount] = await Promise.all([
      prisma.practiceSession.findMany({
        where: { userId },
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
      }),
      prisma.practiceSession.count({ where: { userId } }),
    ]);

    // Compute stats only over non-replay completed sessions
    const nonReplayCompleted = await prisma.practiceSession.findMany({
      where: { userId, isReplay: false, status: 'COMPLETED' },
      select: { correctCount: true, totalQuestions: true, totalTimeMs: true },
    });

    const totalAnsweredQuestions = nonReplayCompleted.reduce(
      (sum, s) => sum + s.totalQuestions,
      0
    );
    const totalCorrect = nonReplayCompleted.reduce((sum, s) => sum + s.correctCount, 0);
    const totalTimeMs = nonReplayCompleted.reduce((sum, s) => sum + s.totalTimeMs, 0);

    const overallAccuracy =
      totalAnsweredQuestions > 0 ? Math.round((totalCorrect / totalAnsweredQuestions) * 100) : 0;
    const avgResponseTimeMs =
      totalAnsweredQuestions > 0 ? Math.round(totalTimeMs / totalAnsweredQuestions) : 0;

    return {
      history: items.map((s) => ({
        id: s.id,
        topicId: s.topicId,
        subjectId: s.subjectId,
        status: s.status,
        correctCount: s.correctCount,
        totalQuestions: s.totalQuestions,
        totalTimeMs: s.totalTimeMs,
        xpAwarded: s.xpAwarded,
        isReplay: s.isReplay,
        replaySourceType: s.replaySourceType,
        replaySourceId: s.replaySourceId,
        startedAt: s.startedAt,
        completedAt: s.completedAt,
        createdAt: s.createdAt,
      })),
      pagination: {
        page,
        limit,
        totalCount,
        totalPages: Math.ceil(totalCount / limit),
      },
      stats: {
        completedDrillsCount: nonReplayCompleted.length,
        overallAccuracy,
        avgResponseTimeMs,
      },
    };
  }
}

export const practiceSessionService = PracticeSessionService.getInstance();
