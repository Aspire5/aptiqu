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
   * A subtopic is LIVE if and only if it has a published lesson script
   * with an active published version in an active roadmap.
   */
  public static async isSubtopicLive(subtopicId: string): Promise<boolean> {
    const liveAssignmentCount = await prisma.scriptAssignment.count({
      where: {
        status: 'PUBLISHED',
        publishedVersionId: { not: null },
        roadmapStep: {
          subtopicId,
          isActive: true,
        },
      },
    });

    if (liveAssignmentCount > 0) return true;

    // Fallback: direct check on LessonScript
    const scriptCount = await prisma.lessonScript.count({
      where: {
        subtopicId,
        status: 'PUBLISHED',
        publishedVersionId: { not: null },
      },
    });

    return scriptCount > 0;
  }

  /**
   * Checks if a Topic is LIVE.
   */
  public static async isTopicLive(topicId: string): Promise<boolean> {
    const count = await prisma.scriptAssignment.count({
      where: {
        status: 'PUBLISHED',
        publishedVersionId: { not: null },
        roadmapStep: {
          topicId,
          isActive: true,
        },
      },
    });

    if (count > 0) return true;

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
    const liveAssignments = await prisma.scriptAssignment.findMany({
      where: {
        status: 'PUBLISHED',
        publishedVersionId: { not: null },
        roadmapStep: {
          topicId,
          isActive: true,
          subtopicId: { not: null },
        },
      },
      include: {
        roadmapStep: {
          include: {
            subtopic: true,
            topic: {
              include: {
                subject: true,
              },
            },
          },
        },
      },
    });

    const seenSubtopics = new Map<string, LiveSubtopicWithContext>();

    for (const a of liveAssignments) {
      const step = a.roadmapStep;
      if (step.subtopic && !seenSubtopics.has(step.subtopic.id)) {
        seenSubtopics.set(step.subtopic.id, {
          id: step.subtopic.id,
          name: step.subtopic.name,
          description: step.subtopic.description,
          topicId: step.topic.id,
          topicName: step.topic.name,
          subjectId: step.topic.subject.id,
          subjectName: step.topic.subject.name,
        });
      }
    }

    return Array.from(seenSubtopics.values());
  }

  /**
   * Returns all LIVE topics and subtopics in the universe.
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
    const liveAssignments = await prisma.scriptAssignment.findMany({
      where: {
        status: 'PUBLISHED',
        publishedVersionId: { not: null },
        roadmapStep: {
          isActive: true,
          subtopicId: { not: null },
        },
      },
      include: {
        roadmapStep: {
          include: {
            subtopic: true,
            topic: {
              include: {
                subject: true,
              },
            },
          },
        },
      },
    });

    const topicMap = new Map<
      string,
      {
        subjectId: string;
        subjectName: string;
        topicId: string;
        topicName: string;
        subtopics: Map<string, { id: string; name: string; description: string | null }>;
      }
    >();

    for (const a of liveAssignments) {
      const step = a.roadmapStep;
      if (!step.subtopic) continue;

      if (!topicMap.has(step.topic.id)) {
        topicMap.set(step.topic.id, {
          subjectId: step.topic.subject.id,
          subjectName: step.topic.subject.name,
          topicId: step.topic.id,
          topicName: step.topic.name,
          subtopics: new Map(),
        });
      }

      const t = topicMap.get(step.topic.id)!;
      t.subtopics.set(step.subtopic.id, {
        id: step.subtopic.id,
        name: step.subtopic.name,
        description: step.subtopic.description,
      });
    }

    return Array.from(topicMap.values()).map((t) => ({
      subjectId: t.subjectId,
      subjectName: t.subjectName,
      topicId: t.topicId,
      topicName: t.topicName,
      subtopics: Array.from(t.subtopics.values()),
    }));
  }
}
