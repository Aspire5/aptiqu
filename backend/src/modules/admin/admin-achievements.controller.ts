import { Request, Response } from 'express';
import { Prisma } from '@prisma/client';
import { z } from 'zod';
import { prisma } from '../../config/prisma';
import { achievementInput, achievementUpdate, achievementOptions } from '../achievements/achievement.rules';
import { achievementAnalyticsQuery } from '../achievements/achievement.analytics';
const listing = z.object({ page: z.coerce.number().int().min(1).max(1000000).default(1),
  limit: z.coerce.number().int().min(1).max(50).default(20),
  search: z.string().max(120).default(''), status: z.enum(['ACTIVE', 'ARCHIVED', 'ALL']).default('ALL') });
const idInput = z.string().uuid();
const versionInput = z.object({ version: z.number().int().positive() }).strict();
function fail(res: Response, error: unknown) {
  if (error instanceof z.ZodError) return res.status(400).json({ success: false, error: error.issues.map(i => i.message).join('; ') });
  if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2025') return res.status(404).json({ success: false, error: 'Achievement no longer exists.' });
  console.error('[Achievements]', error);
  return res.status(500).json({ success: false, error: 'Unable to manage achievements. Please try again.' });
}
export class AdminAchievementsController {
  static options(_req: Request, res: Response) { res.json({ success: true, data: achievementOptions }); }
  static async list(req: Request, res: Response) {
    try {
      const q = listing.parse(req.query);
      const result = await prisma.$queryRaw<{ payload: unknown }[]>(achievementAnalyticsQuery(q.page, q.limit, q.search, q.status));
      res.json({ success: true, data: result[0].payload });
    } catch (error) { fail(res, error); }
  }
  static async create(req: Request, res: Response) {
    try { const data = achievementInput.parse(req.body); res.status(201).json({ success: true, data: await prisma.achievement.create({ data }) }); }
    catch (error) { fail(res, error); }
  }
  static async update(req: Request, res: Response) {
    try {
      const id = idInput.parse(req.params.id); const { version, ...data } = achievementUpdate.parse(req.body);
      const result = await prisma.achievement.updateMany({ where: { id, version, deletedAt: null }, data: { ...data, version: { increment: 1 } } });
      if (!result.count) return res.status(409).json({ success: false, error: 'Achievement changed, was archived, or was deleted. Refresh before editing.' });
      res.json({ success: true });
    } catch (error) { fail(res, error); }
  }
  static async remove(req: Request, res: Response) {
    try {
      const id = idInput.parse(req.params.id); const { version } = versionInput.parse(req.body);
      const hard = z.enum(['true', 'false']).default('false').parse(req.query.hard);
      const result = hard === 'true' ? await prisma.achievement.deleteMany({ where: { id, version } })
        : await prisma.achievement.updateMany({ where: { id, version, deletedAt: null }, data: { deletedAt: new Date(), isActive: false, version: { increment: 1 } } });
      if (!result.count) return res.status(409).json({ success: false, error: 'Achievement changed or no longer exists. Refresh before deleting.' });
      res.json({ success: true });
    } catch (error) { fail(res, error); }
  }
  static async restore(req: Request, res: Response) {
    try {
      const id = idInput.parse(req.params.id); const { version } = versionInput.parse(req.body);
      const result = await prisma.achievement.updateMany({ where: { id, version, deletedAt: { not: null } }, data: { deletedAt: null, isActive: false, version: { increment: 1 } } });
      if (!result.count) return res.status(409).json({ success: false, error: 'Achievement changed or is not archived. Refresh first.' });
      res.json({ success: true });
    } catch (error) { fail(res, error); }
  }
}
