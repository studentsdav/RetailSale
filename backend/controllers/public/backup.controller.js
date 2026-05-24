const { getBackupStatus, toggleCloudBackup } = require("../../utils/backupTracker");
const { processBackup } = require("../../modules/backupService");
const { restoreFromEncBuffer } = require("../../modules/restore");
const fs = require("fs");
const path = require("path");

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
            alert: alertType
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
