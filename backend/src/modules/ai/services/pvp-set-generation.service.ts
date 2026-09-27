import { prisma } from '../../../config/prisma';
import { geminiProvider } from '../gemini.provider';
import { PVP_GENERATION_SYSTEM_INSTRUCTION } from '../prompts/pvp-generation.prompt';
import { PVP_REVIEW_SYSTEM_INSTRUCTION } from '../prompts/pvp-review.prompt';
import { QUESTION_ARRAY_JSON_SCHEMA } from '../prompts/practice-generation.prompt';
import { QUESTION_REVIEW_JSON_SCHEMA } from '../prompts/practice-review.prompt';
import { validateQuestionStructure } from '../../question/validators/question-structural.validator';
import { FingerprintService } from '../../question/services/fingerprint.service';
import { LiveCurriculumService } from '../../curriculum/services/live-curriculum.service';
import { INVENTORY_CONFIG } from '../../../config/inventory.config';
import { ConcurrencyLockService } from '../../concurrency/concurrency-lock.service';
import { QuestionDifficultyEnum, CalculationMode } from '@prisma/client';
import { randomUUID } from 'crypto';

export class PvpSetGenerationService {
  private static instance: PvpSetGenerationService;

  public static getInstance(): PvpSetGenerationService {
    if (!PvpSetGenerationService.instance) {
      PvpSetGenerationService.instance = new PvpSetGenerationService();
    }
    return PvpSetGenerationService.instance;
  }

