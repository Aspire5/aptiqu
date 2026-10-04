import http from 'http';
import cron from 'node-cron';
import { createApp } from './app';
import { ENV } from './config/env';
import { prisma } from './config/prisma';
import { pvpSocketServer } from './modules/pvp/pvp.socket';
import { dailyChallengeService } from './modules/daily-challenge/daily-challenge.service';
import { contentGenQueue, contentGenWorker } from './queues/content-generation.queue';
import { bookIngestionQueue, bookIngestionWorker } from './queues/book-ingestion.queue';

async function bootstrap() {
  const app = createApp();
  const server = http.createServer(app);

  // Verify database connection
  await prisma.$connect();
  console.log('✅ Connected to PostgreSQL database (aptiqu_db)');

  // Initialize Ranked PvP WebSocket Server on the same HTTP server
  pvpSocketServer.init(server);

  // Schedule Daily Streak Reset at 12:00 AM sharp IST (UTC+5:30)
  cron.schedule(
    '0 0 * * *',
    async () => {
      console.log('⏰ [Cron] Triggered 12:00 AM IST Daily Challenge rollover & streak maintenance');
      try {
        await dailyChallengeService.runMidnightIstCron();
      } catch (err) {
        console.error('❌ [Cron] Error running daily streak maintenance:', err);
      }
    },
    {
      timezone: 'Asia/Kolkata',
    }
  );
  console.log('⏳ Daily Streak maintenance cron registered (12:00 AM IST / 18:30 UTC)');

  // Schedule Daily Challenge Pre-Warming at 23:00 IST (11:00 PM IST)
  cron.schedule(
    '0 23 * * *',
    async () => {
      console.log('⏰ [Cron] Triggered 23:00 IST Daily Challenge pre-warming');
      try {
        const tomorrow = new Date(Date.now() + 24 * 60 * 60 * 1000);
        const tomorrowDateString = new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Kolkata' }).format(tomorrow);
        await contentGenQueue.add('prewarm-daily-challenge', { targetDate: tomorrowDateString }, {
          jobId: `prewarm:daily:${tomorrowDateString}`,
          removeOnComplete: true,
        });
        console.log(`🚀 [Cron] Enqueued pre-warming job for tomorrow's challenge (${tomorrowDateString})`);
      } catch (err) {
        console.error('❌ [Cron] Error enqueuing daily challenge pre-warming:', err);
      }
    },
    {
      timezone: 'Asia/Kolkata',
    }
  );
  console.log('⏳ Daily Challenge pre-warming cron registered (23:00 IST)');

  server.listen(ENV.PORT, () => {
    console.log(`🚀 Aptiqu Backend Server running on http://localhost:${ENV.PORT}`);
    console.log(`📡 Health Check: http://localhost:${ENV.PORT}/health`);
    console.log(`⚔️ PvP WebSocket: ws://localhost:${ENV.PORT}/ws/pvp`);
  });

  // Graceful shutdown
  const shutdown = async () => {
    console.log('\n🛑 Gracefully shutting down Aptiqu Backend...');
    server.close(async () => {
      await contentGenWorker.close();
      await contentGenQueue.close();
      await bookIngestionWorker.close();
      await bookIngestionQueue.close();
      await prisma.$disconnect();
      console.log('🔌 Database and Queues disconnected.');
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
