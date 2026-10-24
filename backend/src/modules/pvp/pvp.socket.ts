import { log, safeError } from '../../observability/logger';
import { trustedPeer } from '../../security/trusted-peer';
import { PublicError } from '../../security/errors';
import { takeBudget } from '../../security/request-policy';
import { randomUUID } from 'node:crypto';
import { ENV } from '../../config/env';
import { ACTIVE_STATES, publicPreparation } from '../ai/luna/preparations';
import { prisma } from '../../config/prisma';
import { rankedRuntime } from './ranked/ranked-runtime';
import { rankedEligibilityService } from './ranked/ranked-eligibility.service';
import { RedisRankedQueue } from './ranked/ranked-queue';
import { QueueClaim } from './ranked/ranked-matchmaking-policy';
import { Server as HttpServer } from 'http';
import { WebSocketServer, WebSocket } from 'ws';
import { verifyAccessToken } from '../../utils/jwt';
import { pvpMatchService } from './services/pvp-match.service';
import { matchQuestions } from './ranked/ranked-questions';
import { TIME_CONFIG } from '../../config/inventory.config';
import { redisService } from '../lesson/services/redis.service';
import { PvpError } from './pvp.errors';
import { PvpMessage, pvpMessageSchema } from './pvp.protocol';
import { PvpInternalMatch, publicQuestion, roundFeedback, serializeMatch } from './pvp.dto';

interface ClientSocket extends WebSocket { userId?: string; matchId?: string; isAlive?: boolean; queueToken?: string; authExpiresAt?: number; authTimer?: NodeJS.Timeout }
interface MatchState { matchId: string; players: string[]; currentQuestionIndex: number; timerHandle?: NodeJS.Timeout }

export class PvpSocketServer {
  private static instance: PvpSocketServer;
  private heartbeat?: NodeJS.Timeout;
  private queueTimer?: NodeJS.Timeout;
  private searching = false;
  private refreshingQueue = false;
  private closed = false;
  private queueIntents = new Map<string, number>();
  private queueOwners = new Map<string, string>();
  private claiming = new Map<string, string>();
  private rankedQueue = new RedisRankedQueue(() => redisService.getIsConnected() ? redisService.getClient() : null);
  private queueWork = new Set<Promise<void>>();
  private messageWork = new Set<Promise<void>>();

  private wss: WebSocketServer | null = null;
  private matchmakingQueue: { userId: string; ws: ClientSocket }[] = [];
  private activeMatches = new Map<string, MatchState>();
  private userSockets = new Map<string, ClientSocket>();
  private connectionUpdates = new Map<string, Promise<void>>();

  public static getInstance(): PvpSocketServer {
    return PvpSocketServer.instance ??= new PvpSocketServer();
  }

  private bindSocket(ws: ClientSocket, userId: string) {
    if (ws.userId) throw new PvpError('This connection is already authenticated.', 'ALREADY_AUTHENTICATED', 400);
    const previous = this.userSockets.get(userId);
    if (previous) this.bumpQueueIntent(userId);
    ws.queueToken = previous?.queueToken;
    ws.userId = userId;
    this.userSockets.set(userId, ws);
    this.matchmakingQueue = this.matchmakingQueue.map(entry => entry.userId === userId ? { userId, ws } : entry);
    if (previous && previous !== ws) previous.close(4000, 'Connection replaced');
  }

  private authenticateSocket(ws: ClientSocket, token: string) {
    const payload = verifyAccessToken(token);
    this.bindSocket(ws,payload.userId);
    ws.authExpiresAt = payload.exp * 1000;
    ws.authTimer = setTimeout(() => ws.close(4001,'Authentication expired'),Math.min(2147483647,Math.max(0,ws.authExpiresAt-Date.now())));
  }

  private async updateConnection(userId: string, work: () => Promise<void>) {
    const task = (this.connectionUpdates.get(userId) ?? Promise.resolve()).catch(() => {}).then(work);
    this.connectionUpdates.set(userId, task);
    try { await task; }
    finally { if (this.connectionUpdates.get(userId) === task) this.connectionUpdates.delete(userId); }
  }

