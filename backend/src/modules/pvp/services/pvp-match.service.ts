import { randomUUID } from 'node:crypto';
import { Prisma, PrismaClient } from '@prisma/client';
import { pvpMatchInclude, PvpInternalMatch, requireParticipant, serializeMatch } from '../pvp.dto';
import { PvpError } from '../pvp.errors';
import { lockUsers } from '../../social/friends.service';
import { prisma } from '../../../config/prisma';
import { pvpSetGenerationService } from '../../ai/services/pvp-set-generation.service';
import { XpService } from '../../xp/xp.service';
import { XpPolicy } from '../../xp/xp.policy';
import { matchQuestions, freezeQuestions } from '../ranked/ranked-questions';
import { RankedSeasonService } from '../ranked/ranked-season.service';
import { commitSettlement, prepareRatingSettlement } from '../ranked/ranked-settlement.service';
import { databaseNow, rankedTransaction } from '../ranked/ranked-transaction';
import { RANKED_POLICY, RankedActivation } from '../ranked/ranked-config';
import { rankedReadCache } from '../ranked/ranked-cache';
import { RankedEligibilityService } from '../ranked/ranked-eligibility.service';
import { QueueClaim } from '../ranked/ranked-matchmaking-policy';
import { RankedRuntime, rankedRuntime } from '../ranked/ranked-runtime';
import { rankedActivation } from '../ranked/ranked-config';
import { TIME_CONFIG } from '../../../config/inventory.config';

export interface SubmitPvpAnswerParams {
  matchId: string;
  userId: string;
  questionIndex: number;
  selectedOptionId: string | null;
  responseTimeMs?: number; // Ignored compatibility telemetry.
  receivedAt?: Date; // Set by the server at WebSocket ingress, never parsed from client payload.
}

export class PvpMatchService {
  private static instance: PvpMatchService;

  readonly seasons: RankedSeasonService;
  constructor(private readonly db: PrismaClient = prisma, private readonly clock: () => Date = () => new Date(),
    private readonly activation: () => RankedActivation = rankedActivation, private readonly runtime: () => RankedRuntime = rankedRuntime) {
    this.seasons = new RankedSeasonService(db, activation);
  }

  public static getInstance(): PvpMatchService {
    if (!PvpMatchService.instance) {
      PvpMatchService.instance = new PvpMatchService();
    }
    return PvpMatchService.instance;
  }

