import { prisma } from '../../config/prisma';
import { FingerprintService } from '../question/services/fingerprint.service';
import { QuestionOption, QuestionOptionId, QuestionDifficulty, CalculationMode } from '../question/domain/question.types';

export interface QuestionListFilter {
  search?: string;
  subjectId?: string;
  topicId?: string;
  subtopicId?: string;
  difficulty?: QuestionDifficulty;
  sourceType?: 'MANUAL' | 'AI_GENERATED';
  status?: 'DRAFT' | 'REVIEW' | 'PUBLISHED' | 'ARCHIVED';
  pyqOnly?: boolean | string;
  page?: number;
  limit?: number;
}

export class AdminQuestionsService {
  /**
   * Paginated list of questions with filtering
   */
  public static async listQuestions(filter: QuestionListFilter) {
    const page = Math.max(1, Number(filter.page) || 1);
    const limit = Math.max(1, Math.min(100, Number(filter.limit) || 15));
    const skip = (page - 1) * limit;

    const where: any = {};

    if (filter.subjectId) where.subjectId = filter.subjectId;
    if (filter.topicId) where.topicId = filter.topicId;
    if (filter.subtopicId) where.subtopicId = filter.subtopicId;
    if (filter.difficulty) where.difficulty = filter.difficulty;
    if (filter.sourceType) where.sourceType = filter.sourceType;
    if (filter.status) where.status = filter.status;

    if (filter.pyqOnly !== undefined && filter.pyqOnly !== '') {
      const isPyq = filter.pyqOnly === true || filter.pyqOnly === 'true';
      if (isPyq) {
        where.pyq = { not: null };
      } else {
        where.pyq = null;
      }
    }

    if (filter.search && filter.search.trim()) {
      where.prompt = {
        contains: filter.search.trim(),
        mode: 'insensitive',
      };
    }

    const [questions, total] = await Promise.all([
      prisma.question.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          subject: { select: { id: true, name: true } },
          topic: { select: { id: true, name: true } },
          subtopic: { select: { id: true, name: true } },
        },
      }),
      prisma.question.count({ where }),
    ]);

    return {
      questions,
      pagination: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  /**
   * Question repository aggregate analytics
   */
  public static async getQuestionStats() {
    const [
      total,
      easyCount,
      mediumCount,
      hardCount,
      manualCount,
      aiCount,
      publishedCount,
      draftCount,
      topicsWithCount,
    ] = await Promise.all([
      prisma.question.count(),
      prisma.question.count({ where: { difficulty: 'EASY' } }),
      prisma.question.count({ where: { difficulty: 'MEDIUM' } }),
      prisma.question.count({ where: { difficulty: 'HARD' } }),
      prisma.question.count({ where: { sourceType: 'MANUAL' } }),
      prisma.question.count({ where: { sourceType: 'AI_GENERATED' } }),
      prisma.question.count({ where: { status: 'PUBLISHED' } }),
      prisma.question.count({ where: { status: 'DRAFT' } }),
      prisma.topic.findMany({
        select: {
          id: true,
          name: true,
          _count: { select: { questions: true } },
        },
        take: 10,
        orderBy: { questions: { _count: 'desc' } },
      }),
    ]);

    return {
      total,
      byDifficulty: {
        easy: easyCount,
        medium: mediumCount,
        hard: hardCount,
      },
      bySource: {
        manual: manualCount,
        aiGenerated: aiCount,
      },
      byStatus: {
        published: publishedCount,
        draft: draftCount,
      },
      topTopics: topicsWithCount.map((t) => ({
        id: t.id,
        name: t.name,
        questionCount: t._count.questions,
      })),
    };
  }

  /**
   * Create a single question
   */
  public static async createQuestion(data: {
    subtopicId: string;
    topicId?: string;
    subjectId?: string;
    pattern?: string;
    prompt: string;
    options: QuestionOption[];
    correctAnswer: QuestionOptionId;
    hints?: string[];
    explanation: string;
    method?: string;
    difficulty?: QuestionDifficulty;
    estimatedTimeSeconds?: number;
    calculationMode?: CalculationMode;
    status?: 'DRAFT' | 'REVIEW' | 'PUBLISHED' | 'ARCHIVED';
    sourceType?: 'MANUAL' | 'AI_GENERATED';
    externalKey?: string;
    pyq?: string;
    alternativeExplanation?: string;
    preferredSolution?: 'BOOK' | 'ALTERNATIVE';
    preferredReason?: string;
    generationMethod?: 'HUMAN_MANUAL' | 'AI_EXTRACTED' | 'AI_SYNTHETIC';
    sourceBook?: string;
    sourceEdition?: string;
    sourceChapter?: string;
    sourcePageRange?: string;
  }) {
    // Resolve subtopic hierarchy
    const subtopic = await prisma.subtopic.findUnique({
      where: { id: data.subtopicId },
      include: { topic: { include: { subject: true } } },
    });

    if (!subtopic) {
      throw new Error(`Subtopic not found with id: ${data.subtopicId}`);
    }

    const subjectId = subtopic.topic.subjectId;
    const topicId = subtopic.topicId;

    const fingerprint = FingerprintService.computeFingerprint(data.prompt, data.options);

    // Check duplicate fingerprint
    const existing = await prisma.question.findUnique({ where: { fingerprint } });
    if (existing) {
      throw new Error('A question with identical prompt and options already exists');
    }

    return prisma.question.create({
      data: {
        subjectId,
        topicId,
        subtopicId: data.subtopicId,
        externalKey: data.externalKey?.trim() || null,
        pattern: data.pattern || 'STANDARD_MCQ',
        prompt: data.prompt,
        options: data.options as any,
        correctAnswer: data.correctAnswer,
        hints: data.hints || [],
        explanation: data.explanation || '',
        method: data.method || 'Standard Method',
        difficulty: data.difficulty || 'EASY',
        estimatedTimeSeconds: data.estimatedTimeSeconds || 60,
        calculationMode: data.calculationMode || 'MENTAL',
        sourceType: data.sourceType || 'MANUAL',
        status: data.status || 'PUBLISHED',
        pyq: data.pyq?.trim() || null,
        alternativeExplanation: data.alternativeExplanation?.trim() || null,
        preferredSolution: data.preferredSolution || null,
        preferredReason: data.preferredReason?.trim() || null,
        generationMethod: data.generationMethod || 'HUMAN_MANUAL',
        sourceBook: data.sourceBook?.trim() || null,
        sourceEdition: data.sourceEdition?.trim() || null,
        sourceChapter: data.sourceChapter?.trim() || null,
        sourcePageRange: data.sourcePageRange?.trim() || null,
        fingerprint,
      },
      include: {
        subject: { select: { id: true, name: true } },
        topic: { select: { id: true, name: true } },
        subtopic: { select: { id: true, name: true } },
      },
    });
  }

  /**
   * Update question
   */
  public static async updateQuestion(id: string, data: any) {
    const existing = await prisma.question.findUnique({ where: { id } });
    if (!existing) {
      throw new Error(`Question not found with id: ${id}`);
    }

    let fingerprint = existing.fingerprint;
    const prompt = data.prompt ?? existing.prompt;
    const options = data.options ?? existing.options;

    if (data.prompt || data.options) {
      fingerprint = FingerprintService.computeFingerprint(prompt, options as QuestionOption[]);
    }

    let { subjectId, topicId, subtopicId } = existing;
    if (data.subtopicId && data.subtopicId !== existing.subtopicId) {
      const subtopic = await prisma.subtopic.findUnique({
        where: { id: data.subtopicId },
        include: { topic: true },
      });
      if (!subtopic) {
        throw new Error(`Subtopic not found: ${data.subtopicId}`);
      }
      subtopicId = subtopic.id;
      topicId = subtopic.topicId;
      subjectId = subtopic.topic.subjectId;
    }

    return prisma.question.update({
      where: { id },
      data: {
        subjectId,
        topicId,
        subtopicId,
        externalKey: data.externalKey !== undefined ? (data.externalKey?.trim() || null) : existing.externalKey,
        prompt,
        options,
        correctAnswer: data.correctAnswer ?? existing.correctAnswer,
        hints: data.hints ?? existing.hints,
        explanation: data.explanation ?? existing.explanation,
        method: data.method ?? existing.method,
        difficulty: data.difficulty ?? existing.difficulty,
        estimatedTimeSeconds: data.estimatedTimeSeconds ?? existing.estimatedTimeSeconds,
        calculationMode: data.calculationMode ?? existing.calculationMode,
        status: data.status ?? existing.status,
        pyq: data.pyq !== undefined ? (data.pyq?.trim() || null) : existing.pyq,
        alternativeExplanation: data.alternativeExplanation !== undefined ? (data.alternativeExplanation?.trim() || null) : existing.alternativeExplanation,
        preferredSolution: data.preferredSolution !== undefined ? (data.preferredSolution || null) : existing.preferredSolution,
        preferredReason: data.preferredReason !== undefined ? (data.preferredReason?.trim() || null) : existing.preferredReason,
        sourceBook: data.sourceBook !== undefined ? (data.sourceBook?.trim() || null) : existing.sourceBook,
        sourceEdition: data.sourceEdition !== undefined ? (data.sourceEdition?.trim() || null) : existing.sourceEdition,
        sourceChapter: data.sourceChapter !== undefined ? (data.sourceChapter?.trim() || null) : existing.sourceChapter,
        sourcePageRange: data.sourcePageRange !== undefined ? (data.sourcePageRange?.trim() || null) : existing.sourcePageRange,
        fingerprint,
      },
      include: {
        subject: { select: { id: true, name: true } },
        topic: { select: { id: true, name: true } },
        subtopic: { select: { id: true, name: true } },
      },
    });
  }

  /**
   * Relink question to a different subtopic
   */
  public static async relinkQuestion(id: string, newSubtopicId: string) {
    const subtopic = await prisma.subtopic.findUnique({
      where: { id: newSubtopicId },
      include: { topic: true },
    });

    if (!subtopic) {
      throw new Error(`Target subtopic not found: ${newSubtopicId}`);
    }

    return prisma.question.update({
      where: { id },
      data: {
        subtopicId: subtopic.id,
        topicId: subtopic.topicId,
        subjectId: subtopic.topic.subjectId,
      },
      include: {
        subject: { select: { id: true, name: true } },
        topic: { select: { id: true, name: true } },
        subtopic: { select: { id: true, name: true } },
      },
    });
  }

  /**
   * Hard delete a question cleanly cascading across all dependent tables
   */
  public static async deleteQuestion(id: string) {
    return prisma.$transaction(async (tx) => {
      // 1. Delete dependent entries
      await tx.pvpMatchAnswer.deleteMany({ where: { questionId: id } });
      await tx.pvpQuestionSetQuestion.deleteMany({ where: { questionId: id } });
      await tx.practiceSessionQuestion.deleteMany({ where: { questionId: id } });
      await tx.dailyChallengeAnswer.deleteMany({ where: { questionId: id } });
      await tx.dailyChallengeScriptQuestion.deleteMany({ where: { questionId: id } });
      await tx.userQuestionProgress.deleteMany({ where: { questionId: id } });
      await tx.questionAttempt.deleteMany({ where: { questionId: id } });

      // 2. Delete question itself
      return tx.question.delete({ where: { id } });
    });
  }

  /**
   * Bulk import questions from array (parsed from CSV, XLSX, or JSON)
   */
  public static async bulkImport(rawQuestions: any[], defaultSubtopicId?: string) {
    let successCount = 0;
    let failedCount = 0;
    const errors: Array<{ index: number; reason: string }> = [];

    // 1. Collect all candidate subtopic keys across all rows for a single batched query
    const rawKeys = new Set<string>();
    for (const q of rawQuestions) {
      const key = q.externalSubtopicKey || q.subtopicId || q.subtopicSlug;
      if (key && typeof key === 'string' && key.trim()) {
        rawKeys.add(key.trim());
      }
    }
    if (defaultSubtopicId && defaultSubtopicId.trim()) {
      rawKeys.add(defaultSubtopicId.trim());
    }

    const subtopicList = await prisma.subtopic.findMany({
      where: {
        OR: [
          { slug: { in: Array.from(rawKeys) } },
          { id: { in: Array.from(rawKeys) } },
        ],
      },
      include: { topic: true },
    });

    const subtopicMap = new Map<string, any>();
    for (const s of subtopicList) {
      if (s.slug) subtopicMap.set(s.slug, s);
      subtopicMap.set(s.id, s);
    }

    const resolvedDefaultSubtopic = defaultSubtopicId ? subtopicMap.get(defaultSubtopicId.trim()) : null;

    // 2. First pass: parse, validate format, and compute fingerprints
    interface ValidatedCandidate {
      index: number;
      data: any;
      fingerprint: string;
      externalKey: string | null;
    }

    const candidates: ValidatedCandidate[] = [];
    const seenFingerprintsInBatch = new Set<string>();
    const seenExternalKeysInBatch = new Set<string>();

    for (let i = 0; i < rawQuestions.length; i++) {
      const q = rawQuestions[i];
      try {
        const prompt = String(q.prompt || q.question || '').trim();
        if (!prompt) throw new Error('Missing prompt/question text');

        // Parse options
        let options: QuestionOption[] = [];
        if (Array.isArray(q.options) && q.options.length > 0) {
          options = q.options.map((opt: any, idx: number) => {
            const letter = (['A', 'B', 'C', 'D'][idx] || 'A') as QuestionOptionId;
            return {
              id: (opt.id || letter) as QuestionOptionId,
              text: String(opt.text || opt.label || opt || '').trim(),
            };
          });
        } else if (q.optionA || q.option_a || q.A) {
          options = [
            { id: 'A', text: String(q.optionA || q.option_a || q.A || '').trim() },
            { id: 'B', text: String(q.optionB || q.option_b || q.B || '').trim() },
            { id: 'C', text: String(q.optionC || q.option_c || q.C || '').trim() },
            { id: 'D', text: String(q.optionD || q.option_d || q.D || '').trim() },
          ];
        }

        if (options.length < 2) {
          throw new Error('Question must contain at least 2 options');
        }

        const rawCorrect = String(q.correctAnswer || q.correct_answer || q.answer || 'A').toUpperCase().trim();
        const correctAnswer = (['A', 'B', 'C', 'D'].includes(rawCorrect) ? rawCorrect : 'A') as QuestionOptionId;

        // Subtopic lookup
        const rawTargetKey = (q.externalSubtopicKey || q.subtopicId || q.subtopicSlug || '') as string;
        const targetSubtopicKey = rawTargetKey.trim();

        let subtopic = targetSubtopicKey ? subtopicMap.get(targetSubtopicKey) : null;
        if (!subtopic && resolvedDefaultSubtopic) {
          subtopic = resolvedDefaultSubtopic;
        }

        if (!subtopic) {
          throw new Error(
            targetSubtopicKey
              ? `Unknown subtopic key: "${targetSubtopicKey}"`
              : 'No subtopic key provided and no default subtopic configured'
          );
        }

        const difficultyRaw = String(q.difficulty || 'EASY').toUpperCase().trim();
        const difficulty: QuestionDifficulty = ['EASY', 'MEDIUM', 'HARD'].includes(difficultyRaw)
          ? (difficultyRaw as QuestionDifficulty)
          : 'EASY';

        const fingerprint = FingerprintService.computeFingerprint(prompt, options);

        if (seenFingerprintsInBatch.has(fingerprint)) {
          failedCount++;
          errors.push({ index: i + 1, reason: `Duplicate question within batch: "${prompt.slice(0, 30)}..."` });
          continue;
        }

        const externalKey = q.externalQuestionKey || q.externalKey ? String(q.externalQuestionKey || q.externalKey).trim() : null;
        if (externalKey && seenExternalKeysInBatch.has(externalKey)) {
          failedCount++;
          errors.push({ index: i + 1, reason: `Duplicate externalKey within batch: "${externalKey}"` });
          continue;
        }

        seenFingerprintsInBatch.add(fingerprint);
        if (externalKey) seenExternalKeysInBatch.add(externalKey);

        const pyq = q.pyq ? String(q.pyq).trim() : null;
        const alternativeExplanation = q.alternativeExplanation ? String(q.alternativeExplanation).trim() : null;
        const preferredSolution = q.preferredSolution === 'ALTERNATIVE' ? 'ALTERNATIVE' : q.preferredSolution === 'BOOK' ? 'BOOK' : null;
        const preferredReason = q.preferredReason ? String(q.preferredReason).trim() : null;

        const sourceBook = q.provenance?.bookTitle || q.sourceBook ? String(q.provenance?.bookTitle || q.sourceBook).trim() : null;
        const sourceEdition = q.provenance?.edition || q.sourceEdition ? String(q.provenance?.edition || q.sourceEdition).trim() : null;
        const sourceChapter = q.provenance?.chapter || q.sourceChapter ? String(q.provenance?.chapter || q.sourceChapter).trim() : null;
        const sourcePageRange = q.provenance?.pageRange || q.sourcePageRange ? String(q.provenance?.pageRange || q.sourcePageRange).trim() : null;

        candidates.push({
          index: i + 1,
          fingerprint,
          externalKey,
          data: {
            subjectId: subtopic.topic.subjectId,
            topicId: subtopic.topicId,
            subtopicId: subtopic.id,
            externalKey,
            pattern: q.pattern || 'STANDARD_MCQ',
            prompt,
            options: options as any,
            correctAnswer,
            hints: Array.isArray(q.hints) ? q.hints : (q.hint ? [String(q.hint)] : []),
            explanation: String(q.explanation || ''),
            method: String(q.method || q.pattern || 'Standard Method'),
            difficulty,
            estimatedTimeSeconds: Number(q.estimatedTimeSeconds) || 60,
            calculationMode: (q.calculationMode || 'MENTAL') as CalculationMode,
            sourceType: 'MANUAL',
            status: q.status || 'REVIEW',
            generationMethod: 'AI_EXTRACTED',
            sourceBook,
            sourceEdition,
            sourceChapter,
            sourcePageRange,
            pyq,
            alternativeExplanation,
            preferredSolution,
            preferredReason,
            fingerprint,
          },
        });
      } catch (err: any) {
        failedCount++;
        errors.push({ index: i + 1, reason: err.message || 'Validation error' });
      }
    }

    // 3. Batched duplicate check against database
    const candidateFingerprints = candidates.map((c) => c.fingerprint);
    const candidateExternalKeys = candidates.map((c) => c.externalKey).filter(Boolean) as string[];

    const [existingFpList, existingKeyList] = await Promise.all([
      prisma.question.findMany({
        where: { fingerprint: { in: candidateFingerprints } },
        select: { fingerprint: true },
      }),
      candidateExternalKeys.length > 0
        ? prisma.question.findMany({
            where: { externalKey: { in: candidateExternalKeys } },
            select: { externalKey: true },
          })
        : Promise.resolve([]),
    ]);

    const existingFps = new Set(existingFpList.map((e) => e.fingerprint));
    const existingKeys = new Set(existingKeyList.map((e) => e.externalKey));

    const recordsToInsert: any[] = [];
    for (const c of candidates) {
      if (existingFps.has(c.fingerprint)) {
        failedCount++;
        errors.push({ index: c.index, reason: `Question already exists in database (duplicate fingerprint)` });
        continue;
      }
      if (c.externalKey && existingKeys.has(c.externalKey)) {
        failedCount++;
        errors.push({ index: c.index, reason: `Question with externalKey "${c.externalKey}" already exists in database.` });
        continue;
      }
      recordsToInsert.push(c.data);
    }

    // 4. Batch insert all accepted records
    if (recordsToInsert.length > 0) {
      await prisma.question.createMany({
        data: recordsToInsert,
        skipDuplicates: true,
      });
      successCount = recordsToInsert.length;
    }

    return {
      success: true,
      totalProcessed: rawQuestions.length,
      successCount,
      failedCount,
      errors: errors.slice(0, 50),
    };
  }
}
