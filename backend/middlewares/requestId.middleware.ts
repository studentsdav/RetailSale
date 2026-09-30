import { Request, Response, NextFunction } from 'express';
import crypto from 'crypto';

/**
 * Request Correlation ID Middleware
 * Tags every HTTP request with a unique ID for end-to-end tracing across Flutter & Backend logs.
 */
export function requestIdMiddleware(req: Request, res: Response, next: NextFunction): void {
    const incomingId = req.headers['x-request-id'] as string;
    const requestId = incomingId || `req_${Date.now()}_${crypto.randomBytes(4).toString('hex')}`;

    (req as any).id = requestId;
    res.setHeader('X-Request-ID', requestId);

    next();
}

module.exports = { requestIdMiddleware };
export default requestIdMiddleware;