  public init(server: HttpServer, canServe: () => boolean = () => true) {
    this.wss = new WebSocketServer({ noServer: true, maxPayload: 8192 });
    server.on('upgrade', async (req, socket, head) => {
      if (req.url?.split('?')[0] !== '/ws/pvp') return;
      if(!canServe() || socket.destroyed){socket.destroy();return;}
      try { await takeBudget('socketConnect',trustedPeer(req)); }
      catch (error: any) { socket.end(`HTTP/1.1 ${error.status === 429 ? '429 Too Many Requests' : '503 Service Unavailable'}\r\nRetry-After: ${error.retryAfterSeconds || 3}\r\nConnection: close\r\n\r\n`); return; }
      if(!canServe() || socket.destroyed){socket.destroy();return;}
      this.wss!.handleUpgrade(req, socket, head, ws => this.wss!.emit('connection', ws, req));
    });
    this.wss.on('connection', (ws: ClientSocket, req) => {
      ws.isAlive = true;
      let authTimeout: NodeJS.Timeout | undefined;
      try {
        const token = new URL(req.url || '', `http://${req.headers.host}`).searchParams.get('token');
        if (token) this.authenticateSocket(ws, token);
        else authTimeout = setTimeout(() => { if (!ws.userId) ws.close(4001, 'Authentication timeout'); }, 3000);
      } catch { ws.close(4003, 'Invalid or expired authentication token'); return; }
      ws.on('pong', () => { ws.isAlive = true; });
      let pendingMessages = 0;
      ws.on('message', async raw => {
        if (++pendingMessages > 4) { --pendingMessages; ws.close(4008,'Too many pending messages'); return; }
        let finish!:()=>void;const work=new Promise<void>(resolve=>{finish=resolve;});this.messageWork.add(work);
        const receivedAt = new Date(); // Trusted ingress time; never a payload field.
        try {
          if (!ws.userId) await takeBudget('socketConnect', trustedPeer(req));
          const parsed = pvpMessageSchema.safeParse(JSON.parse(raw.toString()));
          if (!parsed.success) throw new PvpError('Invalid message payload.', 'INVALID_MESSAGE', 400);
          const message = parsed.data;
          if (message.type === 'AUTH_INIT') {
            if (ws.userId) throw new PvpError('This connection is already authenticated.', 'ALREADY_AUTHENTICATED', 400);
            try { this.authenticateSocket(ws, message.payload.token); }
            catch { ws.close(4003, 'Invalid or expired authentication token'); return; }
            clearTimeout(authTimeout);
            this.send(ws, 'AUTH_SUCCESS', { userId: ws.userId });
            await this.recoverPreparation(ws);
            return;
          }
          if (!ws.userId) throw new PvpError('Authentication required.', 'UNAUTHORIZED', 401);
          if (this.userSockets.get(ws.userId) !== ws) throw new PvpError('Connection replaced. Reconnect to continue.', 'STALE_CONNECTION', 401);
          if (!ws.authExpiresAt || receivedAt.getTime() >= ws.authExpiresAt) { ws.close(4001,'Authentication expired'); return; }
          const ingressIntent = message.type === 'JOIN_MATCHMAKING' || message.type === 'LEAVE_MATCHMAKING' ? this.bumpQueueIntent(ws.userId) : undefined;
          await takeBudget('socketMessage',ws.userId);
          if (message.type === 'JOIN_MATCHMAKING' || message.type === 'LEAVE_MATCHMAKING') await takeBudget('socketQueue',ws.userId);
          if (this.userSockets.get(ws.userId) !== ws || Date.now() >= ws.authExpiresAt) { ws.close(4001,'Authentication expired'); return; }
          await this.handleMessage(ws, message, receivedAt, ingressIntent);
        } catch (error) {
          const known = error instanceof PvpError || error instanceof PublicError;
          this.send(ws, 'ERROR', { message: known ? error.message : 'Could not process this update. Please retry.', code: known ? error.code : 'MATCH_UPDATE_FAILED', retryAfterSeconds: known ? error.retryAfterSeconds : undefined });
        } finally { --pendingMessages;finish();this.messageWork.delete(work); }
      });
      ws.on('close', () => {
        clearTimeout(authTimeout);
        clearTimeout(ws.authTimer);
        const userId = ws.userId;
        if (!userId || this.userSockets.get(userId) !== ws) return;
        this.userSockets.delete(userId);
        this.bumpQueueIntent(userId);
        const ticket = this.queueOwners.get(userId);
        if (!this.claiming.has(userId)) {
          this.queueOwners.delete(userId);
          if (ticket) void this.rankedQueue.cancel(userId, ticket).catch(() => {});
        }
        this.matchmakingQueue = this.matchmakingQueue.filter(entry => entry.ws !== ws);
        const redis = redisService.getClient();
        if (!ticket && redis && redisService.getIsConnected()) void redis.zrem('pvp:matchmaking', userId).catch(() => {});
        if (ws.matchId) void this.updateConnection(userId, async () => {
          if (!this.userSockets.has(userId)) await pvpMatchService.setPlayerConnection(ws.matchId!, userId, 'DISCONNECTED');
        }).catch(() => {});
      });
    });
    this.closed = false;
    this.queueTimer = setInterval(() => {
      if (rankedRuntime().skillMatchmaking) this.trackQueueWork(this.searchRanked());
    }, 1000);
    this.heartbeat = setInterval(() => {
      if (this.queueOwners.size) this.trackQueueWork(this.refreshQueue());
      for (const socket of this.wss?.clients ?? []) {
        const ws = socket as ClientSocket;
        if (!ws.isAlive) { ws.terminate(); continue; }
        ws.isAlive = false;
        ws.ping();
      }
    }, 15000);
  }

