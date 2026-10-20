import * as path from 'node:path';
import { isIP } from 'node:net';
type Source = Record<string, string | undefined>;
export const configError = (key: string): never => { throw new Error(`Invalid configuration: ${key}`); };
export function integer(source: Source, key: string, fallback: number, min: number, max: number) {
    const raw = source[key];
    const value = raw === undefined ? fallback : /^\d+$/.test(raw) ? Number(raw) : NaN;
    if (!Number.isSafeInteger(value) || value < min || value > max)
        return configError(key);
    return value;
}
export function flag(source: Source, key: string, fallback = false) {
    if (source[key] === undefined)
        return fallback;
    if (!['true', 'false'].includes(source[key]!))
        return configError(key);
    return source[key] === 'true';
}
export function tokenDuration(source: Source, key: string, fallback: string) {
    const value = source[key] ?? fallback;
    const match = /^(\d+)(s|m|h|d)$/.exec(value);
    const ms = match ? Number(match[1]) * ({ s: 1000, m: 60000, h: 3600000, d: 86400000 }[match[2]]!) : NaN;
    if (!Number.isSafeInteger(ms) || ms <= 0 || ms > 366 * 86400000)
        return configError(key);
    return value;
}
export function redisUrl(value: string) {
    try {
        const url = new URL(value);
        if (!['redis:', 'rediss:'].includes(url.protocol) || !url.hostname || url.search || url.hash || !/^\/(?:\d+)?$/.test(url.pathname || '/'))
            return configError('REDIS_URL');
        return value;
    }
    catch {
        return configError('REDIS_URL');
    }
}
export function readRankedConfig(source: Source = process.env) {
    const admission = flag(source, 'RANKED_ADMISSION_ENABLED');
    const reads = flag(source, 'RANKED_LEAGUES_READ_ENABLED');
    const skill = flag(source, 'RANKED_SKILL_MATCHMAKING_ENABLED');
    const launch = source.RANKED_LAUNCH_SEASON || undefined;
    if (launch && !/^\d{4}-(0[1-9]|1[0-2])$/.test(launch))
        return configError('RANKED_LAUNCH_SEASON');
    if (admission && (!launch || !reads || !skill))
        return configError('RANKED_ADMISSION_ENABLED');
    const secret = source.RANKED_CURSOR_SECRET || '';
    if (reads && (Buffer.byteLength(secret) < 32 || secret === source.JWT_ACCESS_SECRET || secret === source.ADMIN_JWT_SECRET))
        return configError('RANKED_CURSOR_SECRET');
    const narrowWindow = integer(source, 'RANKED_QUEUE_NARROW_WINDOW', 100, 1, 400);
    const maximumWindow = integer(source, 'RANKED_QUEUE_MAXIMUM_WINDOW', 600, 100, 1600);
    if (maximumWindow < narrowWindow)
        return configError('RANKED_QUEUE_MAXIMUM_WINDOW');
    return { admission, reads, skill, launch, secret, drain: flag(source, 'RANKED_ADMISSION_DRAIN'), narrowWindow, maximumWindow,
        expandEveryMs: integer(source, 'RANKED_QUEUE_EXPAND_INTERVAL_MS', 15000, 5000, 60000), expandBy: integer(source, 'RANKED_QUEUE_EXPAND_BY', 50, 1, 200) };
}
export function parseRuntimeConfig(source: Source, cwd: string) {
    const required = (key: string) => source[key]?.trim() || configError(key);
    const mode = source.NODE_ENV ?? 'development';
    if (!['development', 'test', 'production'].includes(mode))
        return configError('NODE_ENV');
    const host = source.HOST ?? '127.0.0.1';
    if (!/^[a-zA-Z0-9.:-]{1,253}$/.test(host))
        return configError('HOST');
    const production = mode === 'production';
    const role = source.BACKEND_ROLE ?? 'combined';
    if (!['combined', 'http', 'realtime', 'jobs'].includes(role))
        return configError('BACKEND_ROLE');
    const root = (key: string, fallback: string) => {
        const value = source[key] ?? (production ? required(key) : path.resolve(cwd, fallback));
        if (!path.isAbsolute(value) || (production && (path.resolve(value) === cwd || path.resolve(value).startsWith(cwd + path.sep))))
            return configError(key);
        return path.resolve(value);
    };
    const database = required('DATABASE_URL');
    let url: URL;
    try {
        url = new URL(database);
    }
    catch {
        return configError('DATABASE_URL');
    }
    if (!['postgres:', 'postgresql:'].includes(url.protocol) || !url.hostname || url.pathname.length < 2)
        return configError('DATABASE_URL');
    for (const key of ['connection_limit', 'pool_timeout', 'connect_timeout']) {
        const values = url.searchParams.getAll(key);
        if (values.length > 1)
            return configError(`DATABASE_URL.${key}`);
        if (!values.length && production && key !== 'connect_timeout')
            return configError(`DATABASE_URL.${key}`);
        const defaults = { connection_limit: 5, pool_timeout: 10, connect_timeout: 3 };
        const value = integer({ [key]: values[0] }, key, defaults[key as keyof typeof defaults], 1, key === 'connection_limit' ? 50 : 60);
        url.searchParams.set(key, String(value));
    }
    if (production) {
        required('DATABASE_CONNECTION_BUDGET');
        required('DATABASE_PROCESS_COUNT');
        required('REDIS_URL');
    }
    const budget = integer(source, 'DATABASE_CONNECTION_BUDGET', 20, 1, 1000);
    const processes = integer(source, 'DATABASE_PROCESS_COUNT', 1, 1, 64);
    if (Number(url.searchParams.get('connection_limit')) * processes > budget)
        return configError('DATABASE_CONNECTION_BUDGET');
    const access = required('JWT_ACCESS_SECRET'), admin = required('ADMIN_JWT_SECRET');
    if (access === admin || production && [access, admin].some(value => Buffer.byteLength(value) < 32 || /replace_with|your_.*secret/i.test(value)))
        return configError('JWT_ACCESS_SECRET/ADMIN_JWT_SECRET');
    const origins = (source.CORS_ALLOWED_ORIGINS ?? '').split(',').map(v => v.trim()).filter(Boolean);
    for (const value of origins) {
        try {
            const origin = new URL(value);
            if (!['http:', 'https:'].includes(origin.protocol) || origin.origin !== value)
                return configError('CORS_ALLOWED_ORIGINS');
        }
        catch {
            return configError('CORS_ALLOWED_ORIGINS');
        }
    }
    const trust = source.TRUST_PROXY ?? '';
    for (const cidr of trust.split(',').map(v => v.trim()).filter(Boolean)) {
        const [ip, bits, ...extra] = cidr.split('/');
        const family = isIP(ip);
        if (!family || extra.length || bits !== undefined && (!/^\d+$/.test(bits) || +bits > (family === 4 ? 32 : 128)))
            return configError('TRUST_PROXY');
    }
    const google = flag(source, 'GOOGLE_AUTH_ENABLED', true);
    const audiences = ['GOOGLE_WEB_CLIENT_ID', 'GOOGLE_ANDROID_CLIENT_ID', 'GOOGLE_IOS_CLIENT_ID'].map(key => source[key]?.trim() || '');
    if (google && !audiences.some(Boolean))
        return configError('GOOGLE_*_CLIENT_ID');
    const ai = flag(source, 'AI_GENERATION_ENABLED', Boolean(source.GEMINI_API_KEY?.trim()));
    if (ai)
        required('GEMINI_API_KEY');
    const bookRoot = root('BOOK_STORAGE_ROOT', 'storage/books'), tempRoot = root('BOOK_TEMP_ROOT', 'storage/temp');
    if (bookRoot === tempRoot || bookRoot.startsWith(tempRoot + path.sep) || tempRoot.startsWith(bookRoot + path.sep))
        return configError('BOOK_STORAGE_ROOT/BOOK_TEMP_ROOT');
    const curriculum = source.CURRICULUM_SOURCE_ROOT ?? path.resolve(cwd, '../books/SubTopics');
    if (!path.isAbsolute(curriculum))
        return configError('CURRICULUM_SOURCE_ROOT');
    const ranked = readRankedConfig(source);
    return {
        NODE_ENV: mode, BACKEND_ROLE: role as 'combined' | 'http' | 'realtime' | 'jobs', HOST: host, PORT: integer(source, 'PORT', 5001, 1, 65535),
        DATABASE_URL: url.toString(), DATABASE_CONNECTION_BUDGET: budget, DATABASE_PROCESS_COUNT: processes,
        JWT_ACCESS_SECRET: access, ADMIN_JWT_SECRET: admin, ADMIN_USERNAME: required('ADMIN_USERNAME'), ADMIN_PASSWORD: required('ADMIN_PASSWORD'),
        JWT_ISSUER: source.JWT_ISSUER || 'aptiqu', JWT_AUDIENCE: source.JWT_AUDIENCE || 'aptiqu-mobile', TRUST_PROXY: trust,
        JWT_ACCESS_EXPIRATION: tokenDuration(source, 'JWT_ACCESS_EXPIRATION', '15m'), JWT_REFRESH_EXPIRATION: tokenDuration(source, 'JWT_REFRESH_EXPIRATION', '7d'), ADMIN_JWT_EXPIRATION: tokenDuration(source, 'ADMIN_JWT_EXPIRATION', '24h'),
        GOOGLE_AUTH_ENABLED: google, GOOGLE_WEB_CLIENT_ID: audiences[0], GOOGLE_ANDROID_CLIENT_ID: audiences[1], GOOGLE_IOS_CLIENT_ID: audiences[2],
        GOOGLE_WEB_CLIENT_SECRET: source.GOOGLE_WEB_CLIENT_SECRET || '', REDIS_URL: redisUrl(source.REDIS_URL ?? 'redis://127.0.0.1:6379'),
        AI_GENERATION_ENABLED: ai, GEMINI_API_KEY: source.GEMINI_API_KEY || '', GEMINI_MODEL: source.GEMINI_MODEL?.trim() || 'gemini-3.5-flash-lite', GEMINI_THINKING_BUDGET: integer(source, 'GEMINI_THINKING_BUDGET', 0, 0, 32768),
        CORS_ALLOWED_ORIGINS: origins, AUTH_JSON_LIMIT_BYTES: integer(source, 'AUTH_JSON_LIMIT_BYTES', 24576, 1024, 65536), MOBILE_JSON_LIMIT_BYTES: integer(source, 'MOBILE_JSON_LIMIT_BYTES', 81920, 4096, 262144), ADMIN_JSON_LIMIT_BYTES: integer(source, 'ADMIN_JSON_LIMIT_BYTES', 8388608, 65536, 16777216),
        READINESS_TIMEOUT_MS: integer(source, 'READINESS_TIMEOUT_MS', 5000, 1000, 30000), SHUTDOWN_TIMEOUT_MS: integer(source, 'SHUTDOWN_TIMEOUT_MS', 30000, 1000, 300000), HTTP_REQUEST_TIMEOUT_MS: integer(source, 'HTTP_REQUEST_TIMEOUT_MS', 300000, 1000, 600000),
        CONTENT_WORKER_CONCURRENCY: integer(source, 'CONTENT_WORKER_CONCURRENCY', 2, 1, 4), SOCIAL_WORKER_CONCURRENCY: integer(source, 'SOCIAL_WORKER_CONCURRENCY', 20, 1, 50), QUEUE_FAILED_RETENTION_COUNT: integer(source, 'QUEUE_FAILED_RETENTION_COUNT', 500, 1, 5000), QUEUE_FAILED_RETENTION_SECONDS: integer(source, 'QUEUE_FAILED_RETENTION_SECONDS', 604800, 3600, 2592000),
        BOOK_STORAGE_ROOT: bookRoot, BOOK_TEMP_ROOT: tempRoot, CURRICULUM_SOURCE_ROOT: curriculum, BOOK_UPLOAD_MAX_BYTES: integer(source, 'BOOK_UPLOAD_MAX_BYTES', 157286400, 1024, 157286400), BOOK_MAX_PAGES: integer(source, 'BOOK_MAX_PAGES', 2000, 1, 5000), BOOK_MAX_EXTRACTED_TEXT_BYTES: integer(source, 'BOOK_MAX_EXTRACTED_TEXT_BYTES', 33554432, 1024, 134217728), BOOK_TEMP_RETENTION_HOURS: integer(source, 'BOOK_TEMP_RETENTION_HOURS', 24, 1, 168),
        LOCAL_CACHE_MAX_ENTRIES: integer(source, 'LOCAL_CACHE_MAX_ENTRIES', 256, 1, 10000), LOCAL_CACHE_MAX_BYTES: integer(source, 'LOCAL_CACHE_MAX_BYTES', 8388608, 1024, 67108864),
        LOG_LEVEL: ['debug', 'info', 'warn', 'error'].includes(source.LOG_LEVEL ?? 'info') ? source.LOG_LEVEL ?? 'info' : configError('LOG_LEVEL'), RANKED: ranked,
    };
}
export function parseAiLimits(source: Source) {
    return {
        concurrency: integer(source, 'AI_MAX_CONCURRENT', 2, 1, 8), requestsPerMinute: integer(source, 'AI_REQUESTS_PER_MINUTE', 12, 1, 1000), tokensPerDay: integer(source, 'AI_TOKENS_PER_DAY', 1000000, 1000, 100000000), maxOutputTokens: integer(source, 'AI_MAX_OUTPUT_TOKENS', 16384, 1024, 65536), timeoutMs: integer(source, 'AI_TIMEOUT_MS', 120000, 1000, 300000),
    };
}
