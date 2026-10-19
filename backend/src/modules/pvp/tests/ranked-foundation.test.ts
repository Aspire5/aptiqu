import test from 'node:test';
import assert from 'node:assert/strict';
import { calculateEloMatch, expectedScore, roundHalfAwayFromZero } from '../ranked/ranked-rating';
import { DEFAULT_RANKED_POLICY, classifyLeagueTransition, qualificationProgress, qualificationRequired, resolveLeague } from '../ranked/ranked-policy';
import { isInSeason, seasonAt, seasonBounds, seasonIdAt } from '../ranked/ranked-season-time';
import { spawnSync } from 'node:child_process';
import path from 'node:path';

const established = (rating: number) => ({ rating, careerRatedMatches: 20 });

test('equal-rated wins, defeats and draws use original pair ratings', () => {
  for (const [outcome, delta] of [['WIN', 16], ['LOSS', -16], ['DRAW', 0]] as const) {
    const result = calculateEloMatch(established(1200), established(1200), outcome);
    assert.equal(result.a.delta, delta);
    assert.equal(result.b.delta, delta === 0 ? 0 : -delta);
    assert.equal(result.a.after, 1200 + delta);
    assert.equal(result.b.after, 1200 - delta);
  }
});

test('expected wins, upsets and unequal draws have independently specified results', () => {
  const expected = calculateEloMatch(established(1600), established(1200), 'WIN');
  const upset = calculateEloMatch(established(1200), established(1600), 'WIN');
  const draw = calculateEloMatch(established(1600), established(1200), 'DRAW');
  assert.equal(expected.a.delta, 3);
  assert.equal(upset.a.delta, 29);
  assert.equal(draw.a.delta, -13);
  assert.equal(draw.b.delta, 13);
  assert.ok(Math.abs(expectedScore(1600, 1200) - 10 / 11) < 1e-12);
  assert.ok(expectedScore(2000, 1200) > expectedScore(1600, 1200));
});

test('provisional K changes after the twentieth lifetime game, including mixed K', () => {
  const mixed = calculateEloMatch({ rating: 1200, careerRatedMatches: 19 }, established(1200), 'WIN');
  assert.equal(mixed.a.k, 64);
  assert.equal(mixed.a.delta, 32);
  assert.equal(mixed.b.delta, -16);
  assert.equal(calculateEloMatch(established(1200), established(1200), 'WIN').a.k, 32);
  assert.equal(calculateEloMatch({ rating: 1200, careerRatedMatches: 0 }, { rating: 1200, careerRatedMatches: 0 }, 'LOSS').a.delta, -32);
});

test('rounding is half away from zero, supports zero gains and does not impose a rating floor', () => {
  assert.deepEqual([0, .49, .5, 1.5, -.49, -.5, -1.5].map(roundHalfAwayFromZero), [0, 0, 1, 2, 0, -1, -2]);
  assert.equal(roundHalfAwayFromZero(0.49999999999999994), 0);
  assert.equal(roundHalfAwayFromZero(-0.49999999999999994), 0);
  assert.equal(roundHalfAwayFromZero(0.5000000000000001), 1);
  assert.equal(roundHalfAwayFromZero(-0.5000000000000001), -1);
  assert.equal(calculateEloMatch(established(3000), established(0), 'WIN').a.delta, 0);
  assert.equal(calculateEloMatch(established(1), established(1), 'LOSS').a.after, -15);
  for (const value of [NaN, Infinity, -Infinity]) assert.throws(() => roundHalfAwayFromZero(value));
  assert.throws(() => calculateEloMatch(established(1200.2), established(1200), 'WIN'));
  assert.throws(() => calculateEloMatch({ rating: 1200, careerRatedMatches: -1 }, established(1200), 'WIN'));
});

test('many balanced games conserve established-player Elo with no participation rewards', () => {
  let a = 1200, b = 1200;
  for (let i = 0; i < 1000; i++) {
    const result = calculateEloMatch(established(a), established(b), i % 2 === 0 ? 'WIN' : 'LOSS');
    a = result.a.after; b = result.b.after;
    assert.equal(a + b, 2400);
    assert.ok(Math.abs(a - 1200) <= 32);
  }
});

test('all league edges are exact and Unranked is independent of numeric rating', () => {
  for (const [rating, league] of [[-20, 'BRONZE'], [999, 'BRONZE'], [1000, 'SILVER'], [1199, 'SILVER'], [1200, 'GOLD'], [1449, 'GOLD'], [1450, 'PLATINUM'], [1699, 'PLATINUM'], [1700, 'DIAMOND']] as const) {
    assert.equal(resolveLeague(rating, true), league);
    assert.equal(resolveLeague(rating, false), 'UNRANKED');
  }
  assert.equal(classifyLeagueTransition('UNRANKED', 'GOLD'), 'PLACEMENT_COMPLETE');
  assert.equal(classifyLeagueTransition('GOLD', 'PLATINUM'), 'PROMOTION');
  assert.equal(classifyLeagueTransition('DIAMOND', 'GOLD'), 'DEMOTION');
  assert.equal(classifyLeagueTransition('GOLD', 'GOLD'), 'NONE');
  assert.equal(classifyLeagueTransition('GOLD', 'UNRANKED'), 'NONE');
});

