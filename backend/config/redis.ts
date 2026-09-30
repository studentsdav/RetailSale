import { cache } from '../utils/cache.util';

/**
 * Resilient Cache & Redis Connector
 * If Redis environment variables are defined, provides Redis access;
 * otherwise provides automatic in-memory caching fallback for local servers.
 */

export const isRedisEnabled = (): boolean => {
    return Boolean(process.env.REDIS_URL || process.env.REDIS_HOST);
};

export { cache };
export default cache;
