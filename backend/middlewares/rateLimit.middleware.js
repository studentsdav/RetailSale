const rateLimit = require('express-rate-limit');

/**
 * Standard API Rate Limiter
 * Allows up to 180 requests per minute per IP for regular POS / billing operations.
 */
const apiLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 180,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    success: false,
    message: 'Too many requests from this IP. Please wait a moment.'
  }
});

/**
 * Login & Auth Brute-Force Rate Limiter
 * Limits failed login / PIN attempts to 10 per 15 minutes per IP.
 */
const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  message: {
    success: false,
    message: 'Too many login attempts. Account temporarily locked for 15 minutes.'
  }
});

/**
 * Global DDoS Burst Limiter
 * Immediately drops aggressive bot spikes (> 300 requests in 10 seconds).
 */
const ddosBurstLimiter = rateLimit({
  windowMs: 10 * 1000,
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    success: false,
    message: 'DDoS protection triggered. Request dropped.'
  }
});

/**
 * Heavy Report & Analytics Query Limiter
 * Protects database CPU from complex aggregation spam.
 */
const reportQueryLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 30,
  message: {
    success: false,
    message: 'Report query rate limit exceeded. Please wait a moment.'
  }
});

module.exports = {
  apiLimiter,
  loginLimiter,
  ddosBurstLimiter,
  reportQueryLimiter
};
