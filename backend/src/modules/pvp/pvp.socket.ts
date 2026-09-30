import { Server as HttpServer } from 'http';
import { WebSocketServer, WebSocket } from 'ws';
import { verifyAccessToken } from '../../utils/jwt';
import { pvpMatchService } from './services/pvp-match.service';
import { TIME_CONFIG } from '../../config/inventory.config';

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

      // Extract and verify JWT token from query string (?token=...)
      try {
        const url = new URL(req.url || '', `http://${req.headers.host}`);
        const token = url.searchParams.get('token');
        if (!token) {
          ws.close(4001, 'Authentication token required');
          return;
        }

        const payload = verifyAccessToken(token);
        ws.userId = payload.userId;
        this.userSockets.set(payload.userId, ws);
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
          await this.handleMessage(ws, message);
        } catch (err: any) {
          this.send(ws, 'ERROR', { message: err.message || 'Invalid message payload' });
        }
      });

      ws.on('close', () => {
        if (ws.userId) {
          this.userSockets.delete(ws.userId);
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
        // Purge dead or disconnected sockets
        this.matchmakingQueue = this.matchmakingQueue.filter(
          (m) => m.ws && m.ws.readyState === WebSocket.OPEN
        );

        const existingIdx = this.matchmakingQueue.findIndex((m) => m.userId === userId);
        if (existingIdx >= 0) {
          this.matchmakingQueue[existingIdx] = { userId, ws };
          this.send(ws, 'QUEUE_STATUS', { status: 'WAITING_FOR_OPPONENT' });
          this.tryPairPlayers();
          return;
        }

        this.matchmakingQueue.push({ userId, ws });
        this.send(ws, 'QUEUE_STATUS', { status: 'WAITING_FOR_OPPONENT' });
        this.tryPairPlayers();
        break;
      }

      case 'LEAVE_MATCHMAKING': {
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
    // Filter out closed or terminated sockets
    this.matchmakingQueue = this.matchmakingQueue.filter(
      (m) => m.ws && m.ws.readyState === WebSocket.OPEN
    );

    if (this.matchmakingQueue.length < 2) return;

    const player1 = this.matchmakingQueue.shift()!;
    const player2 = this.matchmakingQueue.shift()!;

    try {
      const match = await pvpMatchService.createMatch(player1.userId, player2.userId);

      player1.ws.matchId = match.id;
      player2.ws.matchId = match.id;

      this.activeMatches.set(match.id, {
        matchId: match.id,
        players: [player1.userId, player2.userId],
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
      this.send(player1.ws, 'ERROR', { message: 'Failed to initialize match: ' + err.message });
      this.send(player2.ws, 'ERROR', { message: 'Failed to initialize match: ' + err.message });
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
