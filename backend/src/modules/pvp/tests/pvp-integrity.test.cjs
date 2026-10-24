const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { fixture, matchId, users, outsider } = require('./pvp-test-fixture.cjs');

test('active REST/reconnect DTOs recursively whitelist public fields and only the current question', async () => {
  const f = fixture();
  const result = await f.service.getMatchSnapshot(matchId, users[0]);
  const encoded = JSON.stringify(result);
  for (const forbidden of ['DO_NOT_LEAK', 'SECRET_SOLUTION', 'PRIVATE_', 'correctAnswer', 'isCorrect', 'questionSet', 'answers', 'googleId', 'email']) assert.ok(!encoded.includes(forbidden), forbidden);
  assert.equal(result.question.id, 'q0');
  assert.equal(result.question.options.length, 2);
  assert.equal(result.ownAnswer, null);
  assert.equal(result.roundResult, null);
  assert.equal(result.players.length, 2);
  await assert.rejects(f.service.getMatchSnapshot(matchId, outsider), error => error.status === 403);
});

test('receipt time controls scoring, duplicate submissions keep first answer and ACK data', async () => {
  const f = fixture();
  f.setTime(f.now() + 2500);
  const [a, duplicate] = await Promise.all([f.answer(users[0], { responseTimeMs: 0 }), f.answer(users[0], { selectedOptionId: 'A', responseTimeMs: 60000 })]);
  assert.equal(a.answer.responseTimeMs, 2500);
  assert.equal(duplicate.isDuplicate, true);
  assert.equal(duplicate.answer.selectedOptionId, 'B');
  assert.equal(f.state().match.answers.length, 1);
  assert.equal(f.state().match.players[0].score, 1);
  assert.equal(f.state().match.players[0].totalResponseTimeMs, 2500);
  assert.ok(f.locks.every(([sql]) => sql.includes('FOR UPDATE')));
});

test('authorization, option/index/timing/deadline failures cannot write match state', async () => {
  for (const extra of [{ userId: outsider }, { questionIndex: -1 }, { questionIndex: 0.5 }, { questionIndex: 1 }, { selectedOptionId: 'Z' }, { receivedAt: new Date(NaN) }, { receivedAt: new Date('2020-01-01') }]) {
    const f = fixture();
    await assert.rejects(f.answer(users[0], extra));
    assert.equal(f.state().writes, 0);
  }
  const f = fixture();
  f.setTime(f.now() + 60000);
  await assert.rejects(f.answer(), error => error.code === 'ROUND_DEADLINE_PASSED');
  assert.equal(f.state().writes, 0);
  await assert.rejects(f.service.setPlayerConnection(matchId, outsider, 'CONNECTED'), error => error.status === 403);
  assert.equal(f.state().writes, 0);
});

test('missing answers use full timeout, equal no-answer scores/time remain the existing draw', async () => {
  const f = fixture();
  assert.equal(await f.service.closeQuestionRound(matchId, 0), null);
  f.setTime(f.now() + 60000);
  const [closed, duplicate] = await Promise.all([f.service.closeQuestionRound(matchId, 0), f.service.closeQuestionRound(matchId, 0)]);
  assert.equal(closed.status, 'QUESTION_TRANSITION');
  assert.equal(duplicate, null);
  assert.equal(f.state().match.answers.length, 2);
  assert.deepEqual(f.state().match.players.map(p => p.totalResponseTimeMs), [60000, 60000]);
  const snapshot = await f.service.getMatchSnapshot(matchId, users[0]);
  assert.equal(snapshot.roundResult.correctAnswer, 'B');
  assert.equal(snapshot.roundResult.explanation, 'SECRET_SOLUTION_0');
  assert.ok(!JSON.stringify(snapshot).includes('SECRET_SOLUTION_1'));
  f.state().match.currentQuestionIndex = 9;
  const final = await f.service.finalizeMatch(matchId);
  assert.equal(final.isTie, true);
  assert.deepEqual(f.state().match.players.map(p => p.totalResponseTimeMs), [600000, 600000]);
  assert.deepEqual(f.state().match.players.map(p => p.xpAwarded), [50, 50]);
});

