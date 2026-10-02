import { prisma } from '../../../config/prisma';
import { geminiProvider } from '../gemini.provider';
import { DAILY_CHALLENGE_GENERATION_SYSTEM_INSTRUCTION } from '../prompts/daily-challenge-generation.prompt';
import { QUESTION_ARRAY_JSON_SCHEMA } from '../prompts/practice-generation.prompt';
import { validateQuestionStructure } from '../../question/validators/question-structural.validator';
import { FingerprintService } from '../../question/services/fingerprint.service';
import { LiveCurriculumService } from '../../curriculum/services/live-curriculum.service';
import { ConcurrencyLockService } from '../../concurrency/concurrency-lock.service';
import { QuestionDifficultyEnum, CalculationMode } from '@prisma/client';

export class DailyChallengeGenerationService {
  private static instance: DailyChallengeGenerationService;

  public static getInstance(): DailyChallengeGenerationService {
    if (!DailyChallengeGenerationService.instance) {
      DailyChallengeGenerationService.instance = new DailyChallengeGenerationService();
    }
    return DailyChallengeGenerationService.instance;
  }

  /**
   * Generates a Daily Challenge Script for a specific date and streak tier.
   * Tier 1: 1 EASY question (Streak 0-9)
   * Tier 2: 1 EASY + 1 MEDIUM question (Streak 10-99)
   * Tier 3: 1 EASY + 1 MEDIUM + 1 HARD question (Streak 100+)
   */
  public async getOrGenerateDailyScript(dateString: string, tier: number): Promise<any> {
    // 1. Fast check if already exists
    const existing = await prisma.dailyChallengeScript.findUnique({
      where: {
        dateString_tier: {
          dateString,
          tier,
        },
      },
      include: {
        questions: {
          include: { question: true },
          orderBy: { sequence: 'asc' },
        },
      },
    });

    if (existing) {
      return existing;
    }

    // 2. Lock to prevent multiple concurrent generations for the same date & tier
    const lockKey = `DAILY_CHALLENGE_GEN_${dateString}_${tier}`;
    const lockAcquired = await ConcurrencyLockService.acquireLock(lockKey, 75000);
    if (!lockAcquired) {
      // Wait for the other process to finish generating
      await ConcurrencyLockService.waitForCondition(async () => {
        const found = await prisma.dailyChallengeScript.findUnique({
          where: {
            dateString_tier: {
              dateString,
              tier,
            },
          },
        });
        return !!found;
      }, 35000);

      const generated = await prisma.dailyChallengeScript.findUnique({
        where: {
          dateString_tier: {
            dateString,
            tier,
          },
        },
        include: {
          questions: {
            include: { question: true },
            orderBy: { sequence: 'asc' },
          },
        },
      });

      if (generated) return generated;
    }

    try {
      // Double check after lock acquisition
      const doubleCheck = await prisma.dailyChallengeScript.findUnique({
        where: {
          dateString_tier: {
            dateString,
            tier,
          },
        },
        include: {
          questions: {
            include: { question: true },
            orderBy: { sequence: 'asc' },
          },
        },
      });
      if (doubleCheck) return doubleCheck;

      // 3. Resolve requirements based on tier
      const targetDifficulties: QuestionDifficultyEnum[] =
        tier === 1
          ? ['EASY']
          : tier === 2
          ? ['EASY', 'MEDIUM']
          : ['EASY', 'MEDIUM', 'HARD'];

      const questionCount = targetDifficulties.length;
      const selectedQuestions: any[] = [];

      // 4. Query bounded candidate pool per difficulty directly in PostgreSQL
      // Database determines: MANUAL + PUBLISHED + PYQ present + NEVER appeared in any DailyChallenge
      for (let i = 0; i < questionCount; i++) {
        const diff = targetDifficulties[i];
        const candidates = await prisma.question.findMany({
          where: {
            sourceType: 'MANUAL',
            status: 'PUBLISHED',
            pyq: { not: null },
            difficulty: diff,
            id: { notIn: selectedQuestions.map((q) => q.id) },
            dailyChallengeScriptQuestions: {
              none: {}, // Database-level: Never appeared in ANY daily challenge
            },
          },
          take: 25, // Bounded candidate pool (constant memory footprint)
        });

        if (candidates.length === 0) {
          console.error(
            `[DailyChallenge] INVENTORY DEPLETED: Zero unused MANUAL PYQs for difficulty ${diff} on ${dateString} (Tier ${tier}).`
          );
          // Inventory depletion alert is monitored and displayed in Admin Dashboard (AdminDashboardService.getDailyChallengeInventoryStatus)
          // to prevent corrupted or non-PYQ daily challenge generation.
          throw new Error(
            `Daily Challenge creation halted: Manual PYQ inventory depleted for difficulty ${diff} on date ${dateString}.`
          );
        }

        // Deterministic pseudo-random pick from the bounded candidate pool using date hash seed
        const dateHash = Math.abs(
          dateString.split('-').reduce((acc, part) => acc * 31 + parseInt(part, 10), 0) + i * 17
        );
        const chosen = candidates[dateHash % candidates.length];
        selectedQuestions.push(chosen);
      }

      // 5. Persist script and questions in PostgreSQL transaction
      return await prisma.$transaction(async (tx) => {
        const script = await tx.dailyChallengeScript.create({
          data: {
            dateString,
            tier,
            questionCount,
          },
        });

        for (let i = 0; i < questionCount; i++) {
          const q = selectedQuestions[i];
          await tx.dailyChallengeScriptQuestion.create({
            data: {
              scriptId: script.id,
              questionId: q.id,
              sequence: i + 1,
              difficulty: q.difficulty,
              timeLimit: q.estimatedTimeSeconds || 60,
            },
          });
        }

        return await tx.dailyChallengeScript.findUnique({
          where: { id: script.id },
          include: {
            questions: {
              include: { question: true },
              orderBy: { sequence: 'asc' },
            },
          },
        });
      });
    } finally {
      await ConcurrencyLockService.releaseLock(lockKey);
    }
  }

