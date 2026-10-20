// A cache only: never used for locks, idempotency, authorization or reveal decisions.
export class BoundedCache {
    private entries = new Map<string, {
        value: string;
        expiresAt: number;
        bytes: number;
    }>();
    private bytes = 0;
    constructor(private maxEntries = 256, private maxBytes = 8388608, private now = () => Date.now()) { }
    private remove(key: string) { const entry = this.entries.get(key); if (entry)
        this.bytes -= entry.bytes; this.entries.delete(key); }
    private sweep() { for (const [key, entry] of this.entries)
        if (entry.expiresAt <= this.now())
            this.remove(key); }
    get(key: string) { this.sweep(); const entry = this.entries.get(key); if (!entry)
        return null; this.entries.delete(key); this.entries.set(key, entry); return entry.value; }
    set(key: string, value: string, ttlSeconds = 300) {
        this.sweep();
        this.remove(key);
        const bytes = Buffer.byteLength(key) + Buffer.byteLength(value);
        if (bytes > Math.min(this.maxBytes, 1048576))
            return;
        while (this.entries.size >= this.maxEntries || this.bytes + bytes > this.maxBytes)
            this.remove(this.entries.keys().next().value!);
        this.entries.set(key, { value, bytes, expiresAt: this.now() + Math.min(300, Math.max(1, ttlSeconds)) * 1000 });
        this.bytes += bytes;
    }
    delete(key: string) { this.remove(key); }
    keys() { this.sweep(); return this.entries.keys(); }
    clear() { this.entries.clear(); this.bytes = 0; }
    get size() { this.sweep(); return this.entries.size; }
}
export class SingleFlight<T> {
    private pending = new Map<string, Promise<T>>();
    constructor(private capacity = 128) { }
    run(key: string, load: () => Promise<T>): Promise<T> {
        const previous = this.pending.get(key);
        if (previous)
            return previous;
        if (this.pending.size >= this.capacity)
            return load();
        const work = Promise.resolve().then(load).finally(() => { if (this.pending.get(key) === work)
            this.pending.delete(key); });
        this.pending.set(key, work);
        return work;
    }
}