  public beginDrain() {
    this.closed=true;clearInterval(this.queueTimer);
    for(const userId of this.userSockets.keys())this.bumpQueueIntent(userId);
  }
  public async close() {
    this.beginDrain();
    clearInterval(this.queueTimer);
    clearInterval(this.heartbeat);
    for (const [userId, token] of this.queueOwners) {
      try { await this.rankedQueue.cancel(userId, token); } catch { break; }
    }
    this.queueOwners.clear();
    await Promise.allSettled([...this.queueWork]);
    for (const match of this.activeMatches.values()) clearTimeout(match.timerHandle);
    for (const ws of this.wss?.clients ?? []) ws.close(1001, 'Server restarting');
    await Promise.allSettled([...this.messageWork]);
    if(this.wss)await new Promise<void>(resolve=>{
      const timer=setTimeout(()=>{for(const ws of this.wss?.clients??[])ws.terminate();},500);
      this.wss!.close(()=>{clearTimeout(timer);resolve();});
    });
    await Promise.allSettled([...this.connectionUpdates.values()]);
  }

  private send(ws: WebSocket | undefined, event: string, data: unknown) {
    if (ws?.readyState !== WebSocket.OPEN) return;
    try { ws.send(JSON.stringify({ event, data, timestamp: new Date().toISOString() })); }
    catch { /* Socket delivery is optional; committed results remain retrievable. */ }
  }

  private async recoverPreparation(ws: ClientSocket) {
    if (!ws.userId) return;
    const row=await prisma.questionPreparation.findFirst({where:{userIds:{has:ws.userId},mode:{in:['RANKED','UNRANKED']},state:{in:[...ACTIVE_STATES,'READY']},createdAt:{gte:new Date(Date.now()-ENV.LUNA.preparationTimeoutMs-60000)}},orderBy:{createdAt:'desc'}});
    if (!row) return;
    if(row.resultSetId){
      const match=await prisma.pvpMatch.findFirst({where:{questionSetId:row.resultSetId,players:{some:{userId:ws.userId}}},select:{id:true}});
      if(match){ws.matchId=match.id;this.send(ws,'MATCH_FOUND',{matchId:match.id,resume:true,totalQuestions:10});return;}
    }
    if (this.claiming.has(ws.userId)) this.send(ws,'QUESTIONS_PREPARING',publicPreparation(row));
    else {
      await prisma.questionPreparation.updateMany({where:{id:row.id,state:{in:ACTIVE_STATES}},data:{state:'CANCELLED',errorCode:'OWNERSHIP_LOST',version:{increment:1}}});
      this.send(ws,'ERROR',{code:'PREPARATION_INTERRUPTED',message:'Match preparation was interrupted. Please search again.'});
    }
  }

  private broadcastToMatch(matchId: string, event: string, payload: unknown) {
    for (const user of this.activeMatches.get(matchId)?.players ?? []) this.send(this.userSockets.get(user), event, payload);
  }

