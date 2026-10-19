const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { fixture, matchId, users } = require('./pvp-test-fixture.cjs');

async function ratedFixture() {
  const f = fixture();
  const { RankedSeasonService } = f.load(path.join(__dirname, '../ranked/ranked-season.service.ts'));
  const seasons = new RankedSeasonService(f.db, () => ({ enabled: true, launchSeason: '2026-10' }));
  const admission = await f.db.$transaction(tx => seasons.admit(tx, users));
  Object.assign(f.state().match, { ratingMode: admission.ratingMode, seasonId: admission.seasonId, seasonAssignedAt: admission.seasonAssignedAt });
  f.service.seasons.readPolicy = seasons.readPolicy;
  const { freezeQuestions } = f.load(path.join(__dirname, '../ranked/ranked-questions.ts'));
  f.state().match.questionSnapshot = freezeQuestions(f.state().match.questionSet.setQuestions.map(q => q.question));
  function finish() {
    Object.assign(f.state().match, { status: 'QUESTION_TRANSITION', currentQuestionIndex: 9, transitionDeadline: new Date(f.now() + 3000) });
    f.state().match.answers = users.flatMap((userId, player) => Array.from({ length: 10 }, (_, questionIndex) => ({
      matchId, userId, questionIndex, questionId: `q${questionIndex}`, selectedOptionId: player === 0 ? 'B' : 'A',
      isCorrect: player === 0, isLate: false, responseTimeMs: 1000, serverReceivedAt: new Date(f.now()),
    })));
  }
  return { ...f, seasons, admission, finish, standing: userId => f.state().standings.get(`${f.state().match.seasonId}:${userId}`) };
}

test('approved policy, exact IST months and lazy initial standings persist on admission', async () => {
  const f = await ratedFixture();
  assert.equal(f.admission.ratingMode, 'RATED');
  assert.equal(f.admission.seasonId, '2026-10');
  assert.equal(f.state().seasons.size, 3);
  assert.equal(f.state().seasons.get('2026-10').startsAt.toISOString(), '2026-09-30T18:30:00.000Z');
  assert.equal(f.state().seasons.get('2026-12').endsAt.toISOString(), '2026-12-31T18:30:00.000Z');
  assert.equal(f.state().standings.size, 2);
  assert.equal(f.standing(users[0]).placementsRequired, 10);
  await f.db.$transaction(tx => f.seasons.admit(tx, users));
  assert.equal(f.state().standings.size, 2);
  const before = f.state().writes;
  await f.service.getMatchSnapshot(matchId, users[0]);
  assert.equal(f.state().writes, before); // Reads never initialize a standing.
});

test('concurrent repeated completion commits two Elo changes, XP and outcome exactly once', async () => {
  const f = await ratedFixture(); f.finish();
  await Promise.all([f.service.finalizeMatch(matchId), f.service.finalizeMatch(matchId)]);
  assert.equal(f.state().match.status, 'COMPLETED');
  assert.equal(f.state().settlements.size, 1);
  assert.equal(f.state().changes.length, 2);
  assert.equal(f.state().awards.size, 1);
  assert.deepEqual(users.map(u => f.standing(u).rating), [1232, 1168]);
  assert.deepEqual(users.map(u => f.standing(u).played), [1, 1]);
  assert.equal(f.standing(users[0]).wins, 1);
  assert.equal(f.standing(users[1]).losses, 1);
  const snapshot = await f.service.getMatchSnapshot(matchId, users[0]);
  assert.equal(snapshot.rating.delta, 32);
  assert.equal(snapshot.rating.leagueAfter, 'UNRANKED');
  assert.equal(snapshot.xp.total, 1250); // 10 EASY correct +100 win.
  assert.ok(!JSON.stringify(snapshot).includes('ratings'));
  assert.equal(snapshot.rating.userId, users[0]);
});

test('failure after XP and first ledger write rolls everything back, then retries cleanly', async () => {
  const f = await ratedFixture(); f.finish(); f.state().failLedger = true;
  await assert.rejects(f.service.finalizeMatch(matchId), /Injected ledger failure/);
  assert.equal(f.state().match.status, 'QUESTION_TRANSITION');
  assert.equal(f.state().settlements.size, 0);
  assert.equal(f.state().changes.length, 0);
  assert.equal(f.state().awards.size, 0);
  assert.equal(f.state().progress.get(users[0]), 1000);
  assert.deepEqual(users.map(u => f.standing(u).rating), [1200, 1200]);
  f.state().failLedger = false;
  await f.service.finalizeMatch(matchId);
  assert.equal(f.state().changes.length, 2);
});

