import { prisma } from '../../../config/prisma';
import { INVENTORY_CONFIG } from '../../../config/inventory.config';
import { questionGenerationService } from '../../ai/services/question-generation.service';
import { LiveCurriculumService } from '../../curriculum/services/live-curriculum.service';

export class PracticeSelectionService {
  private static instance: PracticeSelectionService;

  public static getInstance(): PracticeSelectionService {
    if (!PracticeSelectionService.instance) {
      PracticeSelectionService.instance = new PracticeSelectionService();
    }
    return PracticeSelectionService.instance;
  }

  /**
   * Selects 10 candidate questions for a user across selected subtopics.
   * On-demand generates questions if inventory is low.
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

    // 2. Check inventory and on-demand generate if below threshold
    for (const subId of subtopicIds) {
      const availableCount = await prisma.question.count({
        where: { subtopicId: subId, status: 'PUBLISHED' },
      });

      if (availableCount < INVENTORY_CONFIG.MINIMUM_THRESHOLD_PER_SUBTOPIC) {
        try {
          await questionGenerationService.generateQuestionsForSubtopic(
            subId,
            INVENTORY_CONFIG.DEFAULT_BATCH_GENERATION_UNIT
          );
        } catch (err: any) {
          console.warn(`[PracticeSelection] Auto-generation failed for subtopic ${subId}:`, err.message);
        }
      }
    }

    // 3. Candidate Prioritization Pipeline
    // Fetch all user progress for questions in these subtopics
    const userProgressRecords = await prisma.userQuestionProgress.findMany({
      where: {
        userId,
        subtopicId: { in: subtopicIds },
      },
      select: {
        questionId: true,
        timesSeen: true,
        lastIsCorrect: true,
        lastSeenAt: true,
      },
    });

    const progressMap = new Map(userProgressRecords.map((p) => [p.questionId, p]));

    // Fetch all available published questions for these subtopics
    const allCandidates = await prisma.question.findMany({
      where: {
        subtopicId: { in: subtopicIds },
        status: 'PUBLISHED',
      },
    });

    if (allCandidates.length === 0) {
      throw new Error('No usable questions available for the selected subtopics.');
    }

    // Categorize candidates
    const unseen: any[] = [];
    const previouslyIncorrect: any[] = [];
    const previouslyCorrect: any[] = [];

    for (const q of allCandidates) {
      const prog = progressMap.get(q.id);
      if (!prog) {
        unseen.push(q);
      } else if (!prog.lastIsCorrect) {
        previouslyIncorrect.push({ q, lastSeenAt: prog.lastSeenAt });
      } else {
        previouslyCorrect.push({ q, lastSeenAt: prog.lastSeenAt });
      }
    }

    // Sort previously incorrect & correct by least recently seen
    previouslyIncorrect.sort((a, b) => a.lastSeenAt.getTime() - b.lastSeenAt.getTime());
    previouslyCorrect.sort((a, b) => a.lastSeenAt.getTime() - b.lastSeenAt.getTime());

    // Assemble final pool
    const selected: any[] = [];

    // Helper to add unique
    const addedIds = new Set<string>();
    const tryAdd = (question: any) => {
      if (selected.length < count && !addedIds.has(question.id)) {
        selected.push(question);
        addedIds.add(question.id);
      }
    };

    // 1. Unseen questions first
    for (const q of unseen) tryAdd(q);

    // 2. Previously incorrect
    for (const item of previouslyIncorrect) tryAdd(item.q);

    // 3. Fallback: least recently seen
    for (const item of previouslyCorrect) tryAdd(item.q);

    // If still short, cycle through remaining allCandidates
    for (const q of allCandidates) tryAdd(q);

    return selected.slice(0, count);
  }
}

export const practiceSelectionService = PracticeSelectionService.getInstance();
