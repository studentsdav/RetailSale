const cron = require("node-cron");
const fs = require("fs");
const path = require("path");
const { decryptAndUnzip } = require("../utils/decrypt");
const { processBackup } = require("../modules/backupService");
const { uploadBackupViaScript, cleanOldBackups } = require("../modules/driveService");
const { retry } = require("../utils/retry");
const { getBackupStatus, updateSyncSuccess } = require("../utils/backupTracker");

// Define strict backup and log directories
const isCompiled = typeof process.pkg !== 'undefined';
const baseDir = isCompiled ? path.dirname(process.execPath) : path.join(__dirname, '..');
const BACKUP_DIR = path.join(baseDir, 'backups');
const LOG_FILE = path.join(baseDir, 'backup-log.txt');
const activeBackupJobs = new Set();

// ==========================================
// LOGGER & EXCEPTION HANDLERS
// ==========================================

function logMessage(msg, isError = false) {
    const timestamp = new Date().toISOString();
    const level = isError ? '[ERROR]' : '[INFO]';
    const logText = `${timestamp} ${level} ${msg}\n`;

    if (isError) {
        console.error(logText.trim());
    } else {
        console.log(logText.trim());
    }

    try {
        fs.appendFileSync(LOG_FILE, logText);
    } catch (e) {
        console.error(`Failed to write to log file: ${e.message}`);
    }
}

process.on('uncaughtException', (err) => {
    logMessage(`[FATAL] Uncaught Exception: ${err.message}\n${err.stack}`, true);
    process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
    logMessage(`[FATAL] Unhandled Rejection: ${reason}`, true);
});

// ==========================================
// BACKUP
// ==========================================

function getReadableTimestamp() {
    const now = new Date();
    return now.getFullYear() + '-' +
        String(now.getMonth() + 1).padStart(2, '0') + '-' +
        String(now.getDate()).padStart(2, '0') + '_' +
        String(now.getHours()).padStart(2, '0') + '-' +
        String(now.getMinutes()).padStart(2, '0') + '-' +
        String(now.getSeconds()).padStart(2, '0');
}

function cleanOldLocalBackups(dir, maxKeep = 5) {
    if (!fs.existsSync(dir)) return;

    const files = fs.readdirSync(dir)
        .filter(f => f.startsWith('backup_') && f.endsWith('.enc'))
        .map(f => ({
            path: path.join(dir, f),
            time: fs.statSync(path.join(dir, f)).mtime.getTime()
        }))
        .sort((a, b) => b.time - a.time);

    if (files.length > maxKeep) {
        const filesToDelete = files.slice(maxKeep);
        for (const f of filesToDelete) {
            fs.unlinkSync(f.path);
        }
        logMessage(`Cleaned ${filesToDelete.length} old local backups. Retention limit: ${maxKeep}.`);
    }
}

async function verifyLocalBackup(encFilePath) {
    const verifyDir = fs.mkdtempSync(path.join(BACKUP_DIR, "verify-"));
    const verifyZip = path.join(verifyDir, "verify.zip");

    try {
        const extractedSql = await decryptAndUnzip(encFilePath, verifyZip, verifyDir);

        if (!extractedSql || !fs.existsSync(extractedSql)) {
            throw new Error("Backup archive did not contain the expected backup.sql payload.");
        }
    } finally {
        if (fs.existsSync(verifyDir)) {
            fs.rmSync(verifyDir, { recursive: true, force: true });
        }
    }
}

async function startBackupJob(client, config) {
    const outletCode = client && client.outlet_code ? client.outlet_code : "unknown";

    if (activeBackupJobs.has(outletCode)) {
        logMessage(`Backup job already running for outlet [${outletCode}]. Skipping duplicate trigger.`);
        return;
    }



    activeBackupJobs.add(outletCode);
    logMessage("Backup scheduler initialized. Running cron: 0 * * * *");
    cron.schedule("0 * * * *", async () => {
        try {
            if (!fs.existsSync(BACKUP_DIR)) {
                fs.mkdirSync(BACKUP_DIR, { recursive: true });
                logMessage(`Created backup directory at: ${BACKUP_DIR}`);
            }

            logMessage("Hourly backup job started.");

            const tempFile = await retry(() => processBackup(config.db_database));

            if (!tempFile || !fs.existsSync(tempFile)) {
                throw new Error(`Backup file missing at temporary path: ${tempFile}`);
            }

            const stats = fs.statSync(tempFile);
            const fileSizeMB = (stats.size / 1024 / 1024).toFixed(2);
            logMessage(`Backup created. File size: ${fileSizeMB} MB`);

            if (stats.size === 0) throw new Error("Backup file size is 0 bytes.");
            if (fileSizeMB > 35) logMessage("Warning: Backup file size exceeds 35 MB threshold.", true);

            logMessage("Verifying backup integrity before local retention and upload.");
            try {
                await verifyLocalBackup(tempFile);
            } catch (verifyErr) {
                if (fs.existsSync(tempFile)) {
                    try { fs.unlinkSync(tempFile); } catch (e) { }
                }
                throw new Error(`Backup integrity verification failed: ${verifyErr.message}`);
            }

            const fileName = `backup_${getReadableTimestamp()}.enc`;
            const finalFilePath = path.join(BACKUP_DIR, fileName);

            fs.renameSync(tempFile, finalFilePath);
            const currentOutlet = outletCode;

            const status = getBackupStatus(currentOutlet);

            if (status.isCloudEnabled) {
                logMessage(`Cloud Sync enabled for outlet [${currentOutlet}]. Initiating upload.`);
                await uploadBackupViaScript(finalFilePath, fileName, client.folderId);
                await cleanOldBackups(client.folderId);

                updateSyncSuccess(currentOutlet);
                logMessage("Cloud upload sequence completed successfully.");
            } else {
                logMessage(`Cloud Sync disabled for outlet [${currentOutlet}]. Bypassing upload.`);
            }

            cleanOldLocalBackups(BACKUP_DIR, 500);

            logMessage("Hourly backup job execution finished.");

        } catch (err) {
            logMessage(`Backup job failed: ${err.message}`, true);
        } finally {
            activeBackupJobs.delete(outletCode);
        }
    });
}

module.exports = { startBackupJob };
