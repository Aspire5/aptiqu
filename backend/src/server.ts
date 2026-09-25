import { createApp } from './app';
import { ENV } from './config/env';
import { prisma } from './config/prisma';

async function bootstrap() {
  const app = createApp();

  // Verify database connection
  await prisma.$connect();
  console.log('✅ Connected to PostgreSQL database (aptiqu_db)');

  const server = app.listen(ENV.PORT, () => {
    console.log(`🚀 Aptiqu Backend Server running on http://localhost:${ENV.PORT}`);
    console.log(`📡 Health Check: http://localhost:${ENV.PORT}/health`);
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
