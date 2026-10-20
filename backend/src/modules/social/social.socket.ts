import { Server } from 'http';
import { randomUUID } from 'crypto';
import { WebSocket, WebSocketServer } from 'ws';
import { verifyAccessToken } from '../../utils/jwt';
import { socialTransport } from './social.transport';
import { prisma } from '../../config/prisma';
import { membership } from './friends.service';
import { z } from 'zod';

export class SocialSocketServer {
  private connections = new Map<string, Set<WebSocket>>();
  private wss = new WebSocketServer({ noServer: true, maxPayload: 4096 });
  private liveness = new Map<WebSocket, { lastSeen: number; expiry: number }>();
  private heartbeat?: NodeJS.Timeout;
  private messageWork=new Set<Promise<void>>();
  init(server: Server, canServe:()=>boolean=()=>true) {
    socialTransport.init(true);
    const subscriber = socialTransport.subscriber!;
    subscriber.on('message', (channel, message) => {
      const user = channel.slice('social:user:'.length);
      for (const ws of this.connections.get(user) ?? []) if (ws.readyState === WebSocket.OPEN) ws.send(message);
    });
    server.on('upgrade', (req, socket, head) => {
      if (req.url?.split('?')[0] !== '/ws/social') return;
      if(!canServe() || socket.destroyed){socket.destroy();return;}
      this.wss.handleUpgrade(req, socket, head, ws => this.wss.emit('connection', ws));
    });
    this.wss.on('connection', ws => {
      let user: string | undefined; let token: string | undefined;
      const connectionId = randomUUID(); let watched: string[] = [];
      let lastHeartbeat = Date.now();
      this.liveness.set(ws, { lastSeen: Date.now(), expiry: Infinity });
      const authDeadline = setTimeout(() => { if (!user) ws.close(4001, 'Authentication required'); }, 3000);
      const renew = async () => {
        if (!user) return;
        const jwt = verifyAccessToken(token!) as { exp?: number };
        this.liveness.set(ws, { lastSeen: Date.now(), expiry: jwt.exp ? jwt.exp * 1000 : Infinity });
        const client = socialTransport.requireReady();
        const admitted = await client.eval(`redis.call('ZREMRANGEBYSCORE',KEYS[1],'-inf',ARGV[1]);
          if not redis.call('ZSCORE',KEYS[1],ARGV[3]) and redis.call('ZCARD',KEYS[1]) >= 5 then return 0 end;
          redis.call('ZADD',KEYS[1],ARGV[2],ARGV[3]); redis.call('EXPIRE',KEYS[1],65); return 1`,
          1, `social:presence:${user}`, Date.now(), Date.now()+60000, connectionId);
        if (!admitted) throw new Error('Too many connections');
        if (watched.length) ws.send(JSON.stringify({ event: 'PRESENCE', items: await socialTransport.presence(watched) }));
      };
      ws.on('message', async bytes => {
        let finish!:()=>void;const work=new Promise<void>(resolve=>{finish=resolve;});this.messageWork.add(work);
        try {
          const msg = JSON.parse(bytes.toString());
          if (msg.type === 'AUTH_INIT' && !user) {
            token = z.string().min(1).max(4000).parse(msg.token);
            const payload = verifyAccessToken(token!); user = z.string().uuid().parse(payload.userId);
            const account = await prisma.user.findFirst({ where: { id: user, isRegistrationComplete: true }, select: { id: true } });
            if (!account) { ws.close(4003, 'Account unavailable'); return; }
            let current = this.connections.get(user);
            if (!current) { current = new Set<WebSocket>(); this.connections.set(user, current); }
            const subscribe = !current.size;
            if (current.size >= 5) { ws.close(4008, 'Too many connections'); return; }
            current.add(ws);
            if (subscribe) await subscriber.subscribe(`social:user:${user}`); this.connections.set(user, current); clearTimeout(authDeadline);
            await renew(); ws.send(JSON.stringify({ event: 'AUTH_SUCCESS' })); return;
          }
          if (!user) throw new Error('Authenticate first.');
          if (msg.type === 'HEARTBEAT') {
            if (Date.now() - lastHeartbeat < 10000) return;
            lastHeartbeat = Date.now(); await renew(); return;
          }
          if (msg.type === 'WATCH_FRIENDS') {
            await socialTransport.limit(user, 'watch', 60, 60);
            const ids = z.array(z.string().uuid()).max(50).parse(msg.ids);
            const links = await prisma.friendship.findMany({ where: { ...membership(user), status: 'ACCEPTED',
              OR: [{ lowId: user, highId: { in: ids } }, { highId: user, lowId: { in: ids } }] }, select: { lowId: true, highId: true } });
            watched = links.map(f => f.lowId === user ? f.highId : f.lowId);
            ws.send(JSON.stringify({ event: 'PRESENCE', items: await socialTransport.presence(watched) }));
          }
        } catch { ws.close(4003, 'Invalid or expired session'); }
        finally {finish();this.messageWork.delete(work);}
      });
      ws.on('close', () => {
        clearTimeout(authDeadline); this.liveness.delete(ws);
        if (!user) return;
        const set = this.connections.get(user); set?.delete(ws);
        if (!set?.size) { this.connections.delete(user); void subscriber.unsubscribe(`social:user:${user}`).catch(() => {}); }
        void socialTransport.client?.zrem(`social:presence:${user}`, connectionId).catch(() => {});
      });
      // TCP pong must not postpone application heartbeats or token revalidation.
    });
    this.heartbeat = setInterval(() => {
      for (const ws of this.wss.clients) {
        const live = this.liveness.get(ws);
        if (live && (Date.now() - live.lastSeen > 70000 || Date.now() >= live.expiry)) ws.close(4003, 'Session expired');
        else if (ws.readyState === WebSocket.OPEN) ws.ping();
      }
    }, 30000);
    this.heartbeat.unref();
  }
  async close() {
    clearInterval(this.heartbeat);
    for(const ws of this.wss.clients)ws.close(1001,'Server restarting');
    await Promise.allSettled([...this.messageWork]);
    await new Promise<void>(resolve=>{
      const timer=setTimeout(()=>{for(const ws of this.wss.clients)ws.terminate();},500);
      this.wss.close(()=>{clearTimeout(timer);resolve();});
    });
  }
}
export const socialSocketServer = new SocialSocketServer();
