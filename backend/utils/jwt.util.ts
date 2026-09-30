import jwt from 'jsonwebtoken';
import crypto from 'crypto';
const loadConfig = require('./decryptConfig');

/**
 * Enterprise JWT Token Manager
 * Resolves JWT_SECRET from environment variables (Cloud Secrets / .env / config.enc)
 * Generates secure dynamic keys in production if missing.
 */

function resolveJwtSecret(): string {
    if (process.env.JWT_SECRET && process.env.JWT_SECRET.trim().length >= 16) {
        return process.env.JWT_SECRET.trim();
    }

    try {
        const config = loadConfig();
        if (config && config.JWT_SECRET && config.JWT_SECRET.trim().length >= 16) {
            return config.JWT_SECRET.trim();
        }
    } catch (error) {
        // config.enc not found on standalone local server
    }

    if (process.env.NODE_ENV === 'production') {
        console.warn('⚠️ [SECURITY WARNING] No secure JWT_SECRET environment variable provided. Using ephemeral runtime key.');
        return crypto.randomBytes(32).toString('hex');
    }

    return 'retailsale_secure_dev_jwt_secret_key_2026';
}

const jwtSecret = resolveJwtSecret();

export const sign = (payload: string | object | Buffer, options: jwt.SignOptions = { expiresIn: '1d' }): string => {
    return jwt.sign(payload, jwtSecret, options);
};

export const verify = <T = any>(token: string): T => {
    return jwt.verify(token, jwtSecret) as T;
};

module.exports = {
    sign,
    verify
};

export default {
    sign,
    verify
};
