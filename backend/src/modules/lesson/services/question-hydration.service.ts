import { prisma } from '../../../config/prisma';
import { ScriptDefinition, LessonNode, QuestionInlineData } from '../interfaces/script-dsl.interface';

export class QuestionHydrationService {
  private static instance: QuestionHydrationService;

  public static getInstance(): QuestionHydrationService {
    if (!QuestionHydrationService.instance) {
      QuestionHydrationService.instance = new QuestionHydrationService();
    }
    return QuestionHydrationService.instance;
  }

  /**
   * Scans a ScriptDefinition for all QUESTION and CHOICE nodes referencing questions
   * by QUESTION_EXTERNAL_ID or REPOSITORY, queries PostgreSQL, and hydrates inlineData.
   *
   * If any referenced question cannot be found, throws an explicit error (fail-fast, no silent broken cards).
   */
  public async hydrateScriptDefinition(definition: ScriptDefinition): Promise<ScriptDefinition> {
    if (!definition || !definition.nodes) {
      return definition;
    }

    const externalKeysToFetch = new Set<string>();
    const questionIdsToFetch = new Set<string>();

    // 1. Collect all question references needing hydration
    for (const node of Object.values(definition.nodes)) {
      if (node.type === 'QUESTION' || node.type === 'CHOICE') {
        const qRef = node.questionReference;
        if (!qRef) continue;

        if (qRef.mode === 'QUESTION_EXTERNAL_ID' && qRef.externalId && typeof qRef.externalId === 'string') {
          externalKeysToFetch.add(qRef.externalId.trim());
        } else if (qRef.mode === 'REPOSITORY' && qRef.questionId && typeof qRef.questionId === 'string') {
          questionIdsToFetch.add(qRef.questionId.trim());
        }
      }
    }

    if (externalKeysToFetch.size === 0 && questionIdsToFetch.size === 0) {
      return definition;
    }

    // 2. Fetch all matching questions from PostgreSQL in a single batched query
    const questions = await prisma.question.findMany({
      where: {
        OR: [
          ...(externalKeysToFetch.size > 0 ? [{ externalKey: { in: Array.from(externalKeysToFetch) } }] : []),
          ...(questionIdsToFetch.size > 0 ? [{ id: { in: Array.from(questionIdsToFetch) } }] : []),
        ],
      },
    });

    const questionByExtKey = new Map<string, any>();
    const questionById = new Map<string, any>();

    for (const q of questions) {
      if (q.externalKey) {
        questionByExtKey.set(q.externalKey.trim(), q);
      }
      questionById.set(q.id.trim(), q);
    }

    // 3. Hydrate nodes with full question content & enforce strict existence
    for (const [nodeId, node] of Object.entries(definition.nodes)) {
      if (node.type === 'QUESTION' || node.type === 'CHOICE') {
        const qRef = node.questionReference;
        if (!qRef) continue;

        let matchedQuestion: any = null;

        if (qRef.mode === 'QUESTION_EXTERNAL_ID' && qRef.externalId) {
          const key = qRef.externalId.trim();
          matchedQuestion = questionByExtKey.get(key);
          if (!matchedQuestion) {
            throw new Error(
              `Script Question Resolution Error: Question "${key}" (referenced in node "${nodeId}") does not exist in the question repository. Please import this question before playing or publishing the script.`
            );
          }
        } else if (qRef.mode === 'REPOSITORY' && qRef.questionId) {
          const id = qRef.questionId.trim();
          matchedQuestion = questionById.get(id);
          if (!matchedQuestion) {
            throw new Error(
              `Script Question Resolution Error: Question ID "${id}" (referenced in node "${nodeId}") does not exist in the question repository.`
            );
          }
        }

        if (matchedQuestion) {
          // Parse options safely: ensure both `id` and `label` exist for Flutter ChoiceOptionModel
          let rawOptions: any[] = [];
          if (Array.isArray(matchedQuestion.options)) {
            rawOptions = matchedQuestion.options;
          } else if (typeof matchedQuestion.options === 'string') {
            try {
              rawOptions = JSON.parse(matchedQuestion.options);
            } catch {
              rawOptions = [];
            }
          }

          const normalizedOptions = rawOptions.map((opt: any, idx: number) => {
            const letter = ['A', 'B', 'C', 'D'][idx] || 'A';
            const optId = String(opt.id || letter);
            const label = String(opt.label || opt.text || opt || '');
            return {
              id: optId,
              label,
              text: label,
            };
          });

          const hints = Array.isArray(matchedQuestion.hints)
            ? matchedQuestion.hints.map((h: any) => String(h))
            : [];

          const inlineData: QuestionInlineData = {
            prompt: matchedQuestion.prompt,
            options: normalizedOptions,
            correctOptionId: matchedQuestion.correctAnswer,
            explanation: matchedQuestion.explanation || '',
            hints,
            difficulty: (matchedQuestion.difficulty || 'EASY') as any,
            questionType: (matchedQuestion.questionType || 'PRACTICE') as any,
            pyq: matchedQuestion.pyq || undefined,
            alternativeExplanation: matchedQuestion.alternativeExplanation || undefined,
            preferredSolution: matchedQuestion.preferredSolution || undefined,
            preferredReason: matchedQuestion.preferredReason || undefined,
          };

          // Attach hydrated data to the node's questionReference
          qRef.inlineData = inlineData;
          qRef.questionId = matchedQuestion.id;
          (qRef as any).conceptId = matchedQuestion.conceptId || undefined;

          // If node prompt/text is generic or empty, reflect the actual question prompt
          if (!node.content || !node.content.text || node.content.text.trim() === '') {
            node.content = { text: matchedQuestion.prompt };
          }
        }
      }
    }

    return definition;
  }
}

export const questionHydrationService = QuestionHydrationService.getInstance();
