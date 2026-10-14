import test from 'node:test';
import assert from 'node:assert/strict';
import { homeStatsQuery, latestHomeMatchQuery } from '../home.queries';

test('Home queries bind user input rather than interpolating it into SQL', () => {
  const userId = "someone' OR true --";
  const stats = homeStatsQuery(userId, '2026-10-01T18:30:00Z', '2026-10-29T18:30:00Z');
  const match = latestHomeMatchQuery(userId);
  assert.equal(stats.sql.includes(userId), false);
  assert.equal(match.sql.includes(userId), false);
  assert.equal(stats.values.filter(value => value === userId).length, 4);
  assert.deepEqual(match.values, [userId]);
});

test('Stats aggregate the four user-scoped sources without deduplicating repeated answers', () => {
  const query = homeStatsQuery('user', 'start', 'end').sql;
  assert.equal((query.match(/UNION ALL/g) ?? []).length, 3);
  assert.equal((query.match(/WHERE [as]\.user_id = \?::uuid/g) ?? []).length, 4);
  assert.match(query, /GROUP BY GROUPING SETS/);
  assert.match(query, /a\.user_selected_option_id <> 'TIMEOUT'/);
  assert.equal((query.match(/a\.selected_option_id <> 'TIMEOUT'/g) ?? []).length, 2);
  assert.match(query, /NOT s\.is_replay/);
  assert.match(query, /NOT a\.is_late/);
  assert.match(query, /happened_at >= \?::timestamp AND happened_at < \?::timestamp/);
});
