import http from 'http';
import { createApp } from './app';
import { ENV } from './config/env';
import { prisma } from './config/prisma';
import { pvpSocketServer } from './modules/pvp/pvp.socket';

async function bootstrap() {
  const app = createApp();
  const server = http.createServer(app);

  // Verify database connection
  await prisma.$connect();
  console.log('✅ Connected to PostgreSQL database (aptiqu_db)');

  // Initialize Ranked PvP WebSocket Server on the same HTTP server
  pvpSocketServer.init(server);

  server.listen(ENV.PORT, () => {
    console.log(`🚀 Aptiqu Backend Server running on http://localhost:${ENV.PORT}`);
    console.log(`📡 Health Check: http://localhost:${ENV.PORT}/health`);
    console.log(`⚔️ PvP WebSocket: ws://localhost:${ENV.PORT}/ws/pvp`);
  });

  // Graceful shutdown
  const shutdown = async () => {
    console.log('\n🛑 Gracefully shutting down Aptiqu Backend...');
    server.close(async () => {
      await prisma.$disconnect();
      console.log('🔌 Database disconnected.');
      process.exit(0);
    });
  };

  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);
}

bootstrap().catch((err) => {
  console.error('❌ Failed to start server:', err);
  process.exit(1);
});
