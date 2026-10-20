// Deliberately allowlist metadata; never serialize arbitrary Error objects or payloads.
const levels = { debug: 10, info: 20, warn: 30, error: 40 };
const fields = new Set(['requestId', 'method', 'route', 'status', 'durationMs', 'code', 'type', 'role', 'event', 'activeRequests', 'rssBytes', 'heapBytes', 'eventLoopDelayMs', 'uptimeSeconds']);
export function safeError(error: unknown) {
    const value = error as {
        name?: unknown;
        code?: unknown;
    };
    const names = new Set(['Error', 'TypeError', 'RangeError', 'SyntaxError', 'PublicError', 'PvpError', 'ZodError', 'AbortError', 'PrismaClientKnownRequestError', 'PrismaClientUnknownRequestError', 'PrismaClientInitializationError', 'PrismaClientValidationError']);
    const codes = new Set(['ECONNREFUSED', 'ECONNRESET', 'ETIMEDOUT', 'ENOSPC', 'EACCES', 'AI_UNAVAILABLE', 'AI_BUDGET_EXCEEDED', 'QUEUE_UNAVAILABLE', 'SCHEMA_INCOMPATIBLE', 'DATABASE_POOL_BUDGET_EXCEEDED', 'RUNTIME_OWNER_CONFLICT', 'DEPENDENCY_TIMEOUT', 'RUNTIME_UNSUPPORTED']);
    return { type: typeof value?.name === 'string' && names.has(value.name) ? value.name : 'Error',
        code: typeof value?.code === 'string' && (/^P\d{4}$/.test(value.code) || codes.has(value.code)) ? value.code : undefined };
}
export function log(level: keyof typeof levels, event: string, metadata: Record<string, unknown> = {}) {
    const configured = process.env.LOG_LEVEL as keyof typeof levels;
    if (levels[level] < (levels[configured] ?? levels.info))
        return;
    const safe = Object.fromEntries(Object.entries(metadata).filter(([key, value]) => fields.has(key) && (typeof value === 'number' && Number.isFinite(value) || typeof value === 'string' && value.length <= 200)));
    const record = JSON.stringify({ time: new Date().toISOString(), level, event: event.replace(/[^\w.-]/g, '_').slice(0, 100), ...safe });
    if (level === 'error')
        console.error(record);
    else if (level === 'warn')
        console.warn(record);
    else
        console.log(record);
}
