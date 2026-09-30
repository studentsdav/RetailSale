import bcrypt from 'bcryptjs';

/**
 * Enterprise Password & PIN Hashing Utility
 * Standardizes Bcrypt salt cost (12 rounds) across all user creations and PIN updates.
 */

const SALT_ROUNDS = 12;

export async function hashPassword(plainText: string): Promise<string> {
    if (!plainText) {
        throw new Error('Cannot hash empty password or PIN.');
    }
    return bcrypt.hash(plainText, SALT_ROUNDS);
}

export async function comparePassword(plainText: string, hashed: string): Promise<boolean> {
    if (!plainText || !hashed) {
        return false;
    }
    return bcrypt.compare(plainText, hashed);
}

module.exports = {
    SALT_ROUNDS,
    hashPassword,
    comparePassword
};

export default {
    SALT_ROUNDS,
    hashPassword,
    comparePassword
};