  private matchError(matchId: string, error: unknown) {
    this.broadcastToMatch(matchId, 'ERROR', { matchId, code: 'MATCH_UPDATE_FAILED', message: 'Match update unavailable. Try Refresh match.' });
    log('error','pvp_socket.matchError.error');
    // Persisted due work is retried by the recovery worker; no guessed outcome.
  }

  private async handleMessage(ws: ClientSocket, message: PvpMessage, receivedAt = new Date(), ingressIntent?: number) {
    const userId = ws.userId!;
    if (ingressIntent !== undefined && this.queueIntents.get(userId) !== ingressIntent) return;
    switch (message.type) {
      case 'JOIN_MATCHMAKING': {
        if (this.closed) throw new PvpError('Server is restarting. Please retry.', 'ADMISSION_PAUSED', 503);
        const intent = ingressIntent ?? this.bumpQueueIntent(userId);
        if (this.claiming.has(userId)) { this.send(ws, 'QUEUE_STATUS', { status: 'PAIRING' }); break; }
        const candidate = await rankedEligibilityService.inspect(userId, message.payload?.rankedCapability ?? 0);
        if (this.userSockets.get(userId) !== ws || this.queueIntents.get(userId) !== intent || this.closed) return;
        if (this.claiming.has(userId)) { this.send(ws, 'QUEUE_STATUS', { status: 'PAIRING' }); break; }
        if (rankedRuntime().skillMatchmaking) {
          const token = randomUUID();
          ws.queueToken = token;
          const reply = await this.rankedQueue.join(candidate, token);
          if (this.userSockets.get(userId) !== ws || this.queueIntents.get(userId) !== intent || this.closed) {
            await this.rankedQueue.cancel(userId, token).catch(() => {}); return;
          }
          const ownerToken = reply.entry?.token ?? token;
          ws.queueToken = ownerToken;
          this.queueOwners.set(userId, ownerToken);
          this.send(ws, 'QUEUE_STATUS', this.rankedQueue.status(reply));
          this.trackQueueWork(this.searchRanked());
        } else {
          const redis = redisService.getClient();
          if (redis && redisService.getIsConnected()) await redis.zadd('pvp:matchmaking', Date.now(), userId);
          else {
            this.matchmakingQueue = this.matchmakingQueue.filter(entry => entry.ws.readyState === WebSocket.OPEN);
            if (!this.matchmakingQueue.some(entry => entry.userId === userId)) this.matchmakingQueue.push({ userId, ws });
          }
          if (this.userSockets.get(userId) !== ws || this.queueIntents.get(userId) !== intent || this.closed) return;
          this.send(ws, 'QUEUE_STATUS', { status: 'WAITING_FOR_OPPONENT' });
          const work = this.tryPairPlayers(); this.trackQueueWork(work); await work;
        }
        break;
      }
      case 'LEAVE_MATCHMAKING': {
        if (ingressIntent === undefined) this.bumpQueueIntent(userId);
        if (this.claiming.has(userId)) { this.send(ws, 'QUEUE_STATUS', { status: 'PAIRING' }); break; }
        const token = this.queueOwners.get(userId);
        if (token) {
          const reply = await this.rankedQueue.cancel(userId, token);
          if (this.userSockets.get(userId) !== ws) return;
          if (reply.status !== 'PAIRING' && this.queueOwners.get(userId) === token) this.queueOwners.delete(userId);
          this.send(ws, 'QUEUE_STATUS', this.rankedQueue.status(reply));
        } else {
          const redis = redisService.getClient();
          if (redis && redisService.getIsConnected()) await redis.zrem('pvp:matchmaking', userId);
          this.matchmakingQueue = this.matchmakingQueue.filter(entry => entry.userId !== userId);
          this.send(ws, 'QUEUE_STATUS', { status: 'LEFT_QUEUE' });
        }
        break;
      }
      case 'SUBMIT_ANSWER': {
        const { matchId, questionIndex, selectedOptionId } = message.payload;
        const result = await pvpMatchService.submitAnswer({ matchId, userId, questionIndex, selectedOptionId, receivedAt });
        this.send(ws, 'ANSWER_ACCEPTED', { matchId, questionIndex, stateVersion: result.stateVersion,
          selectedOptionId: result.answer.selectedOptionId, acceptedAt: result.answer.serverReceivedAt,
        });
        if (result.bothAnswered) await this.endQuestionRound(matchId, questionIndex);
        break;
      }
      case 'RECONNECT_MATCH': {
        const { matchId } = message.payload;
        // Service validates membership before any connection mutation or snapshot disclosure.
        await this.updateConnection(userId, async () => {
          if (this.userSockets.get(userId) === ws) await pvpMatchService.setPlayerConnection(matchId, userId, 'CONNECTED');
        });
        const snapshot = await pvpMatchService.getMatchSnapshot(matchId, userId);
        if (this.userSockets.get(userId) !== ws) return;
        ws.matchId = matchId;
        this.send(ws, 'MATCH_RECONNECTED', snapshot);
        if (!['COMPLETED', 'CANCELLED'].includes(snapshot.status)) await this.publishRecovered(await pvpMatchService.getMatchDetails(matchId));
        break;
      }
    }
  }