  /**
   * Creates a new match between two paired players.
   * Selects an appropriate 10-Question PvP Set or generates a new one on-demand.
   */
  public async createMatch(player1Id: string, player2Id: string, claim?: QueueClaim & { isActive: () => boolean }): Promise<PvpInternalMatch> {
    if (player1Id === player2Id) throw new PvpError('Two different players are required.', 'INVALID_PARTICIPANTS', 400);
    if (this.activation().enabled && !claim) throw new PvpError('Rated admission requires a valid queue claim.', 'QUEUE_CLAIM_REQUIRED', 409);
    if (claim && (claim.a.userId !== player1Id || claim.b.userId !== player2Id || !claim.isActive())) throw new PvpError('Match search expired. Please retry.', 'QUEUE_CLAIM_LOST');
    const admissionId = claim?.id ?? randomUUID();
    // 1. Select a PvP Question Set
    let questionSet = await this.selectPvPSetForPlayers(player1Id, player2Id);
    if (!questionSet) {
      // On-demand generate fresh set
      questionSet = await pvpSetGenerationService.generatePvpQuestionSet();
    }

    if (!questionSet) {
      throw new Error('Failed to obtain or generate a valid PvP Question Set.');
    }

    const questionSnapshot = freezeQuestions(questionSet.setQuestions.map(q => q.question));

    // 2. Persist PvpMatch and PvpMatchPlayer
    try {
      const match = await rankedTransaction(this.db, async (tx) => {
        await lockUsers(tx, [player1Id, player2Id]);
        const existing = await tx.pvpMatch.findUnique({ where: { id: admissionId } });
        if (existing) {
          const details = await this.getMatchDetails(admissionId, tx);
          if (details.players.length !== 2 || ![player1Id, player2Id].every(id => details.players.some(p => p.userId === id))) throw new PvpError('Conflicting queue claim.', 'QUEUE_CLAIM_CONFLICT');
          return existing;
        }
        const eligibility = new RankedEligibilityService(this.db, this.activation, this.runtime);
        if (claim) {
          if (!claim.isActive()) throw new PvpError('Match search expired. Please retry.', 'QUEUE_CLAIM_LOST');
          await eligibility.validate(tx, claim.a); await eligibility.validate(tx, claim.b);
        } else {
          await eligibility.inspect(player1Id, 0, tx); await eligibility.inspect(player2Id, 0, tx);
        }
        const admission = await this.seasons.admit(tx, [player1Id, player2Id]);
        const { admittedAt, policy, ...assignment } = { policy: RANKED_POLICY, ...admission };
        if (claim && (!claim.isActive() || admission.ratingMode !== claim.a.ratingMode || (admission.ratingMode === 'RATED' && admission.seasonId !== claim.a.seasonId))) throw new PvpError('Season or queue claim changed. Search again.', 'QUEUE_STALE');
        const createdMatch = await tx.pvpMatch.create({
          data: {
            id: admissionId, questionSetId: questionSet.id,
            status: 'STARTING',
            totalQuestions: 10,
            currentQuestionIndex: 0,
            ...assignment, questionSnapshot,
            transitionDeadline: new Date(+admittedAt + policy.transitionMs),
            hardExpiresAt: new Date(+admittedAt + policy.hardExpiryMs),
          },
        });

        await tx.pvpMatchPlayer.createMany({
          data: [
            {
              matchId: createdMatch.id,
              userId: player1Id,
              score: 0,
              totalResponseTimeMs: 0,
              connectionStatus: 'CONNECTED',
            },
            {
              matchId: createdMatch.id,
              userId: player2Id,
              score: 0,
              totalResponseTimeMs: 0,
              connectionStatus: 'CONNECTED',
            },
          ],
        });

        // Record set history
        await tx.pvpPlayerSetHistory.upsert({
          where: { userId_questionSetId: { userId: player1Id, questionSetId: questionSet.id } },
          update: { lastPlayedAt: admittedAt, playCount: { increment: 1 } },
          create: { userId: player1Id, questionSetId: questionSet.id },
        });

        await tx.pvpPlayerSetHistory.upsert({
          where: { userId_questionSetId: { userId: player2Id, questionSetId: questionSet.id } },
          update: { lastPlayedAt: admittedAt, playCount: { increment: 1 } },
          create: { userId: player2Id, questionSetId: questionSet.id },
        });

        return createdMatch;
      });

      rankedReadCache.invalidate([player1Id, player2Id]);
      return await this.getMatchDetails(match.id);
    } catch (error) {
      // A fixed server claim ID also resolves a lost admission commit ACK.
      // Never invent another match while the original outcome is unknown.
      try {
        const existing = await this.getMatchDetails(admissionId);
        if (existing.players.length === 2 && [player1Id, player2Id].every(id => existing.players.some(p => p.userId === id))) {
          rankedReadCache.invalidate([player1Id, player2Id]); return existing;
        }
      } catch { /* Original error remains authoritative when DB is unavailable. */ }
      throw error;
    }
  }

