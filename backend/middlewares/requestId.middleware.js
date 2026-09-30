const crypto = require('crypto');

/**
 * Request Correlation ID Middleware
 * Tags every HTTP request with a unique ID for end-to-end tracing across Flutter & Backend logs.
 */
function requestIdMiddleware(req, res, next) {
    const incomingId = req.headers['x-request-id'];
    const requestId = incomingId || `req_${Date.now()}_${crypto.randomBytes(4).toString('hex')}`;

    req.id = requestId;
    res.setHeader('X-Request-ID', requestId);

    next();
}

module.exports = { requestIdMiddleware };
