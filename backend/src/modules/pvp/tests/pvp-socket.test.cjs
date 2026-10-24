const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { EventEmitter } = require('node:events');
const { loader, fixture, matchId, users } = require('./pvp-test-fixture.cjs');

function setup({ skill = false, inspect, queue } = {}) {
  const sent = [], mutations = [], timers = [], redisRemovals = [];
  class Socket extends EventEmitter {
    static OPEN = 1;
    readyState = 1;
    send(value) { sent.push({ socket: this, ...JSON.parse(value), active: server.activeMatches.has(matchId) }); }
    close() { this.readyState = 3; this.emit('close'); }
    ping() {}
    terminate() { this.close(); }
    async receive(value) {
      const raw = Buffer.from(typeof value === 'string' ? value : JSON.stringify(value));
      await Promise.all(this.listeners('message').map(listener => listener(raw)));
    }
  }
  class Wss extends EventEmitter { clients = new Set(); close() {} }
  let closed = false;
  const service = {
    submitAnswer: async input => { mutations.push(input); return { answer: { selectedOptionId: input.selectedOptionId, serverReceivedAt: input.receivedAt }, bothAnswered: false }; },
    setPlayerConnection: async (...input) => { mutations.push(input); },
    getMatchSnapshot: async (id, userId) => ({ matchId: id, status: 'COMPLETED', winnerId: users[0], isTie: false, players: [{ userId }], xp: { total: 100 } }),
    finalizeMatch: async id => { mutations.push(['complete', id]); },
    closeQuestionRound: async () => {
      if (closed) return null;
      closed = true;
      return { id: matchId, status: 'QUESTION_TRANSITION', currentQuestionIndex: 0, totalQuestions: 10,
        questionSet: fixture().state().match.questionSet, players: [], answers: [] };
    },
  };
  const schedule = (fn, delay) => { const timer = { fn, delay, cleared: false }; timers.push(timer); return timer; };
  const deps = {
    '../../config/env':{ENV:{LUNA:{maxPending:32,preparationTimeoutMs:600000}}},
    '../../config/prisma':{prisma:{questionPreparation:{findFirst:async()=>null}}},
    '../ai/luna/preparations':{ACTIVE_STATES:['QUEUED','GENERATING'],publicPreparation:value=>value},
    '../../security/trusted-peer': {trustedPeer: () => '127.0.0.1'},
    '../../security/request-policy': {takeBudget: async () => {}},
    './ranked/ranked-runtime': { rankedRuntime: () => ({ reads: skill, skillMatchmaking: skill }) },
    './ranked/ranked-eligibility.service': { rankedEligibilityService: { inspect: inspect ?? (async userId => ({ userId, rating: 1200, standingVersion: 0, seasonId: '2026-10', policyId: 'ranked-v1', ratingMode: 'RATED', capability: 1, league: 'UNRANKED' })) } },
    ws: { WebSocket: Socket, WebSocketServer: Wss },
    '../../utils/jwt': { verifyAccessToken: token => { if (!users.includes(token)) throw new Error('bad token'); return { userId: token, exp: Math.floor(Date.now()/1000)+900 }; } },
    './services/pvp-match.service': { pvpMatchService: service },
    '../lesson/services/redis.service': { redisService: { getClient: () => ({ zrem: async (...args) => { redisRemovals.push(args); } }), getIsConnected: () => true } },
  };
  if (queue) deps['./ranked/ranked-queue'] = { RedisRankedQueue: class { constructor() { return queue; } } };
  const load = loader(deps, { setTimeout: schedule, clearTimeout: timer => { if (timer) timer.cleared = true; }, setInterval: schedule, clearInterval: timer => { if (timer) timer.cleared = true; } });
  const { PvpSocketServer } = load(path.join(__dirname, '../pvp.socket.ts'));
  const server = new PvpSocketServer();
  server.init(new EventEmitter());
  async function connect(userId) {
    const ws = new Socket();
    server.wss.emit('connection', ws, { url: '/ws/pvp', headers: { host: 'localhost' } });
    if (userId) await ws.receive({ type: 'AUTH_INIT', payload: { token: userId } });
    return ws;
  }
  return { server, service, connect, sent, mutations, timers, redisRemovals, load };
}

