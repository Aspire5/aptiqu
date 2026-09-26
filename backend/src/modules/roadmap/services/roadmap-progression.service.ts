import { prisma } from '../../../config/prisma';
import { xpService } from '../../xp/xp.service';
import { AwardXpResult } from '../../xp/xp.types';

export interface NextLearningStepResult {
  type: 'lesson' | 'roadmap_complete';
  available: boolean;
  reason?: 'SCRIPT_NOT_PUBLISHED' | 'ROADMAP_COMPLETED' | 'STEP_NOT_FOUND';
  roadmapId?: string;
  roadmapStepId?: string;
  topicId?: string;
  topicName?: string;
  subtopicId?: string | null;
  scriptId?: string;
  scriptSlug?: string;
  scriptTitle?: string;
  message?: string;
}

export interface LearningMapSubtopicItem {
  id: string;
  scriptId?: string;
  scriptSlug?: string;
  title: string;
  sequence: number;
  isCompleted: boolean;
  isLocked: boolean;
  canReplay: boolean;
}

export interface LearningMapTopicItem {
  roadmapStepId: string;
  sequence: number;
  topicId: string;
  topicName: string;
  topicSlug: string;
  description: string | null;
  importance: string;
  teachingMinutes: number;
  teachingDepth: number;
  subtopicId: string | null;
  subtopicName: string | null;
  state: 'LOCKED' | 'AVAILABLE' | 'IN_PROGRESS' | 'COMPLETED' | 'COMING_SOON';
  scriptAvailable: boolean;
  scriptSlug?: string;
  scriptTitle?: string;
  totalSubtopics: number;
  completedSubtopics: number;
  subtopics: LearningMapSubtopicItem[];
}

export interface SubjectLearningMapResult {
  roadmap: {
    id: string;
    slug: string;
    name: string;
    course: string;
  };
  subject: {
    id: string;
    slug: string;
    name: string;
    description: string | null;
  };
  topics: LearningMapTopicItem[];
  progress: {
    totalTopics: number;
    completedTopics: number;
    activeStepId: string | null;
  };
}

export class RoadmapProgressionService {
  private static instance: RoadmapProgressionService;

  public static getInstance(): RoadmapProgressionService {
    if (!RoadmapProgressionService.instance) {
      RoadmapProgressionService.instance = new RoadmapProgressionService();
    }
    return RoadmapProgressionService.instance;
  }