  /**
   * Selects a published PvP set, preferring one unseen by both players.
   * Strictly excludes any set containing questions from inactive subjects, topics, or subtopics.
   */
  private async selectPvPSetForPlayers(player1Id: string, player2Id: string) {
    // 1. Prefer set unseen by both players (all questions active)
    const unseenBoth = await this.db.$queryRaw<Array<{ id: string }>>`
      SELECT qs.id FROM learning.pvp_question_sets qs
      WHERE qs.status = 'PUBLISHED' AND qs.question_count = 10 AND (SELECT count(*) FROM learning.pvp_question_set_questions psq WHERE psq.set_id = qs.id) = 10
        AND NOT EXISTS (
          SELECT 1 FROM learning.pvp_player_set_history h
          WHERE h.question_set_id = qs.id AND h.user_id IN (${player1Id}::uuid, ${player2Id}::uuid)
        )
        AND NOT EXISTS (
          SELECT 1 FROM learning.pvp_question_set_questions psq
          JOIN learning.questions q ON q.id = psq.question_id
          JOIN learning.subtopics st ON st.id = q.subtopic_id
          JOIN learning.topics t ON t.id = q.topic_id
          JOIN learning.subjects s ON s.id = q.subject_id
          WHERE psq.set_id = qs.id
            AND (st.is_active = false OR t.is_active = false OR s.is_active = false)
        )
      ORDER BY qs.updated_at ASC LIMIT 1;
    `;

    let selectedSetId = unseenBoth[0]?.id;

    // 2. Fallback: unseen by at least one (all questions active)
    if (!selectedSetId) {
      const unseenOne = await this.db.$queryRaw<Array<{ id: string }>>`
        SELECT qs.id FROM learning.pvp_question_sets qs
        WHERE qs.status = 'PUBLISHED' AND qs.question_count = 10 AND (SELECT count(*) FROM learning.pvp_question_set_questions psq WHERE psq.set_id = qs.id) = 10
          AND (
            NOT EXISTS (
              SELECT 1 FROM learning.pvp_player_set_history h
              WHERE h.question_set_id = qs.id AND h.user_id = ${player1Id}::uuid
            )
            OR NOT EXISTS (
              SELECT 1 FROM learning.pvp_player_set_history h
              WHERE h.question_set_id = qs.id AND h.user_id = ${player2Id}::uuid
            )
          )
          AND NOT EXISTS (
            SELECT 1 FROM learning.pvp_question_set_questions psq
            JOIN learning.questions q ON q.id = psq.question_id
            JOIN learning.subtopics st ON st.id = q.subtopic_id
            JOIN learning.topics t ON t.id = q.topic_id
            JOIN learning.subjects s ON s.id = q.subject_id
            WHERE psq.set_id = qs.id
              AND (st.is_active = false OR t.is_active = false OR s.is_active = false)
          )
        ORDER BY qs.updated_at ASC LIMIT 1;
      `;
      selectedSetId = unseenOne[0]?.id;
    }

    // 3. Fallback: least recently used published set (all questions active)
    if (!selectedSetId) {
      const lru = await this.db.$queryRaw<Array<{ id: string }>>`
        SELECT qs.id FROM learning.pvp_question_sets qs
        WHERE qs.status = 'PUBLISHED' AND qs.question_count = 10 AND (SELECT count(*) FROM learning.pvp_question_set_questions psq WHERE psq.set_id = qs.id) = 10
          AND NOT EXISTS (
            SELECT 1 FROM learning.pvp_question_set_questions psq
            JOIN learning.questions q ON q.id = psq.question_id
            JOIN learning.subtopics st ON st.id = q.subtopic_id
            JOIN learning.topics t ON t.id = q.topic_id
            JOIN learning.subjects s ON s.id = q.subject_id
            WHERE psq.set_id = qs.id
              AND (st.is_active = false OR t.is_active = false OR s.is_active = false)
          )
        ORDER BY qs.updated_at ASC LIMIT 1;
      `;
      selectedSetId = lru[0]?.id;
    }

    if (!selectedSetId) return null;

    const questionSet = await this.db.pvpQuestionSet.findUnique({
      where: { id: selectedSetId },
      include: {
        setQuestions: {
          include: {
            question: {
              include: {
                subtopic: true,
                topic: {
                  include: {
                    subject: true,
                  },
                },
              },
            },
          },
          orderBy: { sequence: 'asc' },
        },
      },
    });

    if (!questionSet || questionSet.questionCount !== 10 || questionSet.setQuestions.length !== 10) {
      return null;
    }

    // Explicit defense-in-depth: discard if any question belongs to an inactive subtopic, topic, or subject
    const hasInactive = questionSet.setQuestions.some(
      (sq) =>
        sq.question.status !== 'PUBLISHED' ||
        !sq.question?.subtopic?.isActive ||
        !sq.question?.topic?.isActive ||
        !sq.question?.topic?.subject?.isActive
    );

    if (hasInactive || new Set(questionSet.setQuestions.map(q => q.questionId)).size !== 10) {
      return null;
    }

    return questionSet;
  }

