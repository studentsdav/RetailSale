const { getBackupStatus, toggleCloudBackup, updateSyncSuccess } = require("../../utils/backupTracker");
const { processBackup } = require("../../modules/backupService");
const { restoreFromEncBuffer } = require("../../modules/restore");
const { uploadBackupViaScript, cleanOldBackups, createClientFolder } = require("../../modules/driveService");
const loadConfig = require("../../utils/decryptConfig");
const fs = require("fs");
const path = require("path");

const rootDir = process.pkg ? path.dirname(process.execPath) : process.cwd();
const CLIENT_FILE = path.join(rootDir, "client.json");
const BACKUP_DIR = path.join(rootDir, 'backups');

exports.getBackupStatusAlert = (req, res) => {
    try {

        const outletCode = req.outlet_code;


        const status = getBackupStatus(outletCode);
        let alertType = "NONE";

        if (!status.isCloudEnabled) {
            alertType = "ENABLE_PROMPT";
        } else {
            const now = new Date().getTime();
            if (!status.lastSyncTime || (now - status.lastSyncTime) > 86400000) {
                alertType = "SYNC_FAILED";
            }
        }

        return res.status(200).json({
            success: true,
            alert: alertType,
            lastSyncTime: status.lastSyncTime
        });

    } catch (err) {
        console.error("Backup Status Controller Error:", err);
        return res.status(500).json({
            success: false,
            error: "Internal server error while checking backup status."
        });
    }
};

exports.toggleBackup = (req, res) => {
    try {
        const outletCode = req.outlet_code;
        const { enabled } = req.body;

        toggleCloudBackup(outletCode, enabled);

        return res.status(200).json({
            success: true,
            message: enabled ? "Cloud backup enabled" : "Cloud backup disabled"
        });

    } catch (err) {
        console.error("Toggle Backup Error:", err);
        return res.status(500).json({ success: false, error: err.message });
    }
};

exports.createLocalEncBackup = async (req, res) => {
    try {
        const dbName =
            req.propertyDb?.config?.database ||
            process.env.DB_NAME ||
            "";
        if (!dbName) {
            return res.status(500).json({
                success: false,
                message: "Database name could not be resolved for backup."
            });
        }

        const encPath = await processBackup(dbName);
        const fileBuffer = fs.readFileSync(encPath);
        const filename = path.basename(encPath);

        return res.status(200).json({
            success: true,
            data: {
                filename,
                base64: fileBuffer.toString("base64")
            }
        });
    } catch (err) {
        console.error("Local ENC backup error:", err);
        return res.status(500).json({
            success: false,
            message: err.message || "Failed to create .enc backup."
        });
    }
};

exports.restoreFromLocalEnc = async (req, res) => {
    try {
        const filename = String(req.body.filename || "").trim();
        const base64 = String(req.body.base64 || "").trim();
        if (!filename.toLowerCase().endsWith(".enc")) {
            return res.status(400).json({
                success: false,
                message: "Only .enc backup files are allowed."
            });
        }
        if (!base64) {
            return res.status(400).json({
                success: false,
                message: "Backup payload is required."
            });
        }

        const encBuffer = Buffer.from(base64, "base64");
        if (!encBuffer.length) {
            return res.status(400).json({
                success: false,
                message: "Invalid backup payload."
            });
        }

        await restoreFromEncBuffer(encBuffer);
        return res.status(200).json({
            success: true,
            message: "Backup restored successfully from .enc file."
        });
    } catch (err) {
        console.error("Restore from local ENC error:", err);
        return res.status(500).json({
            success: false,
            message: err.message || "Failed to restore .enc backup."
        });
    }
};

exports.uploadBackupOnDemand = async (req, res) => {
    try {
        const outletCode = req.user?.outlet_code || req.outlet_code;

        if (!outletCode) {
            return res.status(400).json({
                success: false,
                message: "Missing outlet code in request."
            });
        }

        if (!fs.existsSync(CLIENT_FILE)) {
            return res.status(404).json({
                success: false,
                message: "Client registry file not found."
            });
        }

        const fileData = fs.readFileSync(CLIENT_FILE, "utf8");
        let clients = JSON.parse(fileData);
        if (!Array.isArray(clients)) {
            clients = [clients];
        }

        const targetClient = clients.find(c => c && c.outlet_code === outletCode);

        if (!targetClient) {
            return res.status(404).json({
                success: false,
                message: "Client configuration missing."
            });
        }

        const config = loadConfig();
        const dbName = config.db_database;

        if (!dbName) {
            return res.status(500).json({
                success: false,
                message: "Database name could not be resolved."
            });
        }

        if (!fs.existsSync(BACKUP_DIR)) {
            fs.mkdirSync(BACKUP_DIR, { recursive: true });
        }

        console.log(`[UPLOAD] Starting on-demand backup upload for outlet ${outletCode}...`);

        const tempFile = await processBackup(dbName);
        if (!tempFile || !fs.existsSync(tempFile)) {
            throw new Error(`Backup creation failed. File not found at temporary path.`);
        }

        const now = new Date();
        const timestamp = now.getFullYear() + '-' +
            String(now.getMonth() + 1).padStart(2, '0') + '-' +
            String(now.getDate()).padStart(2, '0') + '_' +
            String(now.getHours()).padStart(2, '0') + '-' +
            String(now.getMinutes()).padStart(2, '0') + '-' +
            String(now.getSeconds()).padStart(2, '0');

        const fileName = `backup_${timestamp}.enc`;
        const finalFilePath = path.join(BACKUP_DIR, fileName);

        fs.renameSync(tempFile, finalFilePath);

        let folderIdToUse = targetClient.folderId;
        let uploadSuccess = false;

        if (folderIdToUse) {
            try {
                await uploadBackupViaScript(finalFilePath, fileName, folderIdToUse);
                await cleanOldBackups(folderIdToUse);
                uploadSuccess = true;
            } catch (uploadErr) {
                console.warn(`[UPLOAD] Initial upload attempt failed: ${uploadErr.message}`);
                // If it is a Drive API error indicating the folder is not found or inaccessible
                if (uploadErr.message.includes("No item with the given ID") || 
                    uploadErr.message.includes("permission") ||
                    uploadErr.message.includes("not found")) {
                    folderIdToUse = null; // force folder recreation
                } else {
                    throw uploadErr;
                }
            }
        }

        if (!folderIdToUse) {
            console.log(`[UPLOAD] Cloud folder missing or invalid. Recreating cloud directory for outlet ${outletCode}...`);
            const newFolderId = await createClientFolder(outletCode);
            if (!newFolderId) {
                throw new Error("Could not allocate a new Google Drive folder.");
            }
            targetClient.folderId = newFolderId;
            fs.writeFileSync(CLIENT_FILE, JSON.stringify(clients, null, 2));

            console.log(`[UPLOAD] Folder recreated successfully (ID: ${newFolderId}). Retrying upload...`);
            await uploadBackupViaScript(finalFilePath, fileName, newFolderId);
            await cleanOldBackups(newFolderId);
            uploadSuccess = true;
        }

        if (uploadSuccess) {
            updateSyncSuccess(outletCode);
            console.log(`[UPLOAD] Cloud upload complete for outlet ${outletCode}.`);
            return res.status(200).json({
                success: true,
                message: "Backup uploaded to cloud successfully!"
            });
        } else {
            throw new Error("Cloud upload sequence completed but flag was false.");
        }

    } catch (err) {
        console.error("On-demand backup upload failed:", err);
        return res.status(500).json({
            success: false,
            message: err.message || "Failed to upload backup to cloud."
        });
    }
};
