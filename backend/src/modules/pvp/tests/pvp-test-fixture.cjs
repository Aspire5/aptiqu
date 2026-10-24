// Inert dependency injection via the same VM/transpile pattern as Practice tests.
// No app bootstrap, environment file, Redis connection or database client is loaded.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require('typescript');

const matchId = '00000000-0000-4000-8000-000000000010';
const users = ['00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000002'];
const outsider = '00000000-0000-4000-8000-000000000003';

function loader(deps, globals = {}) {
  const cache = new Map();
  function load(file) {
    file = path.resolve(file);
    if (cache.has(file)) return cache.get(file);
    const exports = {};
    cache.set(file, exports);
    const code = ts.transpileModule(fs.readFileSync(file, 'utf8'), { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 } }).outputText;
    vm.runInNewContext(code, { exports, require: id => {
      if (Object.hasOwn(deps, id)) return deps[id];
      if (id.startsWith('.')) {
        const target = path.resolve(path.dirname(file), id);
        return load(fs.existsSync(target + '.ts') ? target + '.ts' : target);
      }
      return require(id);
    }, console, Date, Set, Map, Math, Promise, Buffer, URL, process: { env: {} }, setTimeout, clearTimeout, setInterval, clearInterval, ...globals }, { filename: file });
    return exports;
  }
  return load;
}

