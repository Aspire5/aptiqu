import { ENV } from './config/env';
import { RuntimeState, trackAsyncHandlers } from './runtime/lifecycle';
import { observeHttp } from './observability/http';
import { log, safeError } from './observability/logger';
import { ZodError } from 'zod';
import { authenticateJwt } from './middleware/auth.middleware';
import { authenticateAdmin } from './modules/admin/admin.middleware';
import { trustedProxy } from './security/trusted-peer';
import { requestBudget, PublicError } from './security/request-policy';
import socialRoutes from './modules/social/social.routes';
import express, { Application, Request, Response } from 'express';
import cors from 'cors';
import authRoutes from './modules/auth/auth.routes';
import userRoutes from './modules/user/user.routes';
import lessonRoutes from './modules/lesson/lesson.routes';
import roadmapRoutes from './modules/roadmap/roadmap.routes';
import practiceRoutes from './modules/practice/practice.routes';
import pvpRoutes from './modules/pvp/pvp.routes';
import dailyChallengeRoutes from './modules/daily-challenge/daily-challenge.routes';
import adminRoutes from './modules/admin/admin.routes';

export function createApp(runtime?: RuntimeState): Application {
  const app = express();

  // Explicit trusted IP ranges only; no hop-count or blanket trust behind arbitrary proxies.
  app.set('trust proxy', trustedProxy);
  app.disable('x-powered-by');
  app.use(observeHttp);
  app.use((req,res,next)=>{
    res.setHeader('X-Content-Type-Options','nosniff');res.setHeader('Referrer-Policy','no-referrer');
    res.setHeader('X-Frame-Options','DENY');res.setHeader('Content-Security-Policy',"default-src 'none'; frame-ancestors 'none'");
    if(ENV.NODE_ENV==='production' && req.secure)res.setHeader('Strict-Transport-Security','max-age=31536000');
    if(req.path==='/health'||req.path==='/ready'||req.path.startsWith('/api/v1'))res.setHeader('Cache-Control','no-store');
    next();
  });
  if(runtime)app.use(runtime.middleware);
  app.get('/health',(_req,res)=>res.status(200).json({status:'alive'}));
  app.get('/ready',(_req,res)=>res.status(!runtime||runtime.ready?200:503).json({status:!runtime||runtime.ready?'ready':'unavailable'}));
  if(ENV.BACKEND_ROLE==='jobs') {app.use((_req,res)=>res.status(404).json({success:false,code:'NOT_FOUND'}));return app;}
  app.use(cors({origin:(origin,callback)=>{
    if(!origin || (ENV.CORS_ALLOWED_ORIGINS??[]).includes(origin))callback(null,true);
    else {
      // Log only the parsed origin, never credentials, paths or arbitrary headers.
      let denied='invalid';try{denied=new URL(origin).origin;}catch{}
      log('warn','http.origin_denied',{code:'ORIGIN_DENIED',origin:denied});
      callback(new PublicError('Origin is not allowed','ORIGIN_DENIED',403));
    }
  }}));
  app.use('/api/v1', (req, res, next) => {
    res.setHeader('Cache-Control', 'no-store');
    const publicAuth = req.method === 'POST' && ['/auth/google', '/auth/refresh', '/auth/logout', '/admin/auth/login'].includes(req.path);
    if (publicAuth) { next(); return; }
    if (req.path.startsWith('/admin/')) authenticateAdmin(req, res, next);
    else authenticateJwt(req, res, next);
  });
  app.use('/api/v1', requestBudget);
  const authBody = express.json({limit:ENV.AUTH_JSON_LIMIT_BYTES??24576});
  const mobileBody = express.json({limit:ENV.MOBILE_JSON_LIMIT_BYTES??81920});
  const adminBody = express.json({limit:ENV.ADMIN_JSON_LIMIT_BYTES??8388608});
  app.use('/api/v1', (req, res, next) => {
    // Multipart bodies are streamed by authenticated Multer routes (PDF limit remains 150 MB).
    const parser = req.path.startsWith('/auth/') || req.path === '/admin/auth/login' ? authBody
      : req.path.startsWith('/admin/') ? adminBody : mobileBody;
    parser(req, res, error => {
      // Timestamp a fully received body. Header arrival would allow slow-body timing forgery.
      res.locals.receivedAt = new Date();
      next(error);
    });
  });

  // API v1 Routes
  app.use('/api/v1/auth', authRoutes);
  app.use('/api/v1/social', socialRoutes);
  app.use('/api/v1/user', userRoutes);
  app.use('/api/v1/lessons', lessonRoutes);
  app.use('/api/v1/roadmaps', roadmapRoutes);
  app.use('/api/v1/practice', practiceRoutes);
  app.use('/api/v1/pvp', pvpRoutes);
  app.use('/api/v1/daily-challenge', dailyChallengeRoutes);
  app.use('/api/v1/admin', adminRoutes);

  // 404 Handler
  app.use((_req: Request, res: Response) => {
    res.status(404).json({
      success: false,
      message: 'API route not found',
      code: 'NOT_FOUND',
    });
  });

  // Global Error Handler
  app.use((err: any, _req: Request, res: Response, _next: express.NextFunction) => {
    const status = err.type === 'entity.too.large' || err.code === 'LIMIT_FILE_SIZE' ? 413 : err.type === 'entity.parse.failed' || err instanceof ZodError || err.name === 'MulterError' ? 400 : err instanceof PublicError ? err.status : 500;
    log(status>=500?'error':'warn',status>=500?'http.unhandled':'http.rejected',{...safeError(err),status,requestId:res.getHeader('X-Request-ID')});
    if(err instanceof PublicError && (err.retryAfterSeconds || status===503))res.setHeader('Retry-After',String(err.retryAfterSeconds??3));
    res.status(status).json({
      success: false,
      message: status === 413 ? 'Request body too large' : status === 400 ? 'Invalid request' : err instanceof PublicError ? err.message : 'Internal server error',
      code: status === 413 ? 'BODY_TOO_LARGE' : status===400?'INVALID_REQUEST': err instanceof PublicError ? err.code : 'INTERNAL_SERVER_ERROR',
    });
  });

  if(runtime)trackAsyncHandlers(app._router.stack,runtime);
  return app;
}