  /** Internal only. Every REST/WS consumer must use an explicit public serializer. */
  public async getMatchDetails(matchId: string, db: Prisma.TransactionClient = this.db): Promise<PvpInternalMatch> {
    const match = await db.pvpMatch.findUnique({ where: { id: matchId }, include: pvpMatchInclude });
    if (!match) throw new PvpError('Match not found.', 'MATCH_NOT_FOUND', 404);
    return match;
  }

  public async getMatchSnapshot(matchId: string, userId: string) {
    return this.db.$transaction(async tx => {
      const match = await this.getMatchDetails(matchId, tx);
      const snapshot = serializeMatch(match, userId, this.clock());
      const progress = match.status === 'COMPLETED' ? await tx.userProgress.findUnique({ where: { userId } }) : null;
      const total = progress ? Number(progress.totalXp) : 0;
      // Current absolute progress, not an instruction to add the historical award again.
      const xp = progress ? { earned: 0, previousTotal: total, total, ...XpPolicy.getLevelProgress(total) } : null;
      return { ...snapshot, xp };
    }, { isolationLevel: 'RepeatableRead' });
  }

  private async lockMatch(tx: Prisma.TransactionClient, matchId: string) {
    await tx.$queryRaw`SELECT id FROM learning.pvp_matches WHERE id=${matchId}::uuid FOR UPDATE`;
    return this.getMatchDetails(matchId, tx);
  }

  private assertRatedEvidence(match: PvpInternalMatch) {
    if (match.ratingMode !== 'RATED') return;
    const questions = matchQuestions(match);
    if (questions.length !== 10 || match.players.length !== 2 || match.answers.length !== 20) throw new PvpError('Rated answer evidence is incomplete.', 'INVALID_MATCH_STATE');
    for (const player of match.players) {
      for (let index = 0; index < questions.length; index++) {
        const answers = match.answers.filter(a => a.userId === player.userId && a.questionIndex === index);
        const answer = answers[0];
        if (answers.length !== 1 || answer.questionId !== questions[index].id || !Number.isInteger(answer.responseTimeMs)
          || answer.responseTimeMs < 0 || answer.responseTimeMs > 60000) throw new PvpError('Rated answer evidence is invalid.', 'INVALID_MATCH_STATE');
      }
    }
  }

  public async startQuestionRound(matchId: string, questionIndex: number) {
    return this.db.$transaction(async tx => {
      const match = await this.lockMatch(tx, matchId);
      if ((match.transitionDeadline && this.clock() < match.transitionDeadline) || (match.hardExpiresAt && this.clock() >= match.hardExpiresAt)) return null;
      const canStart = (match.status === 'STARTING' && questionIndex === 0)
        || (match.status === 'QUESTION_TRANSITION' && questionIndex === match.currentQuestionIndex + 1);
      if (!canStart) return null; // Stale or duplicate ready/transition callback.
      if (!Number.isInteger(questionIndex) || questionIndex < 0 || questionIndex >= match.totalQuestions) {
        throw new PvpError('Invalid question index.', 'INVALID_QUESTION_INDEX', 400);
      }
      if (!matchQuestions(match)[questionIndex]) throw new PvpError('Question unavailable.', 'QUESTION_UNAVAILABLE');
      const startedAt = this.clock();
      await tx.pvpMatch.update({ where: { id: matchId }, data: {
        status: 'QUESTION_ACTIVE', currentQuestionIndex: questionIndex, stateVersion: { increment: 1 }, transitionDeadline: null,
        currentQuestionStartedAt: startedAt,
        currentQuestionDeadline: new Date(startedAt.getTime() + TIME_CONFIG.PVP_FIXED_SECONDS * 1000),
        ...(questionIndex === 0 ? { startedAt } : {}),
      } });
      return this.getMatchDetails(matchId, tx);
    });
  }

