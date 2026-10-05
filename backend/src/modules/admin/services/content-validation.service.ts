import { prisma } from '../../../config/prisma';
import { ScriptValidator } from '../../lesson/engines/script-validator';
import { bookCancellationService } from './book-cancellation.service';

export interface ValidationIssue {
  entityType: 'QUESTION' | 'SCRIPT' | 'SUBTOPIC';
  entityId: string;
  severity: 'WARNING' | 'ERROR';
  message: string;
}

export interface ValidationResult {
  passed: boolean;
  totalQuestionsChecked: number;
  totalScriptsChecked: number;
  flaggedCount: number;
  issues: ValidationIssue[];
}

export class ContentValidationService {
  private static instance: ContentValidationService;

  private constructor() {}

  public static getInstance(): ContentValidationService {
    if (!ContentValidationService.instance) {
      ContentValidationService.instance = new ContentValidationService();
    }
    return ContentValidationService.instance;
  }

  /**
   * Performs multi-layer validation across all generated questions and scripts for a book.
   */
  public async validateBookContent(bookId: string): Promise<ValidationResult> {
    bookCancellationService.checkAndThrowIfCancelled(bookId, 'start of validateBookContent');

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

    const issues: ValidationIssue[] = [];

    // 1. Validate Questions
    const questions = await prisma.question.findMany({
      where: { subjectId: bookSource.subject.id },
    });

    let totalQuestionsChecked = 0;
    for (const q of questions) {
      totalQuestionsChecked++;

      // A. Check options array
      const options = Array.isArray(q.options) ? (q.options as any[]) : [];
      if (options.length < 2) {
        issues.push({
          entityType: 'QUESTION',
          entityId: q.id,
          severity: 'ERROR',
          message: `Question "${q.externalKey || q.id}" has fewer than 2 options.`,
        });
      }

      // B. Check correct answer existence
      const hasCorrect = options.some((opt) => opt.id === q.correctAnswer);
      if (!hasCorrect) {
        issues.push({
          entityType: 'QUESTION',
          entityId: q.id,
          severity: 'ERROR',
          message: `Correct answer "${q.correctAnswer}" does not match any declared option ID in question "${q.externalKey}".`,
        });
      }

      // C. Check explanation completeness
      if (!q.explanation || q.explanation.trim().length < 10) {
        issues.push({
          entityType: 'QUESTION',
          entityId: q.id,
          severity: 'WARNING',
          message: `Question "${q.externalKey}" has missing or brief explanation.`,
        });
      }
    }

    // 2. Validate Scripts
    const scripts = await prisma.lessonScript.findMany({
      where: { subjectId: bookSource.subject.id },
      include: {
        versions: { orderBy: { versionNumber: 'desc' }, take: 1 },
      },
    });

    let totalScriptsChecked = 0;
    for (const s of scripts) {
      totalScriptsChecked++;
      const latestVer = s.versions[0];
      if (!latestVer || !latestVer.definition) {
        issues.push({
          entityType: 'SCRIPT',
          entityId: s.id,
          severity: 'ERROR',
          message: `Script "${s.slug}" has no valid JSON version definition.`,
        });
        continue;
      }

      const valRes = ScriptValidator.validate(latestVer.definition as any);
      if (!valRes.valid) {
        for (const err of valRes.errors) {
          issues.push({
            entityType: 'SCRIPT',
            entityId: s.id,
            severity: 'WARNING',
            message: `Script "${s.slug}" validation: ${err.message} (${err.field})`,
          });
        }
      }
    }

    const flaggedCount = issues.length;
    const passed = !issues.some((i) => i.severity === 'ERROR');

    // Update BookSource status to READY_FOR_REVIEW
    await prisma.bookSource.update({
      where: { id: bookId },
      data: {
        status: passed ? 'READY_FOR_REVIEW' : 'VALIDATING_CONTENT',
      },
    });

    console.log(
      `[ContentValidationService] Validation finished for book "${bookSource.title}": ${totalQuestionsChecked} questions, ${totalScriptsChecked} scripts. Issues: ${flaggedCount}.`
    );

    return {
      passed,
      totalQuestionsChecked,
      totalScriptsChecked,
      flaggedCount,
      issues,
    };
  }
}

export const contentValidationService = ContentValidationService.getInstance();
