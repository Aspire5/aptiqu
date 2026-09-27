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
    // 1. Direct check on LessonScript with this subtopicId
    const scriptCount = await prisma.lessonScript.count({
      where: {
        subtopicId,
        status: 'PUBLISHED',
        publishedVersionId: { not: null },
      },
    });

    if (scriptCount > 0) return true;

    // 2. Check if subtopic's parent topic has published scripts
    const subtopic = await prisma.subtopic.findUnique({
      where: { id: subtopicId },
      select: { topicId: true },
    });

    if (subtopic) {
      const topicScriptCount = await prisma.lessonScript.count({
        where: {
          topicId: subtopic.topicId,
          status: 'PUBLISHED',
          publishedVersionId: { not: null },
        },
      });
      if (topicScriptCount > 0) return true;
    }

    return false;
  }

  /**
   * Checks if a Topic is LIVE (has at least one published script).
   */
  public static async isTopicLive(topicId: string): Promise<boolean> {
    const scriptCount = await prisma.lessonScript.count({
      where: {
        topicId,
        status: 'PUBLISHED',
        publishedVersionId: { not: null },
      },
    });

    return scriptCount > 0;
  }

  /**
   * Returns all LIVE subtopics for a specific topic.
   */
  public static async getLiveSubtopicsForTopic(topicId: string): Promise<LiveSubtopicWithContext[]> {
    const isLive = await this.isTopicLive(topicId);
    if (!isLive) return [];

    const topic = await prisma.topic.findUnique({
      where: { id: topicId },
      include: {
        subject: true,
        subtopics: {
          orderBy: { sequence: 'asc' },
        },
      },
    });

    if (!topic) return [];

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
      where: { id: { in: topicIds } },
      include: {
        subject: true,
        subtopics: {
          orderBy: { sequence: 'asc' },
        },
      },
      orderBy: { createdAt: 'asc' },
    });

    return topics.map((t) => ({
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
