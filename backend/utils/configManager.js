// modules/configManager.js
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const rootDir = process.pkg ? path.dirname(process.execPath) : process.cwd();
// This must match EXACTLY what you used in the encrypter
const SECRET_PASSPHRASE = 'my-enterprise-inventory-secret-2026';
const SECRET_KEY = crypto.scryptSync(SECRET_PASSPHRASE, 'salt', 32);
const ALGORITHM = 'aes-256-cbc';

function loadSecureConfig() {
    // 1. Candidate paths to look for sysConfig.enc
    const candidatePaths = [
        path.join(rootDir, 'sysConfig.enc'),
        path.join(rootDir, 'backend', 'sysConfig.enc'),
        path.join(process.cwd(), 'sysConfig.enc'),
        path.join(process.cwd(), 'backend', 'sysConfig.enc')
    ];

    let foundPath = candidatePaths.find(p => fs.existsSync(p));

    if (foundPath) {
        try {
            const fileContent = fs.readFileSync(foundPath, 'utf8');
            const parsedFile = JSON.parse(fileContent);

            // Extract IV and Encrypted Data
            const iv = Buffer.from(parsedFile.iv, 'hex');
            const encryptedData = parsedFile.encryptedData;

            // Decrypt
            const decipher = crypto.createDecipheriv(ALGORITHM, SECRET_KEY, iv);
            let decrypted = decipher.update(encryptedData, 'hex', 'utf8');
            decrypted += decipher.final('utf8');

            console.log(`✅ [SYSTEM] Loaded sysConfig.enc from: ${foundPath}`);
            return JSON.parse(decrypted);

        } catch (error) {
            console.error("⚠️ [SYSTEM] Failed to decrypt sysConfig.enc:", error.message);
        }
    }

    // 2. Fallback to Environment Variables if sysConfig.enc is missing or fails
    if (process.env.SHEET_ID || process.env.EMAIL_USER || process.env.SCRIPT_URL) {
        console.log("ℹ️ [SYSTEM] Loading sysConfig from environment variables.");
        return {
            sheetId: process.env.SHEET_ID || null,
            scriptUrl: process.env.SCRIPT_URL || null,
            emailId: process.env.EMAIL_USER || process.env.EMAIL_ID || null,
            emailPass: process.env.EMAIL_PASS || process.env.EMAIL_PASSWORD || null,
            rootFolderId: process.env.ROOT_FOLDER_ID || null
        };
    }

    console.log("🛡️ [SYSTEM] sysConfig.enc not found and env vars not set. Running in safe Recovery Mode.");
    return null;
}

// Load and export the config immediately so it's ready when required
const secureConfig = loadSecureConfig();

module.exports = secureConfig;