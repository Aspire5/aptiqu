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
      const targetDifficulties: ('EASY' | 'MEDIUM' | 'HARD')[] =
        tier === 1
          ? ['EASY']
          : tier === 2
          ? ['EASY', 'MEDIUM']
          : ['EASY', 'MEDIUM', 'HARD'];

      const questionCount = targetDifficulties.length;

      // 4. Fetch Live Curriculum Universe & flatten subtopics
      const liveUniverse = await LiveCurriculumService.getAllLiveCurriculumUniverse();
      if (liveUniverse.length === 0) {
        throw new Error('No live topics or subtopics found in curriculum universe for Daily Challenge.');
      }

      const allLiveSubtopics = liveUniverse.flatMap((u) =>
        u.subtopics.map((sub) => ({
          subtopicId: sub.id,
          subtopicName: sub.name,
          subtopicDescription: sub.description,
          topicId: u.topicId,
          topicName: u.topicName,
          subjectId: u.subjectId,
          subjectName: u.subjectName,
        }))
      );

      if (allLiveSubtopics.length === 0) {
        throw new Error('No live subtopics found in curriculum universe for Daily Challenge.');
      }

      // Select target subtopics for each question deterministically using dateString hash
      const dateHash = Math.abs(
        dateString.split('-').reduce((acc, part) => acc * 31 + parseInt(part, 10), 0)
      );

      const assignedSubtopics = targetDifficulties.map((_, idx) => {
        const subIndex = (dateHash + idx * 7) % allLiveSubtopics.length;
        return allLiveSubtopics[subIndex];
      });

      // 5. Fetch recent fingerprints to avoid duplication
      const recentQuestions = await prisma.question.findMany({
        take: 30,
        orderBy: { createdAt: 'desc' },
        select: { fingerprint: true },
      });
      const existingFingerprints = recentQuestions.map((q) => q.fingerprint);

      // 6. Formulate AI Generation Prompt strictly linked to active syllabus
      const generatorPrompt = `
Generate exactly ${questionCount} brand-new, unseen Aptitude Daily Challenge question(s) for ${dateString} (Tier ${tier}).

CRITICAL REQUIREMENTS:
Each question MUST be drawn strictly from the specified ACTIVE SYLLABUS topic and subtopic:
${targetDifficulties
  .map((diff, idx) => {
    const targetSub = assignedSubtopics[idx];
    return `Question ${idx + 1} (${diff}):
