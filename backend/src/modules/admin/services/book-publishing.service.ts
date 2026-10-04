import { prisma } from '../../../config/prisma';
import { scriptCacheService } from '../../lesson/services/script-cache.service';

export interface PublishResult {
  success: boolean;
  bookId: string;
  subjectId: string;
  subjectName: string;
  publishedTopicsCount: number;
  publishedSubtopicsCount: number;
  publishedScriptsCount: number;
  publishedQuestionsCount: number;
}

export class BookPublishingService {
  private static instance: BookPublishingService;

  private constructor() {}

  public static getInstance(): BookPublishingService {
    if (!BookPublishingService.instance) {
      BookPublishingService.instance = new BookPublishingService();
    }
    return BookPublishingService.instance;
  }

  /**
   * Activates the book Subject and marks all child topics, subtopics,
   * lesson scripts, and questions as live/PUBLISHED.
   */
  public async publishBook(bookId: string): Promise<PublishResult> {
    const bookSource = await prisma.bookSource.findUnique({
      where: { id: bookId },
      include: {
        subject: {
          include: {
            topics: {
              include: {
                subtopics: true,
              },
            },
          },
        },
      },
    });

    if (!bookSource) {
      throw new Error(`BookSource not found: ${bookId}`);
    }

    const subjectId = bookSource.subject.id;

    console.log(`[BookPublishingService] Publishing book "${bookSource.title}" into Subject "${subjectId}"...`);

    const result = await prisma.$transaction(async (tx) => {
      // 1. Activate the Subject
      const subject = await tx.subject.update({
        where: { id: subjectId },
        data: { isActive: true },
      });

      // 2. Activate all Topics under this Subject
      const topicsUpdate = await tx.topic.updateMany({
        where: { subjectId },
        data: { isActive: true },
      });

      // 3. Activate all Subtopics under these Topics
      const topicIds = bookSource.subject.topics.map((t) => t.id);
      const subtopicsUpdate = await tx.subtopic.updateMany({
        where: { topicId: { in: topicIds } },
        data: { isActive: true },
      });

      // 4. Publish all Lesson Scripts and Versions
      const scriptsUpdate = await tx.lessonScript.updateMany({
        where: { subjectId },
        data: { status: 'PUBLISHED' },
      });

      const scriptRecords = await tx.lessonScript.findMany({
        where: { subjectId },
        select: { id: true, slug: true },
      });
      const scriptIds = scriptRecords.map((s) => s.id);

      await tx.lessonScriptVersion.updateMany({
        where: { scriptId: { in: scriptIds } },
        data: {
          status: 'PUBLISHED',
          publishedAt: new Date(),
        },
      });

      // 5. Publish all Questions under this Subject
      const questionsUpdate = await tx.question.updateMany({
        where: { subjectId },
        data: {
          status: 'PUBLISHED',
          reviewedAt: new Date(),
        },
      });

      // 6. Mark BookSource as PUBLISHED
      await tx.bookSource.update({
        where: { id: bookId },
        data: {
          status: 'PUBLISHED',
          errorMessage: null,
        },
      });

      return {
        subject,
        publishedTopicsCount: topicsUpdate.count,
        publishedSubtopicsCount: subtopicsUpdate.count,
        publishedScriptsCount: scriptsUpdate.count,
        publishedQuestionsCount: questionsUpdate.count,
        scriptSlugs: scriptRecords.map((s) => s.slug),
      };
    });

    // Invalidate script caches
    for (const slug of result.scriptSlugs) {
      await scriptCacheService.invalidateScriptCache(slug);
    }

    console.log(
      `[BookPublishingService] Successfully published Subject "${result.subject.name}": ` +
      `${result.publishedTopicsCount} topics, ${result.publishedSubtopicsCount} subtopics, ` +
      `${result.publishedScriptsCount} scripts, ${result.publishedQuestionsCount} questions live.`
    );

    return {
      success: true,
      bookId,
      subjectId,
      subjectName: result.subject.name,
      publishedTopicsCount: result.publishedTopicsCount,
      publishedSubtopicsCount: result.publishedSubtopicsCount,
      publishedScriptsCount: result.publishedScriptsCount,
      publishedQuestionsCount: result.publishedQuestionsCount,
    };
  }
}

export const bookPublishingService = BookPublishingService.getInstance();