  private bumpQueueIntent(userId: string) {
    const version = (this.queueIntents.get(userId) ?? 0) + 1;
    this.queueIntents.set(userId, version);
    // Connected/queued users retain their fence. Remove unrelated old entries.
    if (this.queueIntents.size > 10000) for (const id of this.queueIntents.keys()) {
      if (!this.userSockets.has(id) && !this.claiming.has(id) && !this.queueOwners.has(id)) this.queueIntents.delete(id);
      if (this.queueIntents.size <= 10000) break;
    }
    return version;
  }
  private trackQueueWork(work: Promise<void>) {
    const tracked = work.catch(() => {}).finally(() => this.queueWork.delete(tracked));
    this.queueWork.add(tracked);
  }
  private async refreshQueue() {
    if (this.closed || this.refreshingQueue) return;
    this.refreshingQueue = true;
    try {
      for (const [userId, token] of this.queueOwners) {
        if (this.claiming.has(userId)) continue;
        const ws = this.userSockets.get(userId);
        try {
          if (!rankedRuntime().skillMatchmaking || rankedRuntime().drain) {
            await this.rankedQueue.cancel(userId, token);
            if (this.queueOwners.get(userId) === token) this.queueOwners.delete(userId);
            this.send(ws, 'ERROR', { code: 'ADMISSION_PAUSED', message: 'Match search is paused. Please retry later.' });
            continue;
          }
          const reply = await this.rankedQueue.touch(userId, token);
          if (this.queueOwners.get(userId) !== token) continue;
          if (reply.status === 'EXPIRED') { this.queueOwners.delete(userId); this.send(ws, 'ERROR', { code: 'QUEUE_EXPIRED', message: 'Search expired. Please find a match again.' }); }
          else this.send(ws, 'QUEUE_STATUS', this.rankedQueue.status(reply));
        } catch {
          // Bound outage work to one failed operation. In-flight claims retain
          // their own lease/outcome; only still-searching tickets are fenced.
          for (const id of this.queueOwners.keys()) if (!this.claiming.has(id)) {
            this.queueOwners.delete(id);
            this.send(this.userSockets.get(id), 'ERROR', { code: 'QUEUE_UNAVAILABLE', message: 'Match search unavailable. Please retry.' });
          }
          break;
        }
      }
    } finally { this.refreshingQueue = false; }
  }
  private async searchRanked() {
    if (this.closed || this.searching || !rankedRuntime().skillMatchmaking || rankedRuntime().drain) return;
    this.searching = true;
    try {
      for (let count = 0; count < 4 && !this.closed; count++) {
        if (this.claiming.size >= ENV.LUNA.maxPending * 2) break;
        const claim = await this.rankedQueue.claim();
        if (!claim) break;
        this.trackQueueWork(this.admitClaim(claim));
      }
    } finally { this.searching = false; }
  }
  private async admitClaim(claim: QueueClaim) {
    const entries = [claim.a, claim.b];
    for (const e of entries) this.claiming.set(e.userId, claim.id);
    let valid = true;
    let leaseUntil = Date.now() + 115000;
    const renewal = setInterval(() => {
      this.trackQueueWork(this.rankedQueue.renew(claim).then(renewed => {
        if (!renewed) valid = false;
        else leaseUntil = Date.now() + 115000;
      }).catch(() => { valid = false; }));
    }, 15000);
    try {
      if (entries.some(e => this.queueOwners.get(e.userId) !== e.token || this.userSockets.get(e.userId)?.readyState !== WebSocket.OPEN)) throw new PvpError('Search expired. Please retry.', 'QUEUE_STALE');
      for (const e of entries) this.send(this.userSockets.get(e.userId), 'QUEUE_STATUS', { status: 'PAIRING' });
      const match = await pvpMatchService.createMatch(claim.a.userId, claim.b.userId, { ...claim, isActive: () => valid && !this.closed && Date.now() < leaseUntil }, status => {
        for (const e of entries) this.send(this.userSockets.get(e.userId),'QUESTIONS_PREPARING',status);
      });
      // After commit, transport/Redis errors must never hide or undo the match.
      await this.rankedQueue.finish(claim).catch(() => {});
      for (const e of entries) {
        if (this.queueOwners.get(e.userId) === e.token) this.queueOwners.delete(e.userId);
        const ws = this.userSockets.get(e.userId); if (ws) ws.matchId = match.id;
      }
      if (match.status === 'COMPLETED' || match.status === 'CANCELLED') { await this.publishRecovered(match); return; }
      this.activeMatches.set(match.id, { matchId: match.id, players: entries.map(e => e.userId), currentQuestionIndex: match.currentQuestionIndex });
      this.broadcastToMatch(match.id, 'MATCH_FOUND', {
        matchId: match.id, seasonId: match.seasonId, policyId: claim.a.policyId, ratingMode: match.ratingMode,
        admittedAt: match.seasonAssignedAt?.toISOString() ?? null, totalQuestions: match.totalQuestions,
        players: match.players.map(p => ({ userId: p.userId, firstName: p.user.profile?.firstName || 'Learner', avatarUrl: p.user.profile?.avatarUrl ?? null, league: entries.find(e => e.userId === p.userId)?.league ?? 'UNRANKED' })),
      });
      await this.publishRecovered(match);
    } catch (error) {
      await this.rankedQueue.finish(claim).catch(() => {});
      for (const e of entries) {
        if (this.queueOwners.get(e.userId) === e.token) this.queueOwners.delete(e.userId);
        this.send(this.userSockets.get(e.userId), 'ERROR', { code: error instanceof PvpError ? error.code : 'MATCH_INITIALIZATION_FAILED',
          message: error instanceof PvpError ? error.message : 'Match update unavailable. Refresh Ranked to resume a match or search again.' });
      }
    } finally {
      valid = false; clearInterval(renewal);
      for (const e of entries) if (this.claiming.get(e.userId) === claim.id) this.claiming.delete(e.userId);
    }
  }