  public async submitAnswer(params: SubmitPvpAnswerParams) {
    const { matchId, userId, questionIndex, selectedOptionId } = params;
    const receivedAt = params.receivedAt ?? this.clock();
    return this.db.$transaction(async tx => {
      const match = await this.lockMatch(tx, matchId);
      requireParticipant(match, userId);
      if (!Number.isInteger(questionIndex) || questionIndex < 0 || questionIndex >= match.totalQuestions) {
        throw new PvpError('Invalid question index.', 'INVALID_QUESTION_INDEX', 400);
      }
      // A lost ACK can be retried after a round closes. The first answer is immutable.
      const existing = match.answers.find(a => a.userId === userId && a.questionIndex === questionIndex);
      if (existing) return { isDuplicate: true, answer: existing, stateVersion: match.stateVersion, bothAnswered: match.answers.filter(a => a.questionIndex === questionIndex).length === 2 };
      if (match.status !== 'QUESTION_ACTIVE' || match.currentQuestionIndex !== questionIndex) {
        throw new PvpError('This question is not accepting answers.', 'ROUND_NOT_ACTIVE');
      }
      const start = match.currentQuestionStartedAt?.getTime();
      const deadline = match.currentQuestionDeadline?.getTime();
      const receipt = receivedAt.getTime();
      if (start === undefined || deadline === undefined || !Number.isFinite(receipt) || receipt < start) {
        throw new PvpError('Round timing is unavailable.', 'INVALID_ROUND_TIME');
      }
      if (receipt >= deadline) throw new PvpError('The question deadline has passed.', 'ROUND_DEADLINE_PASSED');
      const question = matchQuestions(match)[questionIndex];
      if (!question) throw new PvpError('Question unavailable.', 'QUESTION_UNAVAILABLE');
      if (selectedOptionId !== null && typeof selectedOptionId !== 'string') throw new PvpError('Choose a valid option.', 'INVALID_OPTION', 400);
      const option = selectedOptionId === null ? null : selectedOptionId.trim().toUpperCase();
      if (option !== null && (!Array.isArray(question.options) || !question.options.some(o => o && typeof o === 'object' && !Array.isArray(o) && typeof o.id === 'string' && o.id.trim().toUpperCase() === option))) {
        throw new PvpError('Choose a valid option.', 'INVALID_OPTION', 400);
      }
      // TODO: server receipt includes network latency; evaluate fairness later without trusting client clocks.
      const responseTimeMs = option === null ? TIME_CONFIG.PVP_FIXED_SECONDS * 1000
        : Math.min(TIME_CONFIG.PVP_FIXED_SECONDS * 1000, receipt - start);
      const isCorrect = option !== null && option === question.correctAnswer.trim().toUpperCase();
      const answer = await tx.pvpMatchAnswer.create({ data: {
        matchId, userId, questionId: question.id, questionIndex, selectedOptionId: option,
        isCorrect, responseTimeMs, serverReceivedAt: receivedAt, isLate: false,
      } });
      await tx.pvpMatchPlayer.update({ where: { matchId_userId: { matchId, userId } }, data: {
        score: { increment: isCorrect ? 1 : 0 }, totalResponseTimeMs: { increment: responseTimeMs },
      } });
      return { isDuplicate: false, answer, stateVersion: match.stateVersion, bothAnswered: match.answers.filter(a => a.questionIndex === questionIndex).length + 1 === 2 };
    });
  }

