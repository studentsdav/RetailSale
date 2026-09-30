import { Request, Response, NextFunction } from 'express';

/**
 * Production Security Headers Middleware
 * Protects against XSS, Clickjacking, MIME sniffing, and enforces HSTS.
 * Zero external dependencies required - works on both Local and Cloud servers.
 */
export function securityHeadersMiddleware(req: Request, res: Response, next: NextFunction): void {
    // Prevent Clickjacking
    res.setHeader('X-Frame-Options', 'SAMEORIGIN');

    // Prevent MIME-type sniffing
    res.setHeader('X-Content-Type-Options', 'nosniff');

    // Enable browser XSS filter
    res.setHeader('X-XSS-Protection', '1; mode=block');

    // Strict Referrer Policy
    res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');

    // Enforce HSTS (Strict-Transport-Security) in HTTPS/Cloud environments
    if (req.secure || req.headers['x-forwarded-proto'] === 'https') {
        res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains; preload');
    }

    // Cross-Origin Resource Policy
    res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');

    next();
}

module.exports = { securityHeadersMiddleware };
export default securityHeadersMiddleware;