test('unauthenticated/malformed packets cannot call match service; AUTH_INIT cannot change owner', async () => {
  const f = setup();
  const ws = await f.connect();
  const answer = { type: 'SUBMIT_ANSWER', payload: { matchId, questionIndex: 0, selectedOptionId: 'B' } };
  await ws.receive(answer);
  assert.equal(f.sent.at(-1).data.code, 'UNAUTHORIZED');
  await ws.receive({ type: 'AUTH_INIT', payload: { token: users[0] } });
  await ws.receive({ type: 'AUTH_INIT', payload: { token: users[1] } });
  assert.equal(ws.userId, users[0]);
  assert.equal(f.sent.at(-1).data.code, 'ALREADY_AUTHENTICATED');
  for (const payload of [{ ...answer.payload, questionIndex: .5 }, { ...answer.payload, matchId: 'bad' }, { ...answer.payload, selectedOptionId: {} }, { ...answer.payload, responseTimeMs: -1 }, { ...answer.payload, receivedAt: 'forged' }]) {
    await ws.receive({ ...answer, payload });
    assert.equal(f.sent.at(-1).data.code, 'INVALID_MESSAGE');
  }
  await ws.receive('null');
  await ws.receive('{');
  assert.equal(f.mutations.length, 0);
});

test('ACK contains no solution/scoring fields and uses server ingress rather than client timing', async () => {
  const f = setup();
  const ws = await f.connect(users[0]);
  await ws.receive({ type: 'SUBMIT_ANSWER', payload: { matchId, questionIndex: 0, selectedOptionId: 'B', responseTimeMs: 0 } });
  assert.equal(f.mutations.length, 1);
  assert.ok(f.mutations[0].receivedAt instanceof Date);
  assert.equal(f.mutations[0].responseTimeMs, undefined);
  const ack = f.sent.at(-1);
  assert.equal(ack.event, 'ANSWER_ACCEPTED');
  assert.equal(ack.data.matchId, matchId);
  assert.equal(ack.data.selectedOptionId, 'B');
  assert.equal(ack.data.correctAnswer, undefined);
  assert.equal(ack.data.isCorrect, undefined);
});

test('outdated close/message cannot remove replacement ownership, queue or connection state', async () => {
  const f = setup();
  const old = await f.connect(users[0]);
  old.matchId = matchId;
  f.server.matchmakingQueue.push({ userId: users[0], ws: old });
  const replacement = await f.connect(users[0]);
  old.emit('close');
  assert.equal(f.server.userSockets.get(users[0]), replacement);
  assert.equal(f.server.matchmakingQueue[0].ws, replacement);
  assert.equal(f.redisRemovals.length, 0);
  await old.receive({ type: 'SUBMIT_ANSWER', payload: { matchId, questionIndex: 0, selectedOptionId: 'B' } });
  assert.equal(f.mutations.length, 0);
  await replacement.receive({ type: 'RECONNECT_MATCH', payload: { matchId } });
  assert.equal(f.sent.at(-1).event, 'MATCH_RECONNECTED');
  assert.equal(f.sent.at(-1).data.status, 'COMPLETED');
});

test('round close callbacks publish and schedule only once; stale round callback cannot affect next round', async () => {
  const f = setup();
  await f.connect(users[0]);
  f.server.activeMatches.set(matchId, { matchId, players: users, currentQuestionIndex: 0 });
  await Promise.all([f.server.endQuestionRound(matchId, 0), f.server.endQuestionRound(matchId, 0)]);
  assert.equal(f.sent.filter(item => item.event === 'QUESTION_ENDED').length, 1);
  const transition = f.timers.at(-1);
  f.server.activeMatches.get(matchId).currentQuestionIndex = 1;
  transition.fn();
  assert.equal(f.mutations.length, 0);
});

