import { prisma } from '../../config/prisma';
import crypto from 'crypto';
import { ScriptDefinition } from '../lesson/interfaces/script-dsl.interface';
import { ScriptValidator } from '../lesson/engines/script-validator';
import { roadmapProgressionService } from '../roadmap/services/roadmap-progression.service';
import { questionHydrationService } from '../lesson/services/question-hydration.service';
import { scriptCacheService } from '../lesson/services/script-cache.service';

export class AdminSyllabusService {
  /**
   * Retrieves full syllabus tree (Subjects -> Topics -> Subtopics) with attached scripts & question counts
   */
  public static async getFullSyllabus() {
    const rawSubjects = await prisma.subject.findMany({
      orderBy: { displayOrder: 'asc' },
      include: {
        topics: {
          where: { isActive: true },
          orderBy: { sequence: 'asc' },
          include: {
            subtopics: {
              where: { isActive: true },
              orderBy: { sequence: 'asc' },
              include: {
                _count: {
                  select: { questions: true },
                },
              },
            },
            topicSubtopics: {
              orderBy: { sequence: 'asc' },
              include: {
                subtopic: {
                  include: {
                    _count: {
                      select: { questions: true },
                    },
                  },
                },
              },
            },
            _count: {
              select: { questions: true, subtopics: true },
            },
          },
        },
        subjectTopics: {
          orderBy: { sequence: 'asc' },
          include: {
            topic: {
              include: {
                subtopics: {
                  where: { isActive: true },
                  orderBy: { sequence: 'asc' },
                  include: {
                    _count: {
                      select: { questions: true },
                    },
                  },
                },
                topicSubtopics: {
                  orderBy: { sequence: 'asc' },
                  include: {
                    subtopic: {
                      include: {
                        _count: {
                          select: { questions: true },
                        },
                      },
                    },
                  },
                },
                _count: {
                  select: { questions: true, subtopics: true },
                },
              },
            },
          },
        },
        _count: {
          select: { questions: true, topics: true },
        },
      },
    });

    // Merge direct & linked topics / subtopics with clean sequence preservation
    const subjects = rawSubjects.map((subject) => {
      const topicMap = new Map<string, any>();

      // 1. Add direct topics
      for (const t of subject.topics) {
        topicMap.set(t.id, { ...t, isLinked: false });
      }

      // 2. Add or merge linked topics
      for (const st of subject.subjectTopics) {
        if (st.topic && st.topic.isActive) {
          topicMap.set(st.topic.id, {
            ...st.topic,
            sequence: st.sequence,
            isLinked: true,
          });
        }
      }

      // Sort topics by sequence
      const topics = Array.from(topicMap.values())
        .sort((a, b) => (a.sequence ?? 0) - (b.sequence ?? 0))
        .map((t) => {
          const subtopicMap = new Map<string, any>();

          // Direct subtopics
          for (const s of t.subtopics || []) {
            subtopicMap.set(s.id, { ...s, isLinked: false });
          }

          // Linked subtopics
          for (const tst of t.topicSubtopics || []) {
            if (tst.subtopic && tst.subtopic.isActive) {
              subtopicMap.set(tst.subtopic.id, {
                ...tst.subtopic,
                sequence: tst.sequence,
                isLinked: true,
              });
            }
          }

          const sortedSubtopics = Array.from(subtopicMap.values()).sort(
            (a, b) => (a.sequence ?? 0) - (b.sequence ?? 0)
          );

          return {
            ...t,
            subtopics: sortedSubtopics,
          };
        });

      return {
        ...subject,
        topics,
      };
    });

    // Also fetch all scripts to map them to topic/subtopic
    const scripts = await prisma.lessonScript.findMany({
      include: {
        versions: {
          orderBy: { versionNumber: 'desc' },
          take: 1,
          select: {
            id: true,
            versionNumber: true,
            status: true,
            createdAt: true,
          },
        },
      },
    });

    return { subjects, scripts };
  }

  // ==================== SUBJECT CRUD ====================

  public static async createSubject(data: {
    id?: string;
    slug?: string;
    name: string;
    description?: string;
    displayOrder?: number;
  }) {
    const slug = data.slug || data.name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '');
    const id = data.id || slug;

    const result = await prisma.subject.create({
      data: {
        id,
        slug,
        name: data.name,
        description: data.description || '',
        displayOrder: data.displayOrder ?? 0,
        isActive: true,
      },
    });

