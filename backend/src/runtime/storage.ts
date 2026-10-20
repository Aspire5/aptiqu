import { promises as fs } from 'node:fs';
import * as path from 'node:path';
import { ENV } from '../config/env';
import { log, safeError } from '../observability/logger';
export async function prepareStorage() {
    for (const directory of [ENV.BOOK_STORAGE_ROOT, ENV.BOOK_TEMP_ROOT]) {
        await fs.mkdir(directory, { recursive: true, mode: 0o700 });
        const real = await fs.realpath(directory), cwd = await fs.realpath(process.cwd());
        if (ENV.NODE_ENV === 'production' && (real === cwd || real.startsWith(cwd + path.sep) || (await fs.stat(real)).mode & 0o077))
            throw new Error('Storage roots must be private and outside the release directory');
    }
}
export async function cleanExpiredUploads(now = Date.now()) {
    // Only this release's named temporary uploads; never source PDFs/book directories.
    const entries = await fs.readdir(ENV.BOOK_TEMP_ROOT, { withFileTypes: true });
    let removed = 0;
    for (const entry of entries.slice(0, 1000)) {
        if (!entry.isFile() || !/^upload-[a-f0-9-]{36}\.pdf$/.test(entry.name))
            continue;
        const file = path.join(ENV.BOOK_TEMP_ROOT, entry.name);
        try {
            const stat = await fs.lstat(file);
            if (stat.isFile() && !stat.isSymbolicLink() && now - stat.mtimeMs > ENV.BOOK_TEMP_RETENTION_HOURS * 3600000) {
                await fs.unlink(file);
                removed++;
            }
        }
        catch (error) {
            if ((error as NodeJS.ErrnoException).code !== 'ENOENT')
                throw error;
        }
    }
    return removed;
}
export function startTempCleanup() {
    let pending: Promise<unknown> | undefined;
    const sweep = () => { if (!pending)
        pending = cleanExpiredUploads().catch(error => log('warn', 'storage.cleanup_failed', safeError(error))).finally(() => { pending = undefined; }); };
    sweep();
    const timer = setInterval(sweep, 3600000);
    timer.unref();
    return async () => { clearInterval(timer); await pending; };
}