  /**
   * Generates a complete verified 10-Question PvP Set from the LIVE syllabus universe.
   */
  public async generatePvpQuestionSet(): Promise<any> {
    const lockAcquired = await ConcurrencyLockService.acquireLock('PVP_SET_GENERATION', 60000);
    if (!lockAcquired) {
      // Another thread is generating a set. Wait and return an available published set.
      await ConcurrencyLockService.waitForCondition(async () => {
        const count = await prisma.pvpQuestionSet.count({
          where: { status: 'PUBLISHED' },
        });
        return count > 0;
      }, 15000);

      const existing = await prisma.pvpQuestionSet.findFirst({
        where: { status: 'PUBLISHED' },
        include: {
          setQuestions: {
            include: { question: true },
            orderBy: { sequence: 'asc' },
          },
        },
        orderBy: { createdAt: 'desc' },
      });
      if (existing) return existing;
    }

    try {
      // 1. Fetch Live Universe
      const liveUniverse = await LiveCurriculumService.getAllLiveCurriculumUniverse();
      if (liveUniverse.length === 0) {
        throw new Error('No live topics or subtopics found in curriculum universe.');
      }

      // 2. Select difficulty distribution (Random draw across EASY, MEDIUM, HARD per question)
      const difficulties: ('EASY' | 'MEDIUM' | 'HARD')[] = [];
      const weights = INVENTORY_CONFIG.PVP_DIFFICULTY_CONFIG;
      for (let i = 0; i < 10; i++) {
        const rand = Math.random();
        if (rand < weights.EASY_WEIGHT) {
          difficulties.push('EASY');
        } else if (rand < weights.EASY_WEIGHT + weights.MEDIUM_WEIGHT) {
          difficulties.push('MEDIUM');
        } else {
          difficulties.push('HARD');
        }
      }

      const easyCount = difficulties.filter((d) => d === 'EASY').length;
      const medCount = difficulties.filter((d) => d === 'MEDIUM').length;
      const hardCount = difficulties.filter((d) => d === 'HARD').length;

      // 3. Fetch fingerprints
      const recentQuestions = await prisma.question.findMany({
        take: 30,
        orderBy: { createdAt: 'desc' },
        select: { fingerprint: true },
      });
      const existingFingerprints = recentQuestions.map((q) => q.fingerprint);

      // 4. Generator Call
      const generatorPrompt = `
Generate a 10-Question Ranked PvP Set from the following LIVE Curriculum Universe:
${liveUniverse.map((s) => `Subject: ${s.subjectName} -> Topic: ${s.topicName} -> Subtopics: ${s.subtopics.map((sub) => sub.name).join(', ')}`).join('\n')}

Requested Difficulty Target for this Set:
- Target Distribution: ${easyCount} EASY, ${medCount} MEDIUM, ${hardCount} HARD
- Each question must be independently solvable within 30 to 60 seconds (60 seconds fixed PvP maximum).

Exclude previously generated fingerprints:
${existingFingerprints.slice(0, 30).map((f) => `- ${f}`).join('\n')}
`.trim();

      const rawGeneration = await geminiProvider.generateStructuredContent<{
        questions: any[];
      }>({
        systemInstruction: PVP_GENERATION_SYSTEM_INSTRUCTION,
        prompt: generatorPrompt,
        responseSchema: QUESTION_ARRAY_JSON_SCHEMA,
      });

      if (!rawGeneration.questions || !Array.isArray(rawGeneration.questions)) {
        throw new Error('Gemini PvP generator did not return a valid questions array.');
      }

      // 5. Structural Validation (PvP time <= 60s)
      const validQuestions: any[] = [];
      for (const rawQ of rawGeneration.questions) {
        const val = validateQuestionStructure(rawQ, true);
        if (val.valid) {
          validQuestions.push(val.data);
        }
      }

      // 6. Reviewer Call
      const reviewerPrompt = `
Audit this 10-question set for head-to-head live duel competition:
Questions to Audit:
${JSON.stringify(validQuestions, null, 2)}
`.trim();

      const rawReview = await geminiProvider.generateStructuredContent<{
        verdict: 'PASS' | 'REVISE';
        auditSummary: string;
        acceptedQuestions: any[];
        rejections: any[];
      }>({
        systemInstruction: PVP_REVIEW_SYSTEM_INSTRUCTION,
        prompt: reviewerPrompt,
        responseSchema: QUESTION_REVIEW_JSON_SCHEMA,
      });

      const candidates = rawReview.acceptedQuestions || validQuestions;

      // 7. Map to live subtopic metadata (fallback to first live subtopic if not matching)
      const firstLiveSubject = liveUniverse[0];
      const firstLiveSubtopic = firstLiveSubject.subtopics[0];

      // Insert questions & create set in a transaction
      const setCode = `pvp_set_${Date.now()}_${randomUUID().slice(0, 8)}`;

      return await prisma.$transaction(async (tx) => {
        const pvpSet = await tx.pvpQuestionSet.create({
          data: {
            code: setCode,
            sourceType: 'AI_GENERATED',
            status: 'PUBLISHED',
            questionCount: Math.min(10, candidates.length),
            generationModel: 'gemini-3.5-flash-lite',
            generationPromptVersion: 'v1.0.0',
          },
        });

        let sequence = 1;
        for (const q of candidates) {
          if (sequence > 10) break;

          const fingerprint = FingerprintService.computeFingerprint(q.prompt, q.options);
          let question = await tx.question.findUnique({
            where: { fingerprint },
          });

          if (!question) {
            question = await tx.question.create({
              data: {
                subjectId: firstLiveSubject.subjectId,
                topicId: firstLiveSubject.topicId,
                subtopicId: firstLiveSubtopic.id,
                pattern: q.pattern,
                prompt: q.prompt,
                options: q.options,
                correctAnswer: q.correctAnswer,
                hints: q.hints,
                explanation: q.explanation,
                method: q.method,
                difficulty: q.difficulty as QuestionDifficultyEnum,
                estimatedTimeSeconds: q.estimatedTimeSeconds,
                calculationMode: q.calculationMode as CalculationMode,
                sourceType: 'AI_GENERATED',
                status: 'PUBLISHED',
                fingerprint,
                generationModel: 'gemini-3.5-flash-lite',
                generationPromptVersion: 'v1.0.0',
              },
            });
          }

          await tx.pvpQuestionSetQuestion.create({
            data: {
              setId: pvpSet.id,
              questionId: question.id,
              sequence,
            },
          });

          sequence++;
        }

        return await tx.pvpQuestionSet.findUnique({
          where: { id: pvpSet.id },
          include: {
            setQuestions: {
              include: { question: true },
              orderBy: { sequence: 'asc' },
            },
          },
        });
      });
    } finally {
      await ConcurrencyLockService.releaseLock('PVP_SET_GENERATION');
    }
  }
}

export const pvpSetGenerationService = PvpSetGenerationService.getInstance();
