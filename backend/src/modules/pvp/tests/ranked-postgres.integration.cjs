// Opt-in only. No dotenv, app bootstrap, schema setup, migrations or cleanup.
// Requires a separately authorized disposable DB with reviewed SQL already applied.
const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { randomUUID } = require('node:crypto');
const { loader } = require('./pvp-test-fixture.cjs');

const enabled = process.env.RANKED_ALLOW_DATABASE_TESTS === 'true';
test('Ranked PostgreSQL atomicity, independent-connection races, restart and constraints', { skip: !enabled, timeout: 60000 }, async t => {
  const rawUrl = process.env.RANKED_TEST_DATABASE_URL;
  assert.ok(rawUrl, 'A dedicated test URL is required; DATABASE_URL is never used.');
  const url = new URL(rawUrl);
  assert.match(url.pathname, /^\/aptiqu_ranked_test(?:_[a-z0-9_]+)?$/i, 'Use a disposable AptiQu ranked test database.');
  assert.ok(['localhost', '127.0.0.1', '[::1]'].includes(url.hostname), 'Tests are restricted to an explicitly provided isolated local database.');
  const { PrismaClient } = require('@prisma/client');
  const db = new PrismaClient({ datasources: { db: { url: rawUrl } } });
  const peer = new PrismaClient({ datasources: { db: { url: rawUrl } } });
  try {
  let tick = Date.now();
  const load = loader({
    '../../../config/prisma': { prisma: db }, '../../config/prisma': { prisma: db },
    '../../ai/services/pvp-set-generation.service': { pvpSetGenerationService: { generatePvpQuestionSet: async () => { throw new Error('Test fixture missing'); } } },
    '../../social/friends.service': { lockUsers: async (tx, ids) => {
      // Load the production mutex, without social/Home application dependencies.
      const { lockUsers } = load(path.join(__dirname, '../../social/user-lock.ts'));
      return lockUsers(tx, ids);
    } },
  });
  const { seasonAt } = load(path.join(__dirname, '../ranked/ranked-season-time.ts'));
  const { PvpMatchService } = load(path.join(__dirname, '../services/pvp-match.service.ts'));
  const { RankedSeasonService } = load(path.join(__dirname, '../ranked/ranked-season.service.ts'));
  const { rankedTransaction } = load(path.join(__dirname, '../ranked/ranked-transaction.ts'));
  const [{ now }] = await db.$queryRaw`SELECT date_trunc('milliseconds',clock_timestamp()) AS now`;
  const [zone] = await db.$queryRaw`SHOW TIMEZONE`;
  assert.equal(Object.values(zone)[0], 'UTC', 'Keep the test DB timezone UTC; the suite never changes it.');
  tick = +now;
  const launchSeason = seasonAt(now).id;
  const activation = () => ({ enabled: true, launchSeason });
  const runtime = () => ({ reads: true, skillMatchmaking: true });
  const service = new PvpMatchService(db, () => new Date(tick), activation, runtime);
  const other = new PvpMatchService(peer, () => new Date(tick), activation, runtime);
  const setId = process.env.RANKED_TEST_SET_ID;
  assert.ok(setId, 'Supply an existing valid 10-question set in this disposable test DB.');
  const set = await db.pvpQuestionSet.findUniqueOrThrow({ where: { id: setId }, include: { setQuestions: { include: { question: true }, orderBy: { sequence: 'asc' } } } });
  assert.equal(set.setQuestions.length, 10);
  service.selectPvPSetForPlayers = async () => set;
  other.selectPvPSetForPlayers = async () => set;
  const { RankedEligibilityService } = load(path.join(__dirname, '../ranked/ranked-eligibility.service.ts'));
  const eligibility = new RankedEligibilityService(db, activation, runtime);
  await rankedTransaction(db, tx => new RankedSeasonService(db, activation).ensureCalendar(tx, now));
  async function claimFor(a, b) {
    const id=randomUUID();
    const candidates=await Promise.all([eligibility.inspect(a,1),eligibility.inspect(b,1)]);
    const entries=candidates.map(candidate=>({...candidate,token:randomUUID(),joinedAt:+now,expiresAt:+now+120000,state:'CLAIMED',claimId:id}));
    // Controlled claim fixtures isolate actual DB admission/settlement behavior;
    // the Redis Lua protocol has a separate opt-in integration suite.
    return {id,a:entries[0],b:entries[1],isActive:()=>true};
  }
  async function pair() {
    const users = [randomUUID(), randomUUID()];
    for (const id of users) await db.user.create({ data: { id, email: `${id}@ranked-test.invalid`, googleId: `ranked-test:${id}`, isRegistrationComplete: true } });
    const match = await service.createMatch(...users, await claimFor(...users));
    return { users, match };
  }
  async function finishRounds(match) {
    tick = +match.transitionDeadline;
    for (let index = 0; index < 10; index++) {
      const started = await service.startQuestionRound(match.id, index);
      assert.ok(started);
      const question = set.setQuestions[index].question;
      tick += 100;
      for (const player of match.players) await service.submitAnswer({ matchId: match.id, userId: player.userId, questionIndex: index, selectedOptionId: question.correctAnswer });
      await service.closeQuestionRound(match.id, index);
      tick += 3000;
    }
  }
    await t.test('two connections cannot settle the same match twice', async () => {
      const { match, users } = await pair();
      await finishRounds(match);
      const result = await Promise.all([service.finalizeMatch(match.id), other.finalizeMatch(match.id)]);
      assert.ok(result.every(m => m.status === 'COMPLETED'));
      assert.equal(await db.rankedMatchSettlement.count({ where: { matchId: match.id } }), 1);
      assert.equal(await db.rankedRatingChange.count({ where: { matchId: match.id } }), 2);
      assert.equal(await db.xpEvent.count({ where: { sourceId: match.id, sourceType: 'RANKED' } }), 2);
      const standings = await db.rankedPlayerSeason.findMany({ where: { seasonId: match.seasonId, userId: { in: users } } });
      assert.deepEqual(standings.map(s => s.played), [1, 1]);
      const snapshot=await service.getMatchSnapshot(match.id,users[0]);
      assert.match(snapshot.rating.eventId,/^[0-9a-f-]{36}$/i);assert.equal(snapshot.settlementId,match.id);
      assert.deepEqual(standings.map(s => s.rating), [1200, 1200]); // Equal simultaneous draws.
    });
    await t.test('independent admissions sharing one player cannot create two active matches', async () => {
      const ids = [randomUUID(), randomUUID(), randomUUID()];
      for (const id of ids) await db.user.create({ data: { id, email: `${id}@ranked-test.invalid`, googleId: `ranked-test:${id}`, isRegistrationComplete: true } });
      const [one,two]=await Promise.all([claimFor(ids[0],ids[1]),claimFor(ids[0],ids[2])]);
      const attempts = await Promise.allSettled([service.createMatch(ids[0], ids[1],one), other.createMatch(ids[0], ids[2],two)]);
      assert.equal(attempts.filter(r => r.status === 'fulfilled').length, 1);
      assert.equal(attempts.filter(r => r.status === 'rejected').length, 1);
      assert.equal(await db.pvpMatch.count({ where: { players: { some: { userId: ids[0] } } } }), 1);
    });
    await t.test('lost admission commit ACK resolves the original server claim ID without a duplicate match', async () => {
      const ids=[randomUUID(),randomUUID()];
      for(const id of ids)await db.user.create({data:{id,email:`${id}@ranked-test.invalid`,googleId:`ranked-test:${id}`,isRegistrationComplete:true}});
      const claim=await claimFor(...ids),original=db.$transaction.bind(db);let lose=true;
      db.$transaction=async(...args)=>{const result=await original(...args);if(lose){lose=false;throw new Error('Lost admission ACK');}return result;};
      try{const match=await service.createMatch(...ids,claim);assert.equal(match.id,claim.id);assert.equal(await db.pvpMatch.count({where:{id:claim.id}}),1);}
      finally{db.$transaction=original;}
    });
    await t.test('failure after real XP/projection writes rolls back the full transaction', async () => {
      const { match, users } = await pair(); await finishRounds(match);
      const { XpService } = load(path.join(__dirname, '../../xp/xp.service.ts'));
      const xp = XpService.getInstance();
      const original = xp.awardXp.bind(xp);
      let calls = 0;
      xp.awardXp = async (...args) => { const result = await original(...args); if (++calls === 2) throw new Error('Injected post-XP failure'); return result; };
      try { await assert.rejects(service.finalizeMatch(match.id), /Injected post-XP failure/); }
      finally { xp.awardXp = original; }
      assert.equal((await db.pvpMatch.findUniqueOrThrow({ where: { id: match.id } })).status, 'QUESTION_TRANSITION');
      assert.equal(await db.rankedMatchSettlement.count({ where: { matchId: match.id } }), 0);
      assert.equal(await db.rankedRatingChange.count({ where: { matchId: match.id } }), 0);
      assert.equal(await db.xpEvent.count({ where: { sourceId: match.id } }), 0);
      const standings = await db.rankedPlayerSeason.findMany({ where: { seasonId: match.seasonId, userId: { in: users } } });
      assert.ok(standings.every(s => s.played === 0));
      await service.finalizeMatch(match.id);
    });
    await t.test('fresh service recovers persisted deadlines and duplicate timeout evidence safely', async () => {
      const { match } = await pair();
      tick = +match.transitionDeadline;
      const started = await service.recoverMatch(match.id);
      assert.equal(started.status, 'QUESTION_ACTIVE');
      const deadline = +started.currentQuestionDeadline;
      tick = deadline;
      const restarted = new PvpMatchService(peer, () => new Date(tick), activation, runtime);
      await Promise.all([restarted.recoverMatch(match.id), service.recoverMatch(match.id)]);
      assert.equal(await db.pvpMatchAnswer.count({ where: { matchId: match.id, questionIndex: 0 } }), 2);
      const recovered = await service.getMatchDetails(match.id);
      assert.equal(recovered.status, 'QUESTION_TRANSITION');
      assert.equal(+recovered.currentQuestionDeadline, deadline);
    });
    await t.test('SQL rejects immutable ledger changes, impossible counts, and admission mutations', async () => {
      const { match } = await pair(); await finishRounds(match); await service.finalizeMatch(match.id);
      await assert.rejects(db.rankedRatingChange.updateMany({ where: { matchId: match.id }, data: { delta: 100 } }));
      await assert.rejects(db.pvpMatch.update({ where: { id: match.id }, data: { seasonId: null } }));
      await assert.rejects(db.rankedPlayerSeason.updateMany({ where: { lastMatchId: match.id }, data: { wins: 100 } }));
      const live = await pair();
      const answer = await db.pvpMatchAnswer.findFirst({ where: { matchId: live.match.id } });
      assert.equal(answer, null);
      // A rated terminal update without its settlement must fail at COMMIT.
      await assert.rejects(db.$transaction(tx => tx.pvpMatch.update({ where: { id: live.match.id }, data: { status: 'COMPLETED', endedAt: new Date() } })));
    });
    await t.test('real leaderboard keyset SQL returns current ordinals and hides unqualified rows', async () => {
      const { RankedQueryService } = load(path.join(__dirname, '../ranked/ranked-query.service.ts'));
      const { RankedReadCache } = load(path.join(__dirname, '../ranked/ranked-cache.ts'));
      const { RankedCursor } = load(path.join(__dirname, '../ranked/ranked-cursor.ts'));
      const query = new RankedQueryService(db,runtime,new RankedReadCache(),new RankedCursor(()=>'integration-test-only-secret-0123456789'));
      const ids=[randomUUID(),randomUUID(),randomUUID(),randomUUID()].sort();
      for(let i=0;i<ids.length;i++){
        await db.user.create({data:{id:ids[i],email:`${ids[i]}@ranked-test.invalid`,googleId:`ranked-test:${ids[i]}`,isRegistrationComplete:true}});
        const rating=i===2?1700:i===3?1800:1500;
        await db.rankedPlayerSeason.create({data:{seasonId:launchSeason,userId:ids[i],seedRating:1200,rating,peakRating:rating,
          qualifiedPeakRating:i===3?null:rating,careerRatedBefore:0,placementsRequired:10,played:i===3?1:10,wins:i===3?1:10,version:i===3?1:10,qualifiedAt:i===3?null:now}});
      }
      const page=await query.leaderboard(ids[0],{limit:2});
      assert.deepEqual(page.entries.map(e=>e.userId),[ids[2],ids[0]]);
      assert.deepEqual(page.entries.map(e=>e.position),[1,2]);
      await db.rankedPlayerSeason.update({where:{seasonId_userId:{seasonId:launchSeason,userId:ids[3]}},data:{played:10,wins:10,version:10,qualifiedAt:now,qualifiedPeakRating:1800}});
      const next=await query.leaderboard(ids[0],{limit:2,cursor:page.nextCursor});
      assert.equal(next.entries[0].userId,ids[1]);assert.equal(next.entries[0].position,4);
      const me=await query.me(ids[1],{fresh:true});assert.equal(me.standing.position,4);assert.equal(me.standing.league,'PLATINUM');
      assert.ok(!JSON.stringify(page).includes('@ranked-test.invalid'));
    });
    await t.test('archival SQL freezes qualified ordinal, peak and unqualified history', async () => {
      // An empty older season is created through production calendar persistence;
      // isolated archive rows are fixtures, not a legacy data backfill.
      const previousId = seasonAt(new Date(+seasonAt(now).startsAt - 1)).id;
      const seasons = new RankedSeasonService(db, () => ({ enabled: true, launchSeason: previousId }));
      await rankedTransaction(db, tx => seasons.ensureCalendar(tx, now));
      const ids = [randomUUID(), randomUUID(), randomUUID()].sort();
      for (let i = 0; i < ids.length; i++) {
        const userId = ids[i];
        await db.user.create({ data: { id: userId, email: `${userId}@ranked-test.invalid`, googleId: `ranked-test:${userId}`, isRegistrationComplete: true } });
        await db.rankedPlayerSeason.create({ data: { seasonId: previousId, userId, seedRating: 1200, rating: i < 2 ? 1500 : 1300, peakRating: 1600,
          qualifiedPeakRating: i < 2 ? 1550 : null, careerRatedBefore: 10, placementsRequired: 3,
          played: i < 2 ? 3 : 1, wins: i < 2 ? 3 : 1, version: i < 2 ? 3 : 1, qualifiedAt: i < 2 ? now : null } });
      }
      assert.equal(await seasons.finalize(previousId), true);
      const rows = await db.rankedPlayerSeason.findMany({ where: { seasonId: previousId, userId: { in: ids } }, orderBy: { userId: 'asc' } });
      assert.deepEqual(rows.map(r => r.finalPosition), [1, 2, null]);
      assert.deepEqual(rows.map(r => r.finalLeague), ['PLATINUM', 'PLATINUM', 'UNRANKED']);
      assert.deepEqual(rows.map(r => r.finalPeakRating), [1550, 1550, null]);
      await assert.rejects(db.rankedPlayerSeason.updateMany({ where: { seasonId: previousId }, data: { rating: 1700 } }));
      assert.equal(await seasons.finalize(previousId), true);
      const { RankedQueryService } = load(path.join(__dirname, '../ranked/ranked-query.service.ts'));
      const { RankedReadCache } = load(path.join(__dirname, '../ranked/ranked-cache.ts'));
      const { RankedCursor } = load(path.join(__dirname, '../ranked/ranked-cursor.ts'));
      const reads=new RankedQueryService(db,runtime,new RankedReadCache(),new RankedCursor(()=>'integration-test-only-secret-0123456789'));
      const board=await reads.leaderboard(ids[0],{seasonId:previousId,limit:25});
      assert.deepEqual(board.entries.map(e=>e.position),[1,2]);
      const history=await reads.seasons(ids[0],{limit:12});assert.equal(history.entries[0].standing.position,1);
    });
  } finally {
    await Promise.allSettled([db.$disconnect(), peer.$disconnect()]);
  }
});
