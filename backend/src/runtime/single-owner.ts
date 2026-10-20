import { randomUUID } from 'node:crypto';
import type Redis from 'ioredis';
const renewScript = "if redis.call('GET',KEYS[1])==ARGV[1] then return redis.call('PEXPIRE',KEYS[1],ARGV[2]) else return 0 end";
const releaseScript = "if redis.call('GET',KEYS[1])==ARGV[1] then return redis.call('DEL',KEYS[1]) else return 0 end";
// Runtime exclusivity only. Domain transactions/leases remain authoritative for commits.
export async function acquireRuntimeOwner(client: Redis, role: 'realtime' | 'jobs', onLost: () => void, ttlMs = 15000) {
    const key = `aptiqu:runtime-owner:${role}`, token = randomUUID();
    if (await client.set(key, token, 'PX', ttlMs, 'NX') !== 'OK')
        throw Object.assign(new Error(`Runtime owner already active: ${role}`), { code: 'RUNTIME_OWNER_CONFLICT' });
    let stopped = false, running: Promise<void> | undefined;
    const renew = async () => {
        if (stopped || running)
            return;
        running = (async () => {
            try {
                if (await client.eval(renewScript, 1, key, token, ttlMs) !== 1)
                    throw new Error('Owner replaced');
            }
            catch {
                if (!stopped) {
                    stopped = true;
                    clearInterval(timer);
                    onLost();
                }
            }
        })();
        try {
            await running;
        }
        finally {
            running = undefined;
        }
    };
    const timer = setInterval(() => void renew(), Math.floor(ttlMs / 3));
    timer.unref();
    return async () => { stopped = true; clearInterval(timer); await running; await client.eval(releaseScript, 1, key, token).catch(() => { }); };
}
