import { Prisma } from '@prisma/client';
import { prisma } from '../../../config/prisma';
import { questionGenerationService } from '../../ai/services/question-generation.service';
import { LiveCurriculumService } from '../../curriculum/services/live-curriculum.service';

export function shuffle<T>(items: T[]): T[] {
  const result = [...items];
  for (let i = result.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [result[i], result[j]] = [result[j], result[i]];
  }
  return result;
}

export class PracticeSelectionService {
  public async selectQuestionsForPractice(userId: string, subtopicIds: string[], count = 10, smartPicks = false): Promise<any[]> {
    if (count !== 10) throw new Error('Practice sessions require exactly 10 questions.');
    const universe = await LiveCurriculumService.getAllLiveCurriculumUniverse();
    const liveIds = new Set(universe.flatMap(t => t.subtopics.map(s => s.id)));
    if (!subtopicIds.length || subtopicIds.some(id => !liveIds.has(id))) {
      throw new Error('Choose available subtopics for this session.');
    }
    const selected: any[] = [];
    const choose = async (ids: string[], limit: number, unseen: boolean, pattern?: string) => {
      if (limit <= 0) return [];
      // Randomize in the database before LIMIT: every eligible question can be drawn.
      // Allocated practice questions count as seen even if a session was abandoned.
      const rows = await prisma.$queryRaw<Array<{ id: string }>>(Prisma.sql`
        SELECT q.id FROM learning.questions q
        JOIN learning.subtopics st ON st.id = q.subtopic_id
        JOIN learning.topics t ON t.id = q.topic_id
        JOIN learning.subjects s ON s.id = q.subject_id
        WHERE q.status = 'PUBLISHED' AND st.is_active AND t.is_active AND s.is_active
          AND q.subtopic_id IN (${Prisma.join(ids)})
          ${pattern ? Prisma.sql`AND q.pattern = ${pattern}` : Prisma.empty}
          ${selected.length ? Prisma.sql`AND q.id NOT IN (${Prisma.join(selected.map(q => q.id))})` : Prisma.empty}
          ${unseen ? Prisma.sql`AND NOT EXISTS (SELECT 1 FROM learning.user_question_progress p WHERE p.question_id = q.id AND p.user_id = ${userId}::uuid)
            AND NOT EXISTS (SELECT 1 FROM learning.question_attempts a WHERE a.question_id = q.id AND a.user_id = ${userId}::uuid)
            AND NOT EXISTS (SELECT 1 FROM learning.practice_session_questions pq JOIN learning.practice_sessions ps ON ps.id = pq.session_id WHERE pq.question_id = q.id AND ps.user_id = ${userId}::uuid)
            AND NOT EXISTS (SELECT 1 FROM learning.pvp_match_answers pa WHERE pa.question_id = q.id AND pa.user_id = ${userId}::uuid)` : Prisma.empty}
        ORDER BY random() LIMIT ${limit}
      `);
      return prisma.question.findMany({ where: { id: { in: rows.map(r => r.id) } } });
    };
    if (smartPicks) {
      // Include lesson and PvP evidence as well as practice; replays never
      // write user progress and therefore cannot bias weakness estimates.
      const progress = await prisma.$queryRaw<Array<{subtopicId: string; pattern: string | null; timesSeen: number; timesCorrect: number}>>(Prisma.sql`
        WITH performance AS (
          SELECT question_id, times_seen AS seen, times_correct AS correct FROM learning.user_question_progress WHERE user_id = ${userId}::uuid
          UNION ALL
          SELECT question_id, 1, CASE WHEN is_correct THEN 1 ELSE 0 END FROM learning.question_attempts WHERE user_id = ${userId}::uuid
          UNION ALL
          SELECT question_id, 1, CASE WHEN is_correct THEN 1 ELSE 0 END FROM learning.pvp_match_answers WHERE user_id = ${userId}::uuid
        )
        SELECT q.subtopic_id AS "subtopicId", q.pattern, SUM(p.seen)::int AS "timesSeen", SUM(p.correct)::int AS "timesCorrect"
        FROM performance p JOIN learning.questions q ON q.id = p.question_id
        WHERE q.subtopic_id IN (${Prisma.join(subtopicIds)})
        GROUP BY q.subtopic_id, q.pattern
      `);
      const groups = new Map<string, { subtopicId: string; pattern: string | null; seen: number; missed: number }>();
      for (const p of progress) {
        const key = JSON.stringify([p.subtopicId, p.pattern]);
        const g = groups.get(key) || { subtopicId: p.subtopicId, pattern: p.pattern, seen: 0, missed: 0 };
        g.seen += p.timesSeen;
        g.missed += Math.max(0, p.timesSeen - p.timesCorrect);
        groups.set(key, g);
      }
      const weak = [...groups.values()].filter(g => g.missed > 0).sort((a, b) => b.missed / b.seen - a.missed / a.seen);
      // Bound generation latency to one focused batch. Never invent an untaught pattern.
      let generated = false;
      for (const g of weak) {
        if (selected.length >= 6) break;
        const needed = Math.min(3, 6 - selected.length);
        let matches = await choose([g.subtopicId], needed, true, g.pattern || undefined);
        if (!matches.length && g.pattern && !generated) {
          generated = true;
          try {
            matches = await questionGenerationService.generateQuestionsForSubtopic(g.subtopicId, needed, g.pattern);
          } catch (error) {
            console.warn('[Practice] Focused generation unavailable; using existing in-scope inventory.', error);
          }
        }
        if (!matches.length) matches = await choose([g.subtopicId], needed, false, g.pattern || undefined);
        selected.push(...matches.filter(q => !selected.some(s => s.id === q.id)).slice(0, needed));
      }
    }
    selected.push(...await choose(subtopicIds, count - selected.length, true));
    selected.push(...await choose(subtopicIds, count - selected.length, false));
    if (selected.length !== count) {
      throw new Error('This selection needs at least 10 available questions. Choose more subtopics and try again.');
    }
    return shuffle(selected);
  }
}
export const practiceSelectionService = new PracticeSelectionService();
