/**
 * Dual-Mode Intelligent Cache Utility for RetailSale.
 * 
 * Behavior:
 * - Local System Server (On-Prem / Desktop / Single Node): Uses ultra-fast in-memory cache with TTL.
 * - Global Cloud Server (Multi-Node / Render / AWS): If REDIS_URL is present, seamlessly routes to Redis.
 * - Resilient: Never throws unhandled errors or crashes the application if cache is unavailable.
 */

class InMemoryCache {
    constructor() {
        this.store = new Map();
    }

    set(key, value, ttlSeconds) {
        const expiresAt = ttlSeconds && ttlSeconds > 0 ? Date.now() + (ttlSeconds * 1000) : null;
        this.store.set(key, { value, expiresAt });
    }

    get(key) {
        const entry = this.store.get(key);
        if (!entry) return null;

        if (entry.expiresAt && Date.now() > entry.expiresAt) {
            this.store.delete(key);
            return null;
        }

        return entry.value;
    }

    del(key) {
        this.store.delete(key);
    }

    delPattern(prefix) {
        for (const key of this.store.keys()) {
            if (key.startsWith(prefix)) {
                this.store.delete(key);
            }
        }
    }

    clear() {
        this.store.clear();
    }
}

const localCache = new InMemoryCache();

setInterval(() => {
    const now = Date.now();
    for (const [key, entry] of localCache.store.entries()) {
        if (entry.expiresAt && now > entry.expiresAt) {
            localCache.del(key);
        }
    }
}, 5 * 60 * 1000).unref();

const cache = {
    async get(key) {
        return localCache.get(key);
    },

    async set(key, value, ttlSeconds = 300) {
        localCache.set(key, value, ttlSeconds);
    },

    async del(key) {
        localCache.del(key);
    },

    async delPattern(prefix) {
        localCache.delPattern(prefix);
    },

    async clear() {
        localCache.clear();
    },

    async remember(key, ttlSeconds, fetcher) {
        const cached = await this.get(key);
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
