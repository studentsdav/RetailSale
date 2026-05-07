
const { sendToGoogleScript } = require("../../modules/driveService");
const sysConfig = require('../../utils/configManager');



const SHEET_ID = sysConfig ? sysConfig.sheetId : null;

async function checkSystemUpdate(req, res) {
    try {
        const response = await sendToGoogleScript({
            action: 'check_update',
            sheetId: SHEET_ID
        });

        // 1. Validate response exists
        if (!response) {
            throw new Error("No response received from the update server.");
        }

        // 2. Handle graceful errors from Google Apps Script
        if (response.status === 'error') {
            throw new Error(`Cloud Error: ${response.message}`);
        }

        // 3. Optional warning for malformed data
        if (!response.latest_version) {
            console.warn("[UPDATE WARNING] 'latest_version' is missing from the payload.");
        }

        // 4. Send clean response to Flutter
        return res.json({
            success: true,
            latest_version: response.latest_version,
            download_url: response.download_url,
            changelog: response.changelog,
            release_date: response.release_date
        });

    } catch (error) {
        console.error("[UPDATE ERROR]", error.message);

        return res.status(500).json({
            success: false,
            message: error.message || "Failed to check for system updates."
        });
    }
}

module.exports = { checkSystemUpdate };