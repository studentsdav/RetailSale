const crypto = require('crypto');

const ALGORITHM = 'aes-256-gcm';
const SECRET_KEY = process.env.ENCRYPTION_SECRET || process.env.BACKUP_SECRET || 'whatsapp_integration_fallback_secret_key_123';

function getEncryptionKey() {
    // Standardize key size to 32 bytes using SHA-256 hash
    return crypto.createHash('sha256').update(SECRET_KEY).digest();
}

/**
 * Encrypt a text string using AES-256-GCM
 * Returns string format: ivHex:encryptedHex:authTagHex
 */
function encrypt(text) {
    if (!text) return null;
    try {
        const iv = crypto.randomBytes(12); // GCM standard IV is 12 bytes
        const key = getEncryptionKey();
        const cipher = crypto.createCipheriv(ALGORITHM, key, iv);
        
        let encrypted = cipher.update(text, 'utf8', 'hex');
        encrypted += cipher.final('hex');
        
        const tag = cipher.getAuthTag().toString('hex');
        return `${iv.toString('hex')}:${encrypted}:${tag}`;
    } catch (err) {
        console.error('[CRYPTO ERROR] Encryption failed:', err.message);
        throw new Error('Encryption failed: ' + err.message);
    }
}

/**
 * Decrypt an AES-256-GCM encrypted string
 * Input format: ivHex:encryptedHex:authTagHex
 */
function decrypt(encryptedText) {
    if (!encryptedText) return null;
    try {
        const parts = encryptedText.split(':');
        if (parts.length !== 3) {
            throw new Error('Invalid encrypted format (expected 3 parts)');
        }
        
        const iv = Buffer.from(parts[0], 'hex');
        const encrypted = parts[1];
        const tag = Buffer.from(parts[2], 'hex');
        
        const key = getEncryptionKey();
        const decipher = crypto.createDecipheriv(ALGORITHM, key, iv);
        decipher.setAuthTag(tag);
        
        let decrypted = decipher.update(encrypted, 'hex', 'utf8');
        decrypted += decipher.final('utf8');
        
        return decrypted;
    } catch (err) {
        console.error('[CRYPTO ERROR] Decryption failed:', err.message);
        return null; // Safe fallback
    }
}

module.exports = {
    encrypt,
    decrypt
};