  /**
   * Resolves the user's active roadmap.
   * If not set on user, defaults to the roadmap marked isDefault: true, or the first active roadmap.
   */
  public async getUserActiveRoadmap(userId: string) {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { activeRoadmapId: true },
    });

    let roadmapId = user?.activeRoadmapId;

    if (!roadmapId) {
      const defaultRoadmap = await prisma.roadmap.findFirst({
        where: { isDefault: true, isActive: true },
      });
      roadmapId = defaultRoadmap?.id;
    }

    if (!roadmapId) {
      const firstActive = await prisma.roadmap.findFirst({
        where: { isActive: true },
      });
      roadmapId = firstActive?.id;
    }

    if (!roadmapId) {
      throw new Error('No active roadmap found in the system.');
    }

    // Persist active roadmap on user if it was null
    if (user && !user.activeRoadmapId) {
      await prisma.user.update({
        where: { id: userId },
        data: { activeRoadmapId: roadmapId },
      });
    }

    const roadmap = await prisma.roadmap.findUnique({
      where: { id: roadmapId },
      include: {
        roadmapSubjects: {
          orderBy: { sequence: 'asc' },
          include: {
            subject: true,
          },
        },
      },
    });

    if (!roadmap) {
      throw new Error(`Active roadmap "${roadmapId}" not found.`);
    }

    return roadmap;
  }

  /**
   * List all active roadmaps with flag indicating if active for user.
   */
  public async listRoadmaps(userId: string) {
    const activeRoadmap = await this.getUserActiveRoadmap(userId);
    const roadmaps = await prisma.roadmap.findMany({
      where: { isActive: true },
      orderBy: [{ isDefault: 'desc' }, { name: 'asc' }],
      include: {
        roadmapSubjects: {
          orderBy: { sequence: 'asc' },
          include: { subject: true },
        },
      },
    });

    return roadmaps.map((r) => ({
      id: r.id,
      slug: r.slug,
      name: r.name,
      course: r.course,
      description: r.description,
      isDefault: r.isDefault,
      isActiveForUser: r.id === activeRoadmap.id,
      subjects: r.roadmapSubjects.map((rs) => ({
        id: rs.subject.id,
        slug: rs.subject.slug,
        name: rs.subject.name,
        sequence: rs.sequence,
      })),
    }));
  }

  /**
   * Set the active roadmap for a user.
   */
  public async setActiveRoadmap(userId: string, roadmapId: string) {
    const roadmap = await prisma.roadmap.findFirst({
      where: {
        OR: [{ id: roadmapId }, { slug: roadmapId }],
        isActive: true,
      },
    });

    if (!roadmap) {
      throw new Error(`Roadmap "${roadmapId}" not found or inactive.`);
    }

    await prisma.user.update({
      where: { id: userId },
      data: { activeRoadmapId: roadmap.id },
    });

    return roadmap;
  }

  /**
   * Generates the authoritative learning map for a subject in a roadmap.
   * Computes LOCKED, AVAILABLE, IN_PROGRESS, COMPLETED, COMING_SOON for each topic.
   */
  public async getSubjectLearningMap(
    userId: string,
    roadmapId: string,
    subjectId: string
  ): Promise<SubjectLearningMapResult> {
    // Resolve roadmap by ID or slug
    const roadmap = await prisma.roadmap.findFirst({
      where: {
        OR: [{ id: roadmapId }, { slug: roadmapId }],
        isActive: true,
      },
    });

    if (!roadmap) {
      throw new Error(`Roadmap "${roadmapId}" not found.`);
    }

    // Resolve subject by ID or slug
    const subject = await prisma.subject.findFirst({
      where: {
        OR: [{ id: subjectId }, { slug: subjectId }],
        isActive: true,
      },
    });

    if (!subject) {
      throw new Error(`Subject "${subjectId}" not found.`);
    }

    // Get all roadmap steps for this subject ordered by sequence
    const steps = await prisma.roadmapStep.findMany({
      where: {
        roadmapId: roadmap.id,
        subjectId: subject.id,
        isActive: true,
      },
      orderBy: { sequence: 'asc' },
      include: {
        topic: {
          include: {
            subtopics: {
              where: { isActive: true },
              orderBy: { sequence: 'asc' },
            },
          },
        },
        subtopic: true,
        scriptAssignments: {
          where: { status: 'PUBLISHED' },
          orderBy: { sequence: 'asc' },
          include: {
            script: true,
            publishedVersion: true,
          },
        },
      },
    });

    // Get user's step progress
    const stepProgressList = await prisma.userRoadmapStepProgress.findMany({
      where: {
        userId,
        roadmapId: roadmap.id,
      },
    });
    const completedStepIds = new Set(
      stepProgressList.filter((p) => p.status === 'COMPLETED').map((p) => p.roadmapStepId)
    );

    // Get user's active/paused sessions for this roadmap
    const activeSessions = await prisma.lessonSession.findMany({
      where: {
        userId,
        roadmapId: roadmap.id,
        status: { in: ['ACTIVE', 'PAUSED'] },
      },
    });
    const inProgressStepIds = new Set(
      activeSessions.filter((s) => s.roadmapStepId).map((s) => s.roadmapStepId as string)
    );

    // Also check sessions that were marked completed directly
    const completedSessions = await prisma.lessonSession.findMany({
      where: {
        userId,
        status: 'COMPLETED',
      },
      select: { scriptId: true, roadmapStepId: true },
    });
    const completedScriptIds = new Set(completedSessions.map((cs) => cs.scriptId));
    for (const step of steps) {
      const assignments = step.scriptAssignments || [];
      if (assignments.length > 0 && assignments.every((sa) => completedScriptIds.has(sa.scriptId))) {
        completedStepIds.add(step.id);
      }
    }

    let activeStepId: string | null = null;
    let foundFirstIncompletePublished = false;

    const topicItems: LearningMapTopicItem[] = steps.map((step) => {
      const assignments = step.scriptAssignments || [];
      const hasPublishedScript =
        assignments.length > 0 &&
        assignments.some((sa) => sa.publishedVersionId != null);

      const firstScriptAssignment = assignments[0];
      const hasSomeCompleted = assignments.some((sa) => completedScriptIds.has(sa.scriptId));
      const hasActiveSession = inProgressStepIds.has(step.id);
      const isStepFullyCompleted = completedStepIds.has(step.id);

      let state: 'LOCKED' | 'AVAILABLE' | 'IN_PROGRESS' | 'COMPLETED' | 'COMING_SOON';

      if (!hasPublishedScript) {
        state = 'COMING_SOON';
      } else if (isStepFullyCompleted) {
        state = 'COMPLETED';
      } else if (hasActiveSession || hasSomeCompleted) {
        state = 'IN_PROGRESS';
        if (!activeStepId) {
          activeStepId = step.id;
        }
      } else {
        // Step has a published script and is not completed
        if (!foundFirstIncompletePublished) {
          state = 'AVAILABLE';
          foundFirstIncompletePublished = true;
          if (!activeStepId) {
            activeStepId = step.id;
          }
        } else {
          // If a prior published step is incomplete, subsequent steps are locked
          state = 'LOCKED';
        }
      }

      // Compute subtopics breakdown
      let totalSubtopics = assignments.length;
      let completedSubtopics = 0;
      let subtopics: LearningMapSubtopicItem[] = [];

      if (assignments.length > 0) {
        let foundIncomplete = false;
        subtopics = assignments.map((sa) => {
          const isDone = completedScriptIds.has(sa.scriptId);
          if (isDone) {
            completedSubtopics++;
          }

          let isLocked = false;
          if (!isDone) {
            if (!foundIncomplete && (step.id === activeStepId || state === 'AVAILABLE' || state === 'IN_PROGRESS' || completedStepIds.has(step.id))) {
              isLocked = false;
              foundIncomplete = true;
            } else {
              isLocked = true;
            }
          }

          return {
            id: sa.id,
            scriptId: sa.scriptId,
            scriptSlug: sa.script.slug,
            title: sa.script.title,
            sequence: sa.sequence,
            isCompleted: isDone,
            isLocked,
            canReplay: isDone,
          };
        });
      } else {
        const topicSubtopics = (step.topic as any).subtopics || [];
        totalSubtopics = topicSubtopics.length;
        subtopics = topicSubtopics.map((st: any) => ({
          id: st.id,
          title: st.name,
          sequence: st.sequence,
          isCompleted: false,
          isLocked: true,
          canReplay: false,
        }));
      }

      if (totalSubtopics > 0 && completedSubtopics >= totalSubtopics) {
        state = 'COMPLETED';
      } else if (totalSubtopics > 1 && completedSubtopics < totalSubtopics && state === 'COMPLETED') {
        state = 'IN_PROGRESS';
      }

      return {
        roadmapStepId: step.id,
        sequence: step.sequence,
        topicId: step.topic.id,
        topicName: step.topic.name,
        topicSlug: step.topic.slug,
        description: step.topic.description,
        importance: step.importance,
        teachingMinutes: step.teachingMinutes,
        teachingDepth: step.teachingDepth,
        subtopicId: step.subtopic?.id || null,
        subtopicName: step.subtopic?.name || null,
        state,
        scriptAvailable: hasPublishedScript,
        scriptSlug: firstScriptAssignment?.script?.slug,
        scriptTitle: firstScriptAssignment?.script?.title,
        totalSubtopics,
        completedSubtopics,
        subtopics,
      };
    });

    const totalTopics = topicItems.length;
    const completedTopics = topicItems.filter((t) => t.state === 'COMPLETED').length;

    return {
      roadmap: {
        id: roadmap.id,
        slug: roadmap.slug,
        name: roadmap.name,
        course: roadmap.course,
      },
      subject: {
        id: subject.id,
        slug: subject.slug,
        name: subject.name,
        description: subject.description,
      },
      topics: topicItems,
      progress: {
        totalTopics,
        completedTopics,
        activeStepId,
      },
    };
  }

  /**
   * Mark a roadmap step as completed by user.
   */
  public async markStepCompleted(userId: string, roadmapId: string, roadmapStepId: string) {
    return prisma.userRoadmapStepProgress.upsert({
      where: {
        userId_roadmapStepId: {
          userId,
          roadmapStepId,
        },
      },
      update: {
        status: 'COMPLETED',
        completedAt: new Date(),
      },
      create: {
        userId,
        roadmapId,
        roadmapStepId,
        status: 'COMPLETED',
        completedAt: new Date(),
      },
    });
  }

  /**
   * Evaluates if an entire topic in the user's active roadmap has been completed,
   * and if so, awards topic completion XP (10 XP * required subtopics count).
   */
  public async checkAndAwardTopicCompletion(
    userId: string,
    roadmapId: string,
    topicId: string
  ): Promise<AwardXpResult | null> {
    // 1. Fetch all steps for this topic in the roadmap
    const steps = await prisma.roadmapStep.findMany({
      where: {
        roadmapId,
        topicId,
        isActive: true,
      },
      include: {
        scriptAssignments: {
          where: { status: 'PUBLISHED' },
          include: { script: true },
        },
      },
    });

    if (steps.length === 0) return null;

    // 2. Check if all required steps are completed
    const completedStepProgress = await prisma.userRoadmapStepProgress.findMany({
      where: {
        userId,
        roadmapId,
        roadmapStepId: { in: steps.map((s) => s.id) },
        status: 'COMPLETED',
      },
      select: { roadmapStepId: true },
    });
    const completedStepIds = new Set(completedStepProgress.map((p) => p.roadmapStepId));

    // Also check completed sessions for scripts on these steps
    const stepIds = steps.map((s) => s.id);
    const completedSessions = await prisma.lessonSession.findMany({
      where: {
        userId,
        roadmapStepId: { in: stepIds },
        status: 'COMPLETED',
      },
      select: { scriptId: true, roadmapStepId: true },
    });
    const completedScriptIds = new Set(completedSessions.map((s) => s.scriptId));

    // Verify all required steps are completed
    for (const step of steps) {
      if (!step.isRequired) continue;

      const isStepMarkedDone = completedStepIds.has(step.id);
      const assignments = step.scriptAssignments || [];
      const allRequiredAssignmentsDone =
        assignments.length > 0 &&
        assignments
          .filter((sa) => sa.isRequired)
          .every((sa) => completedScriptIds.has(sa.scriptId));

      if (!isStepMarkedDone && !allRequiredAssignmentsDone) {
        // Topic is not yet fully completed
        return null;
      }
    }

    // 3. Determine required subtopic count
    // First, check subtopics table for this topic
    const topicSubtopics = await prisma.subtopic.findMany({
      where: {
        topicId,
        isActive: true,
      },
    });

    let requiredSubtopicCount = topicSubtopics.length;

    // If subtopics are tracked at the step or assignment level, check required assignments
    if (requiredSubtopicCount === 0) {
      const requiredAssignmentsCount = steps.reduce(
        (sum, s) => sum + s.scriptAssignments.filter((sa) => sa.isRequired).length,
        0
      );
      requiredSubtopicCount = requiredAssignmentsCount > 0 ? requiredAssignmentsCount : steps.length;
    }

    // 4. Award topic completion XP
    return xpService.awardTopicCompletionXp({
      userId,
      roadmapId,
      topicId,
      requiredSubtopicCount,
      subjectId: steps[0]?.subjectId,
    });
  }

  /**
   * Finds the next eligible learning step or script after completing the current one.
   *
   * Priority:
   * 1. Continue scripts within the current roadmap step if multiple scripts exist.
   * 2. Move to the next step within the same subject.
   * 3. Move to the next subject in the roadmap (first step of next subject).
   * 4. If no steps remain: mark roadmap complete.
   */
  public async getNextStepOrScript(
    userId: string,
    roadmapId: string,
    currentRoadmapStepId?: string | null,
    currentScriptId?: string | null
  ): Promise<NextLearningStepResult> {
    const roadmap = await prisma.roadmap.findUnique({
      where: { id: roadmapId },
      include: {
        roadmapSubjects: {
          orderBy: { sequence: 'asc' },
        },
      },
    });

    if (!roadmap) {
      return {
        type: 'roadmap_complete',
        available: false,
        reason: 'ROADMAP_COMPLETED',
        message: 'Roadmap not found.',
      };
    }

    // If currentRoadmapStepId is not provided, start from the first step of the first subject
    if (!currentRoadmapStepId) {
      const firstSubject = roadmap.roadmapSubjects[0];
      if (!firstSubject) {
        return {
          type: 'roadmap_complete',
          available: false,
          reason: 'ROADMAP_COMPLETED',
          roadmapId: roadmap.id,
          message: 'No subjects in this roadmap.',
        };
      }

      const firstStep = await prisma.roadmapStep.findFirst({
        where: {
          roadmapId: roadmap.id,
          subjectId: firstSubject.subjectId,
          isActive: true,
        },
        orderBy: { sequence: 'asc' },
        include: {
          topic: true,
          scriptAssignments: {
            where: { status: 'PUBLISHED' },
            orderBy: { sequence: 'asc' },
            include: { script: true },
          },
        },
      });

      if (!firstStep) {
        return {
          type: 'roadmap_complete',
          available: false,
          reason: 'ROADMAP_COMPLETED',
          roadmapId: roadmap.id,
        };
      }

      return this.formatStepResult(firstStep, firstStep.scriptAssignments[0]);
    }

    // Step 1: Check current step
    const currentStep = await prisma.roadmapStep.findUnique({
      where: { id: currentRoadmapStepId },
      include: {
        topic: true,
        scriptAssignments: {
          where: { status: 'PUBLISHED' },
          orderBy: { sequence: 'asc' },
          include: { script: true },
        },
      },
    });

    if (!currentStep) {
      return {
        type: 'roadmap_complete',
        available: false,
        reason: 'STEP_NOT_FOUND',
        roadmapId: roadmap.id,
        message: `Step "${currentRoadmapStepId}" not found.`,
      };
    }

    // Rule 1: Are there more scripts in the CURRENT step?
    if (currentScriptId && currentStep.scriptAssignments.length > 1) {
      const currentIdx = currentStep.scriptAssignments.findIndex(
        (sa) => sa.scriptId === currentScriptId
      );
      if (currentIdx !== -1 && currentIdx < currentStep.scriptAssignments.length - 1) {
        const nextAssignment = currentStep.scriptAssignments[currentIdx + 1];
        return {
          type: 'lesson',
          available: true,
          roadmapId: roadmap.id,
          roadmapStepId: currentStep.id,
          topicId: currentStep.topicId,
          topicName: currentStep.topic.name,
          subtopicId: currentStep.subtopicId,
          scriptId: nextAssignment.scriptId,
          scriptSlug: nextAssignment.script.slug,
          scriptTitle: nextAssignment.script.title,
        };
      }
    }

    // Rule 2: Next step within the SAME subject
    const nextStepInSubject = await prisma.roadmapStep.findFirst({
      where: {
        roadmapId: roadmap.id,
        subjectId: currentStep.subjectId,
        sequence: { gt: currentStep.sequence },
        isActive: true,
      },
      orderBy: { sequence: 'asc' },
      include: {
        topic: true,
        scriptAssignments: {
          where: { status: 'PUBLISHED' },
          orderBy: { sequence: 'asc' },
          include: { script: true },
        },
      },
    });

    if (nextStepInSubject) {
      return this.formatStepResult(
        nextStepInSubject,
        nextStepInSubject.scriptAssignments[0]
      );
    }

    // Rule 3: Next subject in the roadmap
    const currentRoadmapSubject = roadmap.roadmapSubjects.find(
      (rs) => rs.subjectId === currentStep.subjectId
    );
    const currentSubjectSequence = currentRoadmapSubject?.sequence ?? 0;

    const nextRoadmapSubject = roadmap.roadmapSubjects.find(
      (rs) => rs.sequence > currentSubjectSequence
    );

    if (nextRoadmapSubject) {
      const firstStepOfNextSubject = await prisma.roadmapStep.findFirst({
        where: {
          roadmapId: roadmap.id,
          subjectId: nextRoadmapSubject.subjectId,
          isActive: true,
        },
        orderBy: { sequence: 'asc' },
        include: {
          topic: true,
          scriptAssignments: {
            where: { status: 'PUBLISHED' },
            orderBy: { sequence: 'asc' },
            include: { script: true },
          },
        },
      });

      if (firstStepOfNextSubject) {
        return this.formatStepResult(
          firstStepOfNextSubject,
          firstStepOfNextSubject.scriptAssignments[0]
        );
      }
    }

    // Rule 4: No steps remain in the roadmap
    return {
      type: 'roadmap_complete',
      available: false,
      reason: 'ROADMAP_COMPLETED',
      roadmapId: roadmap.id,
      message: 'Congratulations! You have completed all steps in this roadmap.',
    };
  }

  private formatStepResult(step: any, scriptAssignment?: any): NextLearningStepResult {
    if (scriptAssignment && scriptAssignment.script) {
      return {
        type: 'lesson',
        available: true,
        roadmapId: step.roadmapId,
        roadmapStepId: step.id,
        topicId: step.topicId,
        topicName: step.topic.name,
        subtopicId: step.subtopicId,
        scriptId: scriptAssignment.scriptId,
        scriptSlug: scriptAssignment.script.slug,
        scriptTitle: scriptAssignment.script.title,
      };
    }

    // Step exists, but script is not published yet
    return {
      type: 'lesson',
      available: false,
      reason: 'SCRIPT_NOT_PUBLISHED',
      roadmapId: step.roadmapId,
      roadmapStepId: step.id,
      topicId: step.topicId,
      topicName: step.topic.name,
      subtopicId: step.subtopicId,
    };
  }
}

export const roadmapProgressionService = RoadmapProgressionService.getInstance();