test('answer/timeout race closes once, stale callbacks cannot advance/reset a later round', async () => {
  const f = fixture();
  f.setTime(f.now() + 59000);
  await f.answer(users[0]);
  f.setTime(f.now() + 1000);
  await Promise.all([f.answer(users[1]).catch(error => assert.equal(error.code, 'ROUND_DEADLINE_PASSED')), f.service.closeQuestionRound(matchId, 0)]);
  assert.equal(f.state().match.players[0].score, 1);
  assert.equal(f.state().match.players[1].score, 0);
  assert.equal(await f.service.startQuestionRound(matchId, 1), null); // Persisted transition is not due yet.
  f.setTime(f.now() + 3000);
  const next = await f.service.startQuestionRound(matchId, 1);
  assert.equal(next.currentQuestionIndex, 1);
  const deadline = next.currentQuestionDeadline.getTime();
  assert.equal(await f.service.startQuestionRound(matchId, 1), null);
  assert.equal(await f.service.closeQuestionRound(matchId, 0), null);
  assert.equal(f.state().match.currentQuestionDeadline.getTime(), deadline);
  const duplicate = await f.answer(users[0]);
  assert.equal(duplicate.isDuplicate, true); // Recover a lost first-round ACK without resubmitting.
  assert.equal(f.state().match.answers.length, 2);
});

test('both answers close early, selection acknowledgements restore after reconnect', async () => {
  const f = fixture();
  f.setTime(f.now() + 1000);
  await f.answer(users[0], { selectedOptionId: 'A' });
  const own = await f.service.getMatchSnapshot(matchId, users[0]);
  assert.equal(own.ownAnswer.selectedOptionId, 'A');
  assert.equal(own.roundResult, null);
  const other = await f.service.getMatchSnapshot(matchId, users[1]);
  assert.equal(other.ownAnswer, null);
  assert.ok(!JSON.stringify(other).includes('selectedOptionId'));
  await f.answer(users[1]);
  const [closed, duplicate] = await Promise.all([f.service.closeQuestionRound(matchId, 0), f.service.closeQuestionRound(matchId, 0)]);
  assert.equal(closed.status, 'QUESTION_TRANSITION');
  assert.equal(duplicate, null);
});

test('completion preserves correct-count/total-time rules, awards existing XP once and recovers absolute progress', async () => {
  const f = fixture();
  await assert.rejects(f.service.finalizeMatch(matchId), error => error.code === 'MATCH_NOT_FINISHED');
  f.state().match.status = 'QUESTION_TRANSITION';
  f.state().match.currentQuestionIndex = 9;
  f.state().match.answers = users.flatMap((userId, player) => Array.from({ length: 10 }, (_, questionIndex) => ({
    matchId, userId, questionIndex, isCorrect: questionIndex === 0, isLate: false, responseTimeMs: player === 0 ? 1000 : 2000,
  })));
  const results = await Promise.all([f.service.finalizeMatch(matchId), f.service.finalizeMatch(matchId), f.service.finalizeMatch(matchId)]);
  assert.ok(results.every(result => result.winnerId === users[0]));
  assert.equal(f.state().awards.size, 2);
  assert.deepEqual(f.state().match.players.map(p => p.xpAwarded), [115, 15]); // 100 victory + 15 EASY ranked solve.
  const snapshot = await f.service.getMatchSnapshot(matchId, users[0]);
  assert.equal(snapshot.winnerId, users[0]);
  assert.equal(snapshot.players[0].xpAwarded, 115);
  assert.equal(snapshot.xp.total, 1115);
  assert.equal(snapshot.xp.earned, 0);
  const before = JSON.stringify(snapshot.players);
  await f.service.setPlayerConnection(matchId, users[0], 'DISCONNECTED');
  assert.equal(JSON.stringify((await f.service.getMatchSnapshot(matchId, users[0])).players), before);
});

