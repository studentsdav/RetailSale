const fs = require('fs');
const path = require('path');
const rootDir = process.pkg ? path.dirname(process.execPath) : process.cwd();

const STATUS_FILE = path.join(rootDir, 'backup_status.json');

// Detect if backend is deployed on an online cloud server (Render, AWS, Heroku, production cloud)
function isCloudEnvironment() {
    return process.env.RENDER === 'true' || 
           !!process.env.RENDER || 
           process.env.NODE_ENV === 'production' || 
           process.env.IS_CLOUD === 'true';
}

function _readAllStatuses() {
    if (!fs.existsSync(STATUS_FILE)) return {};
    try {
        return JSON.parse(fs.readFileSync(STATUS_FILE, 'utf8'));
    } catch (e) {
        return {};
    }
}

function getBackupStatus(outletCode) {
    const allData = _readAllStatuses();
    const defaultState = isCloudEnvironment(); // ON by default for online cloud servers (Render), OFF for local offline

    if (!allData[outletCode]) {
        return { lastSyncTime: null, isCloudEnabled: defaultState };
    }

    const record = allData[outletCode];
    if (typeof record.isCloudEnabled === 'undefined') {
        record.isCloudEnabled = defaultState;
    } else if (isCloudEnvironment() && record.isCloudEnabled === false && !record.userManuallyDisabled) {
        // Force Cloud Sync ON by default for online cloud deployments to protect data from container destruction
        record.isCloudEnabled = true;
    }

    return record;
}

function updateSyncSuccess(outletCode) {
    const allData = _readAllStatuses();
    const defaultState = isCloudEnvironment();

    if (!allData[outletCode]) {
        allData[outletCode] = { lastSyncTime: null, isCloudEnabled: defaultState };
    }

    allData[outletCode].lastSyncTime = new Date().getTime();
    fs.writeFileSync(STATUS_FILE, JSON.stringify(allData, null, 2));
}

function toggleCloudBackup(outletCode, enabled) {
    const allData = _readAllStatuses();

    if (!allData[outletCode]) {
        allData[outletCode] = { lastSyncTime: null, isCloudEnabled: enabled };
    }

    allData[outletCode].isCloudEnabled = enabled;
    allData[outletCode].userManuallyDisabled = !enabled; // Mark if merchant explicitly turned it off
    fs.writeFileSync(STATUS_FILE, JSON.stringify(allData, null, 2));
}

module.exports = { getBackupStatus, updateSyncSuccess, toggleCloudBackup, isCloudEnvironment };