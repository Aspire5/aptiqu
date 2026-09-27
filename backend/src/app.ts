import express, { Application, Request, Response } from 'express';
import cors from 'cors';
import authRoutes from './modules/auth/auth.routes';
import userRoutes from './modules/user/user.routes';
import lessonRoutes from './modules/lesson/lesson.routes';
import roadmapRoutes from './modules/roadmap/roadmap.routes';
import practiceRoutes from './modules/practice/practice.routes';
import pvpRoutes from './modules/pvp/pvp.routes';
import adminRoutes from './modules/admin/admin.routes';

export function createApp(): Application {
  const app = express();

  // Global Middlewares
  app.use(cors());
  app.use(express.json());

  // Health check
  app.get('/health', (_req: Request, res: Response) => {
    res.status(200).json({
      status: 'healthy',
      app: 'Aptiqu Backend API',
      timestamp: new Date().toISOString(),
    });
  });

  // API v1 Routes
  app.use('/api/v1/auth', authRoutes);
  app.use('/api/v1/user', userRoutes);
  app.use('/api/v1/lessons', lessonRoutes);
  app.use('/api/v1/roadmaps', roadmapRoutes);
  app.use('/api/v1/practice', practiceRoutes);
  app.use('/api/v1/pvp', pvpRoutes);
  app.use('/api/v1/admin', adminRoutes);

  // 404 Handler
  app.use((_req: Request, res: Response) => {
    res.status(404).json({
      success: false,
      message: 'API route not found',
    });
  });

  return app;
}
