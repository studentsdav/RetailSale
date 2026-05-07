const { getBackupStatus, toggleCloudBackup } = require("../../utils/backupTracker");

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