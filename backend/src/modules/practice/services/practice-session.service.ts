import { log, safeError } from '../../../observability/logger';
import { PublicError } from '../../../security/errors';
import { matchQuestions } from '../../pvp/ranked/ranked-questions';
import { duelsService } from '../../social/duels.service';
import { lockUsers } from '../../social/friends.service';
import { socialTransport } from '../../social/social.transport';
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
        throw new PublicError('Selected subtopics are unavailable. Please update your selection.');
      }
      if (foundSubtopics.length !== candidateSubtopicIds.size) {
        throw new PublicError('Some selected subtopics are unavailable. Please update your selection.');
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
      throw new PublicError('No available subtopics in this topic. Choose another topic.');
    }
    // 4. Global live curriculum fallback if still empty
    if (!resolvedSubtopicIds || resolvedSubtopicIds.length === 0) {
      const { LiveCurriculumService } = await import('../../curriculum/services/live-curriculum.service');
      const liveUniverse = await LiveCurriculumService.getAllLiveCurriculumUniverse();
      const allSubtopics = liveUniverse.flatMap((u) => u.subtopics.map((s) => s.id));
      if (allSubtopics.length === 0) {
        throw new PublicError('No live topics or subtopics currently available for practice.');
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
      throw new PublicError(`Topic "${resolvedTopicId}" is inactive or not found.`);
    }

    resolvedTopicId = topic.id;

    log('info','practice_session_service.createSession.info');

    // 2. Select 10 Questions
    const questions = await practiceSelectionService.selectQuestionsForPractice(
      userId,
      resolvedSubtopicIds,
      10,
      smartPicks
    );
    if (questions.length !== 10) throw new PublicError('A practice session requires 10 questions.');

    log('info','practice_session_service.createSession.info');

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
  private async assertReplaySourceAvailable(session: { replaySourceType?: string | null; replaySourceId?: string | null }, userId: string, db: any = prisma) {
    const seen = new Set<string>();
    let source = session;
    // Include replay-of-replay chains created before this guard existed.
    for (let depth = 0; depth < 32; depth++) {
      if (!source.replaySourceType) return;
      const id = source.replaySourceId;
      const key = `${source.replaySourceType}:${id}`;
      if (!id || seen.has(key)) throw new PublicError('This replay source is unavailable.');
      seen.add(key);
      if (source.replaySourceType === 'PVP') {
        const match = await db.pvpMatch.findUnique({ where: { id }, select: { status: true, ratingMode: true, questionSnapshot: true, settlement: { select: { disposition: true } }, players: { select: { userId: true } } } });
        if (!match || match.status !== 'COMPLETED' || !match.players.some((p: { userId: string }) => p.userId === userId)) {
          throw new PublicError('Finish the Ranked match before opening its Practice replay.');
        }
        if (match.ratingMode === 'RATED' && match.settlement?.disposition !== 'RATED') throw new PublicError('The Ranked result is still finalizing. Please retry.');
        return match.questionSnapshot ? Object.fromEntries(matchQuestions({ ...match, questionSet: { setQuestions: [] } }).map(q => [q.id, q])) : undefined;
      }
      if (source.replaySourceType !== 'PRACTICE') throw new PublicError('This replay source is unavailable.');
      source = await db.practiceSession.findFirst({ where: { id, userId }, select: { replaySourceType: true, replaySourceId: true, isFriendlyDuel:true, friendlyDuel:{select:{status:true,questionSnapshot:true}} } });
      if (!source) throw new PublicError('This replay source is unavailable.');
      if ((source as any).isFriendlyDuel) {
        const duel = (source as any).friendlyDuel;
        if (!duel || !['COMPLETED','CANCELLED','EXPIRED','ABANDONED'].includes(duel.status)) throw new PublicError('Finish the friendly duel before opening its Practice replay.');
        return duel.questionSnapshot as Record<string,any>;
      }
    }
    throw new PublicError('This replay source chain is too long.');
  }

  public async getSession(sessionId: string, userId: string, txClient?: any) {
    const db = txClient || prisma;
    const session = await db.practiceSession.findFirst({
      where: { id: sessionId, userId },
      include: {
        friendlyDuel: { select: { questionSnapshot:true, status:true } },
        questions: {
          include: { question: true },
          orderBy: { sequence: 'asc' },
        },
      },
    });

    if (!session) {
      throw new PublicError(`Practice session "${sessionId}" not found.`);
    }
    const rankedReplay = await this.assertReplaySourceAvailable(session, userId, db);

    if (session.isFriendlyDuel && session.status === 'ACTIVE') {
      // A prompt is never available before its persistent server clock begins.
      await db.practiceSession.updateMany({where:{id:session.id,userId,status:'ACTIVE',currentIndex:session.currentIndex,questionStartedAt:null},data:{questionStartedAt:new Date()}});
    }
    // Sanitize question data so correct answer is NOT leaked to client before answer
    const sanitizedQuestions = session.questions.filter((sq: any) => !session.isFriendlyDuel || sq.sequence <= session.currentIndex + 1).map((sq: any) => {
      const isAnswered = sq.isAnswered;
      const q = rankedReplay?.[sq.questionId] ?? session.friendlyDuel?.questionSnapshot?.[sq.questionId] ?? sq.question;
      if (rankedReplay && !rankedReplay[sq.questionId]) throw new PublicError('This replay question is unavailable.');
      return {
        id: sq.id,
        sequence: sq.sequence,
        isAnswered: sq.isAnswered,
        userSelectedOptionId: sq.userSelectedOptionId,
        isCorrect: sq.isCorrect,
        responseTimeMs: sq.responseTimeMs,
        hintsRevealedCount: sq.hintsRevealedCount,
        question: {
          id: q.id,
          prompt: q.prompt,
          options: Array.isArray(q.options) ? q.options.map((o: any) => ({id:o.id,text:o.text ?? o.label})) : [],
          difficulty: q.difficulty,
          estimatedTimeSeconds: q.estimatedTimeSeconds,
          calculationMode: q.calculationMode,
          hints: q.hints,
          pattern: q.pattern,
          pyq: q.pyq,
          alternativeExplanation: isAnswered ? q.alternativeExplanation : undefined,
          preferredSolution: isAnswered ? q.preferredSolution : undefined,
          preferredReason: isAnswered ? q.preferredReason : undefined,
          // Only reveal correct answer & explanation if user already answered
          correctAnswer: isAnswered ? q.correctAnswer : undefined,
          explanation: isAnswered ? q.explanation : undefined,
          method: isAnswered ? q.method : undefined,
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
      isFriendlyDuel: session.isFriendlyDuel,
      friendlyDuelId: session.friendlyDuelId,
      timerEnabled: session.timerEnabled,
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
        friendlyDuel: { select: { questionSnapshot:true, status:true } },
        questions: {
          include: { question: true },
          orderBy: { sequence: 'asc' },
        },
      },
    });

    if (!session) {
      throw new PublicError(`Practice session "${sessionId}" not found.`);
    }
    const rankedReplay = await this.assertReplaySourceAvailable(session, userId);

    if (session.status !== 'ACTIVE') {
      throw new PublicError(`Session is already ${session.status}. No further answers accepted.`);
    }

    const sessionQuestion = session.questions.find((sq) => sq.questionId === questionId);
    if (!sessionQuestion) {
      throw new PublicError(`Question "${questionId}" does not belong to this session.`);
    }

    if (sessionQuestion.isAnswered) {
      throw new PublicError(`Question "${questionId}" has already been answered.`);
    }

    if (session.questions[session.currentIndex]?.id !== sessionQuestion.id) {
      throw new PublicError('Answer the current question first.');
    }
    if (!Number.isFinite(responseTimeMs) || responseTimeMs < 0 || responseTimeMs > 86400000) {
      throw new PublicError('Invalid response time.');
    }
    const deck = session.friendlyDuel?.questionSnapshot as Record<string, any> | undefined;
    if (session.isFriendlyDuel && !deck?.[questionId]) throw new PublicError('This friendly duel deck is unavailable.');
    if (rankedReplay && !rankedReplay[questionId]) throw new PublicError('This replay question is unavailable.');
    const question = rankedReplay?.[questionId] ?? deck?.[questionId] ?? sessionQuestion.question;
    const option = selectedOptionId.trim().toUpperCase();
    if (option !== 'TIMEOUT' && !(question.options as any[]).some(o => o.id === option)) {
      throw new PublicError('Choose a valid option.');
    }
    const isCorrect =
      selectedOptionId.trim().toUpperCase() === question.correctAnswer.trim().toUpperCase();

    if (session.isFriendlyDuel && !session.friendlyDuelId) throw new PublicError('This friendly duel is no longer available.');
    // Perform database updates in a transaction
    const result = await prisma.$transaction(async (tx) => {
      if (session.friendlyDuelId) {
        const duel = await tx.friendlyDuel.findUnique({ where: { id: session.friendlyDuelId } });
        if (!duel) throw new PublicError('Duel not found.');
        await lockUsers(tx, [duel.requesterId, duel.recipientId]);
        await tx.$queryRaw`SELECT id FROM learning.friendly_duels WHERE id=${duel.id}::uuid FOR UPDATE`;
        const live = await tx.friendlyDuel.findUnique({ where: { id: duel.id } });
        if (live?.status !== 'ACTIVE' || (live.matchExpiresAt && live.matchExpiresAt.getTime() <= Date.now())) throw new PublicError('This duel is no longer active.');
      }
      // Serialize answers for this session and recheck after acquiring the lock.
      await tx.$queryRaw`SELECT id FROM learning.practice_sessions WHERE id = ${session.id}::uuid FOR UPDATE`;
      const lockedSession = await tx.practiceSession.findUnique({ where: { id: session.id } });
      if (lockedSession?.status !== 'ACTIVE') throw new PublicError('This session is no longer active.');
      const fresh = await tx.practiceSessionQuestion.findUnique({ where: { id: sessionQuestion.id } });
      if (fresh?.isAnswered) throw new PublicError('This question has already been answered.');
      let recordedTime = responseTimeMs;
      let recordedOption = selectedOptionId.trim().toUpperCase();
      let recordedCorrect = isCorrect;
      if (session.isFriendlyDuel) {
        if (!lockedSession.questionStartedAt) throw new PublicError('Start the current question before answering.');
        recordedTime = Math.max(0, Date.now() - lockedSession.questionStartedAt.getTime());
        if (session.timerEnabled && recordedTime >= 60000) { recordedOption = 'TIMEOUT'; recordedCorrect = false; }
        else if (recordedOption === 'TIMEOUT') throw new PublicError('The question timer has not expired.');
      }
      // 1. Update PracticeSessionQuestion
      await tx.practiceSessionQuestion.update({
        where: { id: sessionQuestion.id },
        data: {
          isAnswered: true,
          userSelectedOptionId: recordedOption,
          isCorrect: recordedCorrect,
          responseTimeMs: recordedTime,
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
              timesCorrect: existingProg.timesCorrect + (recordedCorrect ? 1 : 0),
              lastSeenAt: new Date(),
              lastIsCorrect: recordedCorrect,
              avgResponseTimeMs: Math.round(
                ((existingProg.avgResponseTimeMs ?? recordedTime) * existingProg.timesSeen + recordedTime) / (existingProg.timesSeen + 1)
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
              timesCorrect: recordedCorrect ? 1 : 0,
              lastSeenAt: new Date(),
              lastIsCorrect: recordedCorrect,
              avgResponseTimeMs: recordedTime,
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
        if (!session.isReplay && !session.isFriendlyDuel) {
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
            }, tx);
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
            questionStartedAt: null,
          },
        });
      }
      if (session.friendlyDuelId && isComplete) await duelsService.finalizeInTransaction(tx, session.friendlyDuelId);
      const finalSession = session.friendlyDuelId ? await tx.practiceSession.findUnique({ where: { id: session.id } }) : null;

      return {
        isCorrect: recordedCorrect,
        correctAnswer: question.correctAnswer,
        explanation: question.explanation,
        method: question.method,
        alternativeExplanation: question.alternativeExplanation,
        preferredSolution: question.preferredSolution,
        preferredReason: question.preferredReason,
        isComplete,
        totalAnswered: answeredCount,
        correctCount: newCorrectCount,
        xpAwarded: finalSession?.xpAwarded ?? totalXpToAward,
        xpResult,
      };
    });
    if (session.friendlyDuelId) {
      const duel = await prisma.friendlyDuel.findUnique({ where: { id: session.friendlyDuelId } });
      if (duel?.status === 'COMPLETED' && duelsService.clearSchedule) await duelsService.clearSchedule(duel.id).catch(() => {});
      if (duel) await socialTransport.notify([duel.requesterId, duel.recipientId], 'DUEL_CHANGED', duel.id);
    }
    return result;
  }

  async startFriendlyQuestion(sessionId: string, userId: string) {
    return prisma.$transaction(async tx => {
      await tx.$queryRaw`SELECT id FROM learning.practice_sessions WHERE id=${sessionId}::uuid AND user_id=${userId}::uuid FOR UPDATE`;
      const session = await tx.practiceSession.findFirst({ where: { id: sessionId, userId, status: 'ACTIVE', isFriendlyDuel: true }, include: { friendlyDuel: true } });
      if (!session || session.friendlyDuel?.status !== 'ACTIVE' || (session.friendlyDuel.matchExpiresAt && session.friendlyDuel.matchExpiresAt.getTime() <= Date.now())) throw new PublicError('This duel is no longer active.');
      const started = session.questionStartedAt ?? new Date();
      if (!session.questionStartedAt) await tx.practiceSession.update({ where: { id: sessionId }, data: { questionStartedAt: started } });
      return { session: await this.getSession(sessionId,userId,tx), remainingMs: Math.max(0, 60000 - (Date.now() - started.getTime())), timerEnabled: session.timerEnabled };
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
      throw new PublicError(`Practice session "${sessionId}" not found.`);
    }

    if (session.friendlyDuelId) { await duelsService.abandon(userId, session.friendlyDuelId); return { success: true, xpAwarded: session.xpAwarded }; }
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
        friendlyDuel: { select: { questionSnapshot:true, status:true } },
        questions: {
          orderBy: { sequence: 'asc' },
        },
      },
    });

    if (!original) {
      throw new PublicError(`Practice session "${originalSessionId}" not found for replay.`);
    }
    if (original.isFriendlyDuel && (!original.friendlyDuel || !['COMPLETED','CANCELLED','EXPIRED','ABANDONED'].includes((original.friendlyDuel as any).status))) throw new PublicError('Finish the friendly duel before opening its Practice replay.');
    await this.assertReplaySourceAvailable(original, userId);

    if (original.questions.length !== 10) throw new PublicError('This older session does not contain 10 questions. Start a new session.');
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
        settlement: { select: { disposition: true } },
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
      throw new PublicError(`PvP Match "${matchId}" not found for replay.`);
    }

    if (!match.players.some(player => player.userId === userId)) throw new PublicError('You can only replay your own matches.');
    if (match.status !== 'COMPLETED') throw new PublicError('Finish the Ranked match before opening its Practice replay.');
    if (match.ratingMode === 'RATED' && match.settlement?.disposition !== 'RATED') throw new PublicError('The Ranked result is still finalizing. Please retry.');
    const frozen = match.questionSnapshot ? matchQuestions(match) : null;
    const setQuestions = frozen ? frozen.map(question => ({ questionId: question.id, question })) : match.questionSet.setQuestions;
    if (setQuestions.length !== 10) {
      throw new PublicError('A replay requires a complete 10-question set.');
    }

    const firstQuestion = frozen ? await prisma.question.findUniqueOrThrow({ where: { id: frozen[0].id } }) : match.questionSet.setQuestions[0].question;

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
  // CACHE_CANDIDATE ref=C10 scope=user layer=redis ttl=5-10s owner=practice
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