test('existing XP/outcome transaction failure rolls back and can retry; no Elo is written', async () => {
  const f = fixture();
  f.state().match.status = 'QUESTION_TRANSITION'; f.state().match.currentQuestionIndex = 9;
  f.failAward(users[1]);
  await assert.rejects(f.service.finalizeMatch(matchId), /Injected award failure/);
  assert.equal(f.state().match.status, 'QUESTION_TRANSITION');
  assert.equal(f.state().awards.size, 0);
  assert.equal(f.state().progress.get(users[0]), 1000);
  f.failAward(undefined);
  await f.service.finalizeMatch(matchId);
  assert.equal(f.state().awards.size, 2);
  assert.equal(f.state().match.status, 'COMPLETED');
});

test('existing REST match route selects the public snapshot and validates identity/ID', async () => {
  const f = fixture();
  const { PvpController } = f.load(path.join(__dirname, '../pvp.controller.ts'));
  const response = () => ({ code: 0, headers: {}, status(code) { this.code = code; return this; }, setHeader(k, v) { this.headers[k] = v; }, json(body) { this.body = body; } });
  let res = response();
  await PvpController.getMatch({ params: { matchId }, userId: users[0] }, res);
  assert.equal(res.code, 200);
  assert.equal(res.headers['Cache-Control'], 'private, no-store');
  assert.equal(res.body.data.question.id, 'q0');
  assert.ok(!JSON.stringify(res.body).includes('SECRET_SOLUTION'));
  res = response();
  await PvpController.getMatch({ params: { matchId: 'invalid' }, userId: users[0] }, res);
  assert.equal(res.code, 400);
  res = response();
  await PvpController.getMatch({ params: { matchId }, userId: outsider }, res);
  assert.equal(res.code, 403);
});

test('more correct answers win even when the correct player has slower total response time', async () => {
  const f = fixture();
  f.state().match.status = 'QUESTION_TRANSITION'; f.state().match.currentQuestionIndex = 9;
  f.state().match.answers = users.flatMap((userId, player) => Array.from({ length: 10 }, (_, questionIndex) => ({
    userId, questionIndex, isCorrect: questionIndex < (player === 0 ? 2 : 1), isLate: false, responseTimeMs: player === 0 ? 50000 : 1000,
  })));
  const result = await f.service.finalizeMatch(matchId);
  assert.equal(result.winnerId, users[0]);
});

test('XP unique failure inside a caller-owned transaction propagates instead of reading outside it', async () => {
  const f = fixture();
  const { XpService } = f.load(path.join(__dirname, '../../xp/xp.service.ts'));
  const xp = new XpService();
  xp.lockProgress = async () => { throw Object.assign(new Error('Injected constraint'), { code: 'P2002' }); };
  let externalReads = 0;
  f.db.userProgress.findUnique = async () => { externalReads++; };
  await assert.rejects(xp.awardXp({ userId: users[0], amount: 15, sourceType: 'RANKED', idempotencyKey: 'test' }, f.db), error => error.code === 'P2002');
  assert.equal(externalReads, 0);
});


test('arena identities expose public levels, keep XP balances private and share identical question content', async () => {
  const f = fixture();
  f.state().match.players[0].user.progress = { totalXp: 80 };
  f.state().match.players[1].user.progress = { totalXp: 200 };
  const first = await f.service.getMatchSnapshot(matchId, users[0]);
  const second = await f.service.getMatchSnapshot(matchId, users[1]);
  assert.equal(first.players[0].level, 3);
  assert.equal(first.players[1].level, 5);
  assert.deepEqual(first.question, second.question);
  assert.equal(first.roundResult, null);
  assert.equal(second.roundResult, null);
  for (const player of first.players) {
    assert.ok(!Object.hasOwn(player, 'progress'));
    assert.ok(!Object.hasOwn(player, 'totalXp'));
    assert.ok(!Object.hasOwn(player, 'selectedOptionId'));
    assert.ok(!Object.hasOwn(player, 'isCorrect'));
  }
});
