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
  public async createSession(userId: string, topicId?: string, subtopicIds?: string[], smartPicks = false) {
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
      const isUuid = (val: string) =>
        /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(val);

      const uuidSubtopicIds = resolvedSubtopicIds.filter(isUuid);
      const assignments =
        uuidSubtopicIds.length > 0
          ? await prisma.scriptAssignment.findMany({
              where: {
                OR: [
                  { id: { in: uuidSubtopicIds } },
                  { scriptId: { in: uuidSubtopicIds } },
                ],
              },
              include: { script: true },
            })
          : [];

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
        select: { id: true, slug: true, topicId: true },
      });

      // If not directly matched, check if passed IDs match lessonScript slugs or UUIDs
      if (foundSubtopics.length === 0) {
        const scripts = await prisma.lessonScript.findMany({
          where: {
            OR: [
              { slug: { in: Array.from(candidateSubtopicIds) } },
              ...(uuidSubtopicIds.length > 0 ? [{ id: { in: uuidSubtopicIds } }] : []),
            ],
          },
          select: { subtopicId: true, topicId: true },
        });
        const scriptSubtopicIds = scripts
          .map((s) => s.subtopicId)
          .filter((id): id is string => !!id);
        if (scriptSubtopicIds.length > 0) {
          const subsFromScripts = await prisma.subtopic.findMany({
            where: {
              OR: [
                { id: { in: scriptSubtopicIds } },
                { slug: { in: scriptSubtopicIds } },
              ],
              isActive: true,
            },
            select: { id: true, slug: true, topicId: true },
          });
          if (subsFromScripts.length > 0) {
            foundSubtopics.push(...subsFromScripts);
          }
        }
      }

      if (foundSubtopics.length > 0) {
        resolvedSubtopicIds = foundSubtopics.map(s => s.id);
        if (!resolvedTopicId) {
          resolvedTopicId = foundSubtopics[0].topicId;
        }
      } else {
        throw new Error('Selected subtopics are unavailable. Please update your selection.');
      }
      if (foundSubtopics.length !== candidateSubtopicIds.size) {
        throw new Error('Some selected subtopics are unavailable. Please update your selection.');
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

    if (topicId && (!resolvedSubtopicIds || !resolvedSubtopicIds.length)) {
      throw new Error('No available subtopics in this topic. Choose another topic.');
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
      10,
      smartPicks
    );
    if (questions.length !== 10) throw new Error('A practice session requires 10 questions.');

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
          pyq: sq.question.pyq,
          alternativeExplanation: isAnswered ? sq.question.alternativeExplanation : undefined,
          preferredSolution: isAnswered ? sq.question.preferredSolution : undefined,
          preferredReason: isAnswered ? sq.question.preferredReason : undefined,
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

    if (session.questions[session.currentIndex]?.id !== sessionQuestion.id) {
      throw new Error('Answer the current question first.');
    }
    if (!Number.isFinite(responseTimeMs) || responseTimeMs < 0 || responseTimeMs > 86400000) {
      throw new Error('Invalid response time.');
    }
    const question = sessionQuestion.question;
    const option = selectedOptionId.trim().toUpperCase();
    if (option !== 'TIMEOUT' && !(question.options as any[]).some(o => o.id === option)) {
      throw new Error('Choose a valid option.');
    }
    const isCorrect =
      selectedOptionId.trim().toUpperCase() === question.correctAnswer.trim().toUpperCase();

    // Perform database updates in a transaction
    return await prisma.$transaction(async (tx) => {
      // Serialize answers for this session and recheck after acquiring the lock.
      await tx.$queryRaw`SELECT id FROM learning.practice_sessions WHERE id = ${session.id}::uuid FOR UPDATE`;
      const lockedSession = await tx.practiceSession.findUnique({ where: { id: session.id } });
      if (lockedSession?.status !== 'ACTIVE') throw new Error('This session is no longer active.');
      const fresh = await tx.practiceSessionQuestion.findUnique({ where: { id: sessionQuestion.id } });
      if (fresh?.isAnswered) throw new Error('This question has already been answered.');
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
        // Different sessions for the same user may answer the same question.
        // Serialize their progress updates to avoid lost counts/create races.
        // Keep PostgreSQL's `void` lock return value out of Prisma's result set.
        await tx.$queryRaw<Array<{ locked: number }>>`
          SELECT 1::int AS locked
          FROM (SELECT pg_advisory_xact_lock(hashtext(${userId}))) AS practice_user_lock
        `;
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
                ((existingProg.avgResponseTimeMs ?? responseTimeMs) * existingProg.timesSeen + responseTimeMs) / (existingProg.timesSeen + 1)
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
      const newTotalTimeMs = updatedQuestions.reduce((sum, q) => sum + (q.responseTimeMs || 0), 0);

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

    await prisma.practiceSession.updateMany({
      where: { id: sessionId, userId, status: 'ACTIVE' },
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
      where: { id: originalSessionId, userId },
      include: {
        questions: {
          orderBy: { sequence: 'asc' },
        },
      },
    });

    if (!original) {
      throw new Error(`Practice session "${originalSessionId}" not found for replay.`);
    }

    if (original.questions.length !== 10) throw new Error('This older session does not contain 10 questions. Start a new session.');
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
        players: { select: { userId: true } },
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

    if (!match.players.some(player => player.userId === userId)) throw new Error('You can only replay your own matches.');
    const setQuestions = match.questionSet.setQuestions;
    if (setQuestions.length !== 10) {
      throw new Error('A replay requires a complete 10-question set.');
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
    const totals = await prisma.practiceSession.aggregate({
      where: { userId, isReplay: false, status: 'COMPLETED' },
      _count: true,
      _sum: { correctCount: true, totalQuestions: true, totalTimeMs: true },
    });
    const totalAnsweredQuestions = totals._sum.totalQuestions || 0;
    const totalCorrect = totals._sum.correctCount || 0;
    const totalTimeMs = totals._sum.totalTimeMs || 0;

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
        completedDrillsCount: totals._count,
        overallAccuracy,
        avgResponseTimeMs,
      },
    };
  }
}

export const practiceSessionService = PracticeSessionService.getInstance();
