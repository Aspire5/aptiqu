import { prisma } from '../../../config/prisma';
import { LessonNode } from '../interfaces/script-dsl.interface';

export interface EvaluationResult {
  isCorrect: boolean;
  score: number;
  explanation?: string;
  conceptId?: string;
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

    const { mode, inlineData, questionId } = node.questionReference;

    if (mode === 'INLINE' && inlineData) {
      const isCorrect = rawAnswer.trim().toLowerCase() === inlineData.correctOptionId.trim().toLowerCase();
      let explanation = inlineData.explanation;
      if (!isCorrect) {
        if (inlineData.incorrectExplanation) {
          explanation = inlineData.incorrectExplanation;
        } else {
          const correctOpt = inlineData.options?.find(
            (o) => o.id.trim().toLowerCase() === inlineData.correctOptionId.trim().toLowerCase()
          );
          const correctLabel = correctOpt ? correctOpt.label : inlineData.correctOptionId;
          const cleanExp = (inlineData.explanation || '').replace(/^(exactly|right|spot on|correct)[.!,]?\s*/i, '');
          explanation = `Not quite! The correct answer is ${correctLabel}. ${cleanExp}`.trim();
        }
      }
      return {
        isCorrect,
        score: isCorrect ? 1.0 : 0.0,
        explanation,
      };
    }

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
      };
    }

    return { isCorrect: false, score: 0.0, explanation: 'Unable to evaluate question.' };
  }
}

export const questionService = QuestionService.getInstance();