test('qualification uses lifetime K independently and qualified peak starts at qualification result', async () => {
  const f = await ratedFixture(); f.finish();
  Object.assign(f.standing(users[0]), { played: 2, wins: 2, careerRatedBefore: 18, placementsRequired: 3, peakRating: 1800, seedRating: 1800 });
  Object.assign(f.standing(users[1]), { played: 9, wins: 9, placementsRequired: 10 });
  await f.service.finalizeMatch(matchId);
  assert.deepEqual(f.state().changes.map(c => c.kFactor), [32, 64]);
  assert.deepEqual(users.map(u => f.standing(u).rating), [1216, 1168]);
  assert.equal(f.standing(users[0]).qualifiedPeakRating, 1216);
  assert.equal(f.standing(users[0]).peakRating, 1800);
  assert.ok(f.standing(users[0]).qualifiedAt);
  assert.equal(f.state().changes[0].changeKind, 'PLACEMENT_COMPLETE');
  assert.equal(f.state().changes[0].leagueAfter, 'GOLD');
});

test('old-season completion and later admission preserve carry rating and unfinished career qualification', async () => {
  const f = await ratedFixture(); f.finish();
  f.setTime(Date.parse('2026-10-31T18:30:00.000Z'));
  await f.service.finalizeMatch(matchId);
  assert.equal(f.state().settlements.get(matchId).seasonId, '2026-10');
  const next = await f.db.$transaction(tx => f.seasons.admit(tx, users));
  assert.equal(next.seasonId, '2026-11');
  const row = f.state().standings.get(`2026-11:${users[0]}`);
  assert.equal(row.seedSourceSeasonId, '2026-10');
  assert.equal(row.seedRating, 1232);
  assert.equal(row.careerRatedBefore, 1);
  assert.equal(row.placementsRequired, 9);
  assert.equal(row.played, 0);
});

test('database clock sampled after a season lock wait owns exact midnight admission', async () => {
  const f = await ratedFixture();
  const query = f.db.$queryRaw;
  f.setTime(Date.parse('2026-10-31T18:29:59.999Z'));
  let crossed = false;
  f.db.$queryRaw = async (strings, ...values) => {
    if (!crossed && strings.join('?').includes('FOR SHARE')) { crossed = true; f.setTime(f.now() + 1); }
    return query(strings, ...values);
  };
  const result = await f.db.$transaction(tx => f.seasons.admit(tx, users));
  assert.equal(result.seasonId, '2026-11');
  assert.equal(result.seasonAssignedAt.toISOString(), '2026-10-31T18:30:00.000Z');
});

test('immutable questions govern display, validation, feedback and XP after source edits', async () => {
  const f = await ratedFixture();
  const live = f.state().match.questionSet.setQuestions[0].question;
  Object.assign(live, { prompt: 'EDITED_PROMPT', correctAnswer: 'A', explanation: 'EDITED_SOLUTION', difficulty: 'HARD', options: [{ id: 'X', text: 'new' }, { id: 'Y', text: 'new' }] });
  const before = await f.service.getMatchSnapshot(matchId, users[0]);
  assert.equal(before.question.prompt, 'Question 0');
  assert.ok(!JSON.stringify(before).includes('SECRET_SOLUTION'));
  await f.answer(users[0]); await f.answer(users[1]);
  await f.service.closeQuestionRound(matchId, 0);
  const feedback = await f.service.getMatchSnapshot(matchId, users[0]);
  assert.equal(feedback.roundResult.correctAnswer, 'B');
  assert.equal(feedback.roundResult.explanation, 'SECRET_SOLUTION_0');
  f.finish(); await f.service.finalizeMatch(matchId);
  assert.equal(f.state().match.players[0].xpAwarded, 250);
});