test('qualification proposals and policy values are centralized and configurable', () => {
  assert.equal(qualificationRequired(0), 10);
  assert.equal(qualificationRequired(8), 3);
  assert.equal(qualificationRequired(40), 3);
  assert.deepEqual(qualificationProgress(2, 3), { completed: 2, required: 3, remaining: 1, qualified: false });
  assert.equal(qualificationProgress(3, 3).qualified, true);
  assert.equal(qualificationProgress(20, 3).completed, 3);
  const policy = { ...DEFAULT_RANKED_POLICY, initialQualification: 5, establishedK: 16, thresholds: { ...DEFAULT_RANKED_POLICY.thresholds, DIAMOND: 1800 } };
  assert.equal(qualificationRequired(0, policy), 5);
  assert.equal(resolveLeague(1700, true, policy), 'PLATINUM');
  assert.equal(calculateEloMatch(established(1200), established(1200), 'WIN', policy).a.delta, 8);
  assert.throws(() => qualificationProgress(0, 0));
  assert.throws(() => resolveLeague(1200, true, { ...policy, thresholds: { ...policy.thresholds, GOLD: 900 } }));
});

test('calendar has natural February/leap/30/31-day months and exact UTC boundaries', () => {
  for (const [id, days, start, end] of [
    ['2026-02', 28, '2026-01-31T18:30:00.000Z', '2026-02-28T18:30:00.000Z'],
    ['2028-02', 29, '2028-01-31T18:30:00.000Z', '2028-02-29T18:30:00.000Z'],
    ['2026-11', 30, '2026-10-31T18:30:00.000Z', '2026-11-30T18:30:00.000Z'],
    ['2026-10', 31, '2026-09-30T18:30:00.000Z', '2026-10-31T18:30:00.000Z'],
    ['2026-12', 31, '2026-11-30T18:30:00.000Z', '2026-12-31T18:30:00.000Z'],
  ] as const) {
    const season = seasonBounds(id);
    assert.equal(season.startsAt.toISOString(), start);
    assert.equal(season.endsAt.toISOString(), end);
    assert.equal((season.endsAt.getTime() - season.startsAt.getTime()) / 86400000, days);
    assert.equal(seasonAt(season.endsAt).startsAt.getTime(), season.endsAt.getTime());
  }
  assert.equal(seasonIdAt(new Date('2026-12-31T18:30:00Z')), '2027-01');
  assert.equal((seasonBounds('2100-02').endsAt.getTime() - seasonBounds('2100-02').startsAt.getTime()) / 86400000, 28);
});

test('membership is half open and admission ownership does not depend on completion time', () => {
  const october = seasonBounds('2026-10');
  const boundary = october.endsAt.getTime();
  assert.equal(seasonIdAt(new Date(boundary - 1)), '2026-10');
  assert.equal(seasonIdAt(new Date(boundary)), '2026-11');
  assert.equal(seasonIdAt(new Date(boundary + 1)), '2026-11');
  assert.equal(isInSeason(new Date(boundary - 1), october), true);
  assert.equal(isInSeason(new Date(boundary), october), false);
  assert.equal(isInSeason(new Date(boundary + 1), october), false);
  const admitted = seasonAt(new Date(boundary - 1));
  assert.equal(admitted.id, '2026-10'); // Retain this identity; do not derive it again at completion.
  for (const id of ['2026-00', '2026-13', '26-10', '1960-01']) assert.throws(() => seasonBounds(id));
  assert.throws(() => seasonAt(new Date(NaN)));
});

test('calendar results are identical in isolated machine-timezone contexts; parent configuration is unchanged', () => {
  const original = process.env.TZ;
  const modulePath = path.resolve(__dirname, '../ranked/ranked-season-time.ts');
  const script = `const m=require(${JSON.stringify(modulePath)});process.stdout.write(JSON.stringify(m.seasonAt(new Date('2026-10-31T18:30:00Z'))));`;
  const results = ['UTC', 'America/New_York', 'Asia/Tokyo'].map(TZ => {
    const result = spawnSync(process.execPath, ['--import', 'tsx', '-e', script], { cwd: process.cwd(), env: { ...process.env, TZ }, encoding: 'utf8' });
    assert.equal(result.status, 0, result.stderr);
    return result.stdout;
  });
  assert.equal(new Set(results).size, 1);
  assert.equal(process.env.TZ, original);
});