test('completion reaches both recipients before map cleanup and a missed result can reconnect', async () => {
  const f = setup();
  const sockets = await Promise.all(users.map(user => f.connect(user)));
  f.server.activeMatches.set(matchId, { matchId, players: users, currentQuestionIndex: 9 });
  await f.server.completeMatch(matchId);
  const completed = f.sent.filter(item => item.event === 'MATCH_COMPLETED');
  assert.equal(completed.length, 2);
  assert.ok(completed.every(item => item.active));
  assert.equal(f.server.activeMatches.has(matchId), false);
  await f.server.completeMatch(matchId);
  assert.equal(f.sent.filter(item => item.event === 'MATCH_COMPLETED').length, 2);
  await sockets[0].receive({ type: 'RECONNECT_MATCH', payload: { matchId } });
  assert.equal(f.sent.at(-1).data.winnerId, users[0]);
  assert.equal(f.sent.at(-1).data.xp.total, 100);
});

test('a post-commit progress-read or socket-send failure cannot hide the result or prevent cleanup', async () => {
  const f = setup();
  const raw = fixture().state().match;
  raw.status = 'COMPLETED'; raw.winnerId = users[0];
  f.service.finalizeMatch = async () => raw;
  f.service.getMatchSnapshot = async () => { throw new Error('Injected read failure'); };
  const sockets = await Promise.all(users.map(user => f.connect(user)));
  sockets[1].send = () => { throw new Error('Injected send failure'); };
  f.server.activeMatches.set(matchId, { matchId, players: users, currentQuestionIndex: 9 });
  await f.server.completeMatch(matchId);
  const result = f.sent.find(item => item.event === 'MATCH_COMPLETED');
  assert.equal(result.data.winnerId, users[0]);
  assert.equal(result.data.xp, null);
  assert.ok(!JSON.stringify(result).includes('SECRET_SOLUTION'));
  assert.equal(f.server.activeMatches.has(matchId), false);
});

test('restart publication reconstructs a timer from persisted deadline and exposes system void as terminal', async () => {
  const f = setup();
  await f.connect(users[0]);
  const raw = fixture().state().match;
  raw.currentQuestionDeadline = new Date(Date.now() + 20000);
  await f.server.publishRecovered(raw);
  const started = f.sent.find(e => e.event === 'QUESTION_STARTED');
  assert.equal(started.data.deadline, raw.currentQuestionDeadline.toISOString());
  assert.ok(f.timers.at(-1).delay <= 20001 && f.timers.at(-1).delay > 19000);
  assert.ok(!JSON.stringify(started).includes('SECRET_SOLUTION'));
  raw.status = 'CANCELLED'; raw.outcomeReason = 'SYSTEM_VOID';
  await f.server.publishRecovered(raw);
  assert.equal(f.server.activeMatches.has(matchId), false);
  const ended = f.sent.find(e => e.event === 'MATCH_RECONNECTED');
  assert.equal(ended.data.status, 'CANCELLED');
  assert.equal(ended.data.outcomeReason, 'SYSTEM_VOID');
  assert.equal(ended.data.rating, null);
});

function fakeQueue() {
  const entries = new Map(), cancellations = [];
  let ready = false;
  return { entries, cancellations, enableClaim: () => { ready = true; },
    join: async (candidate, token) => { const old = entries.get(candidate.userId); const entry = { ...candidate, token, joinedAt: old?.joinedAt ?? 0, expiresAt: 9999999999999, state: 'QUEUED' }; entries.set(candidate.userId, entry); return { status: 'WAITING_FOR_OPPONENT', now: 0, entry }; },
    cancel: async (userId, token) => { cancellations.push({userId,token}); const e = entries.get(userId); if (!e) return {status:'LEFT_QUEUE'}; if(e.token!==token)return{status:'STALE'};if(e.state==='CLAIMED')return{status:'PAIRING'};entries.delete(userId);return{status:'LEFT_QUEUE'}; },
    claim: async () => { if (!ready || entries.size !== 2) return null; ready=false; const [a,b]=[...entries.values()];a.state=b.state='CLAIMED';return{id:matchId,a:{...a},b:{...b}}; },
    touch: async (userId, token) => ({status:'WAITING_FOR_OPPONENT',now:0,entry:entries.get(userId)}),
    renew: async () => true, finish: async claim => { for(const e of [claim.a,claim.b])if(entries.get(e.userId)?.token===e.token)entries.delete(e.userId); },
    status: reply => ({status:reply.status}),
  };
}

