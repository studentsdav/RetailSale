import fs from 'fs';
import path from 'path';

const rootDir = (process as any).pkg ? path.dirname(process.execPath) : process.cwd();
const STATUS_FILE = path.join(rootDir, 'backup_status.json');

export interface BackupStatusRecord {
  lastSyncTime: number | null;
  isCloudEnabled: boolean;
  userManuallyDisabled?: boolean;
  [key: string]: any;
}

export function isCloudEnvironment(): boolean {
  return (
    process.env.RENDER === 'true' ||
    !!process.env.RENDER ||
    process.env.NODE_ENV === 'production' ||
    process.env.IS_CLOUD === 'true'
  );
}

function _readAllStatuses(): Record<string, BackupStatusRecord> {
  if (!fs.existsSync(STATUS_FILE)) return {};
  try {
    return JSON.parse(fs.readFileSync(STATUS_FILE, 'utf8'));
  } catch (e) {
    return {};
  }
}

export function getBackupStatus(outletCode: string): BackupStatusRecord {
  const allData = _readAllStatuses();
  const defaultState = isCloudEnvironment();

  if (!allData[outletCode]) {
    return { lastSyncTime: null, isCloudEnabled: defaultState };
  }

  const record = allData[outletCode];
  if (typeof record.isCloudEnabled === 'undefined') {
    record.isCloudEnabled = defaultState;
  } else if (isCloudEnvironment() && record.isCloudEnabled === false && !record.userManuallyDisabled) {
    record.isCloudEnabled = true;
  }

  return record;
}

export function updateSyncSuccess(outletCode: string): void {
  const allData = _readAllStatuses();
  const defaultState = isCloudEnvironment();

  if (!allData[outletCode]) {
    allData[outletCode] = { lastSyncTime: null, isCloudEnabled: defaultState };
  }

  allData[outletCode].lastSyncTime = new Date().getTime();
  fs.writeFileSync(STATUS_FILE, JSON.stringify(allData, null, 2));
}

export function toggleCloudBackup(outletCode: string, enabled: boolean): void {
  const allData = _readAllStatuses();

  if (!allData[outletCode]) {
    allData[outletCode] = { lastSyncTime: null, isCloudEnabled: enabled };
  }

  allData[outletCode].isCloudEnabled = enabled;
  allData[outletCode].userManuallyDisabled = !enabled;
  fs.writeFileSync(STATUS_FILE, JSON.stringify(allData, null, 2));
}

module.exports = {
  getBackupStatus,
  updateSyncSuccess,
  toggleCloudBackup,
  isCloudEnvironment
};
