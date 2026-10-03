import { prisma } from '../../../config/prisma';
import { LessonNode } from '../interfaces/script-dsl.interface';

export interface EvaluationResult {
  isCorrect: boolean;
  score: number;
  explanation?: string;
  conceptId?: string;
  correctOptionId?: string;
}

export class QuestionService {
  private static instance: QuestionService;

  public static getInstance(): QuestionService {
    if (!QuestionService.instance) {
      QuestionService.instance = new QuestionService();
    }
    return QuestionService.instance;
  }

  public async evaluate(node: LessonNode, rawAnswer: string): Promise<EvaluationResult> {
    if ((node.type !== 'QUESTION' && node.type !== 'CHOICE') || !node.questionReference) {
      return { isCorrect: true, score: 1.0 };
    }

    const { mode, inlineData, questionId, externalId } = node.questionReference as any;

    // 1. If inlineData is populated (hydrated from external question or inline), evaluate directly
    if (inlineData && inlineData.correctOptionId) {
      const isCorrect = rawAnswer.trim().toLowerCase() === inlineData.correctOptionId.trim().toLowerCase();
      let explanation = inlineData.explanation;
      if (!isCorrect) {
        if (inlineData.incorrectExplanation) {
          explanation = inlineData.incorrectExplanation;
        } else {
          const correctOpt = inlineData.options?.find(
            (o: any) => o.id.trim().toLowerCase() === inlineData.correctOptionId.trim().toLowerCase()
          );
          const correctLabel = correctOpt ? (correctOpt.label || correctOpt.text || correctOpt.id) : inlineData.correctOptionId;
          const cleanExp = (inlineData.explanation || '').replace(/^(exactly|right|spot on|correct)[.!,]?\s*/i, '');
          explanation = `Not quite! The correct answer is ${correctLabel}. ${cleanExp}`.trim();
        }
      }
      return {
        isCorrect,
        score: isCorrect ? 1.0 : 0.0,
        explanation,
        correctOptionId: inlineData.correctOptionId,
        conceptId: (node.questionReference as any).conceptId,
      };
    }

    // 2. Fallback: resolve from database by externalKey
    if (mode === 'QUESTION_EXTERNAL_ID' && externalId) {
      const question = await prisma.question.findFirst({
        where: { externalKey: externalId.trim() },
      });

      if (!question) {
        throw new Error(`Question reference '${externalId}' not found in database.`);
      }

      const isCorrect = rawAnswer.trim().toLowerCase() === question.correctAnswer.trim().toLowerCase();
      return {
        isCorrect,
        score: isCorrect ? 1.0 : 0.0,
        explanation: question.explanation || undefined,
        conceptId: question.conceptId || undefined,
        correctOptionId: question.correctAnswer,
      };
    }

    // 3. Fallback: resolve from database by questionId
    if (mode === 'REPOSITORY' && questionId) {
      const question = await prisma.question.findUnique({
        where: { id: questionId },
      });

      if (!question) {
        throw new Error(`Question ID ${questionId} not found in repository.`);
      }

      const isCorrect = rawAnswer.trim().toLowerCase() === question.correctAnswer.trim().toLowerCase();
      return {
        isCorrect,
        score: isCorrect ? 1.0 : 0.0,
        explanation: question.explanation || undefined,
        conceptId: question.conceptId || undefined,
        correctOptionId: question.correctAnswer,
      };
    }

    throw new Error(`Unable to evaluate question: node "${node.id}" has no valid question data or reference.`);
  }
}

export const questionService = QuestionService.getInstance();
