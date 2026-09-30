const { cache } = require('../utils/cache.util');

/**
 * POS Checkout Idempotency Guard Middleware
 * Prevents double-billing and duplicate invoices caused by cashier double-clicks or unstable retail store WiFi.
 */
function idempotencyMiddleware(ttlSeconds = 120) {
    return async (req, res, next) => {
        if (req.method !== 'POST' && req.method !== 'PUT') {
            return next();
        }

        const idempotencyKey = (
            req.headers['idempotency-key'] ||
            req.headers['x-idempotency-key'] ||
            req.body?.idempotency_key ||
            req.body?.client_transaction_id
        );

        if (!idempotencyKey) {
            return next();
        }

        const outletId = req.user?.outlet_id || req.outlet_id || 'global';
        const cacheKey = `idempotency:${outletId}:${idempotencyKey}`;

        try {
            const cachedResponse = await cache.get(cacheKey);

            if (cachedResponse) {
                console.log(`🛡️ [IDEMPOTENCY] Replaying duplicate request for key [${idempotencyKey}]`);
                res.setHeader('X-Idempotent-Replay', 'true');
                return res.status(cachedResponse.statusCode || 200).json(cachedResponse.data);
            }

            const originalJson = res.json.bind(res);

            res.json = function (data) {
                if (res.statusCode >= 200 && res.statusCode < 300) {
                    cache.set(cacheKey, { statusCode: res.statusCode, data }, ttlSeconds).catch(() => {});
                }
                return originalJson(data);
            };

            next();
        } catch (err) {
            console.warn(`[IDEMPOTENCY] Cache lookup error: ${err.message}. Proceeding with request.`);
            next();
        }
    };
}

module.exports = { idempotencyMiddleware };
