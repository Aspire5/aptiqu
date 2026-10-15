import { randomUUID } from 'crypto';
import { Prisma } from '@prisma/client';
import { prisma } from '../../config/prisma';
import { LiveCurriculumService } from '../curriculum/services/live-curriculum.service';
import { socialError } from './social.transport';
export async function resolveDuelScope(requested: string[]) {
  const live = await LiveCurriculumService.getAllLiveCurriculumUniverse();
  const allowed = new Set(live.flatMap(t => t.subtopics.map(s => s.id)));
  const ids = requested.length ? [...new Set(requested)] : [...allowed];
  if (!ids.length || ids.some(id => !allowed.has(id))) throw socialError('Choose live subtopics for this duel.');
  return ids;
}
export async function selectDuelQuestions(a: string, b: string, scope: string[], smart: boolean) {
  const questions: { id: string; topicId: string; subjectId: string; subtopicId: string }[] = [];
  const notes: string[] = [];
  for (const [index, userId] of [a, b].entries()) {
    let topics: string[] | undefined;
    if (smart) {
      const weak = await prisma.$queryRaw<{ topicId: string }[]>(Prisma.sql`
        WITH evidence AS (
          SELECT question_id, times_seen::bigint AS seen, times_correct::bigint AS correct FROM learning.user_question_progress WHERE user_id=${userId}::uuid
          UNION ALL SELECT question_id, 1, is_correct::int FROM learning.question_attempts WHERE user_id=${userId}::uuid AND question_id IS NOT NULL
          UNION ALL SELECT question_id, 1, is_correct::int FROM learning.pvp_match_answers WHERE user_id=${userId}::uuid AND selected_option_id IS NOT NULL AND selected_option_id <> 'TIMEOUT'
          UNION ALL SELECT a.question_id, 1, a.is_correct::int FROM learning.daily_challenge_answers a
            JOIN learning.daily_challenge_participations p ON p.id=a.participation_id WHERE p.user_id=${userId}::uuid AND a.selected_option_id IS NOT NULL AND a.selected_option_id <> 'TIMEOUT'
        ) SELECT q.topic_id AS "topicId" FROM evidence e JOIN learning.questions q ON q.id=e.question_id
        WHERE q.subtopic_id IN (${Prisma.join(scope)}) GROUP BY q.topic_id
        HAVING sum(e.correct) < sum(e.seen)
        ORDER BY sum(e.correct)::float8 / NULLIF(sum(e.seen),0), sum(e.seen) DESC, q.topic_id LIMIT 5`);
      if (weak.length) topics = weak.map(t => t.topicId);
      else notes.push(`Player ${index + 1} has no recorded weak topic in this selection; their five questions use the selected live topics.`);
    }
    const pivot = randomUUID();
    for (const wrap of [false, true]) {
      const needed = (index + 1) * 5 - questions.length;
      if (!needed) break;
      const batch = await prisma.question.findMany({ where: { status: 'PUBLISHED', subtopicId: { in: scope },
        ...(topics ? { topicId: { in: topics } } : {}),
        id: { ...(wrap ? { lt: pivot } : { gte: pivot }), notIn: questions.map(q => q.id) },
        subtopic: { isActive: true }, topic: { isActive: true }, subject: { isActive: true } },
        select: { id: true, topicId: true, subjectId: true, subtopicId: true }, orderBy: { id: 'asc' }, take: needed });
      questions.push(...batch);
    }
    if (questions.length !== (index + 1) * 5) throw socialError(smart && topics
      ? 'Not enough distinct questions in the selected weak topics. Select more topics or turn AI Picks off.'
      : 'This duel needs ten distinct published questions. Choose more topics.');
  }
  // Same independently shuffled list for both participants, persisted once.
  for (let i = questions.length - 1; i > 0; i--) {
    const j = require('crypto').randomInt(i + 1); [questions[i], questions[j]] = [questions[j], questions[i]];
  }
  return { questions, notes };
}