    await roadmapProgressionService.syncRoadmapWithSyllabus(undefined, true);
    return result;
  }

  public static async updateSubject(id: string, data: {
    name?: string;
    description?: string;
    displayOrder?: number;
    isActive?: boolean;
  }) {
    const result = await prisma.subject.update({
      where: { id },
      data,
    });

    await roadmapProgressionService.syncRoadmapWithSyllabus(undefined, true);
    return result;
  }

  public static async deleteSubject(id: string, hard = false) {
    let result;
    if (!hard) {
      // Soft delete
      result = await prisma.subject.update({
        where: { id },
        data: { isActive: false },
      });
    } else {
      // Hard delete: Clean up related records in transaction
      result = await prisma.$transaction(async (tx) => {
        // Find all topics under subject
        const topics = await tx.topic.findMany({ where: { subjectId: id }, select: { id: true } });
        const topicIds = topics.map((t) => t.id);

        // Find subtopics
        const subtopics = await tx.subtopic.findMany({ where: { topicId: { in: topicIds } }, select: { id: true } });
        const subtopicIds = subtopics.map((s) => s.id);

        // Delete questions in these subtopics
        await tx.questionAttempt.deleteMany({
          where: { question: { subjectId: id } },
        });
        await tx.userQuestionProgress.deleteMany({
          where: { question: { subjectId: id } },
        });
        await tx.pvpQuestionSetQuestion.deleteMany({
          where: { question: { subjectId: id } },
        });
        await tx.practiceSessionQuestion.deleteMany({
          where: { question: { subjectId: id } },
        });
        await tx.question.deleteMany({
          where: { subjectId: id },
        });

        // Delete scripts
        await tx.lessonScript.deleteMany({
          where: { subjectId: id },
        });

        // Delete subtopics, topics, subject
        await tx.subtopic.deleteMany({ where: { id: { in: subtopicIds } } });
        await tx.topic.deleteMany({ where: { id: { in: topicIds } } });
        return tx.subject.delete({ where: { id } });
      });
    }

    await roadmapProgressionService.syncRoadmapWithSyllabus(undefined, true);
    return result;
  }

  // ==================== TOPIC CRUD ====================

  public static async createTopic(data: {
    id?: string;
    subjectId: string;
    slug?: string;
    name: string;
    description?: string;
    defaultImportance?: string;
    defaultTeachingDepth?: number;
    defaultTeachingMinutes?: number;
  }) {
    const slug = data.slug || `${data.subjectId}-${data.name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '')}`;
    const id = data.id || slug;

    const result = await prisma.topic.create({
      data: {
        id,
        subjectId: data.subjectId,
        slug,
        name: data.name,
        description: data.description || '',
        defaultImportance: data.defaultImportance || 'medium',
        defaultTeachingDepth: data.defaultTeachingDepth ?? 3,
        defaultTeachingMinutes: data.defaultTeachingMinutes ?? 30,
        isActive: true,
      },
    });

    await roadmapProgressionService.syncRoadmapWithSyllabus(undefined, true);
    return result;
  }

  public static async updateTopic(id: string, data: {
    name?: string;
    description?: string;
    defaultImportance?: string;
    defaultTeachingDepth?: number;
    defaultTeachingMinutes?: number;
    isActive?: boolean;
  }) {
    const result = await prisma.topic.update({
      where: { id },
      data,
    });

    await roadmapProgressionService.syncRoadmapWithSyllabus(undefined, true);
    return result;
  }

  public static async deleteTopic(id: string, hard = false) {
    let result;
    if (!hard) {
      result = await prisma.topic.update({
        where: { id },
        data: { isActive: false },
      });
    } else {
      result = await prisma.$transaction(async (tx) => {
        const subtopics = await tx.subtopic.findMany({ where: { topicId: id }, select: { id: true } });
        const subtopicIds = subtopics.map((s) => s.id);

        await tx.questionAttempt.deleteMany({
          where: { question: { topicId: id } },
        });
        await tx.userQuestionProgress.deleteMany({
          where: { question: { topicId: id } },
        });
        await tx.pvpQuestionSetQuestion.deleteMany({
          where: { question: { topicId: id } },
        });
        await tx.practiceSessionQuestion.deleteMany({
          where: { question: { topicId: id } },
        });
        await tx.question.deleteMany({ where: { topicId: id } });

        await tx.lessonScript.deleteMany({ where: { topicId: id } });
        await tx.subtopic.deleteMany({ where: { id: { in: subtopicIds } } });
        return tx.topic.delete({ where: { id } });
      });
    }

    await roadmapProgressionService.syncRoadmapWithSyllabus(undefined, true);
    return result;
  }

  // ==================== SUBTOPIC CRUD ====================

  public static async createSubtopic(data: {
    id?: string;
    topicId: string;
    slug?: string;
    name: string;
    description?: string;
    sequence?: number;
    importance?: string;
    teachingDepth?: number;
    teachingMinutes?: number;
  }) {
    const slug = data.slug || `${data.topicId}-${data.name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '')}`;
    const id = data.id || slug;

    const result = await prisma.subtopic.create({
      data: {
        id,
        topicId: data.topicId,
        slug,
        name: data.name,
        description: data.description || '',
        sequence: data.sequence ?? 0,
        importance: data.importance || 'medium',
        teachingDepth: data.teachingDepth ?? 3,
        teachingMinutes: data.teachingMinutes ?? 30,
        isActive: true,
      },
    });

    await roadmapProgressionService.syncRoadmapWithSyllabus(undefined, true);
    return result;
  }

  public static async updateSubtopic(id: string, data: {
    name?: string;
    slug?: string;
    description?: string;
    sequence?: number;
    importance?: string;
    teachingDepth?: number;
    teachingMinutes?: number;
    isActive?: boolean;
  }) {
    const updateData: any = { ...data };
    if (updateData.slug !== undefined) {
      updateData.slug = updateData.slug ? updateData.slug.trim() : null;
    }
    const result = await prisma.subtopic.update({
      where: { id },
      data: updateData,
    });

    await roadmapProgressionService.syncRoadmapWithSyllabus(undefined, true);
    return result;
  }

  public static async deleteSubtopic(id: string, hard = false) {
    let result;
    if (!hard) {
      result = await prisma.subtopic.update({
        where: { id },
        data: { isActive: false },
      });
    } else {
      result = await prisma.$transaction(async (tx) => {
        await tx.questionAttempt.deleteMany({
          where: { question: { subtopicId: id } },
        });
        await tx.userQuestionProgress.deleteMany({
          where: { question: { subtopicId: id } },
        });
        await tx.pvpQuestionSetQuestion.deleteMany({
          where: { question: { subtopicId: id } },
        });
        await tx.practiceSessionQuestion.deleteMany({
          where: { question: { subtopicId: id } },
        });
        await tx.question.deleteMany({ where: { subtopicId: id } });

        await tx.lessonScript.updateMany({
          where: { subtopicId: id },
          data: { subtopicId: null },
        });

        return tx.subtopic.delete({ where: { id } });
      });
    }

    await roadmapProgressionService.syncRoadmapWithSyllabus(undefined, true);
    return result;
  }

  // ==================== SCRIPT OPERATIONS ====================

  /**
   * Retrieves full script including JSON definition
   */
  public static async getScriptDetails(scriptId: string) {
    const script = await prisma.lessonScript.findUnique({
      where: { id: scriptId },
      include: {
        versions: {
          orderBy: { versionNumber: 'desc' },
        },
      },
    });

    if (!script) {
      throw new Error(`Script not found with id: ${scriptId}`);
    }

    const latestVersion = script.versions[0] || null;
    return {
      script,
      latestVersion,
    };
  }

  /**
   * Create a new script for a topic/subtopic
   */
  public static async createScript(data: {
    title: string;
    subjectId: string;
    topicId: string;
    subtopicId?: string | null;
    definition: any;
    status?: 'DRAFT' | 'REVIEW' | 'PUBLISHED';
  }) {
    const slug = `${data.topicId}-${data.title.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '')}-${Date.now().toString(36)}`;
    const normalized = scriptCacheService.normalizeScriptDefinition(data.definition || {}, data.title);
    const hydratedDef = await questionHydrationService.hydrateScriptDefinition(normalized);
    const definitionString = JSON.stringify(hydratedDef);
    const checksum = crypto.createHash('sha256').update(definitionString).digest('hex');
    const status = data.status || 'PUBLISHED';

    const result = await prisma.$transaction(async (tx) => {
      const script = await tx.lessonScript.create({
        data: {
          slug,
          title: data.title,
          subjectId: data.subjectId,
          topicId: data.topicId,
          subtopicId: data.subtopicId || null,
          status,
        },
      });

      const version = await tx.lessonScriptVersion.create({
        data: {
          scriptId: script.id,
          versionNumber: 1,
          definition: hydratedDef as any,
          checksum,
          status,
          publishedAt: status === 'PUBLISHED' ? new Date() : null,
        },
      });

      await tx.lessonScript.update({
        where: { id: script.id },
        data: { publishedVersionId: version.id },
      });

      return { script, version };
    });

    await scriptCacheService.invalidateScriptCache(slug, result.version?.id);
    await roadmapProgressionService.syncRoadmapWithSyllabus(undefined, true);
    return result;
  }

  /**
   * Updates an existing script title, status, or publishes a new JSON version
   */
  public static async updateScript(scriptId: string, data: {
    title?: string;
    status?: 'DRAFT' | 'REVIEW' | 'PUBLISHED' | 'ARCHIVED';
    subtopicId?: string | null;
    definition?: any;
  }) {
    const result = await prisma.$transaction(async (tx) => {
      const existing = await tx.lessonScript.findUnique({
        where: { id: scriptId },
        include: {
          versions: { orderBy: { versionNumber: 'desc' }, take: 1 },
        },
      });

      if (!existing) {
        throw new Error(`Script not found: ${scriptId}`);
      }

      // Update script metadata
      const script = await tx.lessonScript.update({
        where: { id: scriptId },
        data: {
          title: data.title !== undefined ? data.title : existing.title,
          status: data.status !== undefined ? data.status : existing.status,
          subtopicId: data.subtopicId !== undefined ? data.subtopicId : existing.subtopicId,
        },
      });

      // If definition provided, create a new version
      if (data.definition) {
        const normalized = scriptCacheService.normalizeScriptDefinition(data.definition, data.title || existing.title);
        const hydratedDef = await questionHydrationService.hydrateScriptDefinition(normalized);
        const nextVersionNum = (existing.versions[0]?.versionNumber || 0) + 1;
        const definitionString = JSON.stringify(hydratedDef);
        const checksum = crypto.createHash('sha256').update(definitionString).digest('hex');

        const newVersion = await tx.lessonScriptVersion.create({
          data: {
            scriptId,
            versionNumber: nextVersionNum,
            definition: hydratedDef as any,
            checksum,
            status: data.status || 'PUBLISHED',
            publishedAt: new Date(),
          },
        });

        await tx.lessonScript.update({
          where: { id: scriptId },
          data: { publishedVersionId: newVersion.id },
        });

        return { script, version: newVersion };
      }

      return { script, version: existing.versions[0] };
    });

    await scriptCacheService.invalidateScriptCache(result.script?.slug, result.version?.id);
    await roadmapProgressionService.syncRoadmapWithSyllabus(undefined, true);
    return result;
  }

  /**
   * Imports a full Lesson Script with strict external question existence and ownership verification.
   */
  public static async importScript(data: {
    subjectId?: string;
    topicId: string;
    subtopicId?: string;
    externalSubtopicKey?: string;
    definition?: any;
    scriptDefinition?: any;
    status?: 'DRAFT' | 'REVIEW' | 'PUBLISHED';
  }) {
    const rawDef = data.definition || data.scriptDefinition;
    if (!rawDef) {
      throw new Error('Script definition is required.');
    }
    const normalizedDef = scriptCacheService.normalizeScriptDefinition(rawDef);

    const subtopicKey = (
      data.externalSubtopicKey ||
      data.subtopicId ||
      normalizedDef.metadata?.subtopicId ||
      ''
    ).trim();

    if (!subtopicKey) {
      throw new Error('Target subtopicId or externalSubtopicKey is required.');
    }

    // 1. Resolve subtopic by externalSubtopicKey (slug) or ID under topic
    const subtopic = await prisma.subtopic.findFirst({
      where: {
        topicId: data.topicId,
        OR: [
          { slug: subtopicKey },
          { id: subtopicKey },
        ],
      },
      include: { topic: true },
    });

    if (!subtopic) {
      throw new Error(
        `Target subtopic with key '${subtopicKey}' does not exist under topic '${data.topicId}'.`
      );
    }

    // 2. Validate Script DSL Structure
    const validation = ScriptValidator.validate(normalizedDef);
    if (!validation.valid) {
      throw new Error(`Script DSL validation failed: ${validation.errors.map((e) => e.message).join('; ')}`);
    }

    // 3. Hydrate questions from question bank & enforce strict existence
    const hydratedDef = await questionHydrationService.hydrateScriptDefinition(normalizedDef);

    // Verify subtopic & topic ownership of referenced questions
    for (const [nodeId, node] of Object.entries(hydratedDef.nodes)) {
      if (node.type === 'QUESTION' && node.questionReference?.questionId) {
        const q = await prisma.question.findUnique({
          where: { id: node.questionReference.questionId },
          select: { id: true, externalKey: true, topicId: true, subtopicId: true },
        });
        if (q) {
          if (q.topicId !== data.topicId) {
            throw new Error(
              `❌ SCRIPT IMPORT FAILED: Question '${q.externalKey || q.id}' belongs to topic '${q.topicId}', but this script is for topic '${data.topicId}'.`
            );
          }
          if (q.subtopicId !== subtopic.id && q.subtopicId !== subtopic.slug) {
            throw new Error(
              `❌ SCRIPT IMPORT FAILED: Question '${q.externalKey || q.id}' belongs to subtopic '${q.subtopicId}', while this script is for subtopic '${subtopic.id}' (${subtopic.slug || ''}).`
            );
          }
        }
      }
    }

    // 4. Persistence
    const status = data.status || 'PUBLISHED';
    const slug = hydratedDef.scriptId || `${data.topicId}-${subtopic.slug || subtopic.id}-script`;
    const definitionString = JSON.stringify(hydratedDef);
    const checksum = crypto.createHash('sha256').update(definitionString).digest('hex');
    const subjectId = data.subjectId || subtopic.topic.subjectId;

    const result = await prisma.$transaction(async (tx) => {
      let script = await tx.lessonScript.findUnique({
        where: { slug },
      });

      if (!script) {
        script = await tx.lessonScript.create({
          data: {
            slug,
            title: hydratedDef.metadata?.title || `${subtopic.name} Script`,
            subjectId,
            topicId: data.topicId,
            subtopicId: subtopic.id,
            status: status as any,
          },
        });
      } else {
        await tx.lessonScript.update({
          where: { id: script.id },
          data: {
            title: hydratedDef.metadata?.title || script.title,
            subjectId,
            topicId: data.topicId,
            subtopicId: subtopic.id,
            status: status as any,
          },
        });
      }

      // Check current latest version
      const latestVersion = await tx.lessonScriptVersion.findFirst({
        where: { scriptId: script.id },
        orderBy: { versionNumber: 'desc' },
      });
      const nextVersionNumber = (latestVersion?.versionNumber || 0) + 1;

      const version = await tx.lessonScriptVersion.create({
        data: {
          scriptId: script.id,
          versionNumber: nextVersionNumber,
          definition: hydratedDef as any,
          checksum,
          status: status as any,
          publishedAt: status === 'PUBLISHED' ? new Date() : null,
        },
      });

      if (status === 'PUBLISHED') {
        await tx.lessonScript.update({
          where: { id: script.id },
          data: { publishedVersionId: version.id },
        });
      }

      return { script, version };
    });

    await scriptCacheService.invalidateScriptCache(slug, result.version?.id);
    await roadmapProgressionService.syncRoadmapWithSyllabus(undefined, true);
    return result;
  }

  // ==================== REORDERING ====================

  public static async reorderTopics(subjectId: string, topicIds: string[]) {
    const result = await prisma.$transaction(async (tx) => {
      for (let i = 0; i < topicIds.length; i++) {
        const topicId = topicIds[i];
        // 1. Update topic.sequence
        await tx.topic.updateMany({
          where: { id: topicId, subjectId },
          data: { sequence: i },
        });

        // 2. Update subjectTopic.sequence if linked
        await tx.subjectTopic.updateMany({
          where: { subjectId, topicId },
          data: { sequence: i },
        });
      }
      return { success: true };
    });

    await roadmapProgressionService.syncRoadmapWithSyllabus(undefined, true);
    return result;
  }

  public static async reorderSubtopics(topicId: string, subtopicIds: string[]) {
    const result = await prisma.$transaction(async (tx) => {
      for (let i = 0; i < subtopicIds.length; i++) {
        const subtopicId = subtopicIds[i];
        // 1. Update subtopic.sequence
        await tx.subtopic.updateMany({
          where: { id: subtopicId, topicId },
          data: { sequence: i },
        });

        // 2. Update topicSubtopic.sequence if linked
        await tx.topicSubtopic.updateMany({
          where: { topicId, subtopicId },
          data: { sequence: i },
        });
      }
      return { success: true };
    });

    await roadmapProgressionService.syncRoadmapWithSyllabus(undefined, true);
    return result;
  }

  // ==================== LINKING / REUSABILITY ====================

  public static async linkTopicToSubject(subjectId: string, topicId: string) {
    const existing = await prisma.subjectTopic.findUnique({
      where: { subjectId_topicId: { subjectId, topicId } },
    });
    if (existing) return existing;

    const maxSeq = await prisma.subjectTopic.aggregate({
      where: { subjectId },
      _max: { sequence: true },
    });
    const nextSeq = (maxSeq._max.sequence ?? 0) + 1;

    const res = await prisma.subjectTopic.create({
      data: {
        subjectId,
        topicId,
        sequence: nextSeq,
      },
    });

    await roadmapProgressionService.syncRoadmapWithSyllabus(undefined, true);
    return res;
  }

  public static async unlinkTopicFromSubject(subjectId: string, topicId: string) {
    // 1. If in subjectTopics join table, remove it
    await prisma.subjectTopic.deleteMany({
      where: { subjectId, topicId },
    });

    // 2. If it's the primary topic.subjectId, check if another subject is linked
    const topic = await prisma.topic.findUnique({
      where: { id: topicId },
      include: { subjectTopics: true },
    });

    if (topic && topic.subjectId === subjectId) {
      if (topic.subjectTopics.length > 0) {
        const nextSubjectId = topic.subjectTopics[0].subjectId;
        await prisma.topic.update({
          where: { id: topicId },
          data: { subjectId: nextSubjectId },
        });
        await prisma.subjectTopic.deleteMany({
          where: { subjectId: nextSubjectId, topicId },
        });
      }
    }

    await roadmapProgressionService.syncRoadmapWithSyllabus(undefined, true);
    return { success: true, message: 'Topic unlinked successfully without deletion.' };
  }

  public static async linkSubtopicToTopic(topicId: string, subtopicId: string) {
    const existing = await prisma.topicSubtopic.findUnique({
      where: { topicId_subtopicId: { topicId, subtopicId } },
    });
    if (existing) return existing;

    const maxSeq = await prisma.topicSubtopic.aggregate({
      where: { topicId },
      _max: { sequence: true },
    });
    const nextSeq = (maxSeq._max.sequence ?? 0) + 1;

    const res = await prisma.topicSubtopic.create({
      data: {
        topicId,
        subtopicId,
        sequence: nextSeq,
      },
    });

    await roadmapProgressionService.syncRoadmapWithSyllabus(undefined, true);
    return res;
  }

  public static async unlinkSubtopicFromTopic(topicId: string, subtopicId: string) {
    await prisma.topicSubtopic.deleteMany({
      where: { topicId, subtopicId },
    });

    const subtopic = await prisma.subtopic.findUnique({
      where: { id: subtopicId },
      include: { topicSubtopics: true },
    });

    if (subtopic && subtopic.topicId === topicId) {
      if (subtopic.topicSubtopics.length > 0) {
        const nextTopicId = subtopic.topicSubtopics[0].topicId;
        await prisma.subtopic.update({
          where: { id: subtopicId },
          data: { topicId: nextTopicId },
        });
        await prisma.topicSubtopic.deleteMany({
          where: { topicId: nextTopicId, subtopicId },
        });
      }
    }

    await roadmapProgressionService.syncRoadmapWithSyllabus(undefined, true);
    return { success: true, message: 'Subtopic unlinked successfully without deletion.' };
  }

  public static async getAllAvailableTopics() {
    return prisma.topic.findMany({
      where: { isActive: true },
      orderBy: { name: 'asc' },
      include: {
        subject: { select: { id: true, name: true } },
        _count: { select: { subtopics: true, questions: true } },
      },
    });
  }

  public static async getAllAvailableSubtopics() {
    return prisma.subtopic.findMany({
      where: { isActive: true },
      orderBy: { name: 'asc' },
      include: {
        topic: { select: { id: true, name: true } },
        _count: { select: { questions: true } },
      },
    });
  }
}
