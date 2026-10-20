import { monitorEventLoopDelay } from 'node:perf_hooks';
import { log } from '../observability/logger';
import { RuntimeState } from './lifecycle';
export function startTelemetry(state: RuntimeState, role: string) {
    const delay = monitorEventLoopDelay({ resolution: 20 });
    delay.enable();
    const timer = setInterval(() => {
        const memory = process.memoryUsage();
        log('info', 'runtime.resources', { role, activeRequests: state.activeRequests, rssBytes: memory.rss, heapBytes: memory.heapUsed, eventLoopDelayMs: Math.round(delay.percentile(99) / 1e6), uptimeSeconds: Math.floor(process.uptime()) });
        delay.reset();
    }, 60000);
    timer.unref();
    return () => { clearInterval(timer); delay.disable(); };
}