  /** Closes once under the same lock as answers. Missing submissions receive a full timeout. */
  public async closeQuestionRound(matchId: string, questionIndex: number) {
    return this.db.$transaction(async tx => {
      const match = await this.lockMatch(tx, matchId);
      if (match.status !== 'QUESTION_ACTIVE' || match.currentQuestionIndex !== questionIndex) return null;
      const answers = match.answers.filter(a => a.questionIndex === questionIndex);
      const deadline = match.currentQuestionDeadline;
      if (!deadline || (this.clock().getTime() < deadline.getTime() && answers.length < 2)) return null;
      const question = matchQuestions(match)[questionIndex];
      if (!question || match.players.length !== 2) throw new PvpError('Invalid match state.', 'INVALID_MATCH_STATE');
      for (const player of match.players) {
        if (answers.some(a => a.userId === player.userId)) continue;
        await tx.pvpMatchAnswer.create({ data: {
          matchId, userId: player.userId, questionId: question.id, questionIndex,
          selectedOptionId: null, isCorrect: false, responseTimeMs: TIME_CONFIG.PVP_FIXED_SECONDS * 1000,
          serverReceivedAt: deadline, isLate: false,
        } });
        await tx.pvpMatchPlayer.update({ where: { matchId_userId: { matchId, userId: player.userId } },
          data: { totalResponseTimeMs: { increment: TIME_CONFIG.PVP_FIXED_SECONDS * 1000 } } });
      }
      await tx.pvpMatch.update({ where: { id: matchId }, data: { status: 'QUESTION_TRANSITION', stateVersion: { increment: 1 }, transitionDeadline: new Date(+this.clock() + RANKED_POLICY.transitionMs) } });
      return this.getMatchDetails(matchId, tx);
    });
  }

  /** One transaction owns the outcome, XP, Elo, ledger and durable result. */
  public async finalizeMatch(matchId: string) {
    const users = (await this.getMatchDetails(matchId)).players.map(p => p.userId);
    try { return await rankedTransaction(this.db, async tx => {
      const before = await this.getMatchDetails(matchId, tx);
      await lockUsers(tx, before.players.map(p => p.userId));
      const match = await this.lockMatch(tx, matchId);
      if (match.status === 'COMPLETED') return match;
      if (match.status !== 'QUESTION_TRANSITION' || match.currentQuestionIndex !== match.totalQuestions - 1 || match.players.length !== 2) {
        throw new PvpError('The match has not finished all rounds.', 'MATCH_NOT_FINISHED');
      }
      this.assertRatedEvidence(match);
      const players = [...match.players].sort((a, b) => a.userId.localeCompare(b.userId));
      // Include a timeout for every absent round, including older in-flight matches.
      const totals = players.map(player => {
        const answers = match.answers.filter(a => a.userId === player.userId);
        const byIndex = new Map(answers.map(a => [a.questionIndex, a]));
        let score = 0, time = 0;
        for (let index = 0; index < match.totalQuestions; index++) {
          const answer = byIndex.get(index);
          score += answer?.isCorrect && !answer.isLate ? 1 : 0;
          time += answer && !answer.isLate ? Math.max(0, Math.min(60000, answer.responseTimeMs)) : 60000;
        }
        return { player, score, time };
      });
      const [a, b] = totals;
      const comparison = a.score - b.score || b.time - a.time;
      const winnerId = comparison > 0 ? a.player.userId : comparison < 0 ? b.player.userId : null;
      const isTie = comparison === 0;
      const now = await databaseNow(tx);
      const rating = await prepareRatingSettlement(tx, match, winnerId, now, this.seasons);
      const xpSnapshots: { userId: string; awarded: number; total: number }[] = [];
      const xpService = XpService.getInstance();
      for (const { player } of totals) await xpService.lockProgress(tx, player.userId);
      for (const { player, score, time } of totals) {
        const isWinner = player.userId === winnerId;
        let totalXp = isWinner ? 100 : isTie ? 50 : 0;
        for (const answer of match.answers.filter(a => a.userId === player.userId && a.isCorrect && !a.isLate)) {
          totalXp += XpPolicy.calculateQuestionXp('RANKED', matchQuestions(match)[answer.questionIndex]?.difficulty ?? 'MEDIUM');
        }
        if (totalXp > 0) await xpService.awardXp({
          userId: player.userId, amount: totalXp, sourceType: 'RANKED', sourceId: match.id,
          idempotencyKey: `pvp:match:${match.id}:user:${player.userId}`,
          description: `Ranked PvP ${isWinner ? 'Victory' : isTie ? 'Tie' : 'Match Completion'} (${score}/${match.totalQuestions})`,
        }, tx);
        const progress = await tx.userProgress.findUniqueOrThrow({ where: { userId: player.userId } });
        xpSnapshots.push({ userId: player.userId, awarded: totalXp, total: Number(progress.totalXp) });
        await tx.pvpMatchPlayer.update({ where: { matchId_userId: { matchId, userId: player.userId } },
          data: { score, totalResponseTimeMs: time, isWinner, xpAwarded: totalXp } });
      }
      await tx.pvpMatch.update({ where: { id: matchId }, data: { status: 'COMPLETED', winnerId, isTie, endedAt: now, outcomeReason: 'NORMAL', stateVersion: { increment: 1 }, transitionDeadline: null } });
      await commitSettlement(tx, match, now, { winnerId, isTie, reason: 'NORMAL', xp: xpSnapshots }, rating, match.ratingMode === 'RATED' ? 'RATED' : 'LEGACY_UNRATED');
      return this.getMatchDetails(matchId, tx);
    }); } finally { rankedReadCache.invalidate(users); }
  }

