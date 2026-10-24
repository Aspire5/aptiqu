import { XpPolicy } from '../xp/xp.policy';
import type { Prisma } from '@prisma/client';
import { PvpError } from './pvp.errors';
import { MatchQuestion, matchQuestions } from './ranked/ranked-questions';
import { z } from 'zod';

export const pvpMatchInclude = {
  players: { include: { user: { select: { profile: { select: { firstName: true, avatarUrl: true } }, progress: { select: { totalXp: true } } } } } },
  questionSet: { include: { setQuestions: { include: { question: true }, orderBy: { sequence: 'asc' as const } } } },
  answers: true,
  settlement: { select: { disposition: true, resultSnapshot: true, settledAt: true, changes: { select: { id: true, userId: true, seasonVersionAfter: true } } } },
} satisfies Prisma.PvpMatchInclude;
export type PvpInternalMatch = Prisma.PvpMatchGetPayload<{ include: typeof pvpMatchInclude }>;
type Question = MatchQuestion;

export function publicQuestion(question: Question) {
  return {
    id: question.id, prompt: question.prompt, difficulty: question.difficulty,
    pattern: question.sourceType === 'LUNA' && /mental/i.test(question.pattern ?? '') ? null : question.pattern, pyq: question.pyq,
    options: Array.isArray(question.options) ? question.options.flatMap(value => {
      if (!value || typeof value !== 'object' || Array.isArray(value)) return [];
      return typeof value.id === 'string' && typeof value.text === 'string' ? [{ id: value.id, text: value.text }] : [];
    }) : [],
  };
}

export function requireParticipant(match: PvpInternalMatch, userId: string): void {
  if (!match.players.some(player => player.userId === userId)) throw new PvpError('You are not a participant in this match.', 'FORBIDDEN_MATCH_ACCESS', 403);
}

export function publicPlayers(match: PvpInternalMatch) {
  return match.players.map(player => ({
    userId: player.userId, firstName: player.user.profile?.firstName || 'Learner',
    avatarUrl: player.user.profile?.avatarUrl ?? null,
    level: XpPolicy.getLevelFromXp(Number(player.user.progress?.totalXp ?? 0)),
    score: player.score, totalResponseTimeMs: player.totalResponseTimeMs,
    ...(match.status === 'COMPLETED' ? { isWinner: player.isWinner, xpAwarded: player.xpAwarded, isAfk: player.connectionStatus === 'DISCONNECTED' } : {}),
  }));
}

export function roundFeedback(match: PvpInternalMatch, questionIndex: number) {
  if ((match.status !== 'QUESTION_TRANSITION' && match.status !== 'COMPLETED') || questionIndex > match.currentQuestionIndex) {
    throw new PvpError('This round has not closed.', 'ROUND_NOT_CLOSED');
  }
  const question = matchQuestions(match)[questionIndex];
  if (!question) throw new PvpError('Question is unavailable.', 'QUESTION_UNAVAILABLE');
  return {
    matchId: match.id, questionIndex, stateVersion: match.stateVersion, correctAnswer: question.correctAnswer,
    explanation: question.explanation, method: question.method,
    hints:question.hints??[], alternativeExplanation:question.alternativeExplanation??null,
    estimatedTimeSeconds:question.estimatedTimeSeconds??null,
    scores: match.players.map(player => {
      const answer = match.answers.find(a => a.questionIndex === questionIndex && a.userId === player.userId);
      return { userId: player.userId, score: player.score, selectedOptionId: answer?.selectedOptionId ?? null, isCorrect: answer?.isCorrect ?? false, isLate: answer?.isLate ?? false };
    }),
  };
}

/** Explicit public DTO: no raw user, question-set, opponent-answer or solution objects. */
export function serializeMatch(match: PvpInternalMatch, userId: string, now: Date) {
  requireParticipant(match, userId);
  const completed = match.status === 'COMPLETED';
  const question = (match.status === 'QUESTION_ACTIVE' || match.status === 'QUESTION_TRANSITION') ? matchQuestions(match)[match.currentQuestionIndex] : null;
  const ownAnswer = match.answers.find(a => a.userId === userId && a.questionIndex === match.currentQuestionIndex);
  return {
    id: match.id, matchId: match.id, status: match.status, totalQuestions: match.totalQuestions,
    currentQuestionIndex: match.currentQuestionIndex, serverNow: now.toISOString(),
    deadline: match.currentQuestionDeadline?.toISOString() ?? null,
    remainingMs: match.status === 'QUESTION_ACTIVE' && match.currentQuestionDeadline ? Math.max(0, match.currentQuestionDeadline.getTime() - now.getTime()) : 0,
    startedAt: match.startedAt, endedAt: match.endedAt,
    seasonId: match.seasonId ?? null, ratingMode: match.ratingMode ?? 'LEGACY_UNRATED',
    stateVersion: match.stateVersion ?? 0, outcomeReason: match.outcomeReason ?? null,
    transitionDeadline: match.transitionDeadline?.toISOString() ?? null,
    rating: completed ? publicRatingResult(match, userId) : null,
    settlementId: match.settlement ? match.id : null, settledAt: match.settlement?.settledAt?.toISOString() ?? null,
    disposition: match.settlement?.disposition ?? (match.ratingMode === 'RATED' ? 'PENDING' : 'LEGACY_UNRATED'),
    question: question && (match.status === 'QUESTION_ACTIVE' || match.status === 'QUESTION_TRANSITION') ? publicQuestion(question) : null,
    ownAnswer: ownAnswer ? { questionIndex: ownAnswer.questionIndex, selectedOptionId: ownAnswer.selectedOptionId, acceptedAt: ownAnswer.serverReceivedAt } : null,
    roundResult: match.status === 'QUESTION_TRANSITION' ? roundFeedback(match, match.currentQuestionIndex) : null,
    players: publicPlayers(match),
    ...(completed ? { winnerId: match.winnerId, isTie: match.isTie } : {}),
  };
}

// Stored JSON is internal audit evidence. Even terminal responses whitelist only
// this participant's rating block; opponent XP balances never leave the server.
const ratingResultSchema = z.object({
  userId: z.string(), seasonId: z.string(), before: z.number().int(), delta: z.number().int(), after: z.number().int(),
  leagueBefore: z.enum(['UNRANKED','BRONZE','SILVER','GOLD','PLATINUM','DIAMOND']),
  leagueAfter: z.enum(['UNRANKED','BRONZE','SILVER','GOLD','PLATINUM','DIAMOND']),
  changeKind: z.enum(['NONE','PLACEMENT_COMPLETE','PROMOTION','DEMOTION']),
  qualification: z.object({ completed: z.number().int(), required: z.number().int(), remaining: z.number().int(), qualified: z.boolean() }),
  version: z.number().int(),
});
export function publicRatingResult(match: PvpInternalMatch, userId: string) {
  if (match.settlement?.disposition !== 'RATED') return null;
  const parsed = z.object({ ratings: z.array(ratingResultSchema) }).safeParse(match.settlement.resultSnapshot);
  const rating = parsed.success ? parsed.data.ratings.find(r => r.userId === userId) : null;
  const event = match.settlement.changes?.find(c => c.userId === userId);
  return rating ? { ...rating, eventId: event?.id ?? null, status: 'RATED', seasonVersionAfter: event?.seasonVersionAfter ?? rating.version } : null;
}
