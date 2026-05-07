// build_config.js
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const SECRET_PASSPHRASE = 'my-enterprise-inventory-secret-2026';
const SECRET_KEY = crypto.scryptSync(SECRET_PASSPHRASE, 'salt', 32);
const ALGORITHM = 'aes-256-cbc';
const rootDir = process.pkg ? path.dirname(process.execPath) : process.cwd();

const rawConfig = {
    sheetId: "sheetid sheetname Clients",
    scriptUrl: "scripturl",
    emailId: "email",
    emailPass: "apppassword",
    rootFolderId: "rootfolderid"
};

function encrypt(data) {

    const iv = crypto.randomBytes(16);
    const cipher = crypto.createCipheriv(ALGORITHM, SECRET_KEY, iv);

    let encrypted = cipher.update(JSON.stringify(data), 'utf8', 'hex');
    encrypted += cipher.final('hex');

    return {
        iv: iv.toString('hex'),
        encryptedData: encrypted
    };
}

try {
    const encryptedPayload = encrypt(rawConfig);
    const outputPath = path.join(rootDir, 'sysConfig.enc');

    fs.writeFileSync(outputPath, JSON.stringify(encryptedPayload, null, 2));
    console.log(`✅ Success! Encrypted config generated at: ${outputPath}`);
    console.log(`Ship ONLY config.enc to the client. Do not ship this file.`);
} catch (e) {
    console.error("❌ Encryption failed:", e.message);
}