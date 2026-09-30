import { prisma } from '../../config/prisma';
import crypto from 'crypto';

export class AdminSyllabusService {
  /**
   * Retrieves full syllabus tree (Subjects -> Topics -> Subtopics) with attached scripts & question counts
   */
  public static async getFullSyllabus() {
    const subjects = await prisma.subject.findMany({
      orderBy: { displayOrder: 'asc' },
      include: {
        topics: {
          orderBy: { name: 'asc' },
          include: {
            subtopics: {
              orderBy: { sequence: 'asc' },
              include: {
                _count: {
                  select: { questions: true },
                },
              },
            },
            _count: {
              select: { questions: true, subtopics: true },
            },
          },
        },
        _count: {
          select: { questions: true, topics: true },
        },
      },
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

    return prisma.subject.create({
      data: {
        id,
        slug,
        name: data.name,
        description: data.description || '',
        displayOrder: data.displayOrder ?? 0,
        isActive: true,
      },
    });
  }

  public static async updateSubject(id: string, data: {
    name?: string;
    description?: string;
    displayOrder?: number;
    isActive?: boolean;
  }) {
    return prisma.subject.update({
      where: { id },
      data,
    });
  }

  public static async deleteSubject(id: string, hard = false) {
    if (!hard) {
      // Soft delete
      return prisma.subject.update({
        where: { id },
        data: { isActive: false },
      });
    }

    // Hard delete: Clean up related records in transaction
    return prisma.$transaction(async (tx) => {
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

    return prisma.topic.create({
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
  }

  public static async updateTopic(id: string, data: {
    name?: string;
    description?: string;
    defaultImportance?: string;
    defaultTeachingDepth?: number;
    defaultTeachingMinutes?: number;
    isActive?: boolean;
  }) {
    return prisma.topic.update({
      where: { id },
      data,
    });
  }

  public static async deleteTopic(id: string, hard = false) {
    if (!hard) {
      return prisma.topic.update({
        where: { id },
        data: { isActive: false },
      });
    }

    return prisma.$transaction(async (tx) => {
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

    return prisma.subtopic.create({
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
  }

  public static async updateSubtopic(id: string, data: {
    name?: string;
    description?: string;
    sequence?: number;
    importance?: string;
    teachingDepth?: number;
    teachingMinutes?: number;
    isActive?: boolean;
  }) {
    return prisma.subtopic.update({
      where: { id },
      data,
    });
  }

  public static async deleteSubtopic(id: string, hard = false) {
    if (!hard) {
      return prisma.subtopic.update({
        where: { id },
        data: { isActive: false },
      });
    }

    return prisma.$transaction(async (tx) => {
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
    subtopicId?: string;
    definition: any;
    status?: 'DRAFT' | 'REVIEW' | 'PUBLISHED';
  }) {
    const slug = `${data.topicId}-${data.title.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '')}-${Date.now().toString(36)}`;
    const definitionString = JSON.stringify(data.definition || {});
    const checksum = crypto.createHash('sha256').update(definitionString).digest('hex');
    const status = data.status || 'PUBLISHED';

    return prisma.$transaction(async (tx) => {
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
          definition: data.definition || {},
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
    return prisma.$transaction(async (tx) => {
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
        const nextVersionNum = (existing.versions[0]?.versionNumber || 0) + 1;
        const definitionString = JSON.stringify(data.definition);
        const checksum = crypto.createHash('sha256').update(definitionString).digest('hex');

        const newVersion = await tx.lessonScriptVersion.create({
          data: {
            scriptId,
            versionNumber: nextVersionNum,
            definition: data.definition,
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
  }
}