  private async tryPairPlayers() {
    if (this.closed) return;
    let player1Id: string | null = null;
    let player2Id: string | null = null;

    const redis = redisService.getClient();
    if (redis && redisService.getIsConnected()) {
      const lua = `
        local players = redis.call('zrange', KEYS[1], 0, 1)
        if #players == 2 then
          redis.call('zrem', KEYS[1], players[1], players[2])
          return players
        else
          return {}
        end
      `;
      const result = await redis.eval(lua, 1, 'pvp:matchmaking') as string[];
      if (Array.isArray(result) && result.length === 2) {
        player1Id = result[0];
        player2Id = result[1];
      }
    } else {
      this.matchmakingQueue = this.matchmakingQueue.filter(
        (m) => m.ws && m.ws.readyState === WebSocket.OPEN
      );
      if (this.matchmakingQueue.length >= 2) {
        player1Id = this.matchmakingQueue.shift()!.userId;
        player2Id = this.matchmakingQueue.shift()!.userId;
      }
    }

    if (!player1Id || !player2Id) return;
    const claimId = randomUUID();
    this.claiming.set(player1Id, claimId); this.claiming.set(player2Id, claimId);

    try {
      if (this.userSockets.get(player1Id)?.readyState !== WebSocket.OPEN || this.userSockets.get(player2Id)?.readyState !== WebSocket.OPEN) throw new PvpError('Search again.', 'QUEUE_STALE');
      const players=[player1Id,player2Id];
      const match = await pvpMatchService.createMatch(player1Id, player2Id,undefined,status=>{
        for(const id of players)this.send(this.userSockets.get(id),'QUESTIONS_PREPARING',status);
      },()=>!this.closed&&players.every(id=>this.claiming.get(id)===claimId));

      const ws1 = this.userSockets.get(player1Id);
      const ws2 = this.userSockets.get(player2Id);

      if (ws1) ws1.matchId = match.id;
      if (ws2) ws2.matchId = match.id;

      this.activeMatches.set(match.id, {
        matchId: match.id,
        players: [player1Id, player2Id],
        currentQuestionIndex: 0,
      });

      // Broadcast MATCH_FOUND
      this.broadcastToMatch(match.id, 'MATCH_FOUND', {
        matchId: match.id, seasonId: match.seasonId, ratingMode: match.ratingMode, policyId: null,
        players: match.players.map((p: any) => ({
          userId: p.userId,
          firstName: p.user?.profile?.firstName || 'Aptiqu Warrior',
          avatarUrl: p.user?.profile?.avatarUrl,
        })),
        totalQuestions: match.totalQuestions,
      });

      // Start Question 1 after 3s ready countdown
      const state = this.activeMatches.get(match.id)!;
      state.timerHandle = setTimeout(() => {
        if (this.activeMatches.get(match.id) === state) void this.startQuestionRound(match.id, 0).catch(error => this.matchError(match.id, error));
      }, 3000);
    } catch (err: any) {
      const ws1 = this.userSockets.get(player1Id);
      const ws2 = this.userSockets.get(player2Id);
      if (ws1) this.send(ws1, 'ERROR', { message: 'Could not start this match. Please retry.', code: 'MATCH_INITIALIZATION_FAILED' });
      if (ws2) this.send(ws2, 'ERROR', { message: 'Could not start this match. Please retry.', code: 'MATCH_INITIALIZATION_FAILED' });
    } finally {
      if (this.claiming.get(player1Id) === claimId) this.claiming.delete(player1Id);
      if (this.claiming.get(player2Id) === claimId) this.claiming.delete(player2Id);
    }
  }

