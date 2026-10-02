import { Server as HttpServer } from 'http';
import { WebSocketServer, WebSocket } from 'ws';
import { verifyAccessToken } from '../../utils/jwt';
import { pvpMatchService } from './services/pvp-match.service';
import { TIME_CONFIG } from '../../config/inventory.config';
import { redisService } from '../lesson/services/redis.service';

interface ClientSocket extends WebSocket {
  userId?: string;
  matchId?: string;
  isAlive?: boolean;
}

interface MatchState {
  matchId: string;
  players: string[];
  currentQuestionIndex: number;
  timerHandle?: NodeJS.Timeout;
}

export class PvpSocketServer {
  private static instance: PvpSocketServer;
  private wss: WebSocketServer | null = null;
  private matchmakingQueue: { userId: string; ws: ClientSocket }[] = [];
  private activeMatches = new Map<string, MatchState>();
  private userSockets = new Map<string, ClientSocket>();

  public static getInstance(): PvpSocketServer {
    if (!PvpSocketServer.instance) {
      PvpSocketServer.instance = new PvpSocketServer();
    }
    return PvpSocketServer.instance;
  }

  public init(server: HttpServer) {
    this.wss = new WebSocketServer({ server, path: '/ws/pvp' });

    this.wss.on('connection', (ws: ClientSocket, req) => {
      ws.isAlive = true;

      let authTimeout: NodeJS.Timeout | null = null;

      // Extract and verify JWT token from query string (?token=...) if provided
      try {
        const url = new URL(req.url || '', `http://${req.headers.host}`);
        const token = url.searchParams.get('token');
        if (token) {
          const payload = verifyAccessToken(token);
          ws.userId = payload.userId;
          this.userSockets.set(payload.userId, ws);
        } else {
          // Allow up to 3 seconds for client to send AUTH_INIT message frame
          authTimeout = setTimeout(() => {
            if (!ws.userId) {
              ws.close(4001, 'Authentication timeout: AUTH_INIT frame required within 3s');
            }
          }, 3000);
        }
      } catch {
        ws.close(4003, 'Invalid or expired authentication token');
        return;
      }

      ws.on('pong', () => {
        ws.isAlive = true;
      });

      ws.on('message', async (data) => {
        try {
          const message = JSON.parse(data.toString());

          // Handle AUTH_INIT handshake frame
          if (message.type === 'AUTH_INIT') {
            if (authTimeout) clearTimeout(authTimeout);
            const token = message.payload?.token;
            if (!token) {
              ws.close(4001, 'Authentication token required in AUTH_INIT');
              return;
            }
            try {
              const payload = verifyAccessToken(token);
              ws.userId = payload.userId;
              this.userSockets.set(payload.userId, ws);
              this.send(ws, 'AUTH_SUCCESS', { userId: payload.userId });
              return;
            } catch {
              ws.close(4003, 'Invalid or expired authentication token');
              return;
            }
          }

          if (!ws.userId) {
            this.send(ws, 'ERROR', { message: 'Authentication required', code: 'UNAUTHORIZED' });
            return;
          }

          await this.handleMessage(ws, message);
        } catch (err: any) {
          this.send(ws, 'ERROR', { message: err.message || 'Invalid message payload' });
        }
      });

      ws.on('close', () => {
        if (authTimeout) clearTimeout(authTimeout);
        if (ws.userId) {
          this.userSockets.delete(ws.userId);
          const redis = redisService.getClient();
          if (redis && redisService.getIsConnected()) {
            redis.zrem('pvp:matchmaking', ws.userId).catch(() => {});
          }
          // Remove from matchmaking queue if present
          this.matchmakingQueue = this.matchmakingQueue.filter((m) => m.userId !== ws.userId);

          // Mark player connection status in match if in a match
          if (ws.matchId) {
            pvpMatchService.setPlayerConnection(ws.matchId, ws.userId, 'DISCONNECTED').catch(() => {});
          }
        }
      });
    });

    // Heartbeat interval to clean up stale connections
    setInterval(() => {
      if (!this.wss) return;
      this.wss.clients.forEach((ws) => {
        const client = ws as ClientSocket;
        if (!client.isAlive) return client.terminate();
        client.isAlive = false;
        client.ping();
      });
    }, 15000);

    console.log('⚔️ Ranked PvP WebSocket Server initialized on path: /ws/pvp');
  }

