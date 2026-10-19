import type { Prisma } from '@prisma/client';
import { z } from 'zod';
import { PvpError } from '../pvp.errors';

const questionSchema = z.object({
  id: z.string().min(1), prompt: z.string().min(1), difficulty: z.enum(['EASY', 'MEDIUM', 'HARD']),
  pattern: z.string().nullable(), pyq: z.string().nullable(),
  options: z.array(z.object({ id: z.string().min(1), text: z.string() })).min(2),
  correctAnswer: z.string().min(1), explanation: z.string(), method: z.string(),
});
export type MatchQuestion = z.infer<typeof questionSchema>;
const snapshotSchema = z.object({ version: z.literal(1), questions: z.array(questionSchema).length(10) }).strict();
export function freezeQuestions(questions: unknown[]): Prisma.InputJsonObject {
  const snapshot = snapshotSchema.parse({ version: 1, questions });
  if (new Set(snapshot.questions.map(q => q.id)).size !== 10) throw new PvpError('Invalid question set.', 'INVALID_QUESTION_SET');
  for (const q of snapshot.questions) {
    const ids = q.options.map(o => o.id.trim().toUpperCase());
    if (new Set(ids).size !== ids.length || !ids.includes(q.correctAnswer.trim().toUpperCase())) throw new PvpError('Invalid question options.', 'INVALID_QUESTION_SET');
  }
  return snapshot;
}
export function matchQuestions(match: { questionSnapshot?: Prisma.JsonValue; ratingMode?: string; questionSet: { setQuestions: { question: unknown }[] } }): MatchQuestion[] {
  if (match.questionSnapshot != null) return snapshotSchema.parse(match.questionSnapshot).questions;
  if (match.ratingMode === 'RATED') throw new PvpError('Frozen questions unavailable.', 'INVALID_MATCH_STATE');
  // Old, unrated history predates immutable snapshots; never invent historical versions.
  return match.questionSet.setQuestions.map(q => questionSchema.parse(q.question));
}