  private async startQuestionRound(matchId: string, questionIndex: number) {
    const state = this.activeMatches.get(matchId);
    if (!state) return;
    const match = await pvpMatchService.startQuestionRound(matchId, questionIndex);
    if (!match || this.activeMatches.get(matchId) !== state) return;
    state.currentQuestionIndex = questionIndex;
    const question = matchQuestions(match)[questionIndex];
    if (!question) throw new PvpError('Question unavailable.', 'QUESTION_UNAVAILABLE');
    this.broadcastToMatch(matchId, 'QUESTION_STARTED', {
      matchId, questionIndex, stateVersion: match.stateVersion, totalQuestions: match.totalQuestions,
      durationSeconds: TIME_CONFIG.PVP_FIXED_SECONDS,
      deadline: match.currentQuestionDeadline?.toISOString(), serverNow: new Date().toISOString(),
      question: publicQuestion(question),
    });
    clearTimeout(state.timerHandle);
    state.timerHandle = setTimeout(() => {
      if (this.activeMatches.get(matchId) === state) void this.endQuestionRound(matchId, questionIndex).catch(error => this.matchError(matchId, error));
    }, Math.max(0, match.currentQuestionDeadline!.getTime() - Date.now()) + 1);
  }

  private async endQuestionRound(matchId: string, questionIndex: number) {
    const state = this.activeMatches.get(matchId);
    if (!state || state.currentQuestionIndex !== questionIndex) return;
    const match = await pvpMatchService.closeQuestionRound(matchId, questionIndex);
    if (!match || this.activeMatches.get(matchId) !== state) return;
    clearTimeout(state.timerHandle);
    this.broadcastToMatch(matchId, 'QUESTION_ENDED', roundFeedback(match, questionIndex));
    state.timerHandle = setTimeout(() => {
      if (this.activeMatches.get(matchId) !== state || state.currentQuestionIndex !== questionIndex) return;
      const work = questionIndex + 1 < match.totalQuestions
        ? this.startQuestionRound(matchId, questionIndex + 1) : this.completeMatch(matchId);
      void work.catch(error => this.matchError(matchId, error));
    }, Math.max(0, (match.transitionDeadline?.getTime() ?? Date.now() + 3000) - Date.now()) + 1);
  }

