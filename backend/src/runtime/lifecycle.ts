import type { RequestHandler } from 'express';
export function deadline<T>(work: Promise<T>, ms: number, label: string): Promise<T> {
    let timer: NodeJS.Timeout;
    return Promise.race([work, new Promise<never>((_, reject) => { timer = setTimeout(() => reject(Object.assign(new Error(`${label} timed out`), { code: 'DEPENDENCY_TIMEOUT' })), ms); })])
        .finally(() => clearTimeout(timer));
}
export class RuntimeState {
    phase: 'starting' | 'ready' | 'draining' | 'stopped' = 'starting';
    dependenciesReady = false;
    activeRequests = 0;
    private work = new Set<Promise<unknown>>();
    private idle = new Set<() => void>();
    get ready() { return this.phase === 'ready' && this.dependenciesReady; }
    drain() { this.phase = 'draining'; }
    middleware: RequestHandler = (req, res, next) => {
        if (req.path === '/health' || req.path === '/ready') {
            next();
            return;
        }
        if (!this.ready) {
            res.setHeader('Retry-After', '3');
            res.setHeader('Connection', 'close');
            res.status(503).json({ success: false, code: 'SERVICE_UNAVAILABLE', message: 'Service temporarily unavailable. Retry shortly.' });
            return;
        }
        this.activeRequests++;
        let finished = false;
        const finish = () => { if (finished)
            return; finished = true; this.activeRequests--; this.resolveIdle(); };
        res.once('finish', finish);
        res.once('close', finish);
        next();
    };
    private resolveIdle() { if (!this.activeRequests && !this.work.size) {
        for (const resolve of this.idle)
            resolve();
        this.idle.clear();
    } }
    track<T>(promise: Promise<T>): Promise<T> {
        const pending = promise.finally(() => { this.work.delete(pending); this.resolveIdle(); });
        this.work.add(pending);
        return pending;
    }
    async waitForIdle() { if (this.activeRequests || this.work.size)
        await new Promise<void>(resolve => this.idle.add(resolve)); }
}
// Express 4 does not await async handlers. Keep their work owned even if a client
// disconnects before a transaction finishes, and forward rejected handlers safely.
export function trackAsyncHandlers(stack: any[], state: RuntimeState) {
    for (const layer of stack ?? []) {
        if (layer.route?.stack)
            trackAsyncHandlers(layer.route.stack, state);
        else if (layer.handle?.stack)
            trackAsyncHandlers(layer.handle.stack, state);
        else if (typeof layer.handle === 'function' && layer.handle.length < 4) {
            const original = layer.handle;
            layer.handle = function (req: unknown, res: unknown, next: (error?: unknown) => void) {
                const result = original.call(this, req, res, next);
                if (result && typeof result.then === 'function')
                    void state.track(Promise.resolve(result)).catch(next);
                return result;
            };
        }
    }
}
export function shutdownOnce(state: RuntimeState, steps: Array<() => Promise<unknown> | unknown>, timeoutMs: number, onTimeout: () => void) {
    let pending: Promise<void> | undefined;
    return () => pending ??= (async () => {
        state.drain();
        const timer = setTimeout(onTimeout, timeoutMs);
        try {
            for (const step of steps)
                await step();
            state.phase = 'stopped';
        }
        finally {
            clearTimeout(timer);
        }
    })();
}
export function roleCapabilities(role: 'combined' | 'http' | 'realtime' | 'jobs') {
    return { api: role !== 'jobs', realtime: role === 'combined' || role === 'realtime', jobs: role === 'combined' || role === 'jobs' };
}