function fixture() {
  let now = Date.parse('2026-10-19T12:00:00Z');
  let store = {
    match: {
      id: matchId, status: 'QUESTION_ACTIVE', ratingMode: 'LEGACY_UNRATED', seasonId: null, stateVersion: 0, questionSnapshot: null, settlement: null, createdAt: new Date(now), hardExpiresAt: new Date(now + 900000), transitionDeadline: null, totalQuestions: 10, currentQuestionIndex: 0,
      currentQuestionStartedAt: new Date(now), currentQuestionDeadline: new Date(now + 60000),
      startedAt: new Date(now), endedAt: null, winnerId: null, isTie: false,
      players: users.map(userId => ({ userId, score: 0, totalResponseTimeMs: 0, connectionStatus: 'CONNECTED', xpAwarded: 0, isWinner: false,
        user: { email: 'DO_NOT_LEAK', googleId: 'DO_NOT_LEAK', profile: { firstName: 'Learner', avatarUrl: null, dob: 'DO_NOT_LEAK' } } })),
      questionSet: { setQuestions: Array.from({ length: 10 }, (_, index) => ({ question: {
        id: `q${index}`, prompt: `Question ${index}`, difficulty: 'EASY', pattern: null, pyq: null,
        correctAnswer: 'B', explanation: `SECRET_SOLUTION_${index}`, method: 'PRIVATE_METHOD', hints: ['PRIVATE_HINT'], internal: 'DO_NOT_LEAK',
        options: [{ id: 'A', text: '3', isCorrect: false, internal: 'DO_NOT_LEAK' }, { id: 'B', text: '4', isCorrect: true }],
      } })) }, answers: [],
    },
    policies: new Map(), seasons: new Map(), standings: new Map(), changes: [], settlements: new Map(), failLedger: false,
    progress: new Map(users.map(userId => [userId, 1000])), awards: new Map(), writes: 0,
  };
  let tail = Promise.resolve();
  let failUser;
  const locks = [];
  const db = {
    questionPreparation:{count:async()=>0},
    $queryRaw: async (strings, ...values) => { locks.push([strings.join('?'), values]); return strings.join('?').includes('clock_timestamp') ? [{ now: new Date(now) }] : [{ id: matchId }]; },
    pvpMatch: {
      count: async () => store.unresolved ?? 0,
      findUnique: async ({ where }) => where.id === matchId ? structuredClone(store.match) : null,
      update: async ({ data }) => { store.writes++; for (const [key, value] of Object.entries(data)) store.match[key] = value && typeof value === 'object' && 'increment' in value ? (store.match[key] ?? 0) + value.increment : value; return structuredClone(store.match); },
    },
    pvpMatchPlayer: { update: async ({ where, data }) => {
      const player = store.match.players.find(p => p.userId === where.matchId_userId.userId);
      if (!player) throw new Error('Missing participant');
      store.writes++;
      for (const [key, value] of Object.entries(data)) player[key] = value && typeof value === 'object' && 'increment' in value ? player[key] + value.increment : value;
      return structuredClone(player);
    } },
    pvpMatchAnswer: { create: async ({ data }) => {
      if (store.match.answers.some(a => a.userId === data.userId && a.questionIndex === data.questionIndex)) throw Object.assign(new Error('Unique answer'), { code: 'P2002' });
      store.writes++;
      const answer = { id: `answer-${store.match.answers.length}`, ...data };
      store.match.answers.push(answer);
      return structuredClone(answer);
    } },
    userProgress: { findUniqueOrThrow: async ({ where }) => ({ userId: where.userId, totalXp: BigInt(store.progress.get(where.userId) ?? 0) }), findUnique: async ({ where }) => ({ userId: where.userId, totalXp: BigInt(store.progress.get(where.userId) ?? 0) }) },
    rankedPolicy: {
      findUnique: async ({ where }) => structuredClone(store.policies.get(where.id) ?? null),
      create: async ({ data }) => { store.policies.set(data.id, structuredClone(data)); return structuredClone(data); },
      upsert: async ({ where, create }) => {
        if (!store.policies.has(where.id)) store.policies.set(where.id, structuredClone(create));
        return structuredClone(store.policies.get(where.id));
      },
    },
    rankedSeason: {
      create: async ({ data }) => { const row = { settlementState: 'OPEN', finalizedAt: null, ...structuredClone(data) }; store.seasons.set(data.id, row); return structuredClone(row); },
      findUnique: async ({ where, include }) => {
        const row = store.seasons.get(where.id);
        return row ? structuredClone({ ...row, ...(include?.policy ? { policy: store.policies.get(row.policyId) } : {}) }) : null;
      },
      findUniqueOrThrow: async input => { const row = await db.rankedSeason.findUnique(input); if (!row) throw new Error('Missing season'); return row; },
      findMany: async ({ where }) => [...store.seasons.values()].filter(s => (!where.id?.gte || s.id >= where.id.gte) && (!where.startsAt?.lt || s.startsAt < where.startsAt.lt) && (!where.endsAt?.lte || s.endsAt <= where.endsAt.lte) && (!where.settlementState?.not || s.settlementState !== where.settlementState.not)).map(s => structuredClone(s)),
      upsert: async ({ where, create }) => {
        if (!store.seasons.has(where.id)) store.seasons.set(where.id, { settlementState: 'OPEN', finalizedAt: null, ...structuredClone(create) });
        return structuredClone(store.seasons.get(where.id));
      },
      update: async ({ where, data }) => { Object.assign(store.seasons.get(where.id), data); return structuredClone(store.seasons.get(where.id)); },
    },
    rankedPlayerSeason: {
      findUnique: async ({ where }) => structuredClone(store.standings.get(where.seasonId_userId.seasonId + ':' + where.seasonId_userId.userId) ?? null),
      findUniqueOrThrow: async input => { const row = await db.rankedPlayerSeason.findUnique(input); if (!row) throw new Error('Missing standing'); return row; },
      findFirst: async ({ where }) => structuredClone([...store.standings.values()].filter(s => s.userId === where.userId && s.seasonId < where.seasonId.lt).sort((a, b) => b.seasonId.localeCompare(a.seasonId))[0] ?? null),
      create: async ({ data }) => {
        const row = { played: 0, wins: 0, losses: 0, draws: 0, qualifiedAt: null, qualifiedPeakRating: null, version: 0, finalizedAt: null, ...structuredClone(data) };
        const key = row.seasonId + ':' + row.userId;
        if (store.standings.has(key)) throw new Error('Duplicate standing');
        store.standings.set(key, row); return structuredClone(row);
      },
      update: async ({ where, data }) => { const key = where.seasonId_userId.seasonId + ':' + where.seasonId_userId.userId; Object.assign(store.standings.get(key), data); return structuredClone(store.standings.get(key)); },
      count: async ({ where }) => [...store.standings.values()].filter(s => s.seasonId === where.seasonId && s.qualifiedAt !== null).length,
    },
    rankedMatchSettlement: { create: async ({ data }) => {
      if (store.settlements.has(data.matchId)) throw new Error('Duplicate settlement');
      store.settlements.set(data.matchId, structuredClone(data)); store.match.settlement = structuredClone(data); return data;
    } },
    rankedRatingChange: { create: async ({ data }) => {
      if (store.failLedger && store.changes.length === 1) throw new Error('Injected ledger failure');
      store.changes.push(structuredClone(data)); return data;
    } },
    $transaction: async fn => {
      // Deterministic transaction/mutex model, not a claim of a PostgreSQL integration test.
      const previous = tail;
      let release;
      tail = new Promise(resolve => { release = resolve; });
      await previous;
      const before = structuredClone(store);
      try { return await fn(db); }
      catch (error) { store = before; throw error; }
      finally { release(); }
    },
  };
  const xp = {
    lockProgress: async () => {},
    awardXp: async (input, tx) => {
      if (tx !== db) throw new Error('XP must share the existing match transaction');
      if (input.userId === failUser) throw new Error('Injected award failure');
      if (store.awards.has(input.idempotencyKey)) return;
      store.awards.set(input.idempotencyKey, input.amount);
      store.progress.set(input.userId, store.progress.get(input.userId) + input.amount);
    },
  };
  const deps = {
    '../../../config/prisma': { prisma: db }, '../../config/prisma': { prisma: db },
    '../../social/friends.service': { lockUsers: async () => {} },
    '../../ai/services/pvp-set-generation.service': { pvpSetGenerationService: {} },
    '../../xp/xp.service': { XpService: { getInstance: () => xp } },
  };
  const load = loader(deps);
  const { PvpMatchService } = load(path.join(__dirname, '../services/pvp-match.service.ts'));
  const service = new PvpMatchService(db, () => new Date(now));
  return { service, db, load, locks, state: () => store, setTime: value => { now = value; }, now: () => now,
    failAward: user => { failUser = user; },
    answer: (userId = users[0], extra = {}) => service.submitAnswer({ matchId, userId, questionIndex: 0, selectedOptionId: 'B', ...extra }),
  };
}
module.exports = { fixture, loader, matchId, users, outsider };
