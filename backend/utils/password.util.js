const bcrypt = require('bcryptjs');

/**
 * Enterprise Password & PIN Hashing Utility
 * Standardizes Bcrypt salt cost (12 rounds) across all user creations and PIN updates.
 */

const SALT_ROUNDS = 12;

async function hashPassword(plainText) {
    if (!plainText) {
        throw new Error('Cannot hash empty password or PIN.');
    }
    return bcrypt.hash(plainText, SALT_ROUNDS);
}

async function comparePassword(plainText, hashed) {
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
