import { Request, Response } from 'express';
import { prisma } from '../../../config/prisma';
import { bookStorageService } from '../services/book-storage.service';
import { bookPublishingService } from '../services/book-publishing.service';
import { bookIngestionQueue } from '../../../queues/book-ingestion.queue';
import { BookIngestionProgress } from '../types/book-ingestion.types';

export class AdminBooksController {
  /**
   * Uploads a book PDF, creates Subject + BookSource, and enqueues background processing.
   */
  public static async uploadBook(req: Request, res: Response): Promise<void> {
    try {
      const file = req.file;
      if (!file) {
        res.status(400).json({ success: false, message: 'PDF file is required' });
        return;
      }

      const { title, author, edition, isbn } = req.body;
      if (!title || !title.trim()) {
        res.status(400).json({ success: false, message: 'Book title is required' });
        return;
      }

      const { bookSource, subject, isDuplicate } = await bookStorageService.saveUploadedBook(
        file.path,
        {
          title: title.trim(),
          author: author ? String(author).trim() : undefined,
          edition: edition ? String(edition).trim() : undefined,
          isbn: isbn ? String(isbn).trim() : undefined,
        }
      );

      if (isDuplicate && bookSource.status === 'PUBLISHED') {
        res.status(200).json({
          success: true,
          message: 'Book already uploaded and published',
          data: { bookSource, subject, isDuplicate: true },
        });
        return;
      }

      // Enqueue full processing job in BullMQ
      await bookIngestionQueue.add(
        'process-full-book',
        { bookId: bookSource.id },
        {
          jobId: `book-process:${bookSource.id}`,
          removeOnComplete: true,
        }
      );

      res.status(202).json({
        success: true,
        message: 'Book uploaded successfully. Ingestion pipeline initiated in background.',
        data: {
          bookId: bookSource.id,
          subjectId: subject.id,
          subjectName: subject.name,
          status: bookSource.status,
          isDuplicate,
        },
      });
    } catch (err: any) {
      console.error('[AdminBooksController:uploadBook] Error:', err);
      res.status(400).json({ success: false, message: err.message || 'Book upload failed' });
    }
  }

  /**
   * Lists all uploaded books with their processing status and subject info.
   */
  public static async listBooks(req: Request, res: Response): Promise<void> {
    try {
      const page = Math.max(1, Number(req.query.page) || 1);
      const limit = Math.max(1, Math.min(50, Number(req.query.limit) || 15));
      const skip = (page - 1) * limit;

      const where: any = {};
      if (req.query.status) {
        where.status = String(req.query.status);
      }

      const [books, total] = await Promise.all([
        prisma.bookSource.findMany({
          where,
          skip,
          take: limit,
          orderBy: { createdAt: 'desc' },
          include: {
            subject: {
              select: {
                id: true,
                slug: true,
                name: true,
                isActive: true,
                _count: { select: { topics: true, questions: true } },
              },
            },
          },
        }),
        prisma.bookSource.count({ where }),
      ]);

      res.status(200).json({
        success: true,
        data: {
          books: books.map((b) => ({
            ...b,
            fileSizeBytes: b.fileSizeBytes.toString(),
          })),
          pagination: {
            total,
            page,
            limit,
            totalPages: Math.ceil(total / limit),
          },
        },
      });
    } catch (err: any) {
      res.status(500).json({ success: false, message: err.message });
    }
  }

  /**
   * Retrieves full book details and overview statistics.
   */
  public static async getBook(req: Request, res: Response): Promise<void> {
    try {
      const id = req.params.id as string;
      const book = await prisma.bookSource.findUnique({
        where: { id },
        include: {
          subject: {
            include: {
              topics: {
                orderBy: { sequence: 'asc' },
                include: {
                  subtopics: {
                    orderBy: { sequence: 'asc' },
                    include: {
                      _count: { select: { questions: true } },
                    },
                  },
                  _count: { select: { questions: true } },
                },
              },
            },
          },
          jobs: {
            orderBy: { startedAt: 'desc' },
          },
        },
      });

      if (!book) {
        res.status(404).json({ success: false, message: 'Book not found' });
        return;
      }

      res.status(200).json({
        success: true,
        data: {
          ...book,
          fileSizeBytes: book.fileSizeBytes.toString(),
        },
      });
    } catch (err: any) {
      res.status(500).json({ success: false, message: err.message });
    }
  }

