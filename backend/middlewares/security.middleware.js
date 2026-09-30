/**
 * Production Security Headers Middleware
 * Protects against XSS, Clickjacking, MIME sniffing, and enforces HSTS.
 * Zero external dependencies required - works on both Local and Cloud servers.
 */
function securityHeadersMiddleware(req, res, next) {
    res.setHeader('X-Frame-Options', 'SAMEORIGIN');
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('X-XSS-Protection', '1; mode=block');
    res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');

    if (req.secure || req.headers['x-forwarded-proto'] === 'https') {
        res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains; preload');
    }

    res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');
    next();
}

module.exports = { securityHeadersMiddleware };