test('restart recovers ready, active deadline, transition and committed completion without resetting active time', async () => {
  const f = await ratedFixture();
  Object.assign(f.state().match, { status: 'STARTING', transitionDeadline: new Date(f.now() + 3000) });
  assert.equal((await f.service.recoverMatch(matchId)).status, 'STARTING');
  f.setTime(f.now() + 3000);
  const started = await f.service.recoverMatch(matchId);
  assert.equal(started.status, 'QUESTION_ACTIVE');
  const deadline = +started.currentQuestionDeadline;
  f.setTime(f.now() + 10000);
  const recovered = await f.service.recoverMatch(matchId);
  assert.equal(+recovered.currentQuestionDeadline, deadline);
  f.setTime(deadline);
  const closed = await f.service.recoverMatch(matchId);
  assert.equal(closed.status, 'QUESTION_TRANSITION');
  assert.equal(f.state().match.answers.length, 2);
  f.setTime(f.now() + 3000);
  assert.equal((await f.service.recoverMatch(matchId)).currentQuestionIndex, 1);
  f.finish(); f.setTime(f.now() + 3000);
  await f.service.recoverMatch(matchId);
  await f.service.recoverMatch(matchId);
  assert.equal(f.state().changes.length, 2);
});

test('unrecoverable expired match voids once without XP, Elo or false draw; terminal evidence settles instead', async () => {
  const f = await ratedFixture();
  f.setTime(+f.state().match.hardExpiresAt);
  const cancelled = await f.service.recoverMatch(matchId);
  assert.equal(cancelled.status, 'CANCELLED');
  assert.equal(cancelled.outcomeReason, 'SYSTEM_VOID');
  assert.equal(cancelled.isTie, false);
  assert.equal(f.state().settlements.get(matchId).disposition, 'VOID');
  assert.equal(f.state().changes.length, 0);
  assert.equal(f.state().awards.size, 0);
  assert.equal(f.standing(users[0]).played, 0);
  await f.service.recoverMatch(matchId);
  assert.equal(f.state().settlements.size, 1);
  const complete = await ratedFixture(); complete.finish(); complete.setTime(+complete.state().match.hardExpiresAt);
  assert.equal((await complete.service.recoverMatch(matchId)).status, 'COMPLETED');
  assert.equal(complete.state().changes.length, 2);
});

test('activation off preserves legacy history and still settles already admitted rated games', async () => {
  const f = fixture();
  const result = await f.db.$transaction(tx => f.service.seasons.admit(tx, users));
  assert.equal(result.ratingMode, 'LEGACY_UNRATED');
  assert.equal(f.state().policies.size, 0);
  assert.equal(f.state().standings.size, 0);
  Object.assign(f.state().match, { status: 'COMPLETED' });
  await f.service.finalizeMatch(matchId);
  assert.equal(f.state().settlements.size, 0);
  const active = await ratedFixture(); active.finish();
  // Match service's default activation is off, but existing rated obligations remain.
  await active.service.finalizeMatch(matchId);
  assert.equal(active.state().changes.length, 2);
});

test('season archival waits for unresolved outcomes, freezes policy-specific bands and finalizes idempotently', async () => {
  const f = await ratedFixture();
  f.setTime(Date.parse('2026-10-31T18:30:00.000Z'));
  f.state().unresolved = 1;
  let writes = 0;
  f.db.$executeRaw = async () => { writes++; return 0; };
  assert.equal(await f.seasons.finalize('2026-10'), false);
  assert.equal(writes, 0);
  assert.equal(f.state().seasons.get('2026-10').settlementState, 'OPEN');
  f.state().unresolved = 0;
  assert.equal(await f.seasons.finalize('2026-10'), true);
  assert.equal(writes, 2); // SQL itself is covered by the separately gated PostgreSQL test.
  assert.equal(f.state().seasons.get('2026-10').eligibleCount, 0);
  assert.equal(await f.seasons.finalize('2026-10'), true);
  assert.equal(writes, 2);
});

test('calendar catches missed months and rejects attempts to mutate an existing policy', async () => {
  const f = await ratedFixture();
  f.setTime(Date.parse('2027-01-15T00:00:00Z'));
  await f.db.$transaction(tx => f.seasons.ensureCalendar(tx, new Date(f.now())));
  assert.equal(f.state().seasons.size, 6); // Oct through March, with no inactive-user rows.
  assert.equal(f.state().standings.size, 2);
  f.state().policies.get('ranked-v1').configHash = 'tampered';
  await assert.rejects(f.db.$transaction(tx => f.seasons.ensureCalendar(tx, new Date(f.now()))), /policy mismatch/);
});

