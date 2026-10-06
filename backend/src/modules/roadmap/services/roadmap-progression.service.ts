import { prisma } from '../../../config/prisma';
import { xpService } from '../../xp/xp.service';
import { AwardXpResult } from '../../xp/xp.types';

export interface NextLearningStepResult {
  type: 'lesson' | 'roadmap_complete';
  available: boolean;
  reason?: 'SCRIPT_NOT_PUBLISHED' | 'ROADMAP_COMPLETED' | 'STEP_NOT_FOUND';
  roadmapId?: string;
  roadmapStepId?: string;
  subjectId?: string;
  subjectName?: string;
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
  private lastSyncTime = 0;

  public static getInstance(): RoadmapProgressionService {
    if (!RoadmapProgressionService.instance) {
      RoadmapProgressionService.instance = new RoadmapProgressionService();
    }
    return RoadmapProgressionService.instance;
  }

  /**
   * Synchronizes the active roadmap(s) with the current state of the syllabus.
   * Ensures active subjects have corresponding RoadmapSubject entries,
   * active topics have corresponding RoadmapStep entries,
   * and published scripts are linked as ScriptAssignments.
   * Also deactivates/cleans up any entries for inactive subjects or topics.
   */
  public async syncRoadmapWithSyllabus(roadmapId?: string, force = false): Promise<void> {
    const now = Date.now();
    if (!force && now - this.lastSyncTime < 4000) {
      return;
    }
    this.lastSyncTime = now;

    try {
      // 1. Resolve active roadmap(s)
      let roadmaps: any[];
      if (roadmapId) {
        const r = await prisma.roadmap.findFirst({
          where: {
            OR: [{ id: roadmapId }, { slug: roadmapId }],
            isActive: true,
          },
        });
        roadmaps = r ? [r] : [];
      } else {
        roadmaps = await prisma.roadmap.findMany({ where: { isActive: true } });
      }

      if (roadmaps.length === 0) {
        const defaultR = await prisma.roadmap.upsert({
          where: { id: 'general-aptitude' },
          update: { isActive: true, isDefault: true },
          create: {
            id: 'general-aptitude',
            slug: 'general-aptitude',
            name: 'General Aptitude',
            course: 'general',
            isDefault: true,
            isActive: true,
          },
        });
        roadmaps = [defaultR];
      }

      // 2. Fetch all subjects with direct and linked topics & subtopics
      const allSubjects = await prisma.subject.findMany({
        orderBy: { displayOrder: 'asc' },
        include: {
          topics: {
            where: { isActive: true },
            orderBy: { sequence: 'asc' },
            include: {
              subtopics: { where: { isActive: true }, orderBy: { sequence: 'asc' } },
            },
          },
          subjectTopics: {
            orderBy: { sequence: 'asc' },
            include: {
              topic: {
                include: {
                  subtopics: { where: { isActive: true }, orderBy: { sequence: 'asc' } },
                },
              },
            },
          },
        },
      });

      const activeSubjects = allSubjects.filter((s) => s.isActive);
      const inactiveSubjectIds = allSubjects.filter((s) => !s.isActive).map((s) => s.id);

      for (const roadmap of roadmaps) {
        // 3. Clean up inactive subjects from this roadmap
        if (inactiveSubjectIds.length > 0) {
          await prisma.roadmapSubject.deleteMany({
            where: {
              roadmapId: roadmap.id,
              subjectId: { in: inactiveSubjectIds },
            },
          });
          await prisma.roadmapStep.updateMany({
            where: {
              roadmapId: roadmap.id,
              subjectId: { in: inactiveSubjectIds },
            },
            data: { isActive: false },
          });
        }

        // 4. Upsert active subjects into RoadmapSubject
        for (let sIdx = 0; sIdx < activeSubjects.length; sIdx++) {
          const subject = activeSubjects[sIdx];
          const subjectSeq = subject.displayOrder > 0 ? subject.displayOrder : sIdx + 1;

          await prisma.roadmapSubject.upsert({
            where: {
              roadmapId_subjectId: {
                roadmapId: roadmap.id,
                subjectId: subject.id,
              },
            },
            update: { sequence: subjectSeq },
            create: {
              roadmapId: roadmap.id,
              subjectId: subject.id,
              sequence: subjectSeq,
            },
          });

          // 5. Collect all active topics for this subject
          const topicMap = new Map<string, any>();
          for (const t of subject.topics) {
            if (t.isActive) topicMap.set(t.id, t);
          }
          for (const st of subject.subjectTopics) {
            if (st.topic && st.topic.isActive) {
              topicMap.set(st.topic.id, { ...st.topic, sequence: st.sequence });
            }
          }

          const activeTopics = Array.from(topicMap.values()).sort((a, b) => a.sequence - b.sequence);
          const activeTopicIds = activeTopics.map((t) => t.id);

          // Deactivate steps for topics no longer active or linked to this subject
          await prisma.roadmapStep.updateMany({
            where: {
              roadmapId: roadmap.id,
              subjectId: subject.id,
              topicId: { notIn: activeTopicIds },
            },
            data: { isActive: false },
          });

          // Existing steps for this (roadmapId, subjectId)
          const existingSteps = await prisma.roadmapStep.findMany({
            where: { roadmapId: roadmap.id, subjectId: subject.id },
          });
          const existingStepByTopic = new Map(existingSteps.map((s) => [s.topicId, s]));

          // Offset existing sequences temporarily to avoid unique constraint collisions on (roadmapId, subjectId, sequence)
          if (existingSteps.length > 0) {
            await prisma.roadmapStep.updateMany({
              where: { roadmapId: roadmap.id, subjectId: subject.id },
              data: { sequence: { increment: 10000 } },
            });
          }

          for (let tIdx = 0; tIdx < activeTopics.length; tIdx++) {
            const topic = activeTopics[tIdx];
            const stepSeq = tIdx + 1;
            const existing = existingStepByTopic.get(topic.id);
            let currentStepId: string;

            if (existing) {
              currentStepId = existing.id;
              await prisma.roadmapStep.update({
                where: { id: existing.id },
                data: {
                  sequence: stepSeq,
                  importance: topic.defaultImportance || 'medium',
                  teachingDepth: topic.defaultTeachingDepth ?? 3,
                  teachingMinutes: topic.defaultTeachingMinutes ?? 30,
                  isActive: true,
                },
              });
            } else {
              currentStepId = `${roadmap.id}-${subject.slug || subject.id}-${topic.slug || topic.id}`.slice(0, 100);
              await prisma.roadmapStep.upsert({
                where: { id: currentStepId },
                update: {
                  sequence: stepSeq,
                  importance: topic.defaultImportance || 'medium',
                  teachingDepth: topic.defaultTeachingDepth ?? 3,
                  teachingMinutes: topic.defaultTeachingMinutes ?? 30,
                  isActive: true,
                },
                create: {
                  id: currentStepId,
                  roadmapId: roadmap.id,
                  subjectId: subject.id,
                  topicId: topic.id,
                  sequence: stepSeq,
                  course: roadmap.course || 'general',
                  importance: topic.defaultImportance || 'medium',
                  teachingDepth: topic.defaultTeachingDepth ?? 3,
                  teachingMinutes: topic.defaultTeachingMinutes ?? 30,
                  isRequired: true,
                  isActive: true,
                },
              });
            }

            // 6. Sync ScriptAssignments for this step
            const subtopicSeqMap = new Map<string, number>();
            for (const sub of (topic.subtopics || [])) {
              subtopicSeqMap.set(sub.id, sub.sequence);
              if (sub.slug) subtopicSeqMap.set(sub.slug, sub.sequence);
            }

            const publishedScripts = await prisma.lessonScript.findMany({
              where: {
                topicId: topic.id,
                status: { in: ['PUBLISHED', 'REVIEW'] },
              },
              include: {
                versions: {
                  select: { id: true },
                  orderBy: { versionNumber: 'desc' },
                  take: 1,
                },
              },
            });

            publishedScripts.sort((a, b) => {
              const seqA = a.subtopicId ? (subtopicSeqMap.get(a.subtopicId) ?? 999) : 999;
              const seqB = b.subtopicId ? (subtopicSeqMap.get(b.subtopicId) ?? 999) : 999;
              return seqA - seqB;
            });

            for (let scIdx = 0; scIdx < publishedScripts.length; scIdx++) {
              const script = publishedScripts[scIdx];
              const versionId = script.publishedVersionId || script.versions[0]?.id;
              const assignSeq = (script.subtopicId ? subtopicSeqMap.get(script.subtopicId) : undefined) ?? (scIdx + 1);

              const existingAssign = await prisma.scriptAssignment.findFirst({
                where: {
                  roadmapStepId: currentStepId,
                  scriptId: script.id,
                },
              });

              if (!existingAssign) {
                await prisma.scriptAssignment.create({
                  data: {
                    roadmapStepId: currentStepId,
                    scriptId: script.id,
                    publishedVersionId: versionId || null,
                    status: 'PUBLISHED',
                    sequence: assignSeq,
                    isRequired: true,
                  },
                });
              } else {
                await prisma.scriptAssignment.update({
                  where: { id: existingAssign.id },
                  data: {
                    publishedVersionId: versionId || existingAssign.publishedVersionId,
                    status: 'PUBLISHED',
                    sequence: assignSeq,
                  },
                });
              }
            }
          }
        }
      }
    } catch (err) {
      console.error('[RoadmapSync] Error synchronizing roadmap with syllabus:', err);
    }
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

    // Automatically synchronize roadmap with active syllabus
    await this.syncRoadmapWithSyllabus(roadmapId);

    const roadmap = await prisma.roadmap.findUnique({
      where: { id: roadmapId },
      include: {
        roadmapSubjects: {
          where: {
            subject: { isActive: true },
          },
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

    const allSteps = await prisma.roadmapStep.findMany({
      where: { roadmapId, isActive: true },
      include: {
        topic: {
          include: {
            subtopics: {
              where: { isActive: true },
            },
          },
        },
        scriptAssignments: {
          where: { status: 'PUBLISHED' },
          include: { script: true },
        },
      },
      orderBy: { sequence: 'asc' },
    });

    const completedSessions = await prisma.lessonSession.findMany({
      where: { userId, status: 'COMPLETED' },
      select: { scriptId: true, roadmapStepId: true },
    });
    const completedScriptIds = new Set(completedSessions.map((cs) => cs.scriptId));

    const activeSessions = await prisma.lessonSession.findMany({
      where: { userId, status: { in: ['ACTIVE', 'PAUSED'] } },
      select: { scriptId: true, roadmapStepId: true, lastActivityAt: true },
      orderBy: { lastActivityAt: 'desc' },
    });
    const activeStepIds = new Set(activeSessions.map((as) => as.roadmapStepId).filter(Boolean));

    const enrichedRoadmapSubjects = roadmap.roadmapSubjects
      .filter((rs) => rs.subject && rs.subject.isActive)
      .map((rs) => {
        const subjectSteps = allSteps.filter((s) => s.subjectId === rs.subjectId);
        const totalTopics = subjectSteps.length;
        let totalSubtopics = 0;
        let completedSubtopics = 0;
        let completedTopics = 0;
        let hasPlayableContent = false;
        let activeStepId: string | null = null;

        for (const step of subjectSteps) {
          const assignments = step.scriptAssignments || [];
          const stepSubtopicCount = (step.topic as any)?.subtopics?.length || 0;
          totalSubtopics += Math.max(stepSubtopicCount, assignments.length);

          if (assignments.length > 0) {
            hasPlayableContent = true;
            let stepCompleted = true;
            for (const sa of assignments) {
              if (completedScriptIds.has(sa.scriptId)) {
                completedSubtopics++;
              } else {
                stepCompleted = false;
              }
            }
            if (stepCompleted) {
              completedTopics++;
            } else if (!activeStepId) {
              activeStepId = step.id;
            }
          }
        }

        // If user has an active session in this subject, pick that step
        const resumeStep = subjectSteps.find((s) => activeStepIds.has(s.id));
        if (resumeStep) {
          activeStepId = resumeStep.id;
        } else if (!activeStepId && subjectSteps.length > 0) {
          activeStepId = subjectSteps[0].id;
        }

        const isStarted = completedSubtopics > 0 || subjectSteps.some((s) => activeStepIds.has(s.id));
        const isCompleted = hasPlayableContent && completedSubtopics >= totalSubtopics && totalSubtopics > 0;
        const estimatedMinutes = totalSubtopics > 0 ? totalSubtopics * 8 : (subjectSteps.length > 0 ? subjectSteps.length * 15 : 30);

        return {
          ...rs,
          progress: {
            totalTopics,
            completedTopics,
            totalSubtopics,
            completedSubtopics,
            estimatedMinutes,
            hasPlayableContent,
            isStarted,
            isCompleted,
            activeStepId,
          },
        };
      });

    return {
      ...roadmap,
      roadmapSubjects: enrichedRoadmapSubjects,
    };
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
          where: { subject: { isActive: true } },
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
    // 1. Reconcile roadmap with active syllabus
    await this.syncRoadmapWithSyllabus(roadmapId);

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

    // Resolve subject by ID or slug (active only)
    let subject = await prisma.subject.findFirst({
      where: {
        OR: [{ id: subjectId }, { slug: subjectId }],
        isActive: true,
      },
    });

    // Fallback: If requested subject is inactive or not found, fallback to first active subject in this roadmap
    if (!subject) {
      const activeRs = await prisma.roadmapSubject.findFirst({
        where: {
          roadmapId: roadmap.id,
          subject: { isActive: true },
        },
        orderBy: { sequence: 'asc' },
        include: { subject: true },
      });
      if (activeRs?.subject) {
        subject = activeRs.subject;
      } else {
        subject = await prisma.subject.findFirst({
          where: { isActive: true },
          orderBy: { displayOrder: 'asc' },
        });
      }
    }

    if (!subject) {
      throw new Error(`No active subject found for roadmap "${roadmapId}".`);
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
      const topicSubtopics = (step.topic as any)?.subtopics || [];
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
        state = 'AVAILABLE';
        if (!activeStepId) {
          activeStepId = step.id;
        }
      }

      // Compute subtopics breakdown merging topic subtopics with script assignments
      let subtopics: LearningMapSubtopicItem[] = [];
      let totalSubtopics = 0;
      let completedSubtopics = 0;

      if (topicSubtopics.length > 0) {
        totalSubtopics = topicSubtopics.length;

        subtopics = topicSubtopics.map((st: any, idx: number) => {
          const sa = assignments.find(
            (a) => a.script?.subtopicId === st.id || a.sequence === st.sequence
          ) || (idx < assignments.length && !assignments.some((a) => a.script?.subtopicId) ? assignments[idx] : null);

          if (sa) {
            const isDone = completedScriptIds.has(sa.scriptId);
            if (isDone) completedSubtopics++;

            // Any subtopic with a script is playable in any order
            const isLocked = false;

            return {
              id: sa.id,
              scriptId: sa.scriptId,
              scriptSlug: sa.script.slug,
              title: sa.script.title || st.name,
              sequence: st.sequence ?? idx + 1,
              isCompleted: isDone,
              isLocked,
              canReplay: isDone,
            };
          } else {
            return {
              id: st.id,
              title: st.name,
              sequence: st.sequence ?? idx + 1,
              isCompleted: false,
              isLocked: false,
              canReplay: false,
            };
          }
        });
      } else if (assignments.length > 0) {
        totalSubtopics = assignments.length;
        subtopics = assignments.map((sa) => {
          const isDone = completedScriptIds.has(sa.scriptId);
          if (isDone) completedSubtopics++;
          const isLocked = false;
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
    await this.syncRoadmapWithSyllabus(roadmapId);

    const roadmap = await prisma.roadmap.findUnique({
      where: { id: roadmapId },
      include: {
        roadmapSubjects: {
          where: {
            subject: { isActive: true },
          },
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
        subject: true,
        scriptAssignments: {
          where: { status: 'PUBLISHED' },
          orderBy: { sequence: 'asc' },
          include: { script: true },
        },
      },
    });

    if (nextStepInSubject) {
      if (nextStepInSubject.scriptAssignments.length > 0) {
        return this.formatStepResult(
          nextStepInSubject,
          nextStepInSubject.scriptAssignments[0]
        );
      } else {
        return {
          type: 'lesson',
          available: false,
          reason: 'SCRIPT_NOT_PUBLISHED',
          roadmapId: roadmap.id,
          roadmapStepId: nextStepInSubject.id,
          subjectId: nextStepInSubject.subjectId,
          subjectName: nextStepInSubject.subject?.name,
          topicId: nextStepInSubject.topicId,
          topicName: nextStepInSubject.topic?.name,
          subtopicId: nextStepInSubject.subtopicId,
          message: 'The next lesson in this topic is coming soon.',
        };
      }
    }

    // Rule 3: Next subject in the roadmap with published content
    const currentRoadmapSubject = roadmap.roadmapSubjects.find(
      (rs) => rs.subjectId === currentStep.subjectId
    );
    const currentSubjectSequence = currentRoadmapSubject?.sequence ?? 0;

    const laterRoadmapSubjects = roadmap.roadmapSubjects.filter(
      (rs) => rs.sequence > currentSubjectSequence
    );

    for (const rs of laterRoadmapSubjects) {
      const firstStepOfNextSubject = await prisma.roadmapStep.findFirst({
        where: {
          roadmapId: roadmap.id,
          subjectId: rs.subjectId,
          isActive: true,
          scriptAssignments: {
            some: { status: 'PUBLISHED' },
          },
        },
        orderBy: { sequence: 'asc' },
        include: {
          topic: true,
          subject: true,
          scriptAssignments: {
            where: { status: 'PUBLISHED' },
            orderBy: { sequence: 'asc' },
            include: { script: true },
          },
        },
      });

      if (firstStepOfNextSubject && firstStepOfNextSubject.scriptAssignments.length > 0) {
        return this.formatStepResult(
          firstStepOfNextSubject,
          firstStepOfNextSubject.scriptAssignments[0]
        );
      }
    }

    // Rule 4: No published steps remain in the roadmap
    return {
      type: 'roadmap_complete',
      available: false,
      reason: 'ROADMAP_COMPLETED',
      roadmapId: roadmap.id,
      message: 'Congratulations! You have completed all available topics in this roadmap.',
    };
  }

  private formatStepResult(step: any, scriptAssignment?: any): NextLearningStepResult {
    if (scriptAssignment && scriptAssignment.script) {
      return {
        type: 'lesson',
        available: true,
        roadmapId: step.roadmapId,
        roadmapStepId: step.id,
        subjectId: step.subjectId,
        subjectName: step.subject?.name,
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
      subjectId: step.subjectId,
      subjectName: step.subject?.name,
      topicId: step.topicId,
      topicName: step.topic.name,
      subtopicId: step.subtopicId,
    };
  }
}

export const roadmapProgressionService = RoadmapProgressionService.getInstance();
