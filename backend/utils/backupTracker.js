const fs = require('fs');
const path = require('path');
const rootDir = process.pkg ? path.dirname(process.execPath) : process.cwd();

const STATUS_FILE = path.join(rootDir, 'backup_status.json');

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

    if (!allData[outletCode]) {
        return { lastSyncTime: null, isCloudEnabled: false };
    }
    return allData[outletCode];
}

function updateSyncSuccess(outletCode) {
    const allData = _readAllStatuses();

    if (!allData[outletCode]) {
        allData[outletCode] = { lastSyncTime: null, isCloudEnabled: false };
    }

    allData[outletCode].lastSyncTime = new Date().getTime();
    fs.writeFileSync(STATUS_FILE, JSON.stringify(allData, null, 2));
}

function toggleCloudBackup(outletCode, enabled) {
    const allData = _readAllStatuses();

    if (!allData[outletCode]) {
        allData[outletCode] = { lastSyncTime: null, isCloudEnabled: false };
    }

    allData[outletCode].isCloudEnabled = enabled;
    fs.writeFileSync(STATUS_FILE, JSON.stringify(allData, null, 2));
}

module.exports = { getBackupStatus, updateSyncSuccess, toggleCloudBackup };