  /**
   * Real-time progress polling endpoint for admin dashboard.
   */
  public static async getStatus(req: Request, res: Response): Promise<void> {
    try {
      const id = req.params.id as string;
      const book = await prisma.bookSource.findUnique({
        where: { id },
        include: {
          subject: {
            select: {
              id: true,
              name: true,
              _count: { select: { topics: true, questions: true } },
            },
          },
          jobs: {
            orderBy: { startedAt: 'desc' },
          },
        },
      });

      if (!book) {
        res.status(404).json({ success: false, message: 'Book not found' });
        return;
      }

      // Compute overall progress percentage
      const statusWeights: Record<string, number> = {
        UPLOADED: 5,
        VALIDATING: 10,
        PARSING_PAGES: 20,
        PAGES_EXTRACTED: 30,
        DETECTING_TOPICS: 40,
        TOPICS_DETECTED: 50,
        DISCOVERING_SUBTOPICS: 60,
        SUBTOPICS_DISCOVERED: 70,
        EXTRACTING_QUESTIONS: 75,
        QUESTIONS_EXTRACTED: 80,
        CLASSIFYING_QUESTIONS: 85,
        GENERATING_SCRIPTS: 90,
        VALIDATING_CONTENT: 95,
        READY_FOR_REVIEW: 99,
        PUBLISHED: 100,
        FAILED: 0,
      };

      const overallProgressPercent = statusWeights[book.status] ?? 10;

      // Extract stage details from jobs
      const jobsByStage = new Map<string, any>();
      for (const j of book.jobs) {
        if (!jobsByStage.has(j.stage)) {
          jobsByStage.set(j.stage, j);
        }
      }

      const progressData: BookIngestionProgress = {
        bookId: book.id,
        subjectId: book.subject.id,
        title: book.title,
        status: book.status,
        overallProgressPercent,
        stages: {
          pdfProcessing: {
            status: book.totalPages > 0 ? 'COMPLETED' : book.status === 'PARSING_PAGES' ? 'IN_PROGRESS' : 'PENDING',
            progress: book.totalPages > 0 ? 1.0 : jobsByStage.get('PARSING_PAGES')?.stageProgress || 0.0,
            totalPages: book.totalPages,
          },
          topicDetection: {
            status: ['TOPICS_DETECTED', 'DISCOVERING_SUBTOPICS', 'SUBTOPICS_DISCOVERED', 'EXTRACTING_QUESTIONS', 'QUESTIONS_EXTRACTED', 'CLASSIFYING_QUESTIONS', 'GENERATING_SCRIPTS', 'VALIDATING_CONTENT', 'READY_FOR_REVIEW', 'PUBLISHED'].includes(book.status)
              ? 'COMPLETED'
              : book.status === 'DETECTING_TOPICS'
              ? 'IN_PROGRESS'
              : 'PENDING',
            progress: book.subject._count.topics > 0 ? 1.0 : 0.0,
            totalTopics: book.subject._count.topics,
          },
          subtopicDiscovery: {
            status: ['SUBTOPICS_DISCOVERED', 'EXTRACTING_QUESTIONS', 'QUESTIONS_EXTRACTED', 'CLASSIFYING_QUESTIONS', 'GENERATING_SCRIPTS', 'VALIDATING_CONTENT', 'READY_FOR_REVIEW', 'PUBLISHED'].includes(book.status)
              ? 'COMPLETED'
              : book.status === 'DISCOVERING_SUBTOPICS'
              ? 'IN_PROGRESS'
              : 'PENDING',
            progress: jobsByStage.get('DISCOVERING_SUBTOPICS')?.stageProgress || (book.status === 'SUBTOPICS_DISCOVERED' ? 1.0 : 0.0),
            totalSubtopics: (book.metadata as any)?.discoveredSubtopics
              ? Object.values((book.metadata as any).discoveredSubtopics).flat().length
              : 0,
          },
          questionExtraction: {
            status: ['QUESTIONS_EXTRACTED', 'CLASSIFYING_QUESTIONS', 'GENERATING_SCRIPTS', 'VALIDATING_CONTENT', 'READY_FOR_REVIEW', 'PUBLISHED'].includes(book.status)
              ? 'COMPLETED'
              : book.status === 'EXTRACTING_QUESTIONS'
              ? 'IN_PROGRESS'
              : 'PENDING',
            progress: jobsByStage.get('EXTRACTING_QUESTIONS')?.stageProgress || (book.subject._count.questions > 0 ? 1.0 : 0.0),
            totalQuestions: book.subject._count.questions,
          },
          scriptGeneration: {
            status: ['READY_FOR_REVIEW', 'PUBLISHED'].includes(book.status)
              ? 'COMPLETED'
              : book.status === 'GENERATING_SCRIPTS'
              ? 'IN_PROGRESS'
              : 'PENDING',
            progress: jobsByStage.get('GENERATING_SCRIPTS')?.stageProgress || 0.0,
            completed: jobsByStage.get('GENERATING_SCRIPTS')?.completedItems || 0,
            total: jobsByStage.get('GENERATING_SCRIPTS')?.totalItems || 0,
          },
          validation: {
            status: ['READY_FOR_REVIEW', 'PUBLISHED'].includes(book.status)
              ? 'COMPLETED'
              : book.status === 'VALIDATING_CONTENT'
              ? 'IN_PROGRESS'
              : 'PENDING',
            progress: ['READY_FOR_REVIEW', 'PUBLISHED'].includes(book.status) ? 1.0 : 0.0,
            passed: book.status === 'READY_FOR_REVIEW' ? 1 : 0,
            flagged: jobsByStage.get('READY_FOR_REVIEW')?.failedItems || 0,
          },
        },
        currentActivity: `Current stage: ${book.status.replace(/_/g, ' ')}`,
        reviewFlags: {
          ambiguousQuestions: 0,
          lowConfidenceMappings: 0,
        },
        errorMessage: book.errorMessage,
      };

      res.status(200).json({ success: true, data: progressData });
    } catch (err: any) {
      res.status(500).json({ success: false, message: err.message });
    }
  }

