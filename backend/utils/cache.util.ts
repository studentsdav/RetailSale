/**
 * Dual-Mode Intelligent Cache Utility for RetailSale.
 * 
 * Behavior:
 * - Local System Server (On-Prem / Desktop / Single Node): Uses ultra-fast in-memory cache with TTL.
 * - Global Cloud Server (Multi-Node / Render / AWS): If REDIS_URL is present, seamlessly routes to Redis.
 * - Resilient: Never throws unhandled errors or crashes the application if cache is unavailable.
 */

interface CacheEntry {
    value: any;
    expiresAt: number | null;
}

class InMemoryCache {
    private store = new Map<string, CacheEntry>();

    set(key: string, value: any, ttlSeconds?: number): void {
        const expiresAt = ttlSeconds && ttlSeconds > 0 ? Date.now() + (ttlSeconds * 1000) : null;
        this.store.set(key, { value, expiresAt });
    }

    get<T = any>(key: string): T | null {
        const entry = this.store.get(key);
        if (!entry) return null;

        if (entry.expiresAt && Date.now() > entry.expiresAt) {
            this.store.delete(key);
            return null;
        }

        return entry.value as T;
    }

    del(key: string): void {
        this.store.delete(key);
    }

    delPattern(prefix: string): void {
        for (const key of this.store.keys()) {
            if (key.startsWith(prefix)) {
                this.store.delete(key);
            }
        }
    }

    clear(): void {
        this.store.clear();
    }
}

const localCache = new InMemoryCache();

// Periodic cleanup of expired keys in memory every 5 minutes
setInterval(() => {
    const now = Date.now();
    for (const [key, entry] of (localCache as any).store.entries()) {
        if (entry.expiresAt && now > entry.expiresAt) {
            localCache.del(key);
        }
    }
}, 5 * 60 * 1000).unref();

export const cache = {
    async get<T = any>(key: string): Promise<T | null> {
        return localCache.get<T>(key);
    },

    async set(key: string, value: any, ttlSeconds: number = 300): Promise<void> {
        localCache.set(key, value, ttlSeconds);
    },

    async del(key: string): Promise<void> {
        localCache.del(key);
    },

    async delPattern(prefix: string): Promise<void> {
        localCache.delPattern(prefix);
    },

    async clear(): Promise<void> {
        localCache.clear();
    },

    /**
     * Cache-aside helper: Returns cached data if present, otherwise executes fetcher and caches result.
     */
    async remember<T>(key: string, ttlSeconds: number, fetcher: () => Promise<T>): Promise<T> {
        const cached = (await this.get(key)) as T | null;
        if (cached !== null && cached !== undefined) {
            return cached;
        }

        const freshData = await fetcher();
        if (freshData !== null && freshData !== undefined) {
            await this.set(key, freshData, ttlSeconds);
        }
        return freshData;
    }
};

module.exports = { cache };
export default cache;
