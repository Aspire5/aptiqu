import { Router, Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { authenticateJwt, AuthenticatedRequest } from '../../middleware/auth.middleware';
import { prisma } from '../../config/prisma';
import { friendsService, membership, publicUser, publicUserSelect } from './friends.service';
import { duelsService } from './duels.service';
import { socialTransport } from './social.transport';
const router = Router(); router.use(authenticateJwt);
router.use(async (req: AuthenticatedRequest, res, next) => {
  try {
    const user = await prisma.user.findFirst({ where: { id: req.userId, isRegistrationComplete: true }, select: { id: true } });
    if (!user) { res.status(403).json({ success: false, message: 'Complete registration to use Friends.' }); return; }
    next();
  } catch (error) { next(error); }
});
const uuid = z.string().uuid().transform(s => s.toLowerCase());
const page = z.object({ cursor: uuid.optional(), q: z.string().trim().max(254).default('') });
const handle = (fn: (user: string, req: Request) => Promise<unknown>) => async (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
  try {
    if (!req.userId) { res.status(401).json({ success: false }); return; }
    const result = await fn(req.userId, req); res.json({ success: true, data: result ?? null });
  } catch (error) {
    if (error instanceof z.ZodError) { res.status(400).json({ success: false, message: 'Invalid social request.' }); return; }
    next(error);
  }
};
router.get('/friends', handle((u, r) => { const q = page.parse(r.query); return friendsService.list(u, q.cursor, q.q.normalize('NFKC').toLowerCase()); }));
router.get('/search', handle((u, r) => { const q = page.parse(r.query); if (q.q.length < 1) return Promise.resolve({ items: [], nextCursor: null }); return friendsService.search(u, q.q.normalize('NFKC').toLowerCase()); }));
router.get('/profiles/:id', handle(async (u, r) => { await socialTransport.limit(u, 'profile', 60, 60); return friendsService.profile(u, uuid.parse(r.params.id)); }));
router.get('/profiles/:id/activity', handle(async (u, r) => {
  await socialTransport.limit(u, 'profile', 60, 60);
  const { month } = z.object({ month: z.string().regex(/^20\d{2}-(0[1-9]|1[0-2])$/) }).parse(r.query);
  return friendsService.activity(uuid.parse(r.params.id), month);
}));
router.post('/friends/:id/invite', handle((u, r) => friendsService.invite(u, uuid.parse(r.params.id))));
router.delete('/friends/:id', handle((u, r) => friendsService.remove(u, uuid.parse(r.params.id))));
router.post('/friend-invitations/:id/respond', handle((u, r) => { const input = z.object({ accept: z.boolean(), version: z.string().datetime() }).strict().parse(r.body); return friendsService.respond(u, uuid.parse(r.params.id), input.accept, input.version); }));
router.get('/inbox', handle(async u => {
  const [friends, duels, seats] = await prisma.$transaction([
    prisma.friendship.findMany({ where: { ...membership(u), status: 'PENDING', senderId: { not: u } },
      include: { sender: { select: publicUserSelect } }, orderBy: { updatedAt: 'desc' }, take: 200 }),
    prisma.friendlyDuel.findMany({ where: { recipientId: u, status: 'PENDING', expiresAt: { gt: new Date() } },
      include: { requester: { select: publicUserSelect } }, orderBy: { expiresAt: 'asc' }, take: 1 }),
    prisma.friendlyDuelSeat.findUnique({ where: { userId: u } }),
  ]);
  return { friends: friends.map(f => ({ id: f.id, version: f.updatedAt.toISOString(), key: `${f.id}:${f.updatedAt.toISOString()}`, sender: publicUser(f.sender) })),
    duels: duels.map(d => ({ id: d.id, requester: publicUser(d.requester), expiresAt: d.expiresAt,
      remainingMs: Math.max(0, d.expiresAt.getTime() - Date.now()), smartPicks: d.smartPicks, timerEnabled: d.timerEnabled })),
    activeDuelId: seats?.duelId ?? null };
}));
router.post('/duels', handle((u, r) => {
  const input = z.object({ targetId: uuid, requestKey: uuid, subtopicIds: z.array(z.string().min(1).max(120)).max(500).default([]),
    smartPicks: z.boolean().default(false), timerEnabled: z.boolean().default(false) }).strict().parse(r.body);
  return duelsService.invite(u, input.targetId, input);
}));
router.get('/duels/:id', handle((u, r) => duelsService.get(u, uuid.parse(r.params.id))));
router.post('/duels/:id/respond', handle((u, r) => duelsService.respond(u, uuid.parse(r.params.id), z.object({ action: z.enum(['accept', 'reject', 'cancel']) }).strict().parse(r.body).action)));
router.post('/duels/:id/leave', handle((u, r) => duelsService.abandon(u, uuid.parse(r.params.id))));
export default router;
