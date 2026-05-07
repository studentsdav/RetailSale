const fs = require("fs");
const path = require("path");
const rootDir = process.pkg ? path.dirname(process.execPath) : process.cwd();
const SYNC_FILE = path.join(rootDir, "sync_status.json");

const DEFAULT_STATE = {
    folder_created: false,
    sheet_synced: false,
    config_synced: false,
    file_created: false,
    backup_synced: false
};

function getAllSyncStates() {
    try {
        if (fs.existsSync(SYNC_FILE)) {
            return JSON.parse(fs.readFileSync(SYNC_FILE, "utf8"));
        }
    } catch (err) {
        console.error("[SYNC] Could not read sync_status.json, initializing new tracker.");
    }
    return {};
}

function getSyncState(outletCode) {
    if (!outletCode) {
        throw new Error("[SYNC] Outlet code is required to fetch sync state.");
    }

    const allStates = getAllSyncStates();
    return allStates[outletCode] || { ...DEFAULT_STATE };
}

function updateSyncState(outletCode, taskName, status) {
    if (!outletCode) {
        throw new Error("[SYNC] Outlet code is required to update sync state.");
    }

    const allStates = getAllSyncStates();

    if (!allStates[outletCode]) {
        allStates[outletCode] = { ...DEFAULT_STATE };
    }

    allStates[outletCode][taskName] = status;

    try {
        const dir = path.dirname(SYNC_FILE);
        if (!fs.existsSync(dir)) {
            fs.mkdirSync(dir, { recursive: true });
        }

        fs.writeFileSync(SYNC_FILE, JSON.stringify(allStates, null, 2));
    } catch (err) {
        console.error(`[SYNC] Could not save sync state for ${taskName} at ${outletCode}: ${err.message}`);
    }
}

module.exports = {
    getSyncState,
    updateSyncState
};