test('known transaction rollback retries are bounded; unknown commit is reread by immutable match key', async () => {
  const f = fixture();
  const { rankedTransaction } = f.load(path.join(__dirname, '../ranked/ranked-transaction.ts'));
  let tries = 0;
  const db = { $transaction: async fn => { if (++tries < 3) throw Object.assign(new Error('serialization'), { code: 'P2034' }); return fn({}); } };
  assert.equal(await rankedTransaction(db, async () => 7), 7);
  assert.equal(tries, 3);
  tries = 0;
  await assert.rejects(rankedTransaction({ $transaction: async () => { tries++; throw new Error('unknown connection loss'); } }, async () => 7));
  assert.equal(tries, 1);
  const committed = await ratedFixture(); committed.finish();
  const original = committed.db.$transaction;
  let loseAck = true;
  committed.db.$transaction = async (...args) => {
    const value = await original(...args);
    if (loseAck) { loseAck = false; throw new Error('Lost commit ACK'); }
    return value;
  };
  await assert.rejects(committed.service.finalizeMatch(matchId), /Lost commit ACK/);
  const recovered = await committed.service.finalizeMatch(matchId);
  assert.equal(recovered.status, 'COMPLETED');
  assert.equal(committed.state().changes.length, 2);
  assert.equal(committed.state().awards.size, 1);
});

test('expired incomplete final-round evidence voids; valid results remain pending on temporary XP failure', async () => {
  const f = await ratedFixture(); f.finish(); f.state().match.answers.pop();
  f.setTime(+f.state().match.hardExpiresAt);
  assert.equal((await f.service.recoverMatch(matchId)).status, 'CANCELLED');
  assert.equal(f.state().changes.length, 0);
  const g = await ratedFixture(); g.finish(); g.setTime(+g.state().match.hardExpiresAt); g.failAward(users[0]);
  await assert.rejects(g.service.recoverMatch(matchId), /Injected award failure/);
  assert.equal(g.state().match.status, 'QUESTION_TRANSITION');
  assert.equal(g.state().settlements.size, 0);
});

test('bounded recovery worker does not overlap, advances its cursor, isolates failures and stops cleanly', async () => {
  const published = [], cursors = [];
  let release;
  const pending = new Promise(resolve => { release = resolve; });
  let calls = 0, maintenance = 0;
  const service = {
    recoveryPage: async cursor => { cursors.push(cursor); if (++calls === 1) { await pending; return Array.from({ length: 100 }, (_, i) => ({ id: `id-${i}` })); } return []; },
    recoverMatch: async id => { if (id === 'id-50') throw new Error('one bad row'); return { id }; },
    seasons: { maintain: async () => { maintenance++; } },
  };
  const load = require('./pvp-test-fixture.cjs').loader({
    '../services/pvp-match.service': { pvpMatchService: service },
    '../pvp.socket': { pvpSocketServer: {} },
  });
  const { RankedRecoveryWorker } = load(path.join(__dirname, '../ranked/ranked-worker.ts'));
  const worker = new RankedRecoveryWorker(service, async match => { published.push(match.id); });
  const first = worker.tick();
  await worker.tick();
  assert.equal(calls, 1);
  release(); await first;
  assert.equal(published.length, 99);
  assert.equal(maintenance, 1);
  await worker.tick();
  assert.deepEqual(cursors, [undefined, 'id-99']);
  assert.equal(maintenance, 1);
  await worker.stop(); await worker.tick();
  assert.equal(calls, 2);
});

test('shared user mutex sorts and deduplicates IDs while allowing FK key-share checks', async () => {
  const { loader } = require('./pvp-test-fixture.cjs');
  const { lockUsers } = loader({})(path.join(__dirname, '../../social/user-lock.ts'));
  const queries = [];
  const tx = { $queryRaw: async query => { queries.push(query); return []; } };
  await lockUsers(tx, [users[1], users[0], users[1]]);
  assert.deepEqual(queries[0].values, users);
  assert.ok(queries[0].sql.includes('ORDER BY id FOR NO KEY UPDATE'));
  await lockUsers(tx, []);
  assert.equal(queries.length, 1);
});
