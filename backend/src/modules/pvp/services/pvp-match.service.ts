import { prisma } from '../../../config/prisma';
import { pvpSetGenerationService } from '../../ai/services/pvp-set-generation.service';
import { XpService } from '../../xp/xp.service';
import { XpPolicy } from '../../xp/xp.policy';
import { TIME_CONFIG } from '../../../config/inventory.config';

export interface SubmitPvpAnswerParams {
  matchId: string;
  userId: string;
  questionIndex: number;
  selectedOptionId: string | null;
  responseTimeMs: number;
}

export class PvpMatchService {
  private static instance: PvpMatchService;

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
  public async createMatch(player1Id: string, player2Id: string): Promise<any> {
    // 1. Select a PvP Question Set
    let questionSet = await this.selectPvPSetForPlayers(player1Id, player2Id);
    if (!questionSet) {
      // On-demand generate fresh set
      questionSet = await pvpSetGenerationService.generatePvpQuestionSet();
    }

    if (!questionSet) {
      throw new Error('Failed to obtain or generate a valid PvP Question Set.');
    }

    // 2. Persist PvpMatch and PvpMatchPlayer
    const match = await prisma.$transaction(async (tx) => {
      const createdMatch = await tx.pvpMatch.create({
        data: {
          questionSetId: questionSet.id,
          status: 'STARTING',
          totalQuestions: questionSet.questionCount || 10,
          currentQuestionIndex: 0,
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
        update: { lastPlayedAt: new Date(), playCount: { increment: 1 } },
        create: { userId: player1Id, questionSetId: questionSet.id },
      });

      await tx.pvpPlayerSetHistory.upsert({
        where: { userId_questionSetId: { userId: player2Id, questionSetId: questionSet.id } },
        update: { lastPlayedAt: new Date(), playCount: { increment: 1 } },
        create: { userId: player2Id, questionSetId: questionSet.id },
      });

      return createdMatch;
    });

    return await this.getMatchDetails(match.id);
  }

  /**
   * Selects a published PvP set, preferring one unseen by both players.
   */
  private async selectPvPSetForPlayers(player1Id: string, player2Id: string) {
    // 1. Prefer set unseen by both players
    const unseenBoth = await prisma.$queryRaw<Array<{ id: string }>>`
      SELECT qs.id FROM learning.pvp_question_sets qs
      WHERE qs.status = 'PUBLISHED'
        AND NOT EXISTS (
          SELECT 1 FROM learning.pvp_player_set_history h
          WHERE h.question_set_id = qs.id AND h.user_id IN (${player1Id}::uuid, ${player2Id}::uuid)
        )
      ORDER BY qs.updated_at ASC LIMIT 1;
    `;

    let selectedSetId = unseenBoth[0]?.id;

    // 2. Fallback: unseen by at least one
    if (!selectedSetId) {
      const unseenOne = await prisma.$queryRaw<Array<{ id: string }>>`
        SELECT qs.id FROM learning.pvp_question_sets qs
        WHERE qs.status = 'PUBLISHED'
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
        ORDER BY qs.updated_at ASC LIMIT 1;
      `;
      selectedSetId = unseenOne[0]?.id;
    }

    // 3. Fallback: least recently used published set
    if (!selectedSetId) {
      const lru = await prisma.$queryRaw<Array<{ id: string }>>`
        SELECT qs.id FROM learning.pvp_question_sets qs
        WHERE qs.status = 'PUBLISHED'
        ORDER BY qs.updated_at ASC LIMIT 1;
      `;
      selectedSetId = lru[0]?.id;
    }

    if (!selectedSetId) return null;

    return await prisma.pvpQuestionSet.findUnique({
      where: { id: selectedSetId },
      include: {
        setQuestions: {
          include: { question: true },
          orderBy: { sequence: 'asc' },
        },
      },
    });
  }

  /**
   * Retrieves full match state with sanitized questions.
   */
  public async getMatchDetails(matchId: string) {
    const match = await prisma.pvpMatch.findUnique({
      where: { id: matchId },
      include: {
        players: {
          include: {
            user: {
              include: { profile: true },
            },
          },
        },
        questionSet: {
          include: {
            setQuestions: {
              include: { question: true },
              orderBy: { sequence: 'asc' },
            },
          },
        },
        answers: true,
      },
    });

    if (!match) throw new Error(`PvP Match "${matchId}" not found.`);

    return match;
  }

  /**
   * Starts a question round and establishes server-authoritative clock.
   * Fixed 60 seconds per question.
   */
  public async startQuestionRound(matchId: string, questionIndex: number) {
    const startedAt = new Date();
    const deadline = new Date(startedAt.getTime() + TIME_CONFIG.PVP_FIXED_SECONDS * 1000);

    return await prisma.pvpMatch.update({
      where: { id: matchId },
      data: {
        status: 'QUESTION_ACTIVE',
        currentQuestionIndex: questionIndex,
        currentQuestionStartedAt: startedAt,
        currentQuestionDeadline: deadline,
      },
      include: {
        players: true,
      },
    });
  }

  /**
   * Submits player's answer for the active question round.
   */
  public async submitAnswer(params: SubmitPvpAnswerParams) {
    const { matchId, userId, questionIndex, selectedOptionId, responseTimeMs } = params;

    const match = await this.getMatchDetails(matchId);
    if (match.status !== 'QUESTION_ACTIVE') {
      throw new Error(`Match is currently ${match.status}, not accepting answers.`);
    }

    if (match.currentQuestionIndex !== questionIndex) {
      throw new Error(`Current question is ${match.currentQuestionIndex}, got ${questionIndex}.`);
    }

    const setQuestion = match.questionSet.setQuestions[questionIndex];
    if (!setQuestion) {
      throw new Error(`Question index ${questionIndex} out of bounds.`);
    }

    const question = setQuestion.question;
    const now = new Date();
    const isLate = match.currentQuestionDeadline
      ? now.getTime() > match.currentQuestionDeadline.getTime() + 1000 // 1s grace buffer
      : false;

    const isCorrect =
      !isLate &&
      selectedOptionId !== null &&
      selectedOptionId.trim().toUpperCase() === question.correctAnswer.trim().toUpperCase();

    // Check if already answered
    const existing = await prisma.pvpMatchAnswer.findUnique({
      where: {
        matchId_userId_questionIndex: {
          matchId,
          userId,
          questionIndex,
        },
      },
    });

    if (existing) {
      return { isDuplicate: true, answer: existing };
    }

    // Persist answer and update player score
    const answer = await prisma.$transaction(async (tx) => {
      const createdAnswer = await tx.pvpMatchAnswer.create({
        data: {
          matchId,
          userId,
          questionId: question.id,
          questionIndex,
          selectedOptionId: selectedOptionId ? selectedOptionId.trim().toUpperCase() : null,
          isCorrect,
          responseTimeMs,
          serverReceivedAt: now,
          isLate,
        },
      });

      if (isCorrect) {
        await tx.pvpMatchPlayer.update({
          where: { matchId_userId: { matchId, userId } },
          data: {
            score: { increment: 1 },
            totalResponseTimeMs: { increment: responseTimeMs },
          },
        });
      } else {
        await tx.pvpMatchPlayer.update({
          where: { matchId_userId: { matchId, userId } },
          data: {
            totalResponseTimeMs: { increment: responseTimeMs },
          },
        });
      }

      return createdAnswer;
    });

    // Check if both players have answered this question
    const answersForQuestion = await prisma.pvpMatchAnswer.count({
      where: { matchId, questionIndex },
    });

    const bothAnswered = answersForQuestion >= match.players.length;

    return {
      isDuplicate: false,
      answer,
      bothAnswered,
      isCorrect,
      correctAnswer: question.correctAnswer,
    };
  }

  /**
   * Finalizes the match, resolves winner/tie-breaker, and authoritatively awards XP.
   * Uninterrupted active player run: if opponent went AFK, active player completes the script and wins.
   */
  public async finalizeMatch(matchId: string) {
    const match = await this.getMatchDetails(matchId);
    if (match.status === 'COMPLETED') return match;

    const [player1, player2] = match.players;

    // Decision rule:
    // 1. More correct answers wins
    // 2. If tied, lower total response time wins
    let winnerId: string | null = null;
    let isTie = false;

    if (player1.score > player2.score) {
      winnerId = player1.userId;
    } else if (player2.score > player1.score) {
      winnerId = player2.userId;
    } else {
      // Tie breaker by time
      if (player1.totalResponseTimeMs < player2.totalResponseTimeMs) {
        winnerId = player1.userId;
      } else if (player2.totalResponseTimeMs < player1.totalResponseTimeMs) {
        winnerId = player2.userId;
      } else {
        isTie = true;
      }
    }

    // Award XP
    for (const player of match.players) {
      const isWinner = player.userId === winnerId;
      const bonusXp = isWinner ? 100 : isTie ? 50 : 0;

      // Base question XP: 10 per ranked correct answer + difficulty XP
      let questionXp = 0;
      const playerAnswers = match.answers.filter((a) => a.userId === player.userId && a.isCorrect);

      for (const a of playerAnswers) {
        const sq = match.questionSet.setQuestions[a.questionIndex];
        const diff = sq ? sq.question.difficulty : 'MEDIUM';
        questionXp += XpPolicy.calculateQuestionXp('RANKED', diff);
      }

      const totalXp = bonusXp + questionXp;

      if (totalXp > 0) {
        await XpService.getInstance().awardXp({
          userId: player.userId,
          amount: totalXp,
          sourceType: 'RANKED',
          sourceId: match.id,
          idempotencyKey: `pvp:match:${match.id}:user:${player.userId}`,
          description: isWinner
            ? `Ranked PvP Victory (${player.score}/10)`
            : isTie
              ? `Ranked PvP Tie (${player.score}/10)`
              : `Ranked PvP Match Completion (${player.score}/10)`,
        });
      }

      await prisma.pvpMatchPlayer.update({
        where: { matchId_userId: { matchId, userId: player.userId } },
        data: {
          isWinner,
          xpAwarded: totalXp,
        },
      });
    }

    return await prisma.pvpMatch.update({
      where: { id: matchId },
      data: {
        status: 'COMPLETED',
        winnerId,
        isTie,
        endedAt: new Date(),
      },
      include: {
        players: {
          include: {
            user: { include: { profile: true } },
          },
        },
      },
    });
  }

  /**
   * Updates player connection status (AFK / Disconnected).
   */
  public async setPlayerConnection(matchId: string, userId: string, status: 'CONNECTED' | 'DISCONNECTED') {
    await prisma.pvpMatchPlayer.update({
      where: { matchId_userId: { matchId, userId } },
      data: { connectionStatus: status },
    });
  }
}

export const pvpMatchService = PvpMatchService.getInstance();
