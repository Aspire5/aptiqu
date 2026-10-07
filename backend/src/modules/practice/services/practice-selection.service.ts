import { prisma } from '../../../config/prisma';
import { INVENTORY_CONFIG } from '../../../config/inventory.config';
import { questionGenerationService } from '../../ai/services/question-generation.service';
import { LiveCurriculumService } from '../../curriculum/services/live-curriculum.service';
import { contentGenQueue } from '../../../queues/content-generation.queue';

export class PracticeSelectionService {
  private static instance: PracticeSelectionService;

  public static getInstance(): PracticeSelectionService {
    if (!PracticeSelectionService.instance) {
      PracticeSelectionService.instance = new PracticeSelectionService();
    }
    return PracticeSelectionService.instance;
  }

  /**
   * Selects candidate questions for a user across selected subtopics.
   * INVARIANT: No AI question may appear while an eligible unsolved MANUAL question exists.
   */
  public async selectQuestionsForPractice(
    userId: string,
    subtopicIds: string[],
    count = INVENTORY_CONFIG.PRACTICE_SESSION_QUESTIONS_COUNT
  ): Promise<any[]> {
    if (subtopicIds.length === 0) {
      throw new Error('At least one subtopic must be selected for Practice.');
    }

    // 1. Verify all subtopics are live
    for (const subId of subtopicIds) {
      const isLive = await LiveCurriculumService.isSubtopicLive(subId);
      if (!isLive) {
        throw new Error(`Subtopic "${subId}" is locked or not live.`);
      }
    }

    // 2. QUERY SCALABLE DATABASE-LEVEL: Eligible unsolved MANUAL questions
    // Inactive subjects/topics/subtopics are strictly excluded.
    // Unsolved = user has never answered correctly (userProgress.none with timesCorrect > 0)
    const unsolvedManual = await prisma.question.findMany({
      where: {
        subtopicId: { in: subtopicIds },
        sourceType: 'MANUAL',
        status: 'PUBLISHED',
        subtopic: {
          isActive: true,
          topic: {
            isActive: true,
            subject: { isActive: true },
          },
        },
        userProgress: {
          none: {
            userId,
            timesCorrect: { gt: 0 },
          },
        },
      },
      take: count,
      include: {
        userProgress: {
          where: { userId },
          select: { timesSeen: true, timesCorrect: true, lastIsCorrect: true },
        },
      },
      orderBy: [
        // Prioritize previously failed questions over completely unseen
        { attempts: { _count: 'desc' } },
        { createdAt: 'asc' },
      ],
    });

    // 3. STRICT INVARIANT: If at least one unsolved manual question exists, serve ONLY manual questions!
    if (unsolvedManual.length > 0) {
      console.log(
        `[PracticeSelection] Found ${unsolvedManual.length} unsolved MANUAL questions for user ${userId}. Strictly serving MANUAL questions.`
      );

      if (unsolvedManual.length >= count) {
        return unsolvedManual.sort(() => 0.5 - Math.random());
      }

      // Reinforcement fill: If unsolved manual count < session count, fill remaining slots
      // with previously solved MANUAL questions from the same subtopics (ZERO AI questions)
      const needed = count - unsolvedManual.length;
      const reinforcementManual = await prisma.question.findMany({
        where: {
          subtopicId: { in: subtopicIds },
          sourceType: 'MANUAL',
          status: 'PUBLISHED',
          subtopic: {
            isActive: true,
            topic: {
              isActive: true,
              subject: { isActive: true },
            },
          },
          id: { notIn: unsolvedManual.map((q) => q.id) },
        },
        take: needed,
        orderBy: { updatedAt: 'asc' },
      });

      const manualCombined = [...unsolvedManual, ...reinforcementManual];
      return manualCombined.sort(() => 0.5 - Math.random());
    }

    // 4. If zero unsolved manual questions exist, check if user has solved all existing manual questions
    console.log(
      `[PracticeSelection] Zero unsolved MANUAL questions remaining for user ${userId} in selected subtopics. AI_GENERATED questions are now eligible.`
    );

    // 5. Query published AI questions that user hasn't solved correctly
    let aiCandidates = await prisma.question.findMany({
      where: {
        subtopicId: { in: subtopicIds },
        sourceType: 'AI_GENERATED',
        status: 'PUBLISHED',
        subtopic: {
          isActive: true,
          topic: {
            isActive: true,
            subject: { isActive: true },
          },
        },
        userProgress: {
          none: {
            userId,
            timesCorrect: { gt: 0 },
          },
        },
      },
      take: count,
      orderBy: { createdAt: 'desc' },
    });

    // 6. If fresh candidate inventory is low, dispatch background BullMQ job (non-blocking)
    if (aiCandidates.length < count) {
      console.log(
        `[PracticeSelection] Shortage of questions detected (${aiCandidates.length} < ${count}). Dispatching background BullMQ generation...`
      );

      // Trigger background replenishment for requested subtopics
      for (const targetId of subtopicIds) {
        contentGenQueue.add('generate-subtopic-questions', { subtopicId: targetId }, {
          jobId: `subtopic-${targetId}`,
          removeOnComplete: true,
        }).catch((err) => {
          console.warn(`[PracticeSelection] Failed to enqueue background generation for subtopic ${targetId}:`, err);
        });
      }
    }

    // 7. Safety fallback: If still less than count, reuse least recently updated published questions for the SAME subtopics
    if (aiCandidates.length < count) {
      const fallbackQuestions = await prisma.question.findMany({
        where: {
          subtopicId: { in: subtopicIds },
          status: 'PUBLISHED',
          id: { notIn: aiCandidates.map((q) => q.id) },
        },
        take: count - aiCandidates.length,
        orderBy: { updatedAt: 'asc' },
      });
      aiCandidates.push(...fallbackQuestions);
    }

    // 8. Topic fallback: If still less than count, find published questions under the same topic
    if (aiCandidates.length < count && subtopicIds.length > 0) {
      const subtopicsWithTopic = await prisma.subtopic.findMany({
        where: {
          OR: [
            { id: { in: subtopicIds } },
            { slug: { in: subtopicIds } },
          ],
        },
        select: { topicId: true },
      });
      const topicIds = Array.from(new Set(subtopicsWithTopic.map((s) => s.topicId).filter(Boolean)));
      if (topicIds.length > 0) {
        const topicFallback = await prisma.question.findMany({
          where: {
            topicId: { in: topicIds },
            status: 'PUBLISHED',
            id: { notIn: aiCandidates.map((q) => q.id) },
          },
          take: count - aiCandidates.length,
          orderBy: { updatedAt: 'asc' },
        });
        aiCandidates.push(...topicFallback);
      }
    }

    // 9. If zero valid questions exist, return clean preparation state
    if (aiCandidates.length === 0) {
      const err: any = new Error(
        'Practice questions for this subtopic are currently being prepared. Please check back shortly.'
      );
      err.statusCode = 422;
      err.code = 'QUESTIONS_BEING_PREPARED';
      throw err;
    }

    return aiCandidates.slice(0, count).sort(() => 0.5 - Math.random());
  }
}

export const practiceSelectionService = PracticeSelectionService.getInstance();
