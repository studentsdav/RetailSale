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
    try {
        const configPath = path.join(rootDir, 'sysConfig.enc');

        if (!fs.existsSync(configPath)) {
            throw new Error("CRITICAL: sysConfig.enc file is missing from the installation directory.");
        }

        const fileContent = fs.readFileSync(configPath, 'utf8');
        const parsedFile = JSON.parse(fileContent);

        // Extract IV and Encrypted Data
        const iv = Buffer.from(parsedFile.iv, 'hex');
        const encryptedData = parsedFile.encryptedData;

        // Decrypt
        const decipher = crypto.createDecipheriv(ALGORITHM, SECRET_KEY, iv);
        let decrypted = decipher.update(encryptedData, 'hex', 'utf8');
        decrypted += decipher.final('utf8');

        // Parse back into a JavaScript Object
        return JSON.parse(decrypted);

    } catch (error) {
        console.error("⚠️ [SYSTEM] Failed to load secure configuration:", error.message);
        console.log("🛡️ [SYSTEM] Running in safe Recovery Mode.");

        return null;
    }
}

// Load and export the config immediately so it's ready when required
const secureConfig = loadSecureConfig();

module.exports = secureConfig;