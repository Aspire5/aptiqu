import express, { Application, Request, Response } from 'express';
import cors from 'cors';
import authRoutes from './modules/auth/auth.routes';
import userRoutes from './modules/user/user.routes';
import lessonRoutes from './modules/lesson/lesson.routes';
import roadmapRoutes from './modules/roadmap/roadmap.routes';

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

  // 404 Handler
  app.use((_req: Request, res: Response) => {
    res.status(404).json({
      success: false,
      message: 'API route not found',
    });
  });

  return app;
}