  /** Keyset pagination includes all active matches, not only this process's cache. */
  public async recoveryPage(afterId?: string) {
    return this.db.$queryRaw<{ id: string }[]>`SELECT m.id FROM learning.pvp_matches m
      WHERE m.status IN ('STARTING','IN_PROGRESS','QUESTION_ACTIVE','QUESTION_TRANSITION')
      AND (${afterId ?? null}::uuid IS NULL OR m.id > ${afterId ?? null}::uuid)
      AND (m.hard_expires_at IS NULL OR m.hard_expires_at <= clock_timestamp()
        OR (m.status IN ('STARTING','QUESTION_TRANSITION') AND (m.transition_deadline IS NULL OR m.transition_deadline <= clock_timestamp()))
        OR (m.status='QUESTION_ACTIVE' AND (m.current_question_deadline IS NULL
          OR m.current_question_deadline <= (clock_timestamp() AT TIME ZONE 'UTC')
          OR (SELECT count(*) FROM learning.pvp_match_answers a WHERE a.match_id=m.id AND a.question_index=m.current_question_index)=2))
        OR m.status='IN_PROGRESS')
      ORDER BY m.id LIMIT 100`;

  }

  public async recoverMatch(matchId: string) {
    let match = await this.getMatchDetails(matchId);
    if (match.status === 'COMPLETED' || match.status === 'CANCELLED') return match;
    // Adopt legacy in-flight deadlines once, under the same match lock. Existing
    // active round timing is retained; no answer is retroactively certified.
    if (!match.hardExpiresAt || ((match.status === 'STARTING' || match.status === 'QUESTION_TRANSITION') && !match.transitionDeadline)) {
      match = await rankedTransaction(this.db, async tx => {
        const current = await this.lockMatch(tx, matchId);
        if (current.status === 'COMPLETED' || current.status === 'CANCELLED') return current;
        await tx.pvpMatch.update({ where: { id: matchId }, data: {
          hardExpiresAt: current.hardExpiresAt ?? new Date(+current.createdAt + RANKED_POLICY.hardExpiryMs),
          ...((current.status === 'STARTING' || current.status === 'QUESTION_TRANSITION') && !current.transitionDeadline
            ? { transitionDeadline: this.clock() } : {}),
        } });
        return this.getMatchDetails(matchId, tx);
      });
    }
    const now = this.clock();
    if (match.status === 'QUESTION_ACTIVE') {
      try {
        const closed = await this.closeQuestionRound(matchId, match.currentQuestionIndex);
        if (closed) match = closed;
      } catch (error) {
        if (match.hardExpiresAt && now >= match.hardExpiresAt && (error instanceof PvpError || (error instanceof Error && error.name === 'ZodError'))) return this.voidExpiredMatch(matchId);
        throw error;
      }
    }
    // Complete recoverable final-round evidence before considering system void.
    if (match.status === 'QUESTION_TRANSITION' && match.currentQuestionIndex === match.totalQuestions - 1
      && (!match.transitionDeadline || now >= match.transitionDeadline || (match.hardExpiresAt && now >= match.hardExpiresAt))) {
      try { this.assertRatedEvidence(match); }
      catch (error) {
        if (match.hardExpiresAt && now >= match.hardExpiresAt) return this.voidExpiredMatch(matchId);
        throw error;
      }
      return this.finalizeMatch(matchId);
    }
    if (match.hardExpiresAt && now >= match.hardExpiresAt) return this.voidExpiredMatch(matchId);
    if ((match.status === 'STARTING' || match.status === 'QUESTION_TRANSITION') && match.transitionDeadline && now >= match.transitionDeadline) {
      return await this.startQuestionRound(matchId, match.status === 'STARTING' ? 0 : match.currentQuestionIndex + 1) ?? this.getMatchDetails(matchId);
    }
    return match;
  }

