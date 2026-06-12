
const fs = require("fs");
const crypto = require("crypto");
const { exec } = require("child_process");
const sysConfig = require('../utils/configManager');

const SHEET_ID = sysConfig ? sysConfig.sheetId : null;
const ROOT_FOLDER_ID = sysConfig ? sysConfig.rootFolderId : null;
const WEB_APP_URL = sysConfig ? sysConfig.scriptUrl : null;


const HEADERS = [
    "client_id", "outlet_code", "outlet_id", "property_name",
    "db_name", "machine_id", "created_at", "expiry_date",
    "status", "last_updated", "contact_email", "contact_phone", "tax_id", "recovery_pin_hash"
];

function log(message) {
    console.log(`[DRIVE_SERVICE] ${message}`);
}

async function isOnline() {
    try {
        const response = await fetch("https://8.8.8.8", { method: "HEAD", timeout: 3000 });
        return response.ok;
    } catch (e) {
        return false;
    }
}


async function sendToGoogleScript(payload) {
    try {
        const response = await fetch(WEB_APP_URL, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });

        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        const rawText = await response.text();
        let data;

        try {
            data = JSON.parse(rawText);
        } catch (parseError) {
            console.error("[DRIVE_SERVICE] Non-JSON response received:", rawText.substring(0, 250));
            throw new Error("Invalid response format from cloud server. Expected JSON.");
        }

        if (data.status !== 'success') {
            throw new Error(data.message || "Unknown error occurred in cloud script.");
        }

        return data;

    } catch (error) {
        console.error(`[DRIVE_SERVICE] Cloud communication failed: ${error.message}`);
        throw error;
    }
}
// ---------------------------------------------------------
// GOOGLE SHEETS FUNCTIONS
// ---------------------------------------------------------

async function upsertClient(client) {
    if (!client || !client.outlet_code) {
        console.error("[DRIVE_SERVICE] upsertClient called with invalid client object.");
        return;
    }

    const newRow = [
        client.client_id || "",
        String(client.outlet_code || ""),
        String(client.outlet_id || ""),
        client.property_name || "",
        client.db_name || "",
        client.machine_id || "",
        client.created_at || "",
        client.expiry_date || "",
        client.status || "ACTIVE",
        new Date().toISOString(),
        client.contact_email || "",
        client.contact_phone || "",
        client.tax_id || "",
        client.pin || ""
    ];

    try {
        await sendToGoogleScript({
            action: 'upsert_client',
            sheetId: SHEET_ID,
            headers: HEADERS,
            newRow: newRow
        });
        log(`Client ${client.outlet_code} upserted in Google Sheets successfully`);
    } catch (err) {
        console.error(`[DRIVE_SERVICE] Sheet upsert failed for ${client.outlet_code}:`, err.message);
    }
}

// ---------------------------------------------------------
// GOOGLE DRIVE FUNCTIONS
// ---------------------------------------------------------

async function createClientFolder(outletCode) {
    try {
        const res = await sendToGoogleScript({
            action: 'create_folder',
            rootFolderId: ROOT_FOLDER_ID,
            folderName: String(outletCode)
        });
        log(`Folder created for ${outletCode}: ${res.folderId}`);
        return res.folderId;
    } catch (err) {
        console.error(`[DRIVE_SERVICE] Folder creation failed for ${outletCode}:`, err.message);
        throw err;
    }
}

async function uploadBackupViaScript(filePath, fileName, targetFolderId) {
    if (!(await isOnline())) {
        log("No internet, skipping upload");
        throw new Error("No internet connection.");
    }

    try {
        log(`Uploading ${fileName}...`);
        const base64Data = fs.readFileSync(filePath).toString('base64');

        const res = await sendToGoogleScript({
            action: 'upload_backup',
            folderId: targetFolderId,
            filename: fileName,
            mimeType: "application/octet-stream",
            base64: base64Data
        });

        log(`Upload success! File ID: ${res.fileId}`);
    } catch (error) {
        console.error("[DRIVE_SERVICE] Upload failed:", error.message);
        throw error;
    }
}

async function cleanOldBackups(folderId) {
    try {
        await sendToGoogleScript({
            action: 'clean_old_backups',
            folderId: folderId
        });
        log("Old backups cleaned successfully");
    } catch (error) {
        console.error("[DRIVE_SERVICE] Clean old backups failed:", error.message);
        throw error;
    }
}

// ---------------------------------------------------------
// RESTORE FUNCTION
// ---------------------------------------------------------

async function restoreLatestBackup(folderId, db_name) {
    try {
        log("Asking cloud for the latest backup...");

        const res = await sendToGoogleScript({
            action: 'download_latest_backup',
            folderId: folderId
        });

        log(`Downloading: ${res.filename}`);

        // Convert Base64 back to binary file
        const fileBuffer = Buffer.from(res.base64, 'base64');
        fs.writeFileSync("restore.enc", fileBuffer);

        log("File saved. Decrypting and restoring...");

        // Note: crypto.createDecipher is deprecated in modern Node versions.
        // It's highly recommended to use crypto.createDecipheriv instead for security.
        const decipher = crypto.createDecipher("aes-256-cbc", "SECRET_KEY");

        const extractProcess = exec(`tar -xf restore.zip`, (err) => {
            if (err) return console.error("[DRIVE_SERVICE] Extract error:", err);
            exec(`psql -U postgres ${db_name} < backup.sql`, (dbErr) => {
                if (dbErr) return console.error("[DRIVE_SERVICE] Database restore failed:", dbErr);
                log("Database successfully restored from the latest backup!");
            });
        });

        fs.createReadStream("restore.enc")
            .pipe(decipher)
            .pipe(fs.createWriteStream("restore.zip"))
            .on("finish", () => {
                extractProcess;
            });

    } catch (error) {
        console.error("[DRIVE_SERVICE] Restore failed:", error.message);
    }
}

module.exports = {
    sendToGoogleScript,
    upsertClient,
    createClientFolder,
    uploadBackupViaScript,
    cleanOldBackups,
    restoreLatestBackup
};