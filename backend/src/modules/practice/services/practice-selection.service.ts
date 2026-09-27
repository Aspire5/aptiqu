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

    // 2. Fetch user progress for questions in these subtopics
    const userProgressRecords = await prisma.userQuestionProgress.findMany({
      where: {
        userId,
        subtopicId: { in: subtopicIds },
      },
      include: {
        question: true,
      },
      orderBy: { lastSeenAt: 'asc' }, // Least recently seen first
    });

    const seenQuestionIds = new Set(userProgressRecords.map((p) => p.questionId));

    // Identify questions the user previously failed (lastIsCorrect == false)
    const failedQuestions = userProgressRecords
      .filter((p) => !p.lastIsCorrect && p.question && p.question.status === 'PUBLISHED')
      .map((p) => p.question);

    // Reserve up to 3 questions for previously failed patterns/questions
    const targetFailedCount = Math.min(3, failedQuestions.length);
    const selectedFailed: any[] = [];
    const addedIds = new Set<string>();

    // Prioritize variety of patterns among failed questions
    const seenPatterns = new Set<string>();
    for (const q of failedQuestions) {
      if (selectedFailed.length >= targetFailedCount) break;
      const patternKey = q.pattern || q.id;
      if (!seenPatterns.has(patternKey) && !addedIds.has(q.id)) {
        selectedFailed.push(q);
        addedIds.add(q.id);
        seenPatterns.add(patternKey);
      }
    }
    // If we have remaining failed slots, fill with remaining failed questions
    for (const q of failedQuestions) {
      if (selectedFailed.length >= targetFailedCount) break;
      if (!addedIds.has(q.id)) {
        selectedFailed.push(q);
        addedIds.add(q.id);
      }
    }

    const neededFresh = count - selectedFailed.length;

    // 3. Check inventory of UNSEEN published questions for this user
    let unseenCandidates = await prisma.question.findMany({
      where: {
        subtopicId: { in: subtopicIds },
        status: 'PUBLISHED',
        id: { notIn: Array.from(seenQuestionIds) },
      },
    });

    console.log(
      `[PracticeSelection] User has ${failedQuestions.length} previously failed questions (selected ${selectedFailed.length}). Needs ${neededFresh} fresh questions. Currently unseen in DB: ${unseenCandidates.length}`
    );

    // 4. Trigger AI Generation if unseen inventory is insufficient
    if (unseenCandidates.length < neededFresh) {
      const shortage = neededFresh - unseenCandidates.length;
      console.log(
        `[PracticeSelection] Fresh question shortage detected (${unseenCandidates.length} < ${neededFresh}, deficit: ${shortage}). Triggering on-demand Gemini generation...`
      );

      // Distribute generation across subtopics with lowest unseen inventory
      const subtopicCounts = await Promise.all(
        subtopicIds.map(async (id) => ({
          id,
          count: await prisma.question.count({
            where: {
              subtopicId: id,
              status: 'PUBLISHED',
              id: { notIn: Array.from(seenQuestionIds) },
            },
          }),
        }))
      );
      subtopicCounts.sort((a, b) => a.count - b.count);

      for (const target of subtopicCounts) {
        if (unseenCandidates.length >= neededFresh) break;

        console.log(
          `[PracticeSelection] Auto-generating batch of fresh questions for subtopic "${target.id}"...`
        );

        try {
          const generated = await questionGenerationService.generateQuestionsForSubtopic(
            target.id,
            INVENTORY_CONFIG.DEFAULT_BATCH_GENERATION_UNIT
          );

          // Add newly generated questions to our fresh pool
          for (const g of generated) {
            if (!addedIds.has(g.id) && !seenQuestionIds.has(g.id)) {
              unseenCandidates.push(g);
            }
          }
        } catch (err: any) {
          console.warn(`[PracticeSelection] Auto-generation failed for subtopic ${target.id}:`, err.message);
        }
      }
    }

    // 5. Assemble final pool
    const selected: any[] = [...selectedFailed];

    // Shuffle unseen candidates for variety and add up to target count
    const shuffledUnseen = unseenCandidates.sort(() => 0.5 - Math.random());
    for (const q of shuffledUnseen) {
      if (selected.length >= count) break;
      if (!addedIds.has(q.id)) {
        selected.push(q);
        addedIds.add(q.id);
      }
    }

    // 6. Safety fallback: If AI generation couldn't fulfill fresh count, use least recently seen
    if (selected.length < count) {
      const seenSorted = [...userProgressRecords]
        .sort((a, b) => a.lastSeenAt.getTime() - b.lastSeenAt.getTime())
        .map((p) => p.question)
        .filter((q) => q && q.status === 'PUBLISHED');

      for (const q of seenSorted) {
        if (selected.length >= count) break;
        if (!addedIds.has(q.id)) {
          selected.push(q);
          addedIds.add(q.id);
        }
      }
    }

    // 7. Final shuffle so review questions are interleaved naturally
    selected.sort(() => 0.5 - Math.random());
    return selected.slice(0, count);
  }
}

export const practiceSelectionService = PracticeSelectionService.getInstance();