  private async voidExpiredMatch(matchId: string) {
    const users = (await this.getMatchDetails(matchId)).players.map(p => p.userId);
    try { return await rankedTransaction(this.db, async tx => {
      const before = await this.getMatchDetails(matchId, tx);
      await lockUsers(tx, before.players.map(p => p.userId));
      const match = await this.lockMatch(tx, matchId);
      if (match.status === 'COMPLETED' || match.status === 'CANCELLED') return match;
      const now = await databaseNow(tx);
      if (!match.hardExpiresAt || now < match.hardExpiresAt) return match;
      // A competing close may just have made the match fully recoverable.
      if (match.status === 'QUESTION_TRANSITION' && match.currentQuestionIndex === match.totalQuestions - 1) {
        try { this.assertRatedEvidence(match); return match; }
        catch { /* Invalid evidence is an unrecoverable system failure, not a player loss. */ }
      }
      if (match.seasonId) await tx.$queryRaw`SELECT id FROM learning.ranked_seasons WHERE id=${match.seasonId} FOR SHARE`;
      await tx.pvpMatch.update({ where: { id: matchId }, data: {
        status: 'CANCELLED', winnerId: null, isTie: false, outcomeReason: 'SYSTEM_VOID', endedAt: now,
        stateVersion: { increment: 1 }, transitionDeadline: null,
      } });
      await commitSettlement(tx, match, now, { winnerId: null, isTie: false, reason: 'SYSTEM_VOID', xp: [] }, null, 'VOID');
      return this.getMatchDetails(matchId, tx);
    }); } finally { rankedReadCache.invalidate(users); }
  }

  public async setPlayerConnection(matchId: string, userId: string, status: 'CONNECTED' | 'DISCONNECTED') {
    await this.db.$transaction(async tx => {
      const match = await this.lockMatch(tx, matchId);
      requireParticipant(match, userId);
      if (match.status === 'COMPLETED' || match.status === 'CANCELLED') return;
      await tx.pvpMatchPlayer.update({ where: { matchId_userId: { matchId, userId } }, data: { connectionStatus: status, disconnectedAt: status === 'DISCONNECTED' ? this.clock() : null } });
    });
  }
}

export const pvpMatchService = PvpMatchService.getInstance();
