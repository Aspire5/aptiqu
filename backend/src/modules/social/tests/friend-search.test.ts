import test from 'node:test';
import assert from 'node:assert/strict';
import { friendSearchQuery } from '../friend-search';
import { friendsService } from '../friends.service';
import { prisma } from '../../../config/prisma';
import { socialTransport } from '../social.transport';

test('search binds literal wildcards and caps ranked results at ten in SQL', () => {
  const query = friendSearchQuery('00000000-0000-4000-8000-000000000001', "a_%' OR TRUE--");
  assert.match(query.sql, /LIMIT 10/);
  assert.match(query.sql, /lower\(u.email\)/);
  assert.match(query.sql, /ORDER BY CASE/);
  assert.equal(query.sql.includes('OR TRUE--'), false);
  assert.ok(query.values.includes("%a\\_\\%' OR TRUE--%"));
});

test('search preserves relevance order, relation version, acceptance date and friend-only presence', async () => {
  const raw = prisma.$queryRaw, transaction = prisma.$transaction;
  const users = prisma.user.findMany, friendships = prisma.friendship.findMany;
  const limit = socialTransport.limit, presence = socialTransport.presence;
  try {
    prisma.$queryRaw = (async () => [{id: 'b'}, {id: 'a'}]) as any;
    prisma.user.findMany = (async () => []) as any;
    prisma.friendship.findMany = (async () => []) as any;
    socialTransport.limit = async () => {};
    socialTransport.presence = async ids => {
      assert.deepEqual(ids, ['a']);
      return [{id: 'a', online: true}];
    };
    prisma.$transaction = (async () => [[{id: 'a'}, {id: 'b'}], [
      {id: 'link-a', lowId: 'self', highId: 'a', status: 'ACCEPTED', updatedAt: new Date('2026-10-01T00:00:00Z')},
      {id: 'link-b', lowId: 'b', highId: 'self', status: 'PENDING', senderId: 'b', updatedAt: new Date('2026-10-02T00:00:00Z')},
    ]]) as any;
    const result = await friendsService.search('self', 'learner');
    assert.deepEqual(result.items.map(r => r.id), ['b', 'a']);
    assert.equal(result.items[0].relation, 'INCOMING');
    assert.equal(result.items[0].friendshipVersion, '2026-10-02T00:00:00.000Z');
    assert.equal(result.items[0].online, null);
    assert.equal(result.items[1].friendsSince, '2026-10-01T00:00:00.000Z');
    assert.equal(result.items[1].online, true);
    assert.equal(result.nextCursor, null);
    assert.equal('email' in result.items[0], false);
  } finally {
    prisma.$queryRaw = raw; prisma.$transaction = transaction;
    prisma.user.findMany = users; prisma.friendship.findMany = friendships;
    socialTransport.limit = limit; socialTransport.presence = presence;
  }
});