  private normalizeDailyChallengeQuestion(
    raw: any,
    targetDifficulty: 'EASY' | 'MEDIUM' | 'HARD'
  ): any {
    if (!raw || typeof raw !== 'object') return raw;

    let pattern = typeof raw.pattern === 'string' ? raw.pattern.trim() : '';
    if (pattern.length < 2) pattern = 'Speed Shortcut';
    if (pattern.length > 100) pattern = pattern.slice(0, 100);

    let prompt = typeof raw.prompt === 'string' ? raw.prompt.trim() : '';

    let difficulty =
      typeof raw.difficulty === 'string'
        ? raw.difficulty.trim().toUpperCase()
        : targetDifficulty;
    if (!['EASY', 'MEDIUM', 'HARD'].includes(difficulty)) {
      difficulty = targetDifficulty;
    }

    let options = Array.isArray(raw.options) ? raw.options : [];
    const validIds: ('A' | 'B' | 'C' | 'D')[] = ['A', 'B', 'C', 'D'];
    const normalizedOptions = validIds.map((id, index) => {
      const existing = options[index];
      let text = '';
      if (typeof existing === 'string') {
        text = existing.trim();
      } else if (existing && typeof existing === 'object') {
        text =
          typeof existing.text === 'string'
            ? existing.text.trim()
            : String(existing.text ?? '').trim();
      }
      if (!text) text = `Option ${id}`;
      if (text.length > 300) text = text.slice(0, 300);
      return { id, text };
    });

    let correctAnswer =
      typeof raw.correctAnswer === 'string'
        ? raw.correctAnswer.trim().toUpperCase()
        : 'A';
    if (!['A', 'B', 'C', 'D'].includes(correctAnswer)) {
      correctAnswer = 'A';
    }

    // Enforce 30..120 window required by RawQuestionSchema
    let est = Number(raw.estimatedTimeSeconds);
    if (isNaN(est) || est < 30) {
      est = 30;
    } else if (est > 120) {
      est = 120;
    } else {
      est = Math.round(est);
    }

    let calc =
      typeof raw.calculationMode === 'string'
        ? raw.calculationMode.trim().toUpperCase()
        : 'MENTAL';
    if (!['MENTAL', 'LIGHT_PEN_AND_PAPER', 'PEN_AND_PAPER'].includes(calc)) {
      calc = 'MENTAL';
    }

    let hints = Array.isArray(raw.hints)
      ? raw.hints
          .map((h: any) => String(h || '').trim())
          .filter((h: string) => h.length >= 5)
      : [];
    if (hints.length < 1) {
      hints.push('Identify the fundamental relationship and spot the speed trick.');
    }
    if (hints.length < 2) {
      hints.push('Eliminate illogical options to find the correct answer in under 60 seconds.');
    }
    if (hints.length > 2) {
      hints = hints.slice(0, 2);
    }
    hints = hints.map((h: string) => h.slice(0, 300));

    let method = typeof raw.method === 'string' ? raw.method.trim() : '';
    if (method.length < 5) method = 'Mental Aptitude Shortcut';
    if (method.length > 500) method = method.slice(0, 500);

    let explanation =
      typeof raw.explanation === 'string' ? raw.explanation.trim() : '';
    if (explanation.length < 10) {
      explanation = `The correct answer is Option ${correctAnswer}. Apply standard speed trick to solve in under 60s.`;
    }
    if (explanation.length > 1000) explanation = explanation.slice(0, 1000);

    return {
      pattern,
      prompt,
      options: normalizedOptions,
      correctAnswer,
      difficulty,
      estimatedTimeSeconds: est,
      calculationMode: calc,
      hints,
      method,
      explanation,
    };
  }
}

export const dailyChallengeGenerationService = DailyChallengeGenerationService.getInstance();

