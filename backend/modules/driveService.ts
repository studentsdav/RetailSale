import fs from "fs";
import crypto from "crypto";
import { exec } from "child_process";
import sysConfig from '../utils/configManager';

const SHEET_ID = sysConfig ? sysConfig.sheetId : null;
const ROOT_FOLDER_ID = sysConfig ? sysConfig.rootFolderId : null;
const WEB_APP_URL = sysConfig ? sysConfig.scriptUrl : null;

const HEADERS = [
    "client_id", "outlet_code", "outlet_id", "property_name",
    "db_name", "machine_id", "created_at", "expiry_date",
    "status", "last_updated", "contact_email", "contact_phone", "tax_id", "recovery_pin_hash"
];

function log(message: string): void {
    console.log(`[DRIVE_SERVICE] ${message}`);
}

export async function isOnline(): Promise<boolean> {
    try {
        const response = await fetch("https://8.8.8.8", { method: "HEAD" });
        return response.ok;
    } catch (e) {
        return false;
    }
}

export async function sendToGoogleScript(payload: any): Promise<any> {
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
        let data: any;

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

    } catch (error: any) {
        console.error(`[DRIVE_SERVICE] Cloud communication failed: ${error.message}`);
        throw error;
    }
}

// ---------------------------------------------------------
// GOOGLE SHEETS FUNCTIONS
// ---------------------------------------------------------

export async function upsertClient(client: any): Promise<void> {
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
    } catch (err: any) {
        console.error(`[DRIVE_SERVICE] Sheet upsert failed for ${client.outlet_code}:`, err.message);
    }
}

// ---------------------------------------------------------
// GOOGLE DRIVE FUNCTIONS
// ---------------------------------------------------------

export async function createClientFolder(outletCode: string): Promise<string> {
    try {
        const res = await sendToGoogleScript({
            action: 'create_folder',
            rootFolderId: ROOT_FOLDER_ID,
            folderName: String(outletCode)
        });
        log(`Folder created for ${outletCode}: ${res.folderId}`);
        return res.folderId;
    } catch (err: any) {
        console.error(`[DRIVE_SERVICE] Folder creation failed for ${outletCode}:`, err.message);
        throw err;
    }
}

export async function uploadBackupViaScript(filePath: string, fileName: string, targetFolderId: string): Promise<void> {
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
    } catch (error: any) {
        console.error("[DRIVE_SERVICE] Upload failed:", error.message);
        throw error;
    }
}

export async function cleanOldBackups(folderId: string): Promise<void> {
    try {
        await sendToGoogleScript({
            action: 'clean_old_backups',
            folderId: folderId
        });
        log("Old backups cleaned successfully");
    } catch (error: any) {
        console.error("[DRIVE_SERVICE] Clean old backups failed:", error.message);
        throw error;
    }
}

// ---------------------------------------------------------
// RESTORE FUNCTION
// ---------------------------------------------------------

export async function restoreLatestBackup(folderId: string, db_name: string): Promise<void> {
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

        const decipher = (crypto as any).createDecipher("aes-256-cbc", "SECRET_KEY");

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

    } catch (error: any) {
        console.error("[DRIVE_SERVICE] Restore failed:", error.message);
    }
}

export default {
    sendToGoogleScript,
    upsertClient,
    createClientFolder,
    uploadBackupViaScript,
    cleanOldBackups,
    restoreLatestBackup
};