  /** Rebuild the routing/timer cache from committed database state. The cache
   * never owns the outcome; a restart does not grant a fresh round deadline. */
  public async publishRecovered(match: PvpInternalMatch) {
    let state = this.activeMatches.get(match.id);
    if (match.status === 'COMPLETED') {
      if (!state) this.activeMatches.set(match.id, { matchId: match.id, players: match.players.map(p => p.userId), currentQuestionIndex: match.currentQuestionIndex });
      await this.completeMatch(match.id);
      return;
    }
    if (match.status === 'CANCELLED') {
      for (const p of match.players) {
        this.send(this.userSockets.get(p.userId), 'MATCH_RECONNECTED', serializeMatch(match, p.userId, new Date()));
        this.send(this.userSockets.get(p.userId), 'ERROR', { matchId: match.id, code: 'MATCH_VOIDED', message: 'A server interruption ended this match. No Elo or XP was awarded. You can return to Ranked.' });
      }
      clearTimeout(state?.timerHandle);
      this.activeMatches.delete(match.id);
      return;
    }
    if (!state) {
      state = { matchId: match.id, players: match.players.map(p => p.userId), currentQuestionIndex: match.currentQuestionIndex };
      this.activeMatches.set(match.id, state);
    }
    clearTimeout(state.timerHandle);
    state.currentQuestionIndex = match.currentQuestionIndex;
    const cached = state;
    if (match.status === 'QUESTION_ACTIVE') {
      this.broadcastToMatch(match.id, 'QUESTION_STARTED', {
        matchId: match.id, questionIndex: match.currentQuestionIndex, stateVersion: match.stateVersion, totalQuestions: match.totalQuestions,
        durationSeconds: Math.ceil(Math.max(0, +match.currentQuestionDeadline! - Date.now()) / 1000),
        deadline: match.currentQuestionDeadline?.toISOString(), serverNow: new Date().toISOString(),
        question: publicQuestion(matchQuestions(match)[match.currentQuestionIndex]),
      });
      state.timerHandle = setTimeout(() => {
        if (this.activeMatches.get(match.id) === cached) void this.endQuestionRound(match.id, match.currentQuestionIndex).catch(error => this.matchError(match.id, error));
      }, Math.max(0, +match.currentQuestionDeadline! - Date.now()) + 1);
    } else if (match.status === 'STARTING' || match.status === 'QUESTION_TRANSITION') {
      if (match.status === 'QUESTION_TRANSITION') this.broadcastToMatch(match.id, 'QUESTION_ENDED', roundFeedback(match, match.currentQuestionIndex));
      state.timerHandle = setTimeout(() => {
        if (this.activeMatches.get(match.id) !== cached) return;
        const work = match.status === 'QUESTION_TRANSITION' && match.currentQuestionIndex === match.totalQuestions - 1
          ? this.completeMatch(match.id) : this.startQuestionRound(match.id, match.status === 'STARTING' ? 0 : match.currentQuestionIndex + 1);
        void work.catch(error => this.matchError(match.id, error));
      }, Math.max(0, +(match.transitionDeadline ?? new Date()) - Date.now()) + 1);
    }
  }

  private async completeMatch(matchId: string) {
    const state = this.activeMatches.get(matchId);
    if (!state) return;
    const finalized = await pvpMatchService.finalizeMatch(matchId);
    if (this.activeMatches.get(matchId) !== state) return;
    // Capture recipients before cleanup; send individualized absolute XP snapshots.
    const results = await Promise.allSettled(state.players.map(userId => pvpMatchService.getMatchSnapshot(matchId, userId)));
    if (this.activeMatches.get(matchId) !== state) return;
    for (let i = 0; i < state.players.length; i++) {
      const result = results[i];
      // Outcome already committed: a subsequent XP-read failure must not hide it
      // or leak the active map. The client can refresh absolute XP separately.
      const data = result.status === 'fulfilled' ? result.value
        : { ...serializeMatch(finalized, state.players[i], new Date()), xp: null };
      this.send(this.userSockets.get(state.players[i]), 'MATCH_COMPLETED', data);
    }
    clearTimeout(state.timerHandle);
    this.activeMatches.delete(matchId);
  }
}

export const pvpSocketServer = PvpSocketServer.getInstance();