test('cancel fences a JOIN waiting for eligibility; a late JOIN cannot silently requeue', async () => {
  let release; const gate = new Promise(resolve => { release=resolve; });
  const queue=fakeQueue(), f=setup({skill:true,queue,inspect:async userId=>{await gate;return{userId,rating:1200};}}),ws=await f.connect(users[0]);
  const pending=ws.receive({type:'JOIN_MATCHMAKING',payload:{rankedCapability:1}});
  await ws.receive({type:'LEAVE_MATCHMAKING'});release();await pending;
  assert.equal(queue.entries.size,0);assert.equal(f.sent.at(-1).data.status,'LEFT_QUEUE');
});

test('replacement sockets retain queue ownership and an outdated close cannot cancel the valid ticket', async () => {
 const queue=fakeQueue(),f=setup({skill:true,queue}),old=await f.connect(users[0]);await old.receive({type:'JOIN_MATCHMAKING',payload:{rankedCapability:1}});const token=f.server.queueOwners.get(users[0]);
 const next=await f.connect(users[0]);old.emit('close');assert.equal(next.queueToken,token);assert.equal(f.server.queueOwners.get(users[0]),token);assert.equal(queue.cancellations.length,0);
 await next.receive({type:'LEAVE_MATCHMAKING'});assert.equal(queue.entries.size,0);
});

test('a winning claim replies PAIRING to cancellation, and Redis cleanup failure cannot hide a committed match', async () => {
 const queue=fakeQueue(),f=setup({skill:true,queue}),sockets=await Promise.all(users.map(id=>f.connect(id)));
 for(const ws of sockets)await ws.receive({type:'JOIN_MATCHMAKING',payload:{rankedCapability:1}});
 let release,entered;const gate=new Promise(resolve=>{release=resolve;}),started=new Promise(resolve=>{entered=resolve;});
 const raw=fixture().state().match;raw.status='STARTING';raw.transitionDeadline=new Date(Date.now()+3000);
 f.service.createMatch=async(a,b,claim)=>{assert.equal(claim.isActive(),true);entered();await gate;return raw;};
 queue.enableClaim();const work=f.server.searchRanked();await started;await work;
 assert.equal(f.server.claiming.size,2,'Pairing loop returns while content preparation remains active');
 await sockets[0].receive({type:'LEAVE_MATCHMAKING'});assert.equal(f.sent.at(-1).data.status,'PAIRING');
 queue.finish=async()=>{throw new Error('Redis lost after commit');};release();await Promise.all([...f.server.queueWork]);
 assert.equal(f.sent.filter(item=>item.event==='MATCH_FOUND').length,2);assert.equal(f.server.activeMatches.has(matchId),true);assert.equal(f.server.claiming.size,0);
});

test('rated search pauses on Redis failure without entering the local FIFO fallback', async () => {
 const f=setup({skill:true}),ws=await f.connect(users[0]);await ws.receive({type:'JOIN_MATCHMAKING',payload:{rankedCapability:1}});
 assert.equal(f.sent.at(-1).data.code,'QUEUE_UNAVAILABLE');assert.equal(f.server.matchmakingQueue.length,0);assert.equal(f.server.queueOwners.size,0);
});

test('expired authentication closes the socket and cannot submit another answer', async () => {
  const f = setup(); const ws = await f.connect(users[0]);
  ws.authExpiresAt = Date.now()-1;
  await ws.receive({type:'SUBMIT_ANSWER',payload:{matchId,questionIndex:0,selectedOptionId:'B',responseTimeMs:0}});
  assert.equal(ws.readyState,3); assert.equal(f.mutations.length,0);
});
