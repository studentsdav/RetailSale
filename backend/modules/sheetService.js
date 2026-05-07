const fs = require("fs");
const path = require("path");
const { upsertClient } = require("./driveService");
const loadConfig = require("../utils/decryptConfig");
const { startBackupJob } = require("../jobs/backupJob");
const { autoRestoreLatest } = require("./restore");
const rootDir = process.pkg ? path.dirname(process.execPath) : process.cwd();

const CLIENT_FILE = path.join(rootDir, "client.json");

async function touchClient(outletCode) {
    if (!outletCode) {
        console.error("[TOUCH] Missing outletCode parameter.");
        return;
    }

    try {

        if (!fs.existsSync(CLIENT_FILE)) {
            return;
        }
        const config = loadConfig();

        const fileData = fs.readFileSync(CLIENT_FILE, "utf8");
        let clients = JSON.parse(fileData);
        if (!Array.isArray(clients)) {
            clients = [clients];
        }

        const targetClient = clients.find(c => c && c.outlet_code === outletCode);

        if (targetClient) {
            startBackupJob(targetClient, config);
            await upsertClient(targetClient);
        } else {
            console.warn(`[TOUCH] Outlet configuration for ${outletCode} not found.`);
        }
    } catch (err) {
        console.error(`[TOUCH] Client sync failed: ${err.message}`);
    }
}

async function syncDatabaseOnly(req, res) {
    try {
        const outletCode = req.user.outlet_code;

        if (!outletCode) {
            return res.status(400).json({
                success: false,
                message: "Missing outlet code in request."
            });
        }

        const fileData = fs.readFileSync(CLIENT_FILE, "utf8");
        let clients = JSON.parse(fileData);

        if (!Array.isArray(clients)) {
            clients = [clients];
        }

        const targetClient = clients.find(c => c && c.outlet_code === outletCode);

        if (!targetClient || !targetClient.folderId) {
            return res.status(404).json({
                success: false,
                message: "Client not found or missing Google Drive folder ID."
            });
        }

        console.log(`[SYNC] Executing on-demand database sync from folder: ${targetClient.folderId}`);

        await autoRestoreLatest(targetClient.folderId);

        console.log("[SYNC] Database sync sequence complete. Local data is up to date.");

        res.json({
            success: true,
            message: "Database synced successfully!"
        });

    } catch (error) {
        console.error(`[SYNC] Critical Sync Failure: ${error.message}`);

        res.status(500).json({
            success: false,
            message: "Data sync failed: " + error.message
        });
    }
}

module.exports = { touchClient, syncDatabaseOnly };