- Active Syllabus Subject: ${targetSub.subjectName}
- Active Syllabus Topic: ${targetSub.topicName}
- Active Syllabus Subtopic: ${targetSub.subtopicName} (Description: ${targetSub.subtopicDescription || 'Core concepts'})
- Difficulty Target: ${diff}
${diff === 'EASY' ? '- EASY CONSTRAINT: Keep it ACTUALLY EASY! Solvable quickly with basic conceptual pattern recognition and simple, clean numbers (e.g. 10%, 25%, 50%, clean ratios 1:2, small single/double digits). NO tedious or heavy mental calculations!' : ''}`;
  })
  .join('\n\n')}

STRICT CONSTRAINTS:
- EACH QUESTION MUST BE SOLVABLE IN UNDER 60 SECONDS using an aptitude trick or mental shortcut!
- estimatedTimeSeconds MUST be an integer between 30 and 60 (use 30 for EASY, 45 for MEDIUM, 60 for HARD). Minimum allowed is 30.
- NO hints in the question prompts, but provide exactly 2 hints in the hints array for future reuse.
- The explanation must prominently describe the exact speed trick / shortcut.
- Provide 4 distinct options (A, B, C, D) with plausible distractors.

Do NOT duplicate these recent question fingerprints:
${existingFingerprints.slice(0, 25).map((f) => `- ${f}`).join('\n')}
`.trim();

      console.log(
        `[DailyChallengeGen] Requesting Gemini generation for date ${dateString}, tier ${tier} (${questionCount} questions)...`
      );

      let rawQuestions: any[] = [];
      try {
        const rawGeneration = await geminiProvider.generateStructuredContent<{
          questions: any[];
        }>({
          systemInstruction: DAILY_CHALLENGE_GENERATION_SYSTEM_INSTRUCTION,
          prompt: generatorPrompt,
          responseSchema: QUESTION_ARRAY_JSON_SCHEMA,
        });

        if (rawGeneration?.questions && Array.isArray(rawGeneration.questions)) {
          rawQuestions = rawGeneration.questions;
        }
      } catch (genError) {
        console.warn(`[DailyChallengeGen] Gemini API generation error:`, genError);
      }

      // 7. Validate & Normalize questions
      const validQuestions: any[] = [];
      for (let i = 0; i < rawQuestions.length; i++) {
        const rawQ = rawQuestions[i];
        const assignedDiff = targetDifficulties[i] || 'EASY';
        const normalized = this.normalizeDailyChallengeQuestion(rawQ, assignedDiff);
        const valResult = validateQuestionStructure(normalized);
        if (valResult.valid) {
          validQuestions.push(valResult.data);
        } else {
          console.warn(`[DailyChallengeGen] Question structural validation failed: ${valResult.errors.join('; ')}`);
        }
      }

      // Fallback: If AI returned fewer valid questions than required, draw from published question repository
      if (validQuestions.length < questionCount) {
        console.warn(
          `[DailyChallengeGen] Only ${validQuestions.length}/${questionCount} AI questions valid. Sourcing from published questions pool...`
        );
        const needed = questionCount - validQuestions.length;
        const fallbackQuestions = await prisma.question.findMany({
          where: {
            status: 'PUBLISHED',
          },
          take: Math.max(needed * 4, 10),
          orderBy: { createdAt: 'desc' },
        });

        for (const candidate of fallbackQuestions) {
          if (validQuestions.length >= questionCount) break;
          if (validQuestions.some((v) => v.prompt === candidate.prompt)) continue;

          validQuestions.push({
            pattern: candidate.pattern,
            prompt: candidate.prompt,
            options: candidate.options as any,
            correctAnswer: candidate.correctAnswer as any,
            difficulty: candidate.difficulty,
            estimatedTimeSeconds: candidate.estimatedTimeSeconds,
            calculationMode: candidate.calculationMode,
            hints: candidate.hints,
            method: candidate.method,
            explanation: candidate.explanation,
            persistedQuestionId: candidate.id,
          });
        }
      }

      if (validQuestions.length < questionCount) {
        throw new Error(
          `Only ${validQuestions.length}/${questionCount} questions passed validation for Daily Challenge.`
        );
      }

      // 8. Persist script and questions in PostgreSQL transaction
      return await prisma.$transaction(async (tx) => {
        const script = await tx.dailyChallengeScript.create({
          data: {
            dateString,
            tier,
            questionCount,
          },
        });

        for (let i = 0; i < questionCount; i++) {
          const q = validQuestions[i];
          const assignedDifficulty = targetDifficulties[i];
          const targetSub = assignedSubtopics[i];

          let questionId: string;

          if (q.persistedQuestionId) {
            questionId = q.persistedQuestionId;
          } else {
            const fingerprint = FingerprintService.computeFingerprint(q.prompt, q.options);
            let question = await tx.question.findUnique({
              where: { fingerprint },
            });

            if (!question) {
              question = await tx.question.create({
                data: {
                  subjectId: targetSub.subjectId,
                  topicId: targetSub.topicId,
                  subtopicId: targetSub.subtopicId,
                  pattern: q.pattern || 'DAILY_CHALLENGE',
                  prompt: q.prompt,
                  options: q.options,
                  correctAnswer: q.correctAnswer,
                  hints: q.hints || [],
                  explanation: q.explanation,
                  method: q.method || 'Speed Aptitude Shortcut',
                  difficulty: assignedDifficulty as QuestionDifficultyEnum,
                  estimatedTimeSeconds: q.estimatedTimeSeconds || 60,
                  calculationMode: (q.calculationMode as CalculationMode) || CalculationMode.MENTAL,
                  sourceType: 'AI_GENERATED',
                  status: 'PUBLISHED',
                  fingerprint,
                  generationModel: 'gemini-3.5-flash-lite',
                  generationPromptVersion: 'v1.0.0',
                },
              });
            }
            questionId = question.id;
          }

          await tx.dailyChallengeScriptQuestion.create({
            data: {
              scriptId: script.id,
              questionId,
              sequence: i + 1,
              difficulty: assignedDifficulty as QuestionDifficultyEnum,
              timeLimit: 60,
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