  /**
   * Retrieves detected topics for the book.
   */
  public static async getTopics(req: Request, res: Response): Promise<void> {
    try {
      const id = req.params.id as string;
      const book = await prisma.bookSource.findUnique({
        where: { id },
        include: {
          subject: {
            include: {
              topics: {
                orderBy: { sequence: 'asc' },
                include: {
                  _count: { select: { subtopics: true, questions: true } },
                },
              },
            },
          },
        },
      });

      if (!book) {
        res.status(404).json({ success: false, message: 'Book not found' });
        return;
      }

      res.status(200).json({
        success: true,
        data: {
          topics: book.subject.topics,
          metadataTopics: (book.metadata as any)?.detectedTopics || [],
        },
      });
    } catch (err: any) {
      res.status(500).json({ success: false, message: err.message });
    }
  }

  /**
   * Admin updates or re-arranges detected topics.
   */
  public static async updateTopics(req: Request, res: Response): Promise<void> {
    try {
      const id = req.params.id as string;
      const { topics } = req.body;

      if (!Array.isArray(topics)) {
        res.status(400).json({ success: false, message: 'topics array is required' });
        return;
      }

      for (let i = 0; i < topics.length; i++) {
        const t = topics[i];
        if (t.id) {
          await prisma.topic.update({
            where: { id: t.id },
            data: {
              name: t.name,
              sequence: i,
              description: t.description,
            },
          });
        }
      }

      res.status(200).json({ success: true, message: 'Topics updated successfully' });
    } catch (err: any) {
      res.status(400).json({ success: false, message: err.message });
    }
  }

  /**
   * Retrieves subtopics for a topic.
   */
  public static async getSubtopics(req: Request, res: Response): Promise<void> {
    try {
      const { topicId } = req.query;
      if (!topicId) {
        res.status(400).json({ success: false, message: 'topicId is required' });
        return;
      }

      const subtopics = await prisma.subtopic.findMany({
        where: { topicId: String(topicId) },
        orderBy: { sequence: 'asc' },
        include: {
          _count: { select: { questions: true } },
        },
      });

      res.status(200).json({ success: true, data: subtopics });
    } catch (err: any) {
      res.status(500).json({ success: false, message: err.message });
    }
  }

  /**
   * Previews generated script and questions for a subtopic.
   */
  public static async getContentPreview(req: Request, res: Response): Promise<void> {
    try {
      const { subtopicId } = req.query;
      if (!subtopicId) {
        res.status(400).json({ success: false, message: 'subtopicId is required' });
        return;
      }

      const [script, questions] = await Promise.all([
        prisma.lessonScript.findFirst({
          where: { subtopicId: String(subtopicId) },
          include: {
            versions: { orderBy: { versionNumber: 'desc' }, take: 1 },
          },
        }),
        prisma.question.findMany({
          where: { subtopicId: String(subtopicId) },
          take: 20,
        }),
      ]);

      res.status(200).json({
        success: true,
        data: {
          script,
          questions,
        },
      });
    } catch (err: any) {
      res.status(500).json({ success: false, message: err.message });
    }
  }

  /**
   * Publishes the book Subject and activates all child curriculum content.
   */
  public static async publishBook(req: Request, res: Response): Promise<void> {
    try {
      const id = req.params.id as string;
      const result = await bookPublishingService.publishBook(id);
      res.status(200).json({ success: true, data: result });
    } catch (err: any) {
      res.status(400).json({ success: false, message: err.message });
    }
  }

  /**
   * Retries a specific stage of ingestion.
   */
  public static async retryStage(req: Request, res: Response): Promise<void> {
    try {
      const id = req.params.id as string;
      const { stage } = req.body;

      const jobName = stage || 'process-full-book';
      await bookIngestionQueue.add(
        jobName,
        { bookId: id },
        { removeOnComplete: true }
      );

      res.status(200).json({ success: true, message: `Retrying stage "${jobName}" in background` });
    } catch (err: any) {
      res.status(400).json({ success: false, message: err.message });
    }
  }

  /**
   * Deletes a book source and optionally cascades to the Subject.
   */
  public static async deleteBook(req: Request, res: Response): Promise<void> {
    try {
      const id = req.params.id as string;
      const hardDeleteSubject = req.query.hardDeleteSubject === 'true';

      const book = await prisma.bookSource.findUnique({
        where: { id },
      });

      if (!book) {
        res.status(404).json({ success: false, message: 'Book not found' });
        return;
      }

      await prisma.$transaction(async (tx) => {
        if (hardDeleteSubject) {
          await tx.subject.delete({
            where: { id: book.subjectId },
          });
        } else {
          await tx.bookSource.delete({
            where: { id },
          });
        }
      });

      res.status(200).json({ success: true, message: 'Book deleted successfully' });
    } catch (err: any) {
      res.status(400).json({ success: false, message: err.message });
    }
  }
}
