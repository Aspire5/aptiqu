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

    // 1. Resolve Subject for the Topic
    const topic = await prisma.topic.findUnique({
      where: { id: resolvedTopicId },
      include: { subject: true },
    });

    if (!topic) {
      throw new Error(`Topic "${resolvedTopicId}" not found.`);
    }

    // 2. Select 10 Questions
    const questions = await practiceSelectionService.selectQuestionsForPractice(
      userId,
      resolvedSubtopicIds,
      10
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

      // 2. Update UserQuestionProgress (history & mastery tracking)
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
        // Calculate XP for each correct question
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
}

export const practiceSessionService = PracticeSessionService.getInstance();
