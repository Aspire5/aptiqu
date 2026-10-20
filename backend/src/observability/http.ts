import { performance } from 'node:perf_hooks';
import { randomUUID } from 'node:crypto';
import type { RequestHandler } from 'express';
import { log } from './logger';
export const observeHttp: RequestHandler = (req, res, next) => {
    const start = performance.now();
    const requestId = randomUUID(); // Never trust a client-controlled logging identifier.
    res.setHeader('X-Request-ID', requestId);
    res.on('finish', () => {
        const route = typeof req.route?.path === 'string' ? req.route.path : 'unmatched';
        log(res.statusCode >= 500 ? 'error' : res.statusCode >= 400 ? 'warn' : 'info', 'http.request', {
            requestId, method: req.method, route, status: res.statusCode, durationMs: Math.round(performance.now() - start),
        });
    });
    next();
};
