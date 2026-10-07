import { prisma } from '../../../config/prisma';

export interface LiveSubtopicWithContext {
  id: string;
  name: string;
  description: string | null;
  topicId: string;
  topicName: string;
  subjectId: string;
  subjectName: string;
}

export class LiveCurriculumService {
  /**
   * Authoritatively determines if a topic or subtopic is LIVE.
   * A subtopic is LIVE if and only if it (or its parent topic) has a published lesson script
   * with an active published version.
   */
  public static async isSubtopicLive(subtopicId: string): Promise<boolean> {
    // 0. Verify subtopic and its parent hierarchy are ACTIVE
    const subtopic = await prisma.subtopic.findFirst({
      where: {
        OR: [
          { id: subtopicId },
          { slug: subtopicId },
        ],
      },
      include: {
        topic: {
          include: {
            subject: true,
          },
        },
      },
    });

    if (!subtopic || !subtopic.isActive || (subtopic.topic && !subtopic.topic.isActive) || (subtopic.topic?.subject && !subtopic.topic.subject.isActive)) {
      return false;
    }

    // 1. Direct check on LessonScript with this subtopicId or slug
    const scriptCount = await prisma.lessonScript.count({
      where: {
        OR: [
          { subtopicId: subtopic.id },
          ...(subtopic.slug ? [{ subtopicId: subtopic.slug }] : []),
        ],
        status: 'PUBLISHED',
        publishedVersionId: { not: null },
      },
    });

    if (scriptCount > 0) return true;

    // 2. Check if subtopic's parent topic has published scripts
    const topicScriptCount = await prisma.lessonScript.count({
      where: {
        OR: [
          { topicId: subtopic.topicId },
          ...(subtopic.topic?.slug ? [{ topicId: subtopic.topic.slug }] : []),
        ],
        status: 'PUBLISHED',
        publishedVersionId: { not: null },
      },
    });
    if (topicScriptCount > 0) return true;

    // 3. Check if roadmap steps have published script assignments for this topic/subtopic
    const stepWithScript = await prisma.roadmapStep.findFirst({
      where: {
        OR: [
          { subtopicId: subtopic.id },
          { topicId: subtopic.topicId },
        ],
        scriptAssignments: {
          some: {
            status: 'PUBLISHED',
          },
        },
      },
    });
    if (stepWithScript) return true;

    // 4. Check if published questions exist for this subtopic or topic
    const questionCount = await prisma.question.count({
      where: {
        OR: [
          { subtopicId: subtopic.id },
          ...(subtopic.slug ? [{ subtopicId: subtopic.slug }] : []),
          { topicId: subtopic.topicId },
        ],
        status: 'PUBLISHED',
      },
    });
    return questionCount > 0;
  }

  /**
   * Checks if a Topic is LIVE (is active, subject is active, and has at least one published script or question).
   */
  public static async isTopicLive(topicId: string): Promise<boolean> {
    const topic = await prisma.topic.findFirst({
      where: {
        OR: [
          { id: topicId },
          { slug: topicId },
        ],
      },
      include: { subject: true },
    });

    if (!topic || !topic.isActive || (topic.subject && !topic.subject.isActive)) {
      return false;
    }

    const scriptCount = await prisma.lessonScript.count({
      where: {
        OR: [
          { topicId: topic.id },
          ...(topic.slug ? [{ topicId: topic.slug }] : []),
        ],
        status: 'PUBLISHED',
        publishedVersionId: { not: null },
      },
    });

    if (scriptCount > 0) return true;

    const stepWithScript = await prisma.roadmapStep.findFirst({
      where: {
        topicId: topic.id,
        scriptAssignments: {
          some: {
            status: 'PUBLISHED',
          },
        },
      },
    });
    if (stepWithScript) return true;

    const questionCount = await prisma.question.count({
      where: {
        topicId: topic.id,
        status: 'PUBLISHED',
      },
    });
    return questionCount > 0;
  }

  /**
   * Returns all LIVE and ACTIVE subtopics for a specific topic.
   */
  public static async getLiveSubtopicsForTopic(topicId: string): Promise<LiveSubtopicWithContext[]> {
    const isLive = await this.isTopicLive(topicId);
    if (!isLive) return [];

    const topic = await prisma.topic.findFirst({
      where: {
        OR: [
          { id: topicId },
          { slug: topicId },
        ],
        isActive: true,
      },
      include: {
        subject: true,
        subtopics: {
          where: { isActive: true },
          orderBy: { sequence: 'asc' },
        },
      },
    });

    if (!topic || !topic.isActive || (topic.subject && !topic.subject.isActive)) return [];

    return topic.subtopics.map((s) => ({
      id: s.id,
      name: s.name,
      description: s.description,
      topicId: topic.id,
      topicName: topic.name,
      subjectId: topic.subject.id,
      subjectName: topic.subject.name,
    }));
  }

  /**
   * Returns all LIVE topics and subtopics in the universe that have published scripts.
   * Inactive subjects, topics, or subtopics are strictly excluded.
   * Topics/subjects without scripts (coming soon) are excluded.
   */
  public static async getAllLiveCurriculumUniverse(): Promise<
    {
      subjectId: string;
      subjectName: string;
      topicId: string;
      topicName: string;
      subtopics: { id: string; name: string; description: string | null }[];
    }[]
  > {
    const publishedScripts = await prisma.lessonScript.findMany({
      where: {
        status: 'PUBLISHED',
        publishedVersionId: { not: null },
      },
      select: {
        id: true,
        subjectId: true,
        topicId: true,
        subtopicId: true,
      },
    });

    if (publishedScripts.length === 0) return [];

    const topicIds = Array.from(new Set(publishedScripts.map((s) => s.topicId)));

    const topics = await prisma.topic.findMany({
      where: {
        id: { in: topicIds },
        isActive: true,
        subject: { isActive: true },
      },
      include: {
        subject: true,
        subtopics: {
          where: { isActive: true },
          orderBy: { sequence: 'asc' },
        },
      },
      orderBy: { createdAt: 'asc' },
    });

    return topics
      .filter((t) => t.isActive && t.subject.isActive && t.subtopics.length > 0)
      .map((t) => ({
        subjectId: t.subject.id,
        subjectName: t.subject.name,
        topicId: t.id,
        topicName: t.name,
        subtopics: t.subtopics.map((s) => ({
          id: s.id,
          name: s.name,
          description: s.description,
        })),
      }));
  }
}