  private send(ws: WebSocket | undefined, event: string, payload: any) {
    if (ws && ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify({ event, data: payload, timestamp: new Date().toISOString() }));
    }
  }

  private broadcastToMatch(matchId: string, event: string, payload: any) {
    const match = this.activeMatches.get(matchId);
    if (!match) return;

    for (const userId of match.players) {
      const socket = this.userSockets.get(userId);
      this.send(socket, event, payload);
    }
  }

  private async handleMessage(ws: ClientSocket, message: { type: string; payload?: any }) {
    const { type, payload } = message;
    const userId = ws.userId;
    if (!userId) return;

    switch (type) {
      case 'JOIN_MATCHMAKING': {
        this.userSockets.set(userId, ws);
        const redis = redisService.getClient();
        if (redis && redisService.getIsConnected()) {
          await redis.zadd('pvp:matchmaking', Date.now(), userId);
        } else {
          // Local fallback
          this.matchmakingQueue = this.matchmakingQueue.filter(
            (m) => m.ws && m.ws.readyState === WebSocket.OPEN
          );
          const existingIdx = this.matchmakingQueue.findIndex((m) => m.userId === userId);
          if (existingIdx >= 0) {
            this.matchmakingQueue[existingIdx] = { userId, ws };
          } else {
            this.matchmakingQueue.push({ userId, ws });
          }
        }

        this.send(ws, 'QUEUE_STATUS', { status: 'WAITING_FOR_OPPONENT' });
        this.tryPairPlayers();
        break;
      }

      case 'LEAVE_MATCHMAKING': {
        const redis = redisService.getClient();
        if (redis && redisService.getIsConnected()) {
          await redis.zrem('pvp:matchmaking', userId);
        }
        this.matchmakingQueue = this.matchmakingQueue.filter((m) => m.userId !== userId);
        this.send(ws, 'QUEUE_STATUS', { status: 'LEFT_QUEUE' });
        break;
      }

      case 'SUBMIT_ANSWER': {
        const { matchId, questionIndex, selectedOptionId, responseTimeMs } = payload || {};
        if (!matchId || typeof questionIndex !== 'number') return;

        const result = await pvpMatchService.submitAnswer({
          matchId,
          userId,
          questionIndex,
          selectedOptionId: selectedOptionId || null,
          responseTimeMs: typeof responseTimeMs === 'number' ? responseTimeMs : 60000,
        });

        // Acknowledge answer to submitting player
        this.send(ws, 'ANSWER_ACCEPTED', {
          questionIndex,
          isCorrect: result.isCorrect,
          correctAnswer: result.correctAnswer,
        });

        // If both players answered before deadline, end question early
        if (result.bothAnswered) {
          const matchState = this.activeMatches.get(matchId);
          if (matchState && matchState.timerHandle) {
            clearTimeout(matchState.timerHandle);
            matchState.timerHandle = undefined;
            await this.endQuestionRound(matchId, questionIndex);
          }
        }
        break;
      }

      case 'RECONNECT_MATCH': {
        const { matchId } = payload || {};
        if (!matchId) return;

        const match = await pvpMatchService.getMatchDetails(matchId);
        ws.matchId = matchId;
        this.userSockets.set(userId, ws);
        await pvpMatchService.setPlayerConnection(matchId, userId, 'CONNECTED');

        const remainingMs = match.currentQuestionDeadline
          ? Math.max(0, match.currentQuestionDeadline.getTime() - Date.now())
          : 0;

        const currentQ = match.questionSet.setQuestions[match.currentQuestionIndex];

        this.send(ws, 'MATCH_RECONNECTED', {
          matchId: match.id,
          status: match.status,
          currentQuestionIndex: match.currentQuestionIndex,
          remainingMs,
          question: currentQ
            ? {
                prompt: currentQ.question.prompt,
                options: currentQ.question.options,
                pattern: currentQ.question.pattern,
                difficulty: currentQ.question.difficulty,
              }
            : null,
          players: match.players.map((p) => ({
            userId: p.userId,
            score: p.score,
          })),
        });
        break;
      }
    }
  }

  /**
   * Pairs two players in the matchmaking queue and launches their match.
   */
  private async tryPairPlayers() {
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

    try {
      const match = await pvpMatchService.createMatch(player1Id, player2Id);

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
        matchId: match.id,
        players: match.players.map((p: any) => ({
          userId: p.userId,
          firstName: p.user?.profile?.firstName || 'Aptiqu Warrior',
          avatarUrl: p.user?.profile?.avatarUrl,
        })),
        totalQuestions: match.totalQuestions,
      });

      // Start Question 1 after 3s ready countdown
      setTimeout(() => {
        this.startQuestionRound(match.id, 0);
      }, 3000);
    } catch (err: any) {
      const ws1 = this.userSockets.get(player1Id);
      const ws2 = this.userSockets.get(player2Id);
      if (ws1) this.send(ws1, 'ERROR', { message: 'Failed to initialize match: ' + err.message });
      if (ws2) this.send(ws2, 'ERROR', { message: 'Failed to initialize match: ' + err.message });
    }
  }

  /**
   * Starts a question round with server-authoritative 60s timer.
   */
  private async startQuestionRound(matchId: string, questionIndex: number) {
    const matchState = this.activeMatches.get(matchId);
    if (!matchState) return;

    matchState.currentQuestionIndex = questionIndex;

    const match = await pvpMatchService.startQuestionRound(matchId, questionIndex);
    const setQuestion = (await pvpMatchService.getMatchDetails(matchId)).questionSet.setQuestions[
      questionIndex
    ];

    if (!setQuestion) {
      await this.completeMatch(matchId);
      return;
    }

    // Broadcast QUESTION_STARTED
    this.broadcastToMatch(matchId, 'QUESTION_STARTED', {
      matchId,
      questionIndex,
      totalQuestions: match.totalQuestions,
      durationSeconds: TIME_CONFIG.PVP_FIXED_SECONDS,
      deadline: match.currentQuestionDeadline?.toISOString(),
      question: {
        id: setQuestion.question.id,
        prompt: setQuestion.question.prompt,
        options: setQuestion.question.options,
        difficulty: setQuestion.question.difficulty,
        pattern: setQuestion.question.pattern,
      },
    });

    // Schedule 60s hard deadline timeout
    matchState.timerHandle = setTimeout(async () => {
      await this.endQuestionRound(matchId, questionIndex);
    }, TIME_CONFIG.PVP_FIXED_SECONDS * 1000);
  }

  /**
   * Ends question round, broadcasts results, and transitions to next question.
   */
  private async endQuestionRound(matchId: string, questionIndex: number) {
    const matchState = this.activeMatches.get(matchId);
    if (!matchState) return;

    const match = await pvpMatchService.getMatchDetails(matchId);
    const setQuestion = match.questionSet.setQuestions[questionIndex];

    const answers = match.answers.filter((a) => a.questionIndex === questionIndex);

    // Broadcast QUESTION_ENDED
    this.broadcastToMatch(matchId, 'QUESTION_ENDED', {
      questionIndex,
      correctAnswer: setQuestion.question.correctAnswer,
      explanation: setQuestion.question.explanation,
      method: setQuestion.question.method,
      scores: match.players.map((p) => {
        const playerAns = answers.find((a) => a.userId === p.userId);
        return {
          userId: p.userId,
          score: p.score,
          selectedOptionId: playerAns?.selectedOptionId || null,
          isCorrect: playerAns?.isCorrect || false,
          isLate: playerAns?.isLate || false,
        };
      }),
    });

    // 3-second transition to next question or completion
    setTimeout(async () => {
      const nextIndex = questionIndex + 1;
      if (nextIndex < match.totalQuestions) {
        await this.startQuestionRound(matchId, nextIndex);
      } else {
        await this.completeMatch(matchId);
      }
    }, 3000);
  }

  /**
   * Completes the match, computes winner, awards XP, and broadcasts MATCH_COMPLETED.
   * If one player went AFK, the active player completes the script and wins cleanly.
   */
  private async completeMatch(matchId: string) {
    const finalized = await pvpMatchService.finalizeMatch(matchId);
    const matchState = this.activeMatches.get(matchId);
    if (matchState?.timerHandle) {
      clearTimeout(matchState.timerHandle);
    }
    this.activeMatches.delete(matchId);

    this.broadcastToMatch(matchId, 'MATCH_COMPLETED', {
      matchId: finalized.id,
      winnerId: finalized.winnerId,
      isTie: finalized.isTie,
      players: finalized.players.map((p) => ({
        userId: p.userId,
        firstName: p.user?.profile?.firstName || 'Warrior',
        score: p.score,
        totalResponseTimeMs: p.totalResponseTimeMs,
        isWinner: p.isWinner,
        xpAwarded: p.xpAwarded,
        isAfk: p.connectionStatus === 'DISCONNECTED',
      })),
    });
  }
}

export const pvpSocketServer = PvpSocketServer.getInstance();
