const fs = require("fs");
const path = require("path");
const { spawn } = require("child_process");
const { sendToGoogleScript } = require("./driveService");
const { decryptAndUnzip } = require("../utils/decrypt");
const loadConfig = require("../utils/decryptConfig");

const psqlPath = "C:\\Program Files\\PostgreSQL\\18\\bin\\psql.exe";
const isCompiled = typeof process.pkg !== 'undefined';
const baseDir = isCompiled ? path.dirname(process.execPath) : path.join(__dirname, '..');
/**
 * Executes the PostgreSQL restore using the plain SQL file
 */

function executeDatabaseRestore(sqlFilePath, db_name, db_user, db_pass) {
    return new Promise((resolve, reject) => {
        const env = { ...process.env, PGPASSWORD: db_pass };
        const args = ["-U", db_user, "-d", db_name, "-f", sqlFilePath];

        console.log(`🚀 Starting database restore for ${db_name}...`);
        const restoreProcess = spawn(psqlPath, args, { env });

        restoreProcess.stderr.on("data", (data) => console.log(`📦 psql: ${data.toString().trim()}`));

        restoreProcess.on("close", (code) => {
            if (code === 0) {
                console.log("✅ Database restored completely!");
                resolve();
            } else {
                reject(new Error("psql failed with code " + code));
            }
        });

        restoreProcess.on("error", reject);
    });
}

async function autoRestoreLatest(folderId) {
    const config = loadConfig();

    const restoreDir = path.join(baseDir, "backups", `restore-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`);
    const encFile = path.join(restoreDir, "restore.enc");
    const zipFile = path.join(restoreDir, "restore.zip");
    const sqlFile = path.join(restoreDir, "backup.sql");

    try {
        fs.mkdirSync(restoreDir, { recursive: true });
        console.log("[RESTORE] Locating latest backup in Google Drive...");

        // 1. Request Download
        const res = await sendToGoogleScript({
            action: 'download_latest_backup',
            folderId: folderId
        });

        // Validation: Verify cloud response contains actual file data
        if (!res || !res.base64) {
            throw new Error("No backup files found in the cloud directory.");
        }

        fs.writeFileSync(encFile, Buffer.from(res.base64, 'base64'));
        console.log(`[RESTORE] Successfully downloaded payload: ${res.filename}`);

        // Validation: Ensure the file was actually written to the local disk
        if (!fs.existsSync(encFile)) {
            throw new Error("Local I/O Error: Failed to write downloaded backup to disk.");
        }

        // 2. Decrypt & Unzip
        console.log("[RESTORE] Decrypting and extracting backup archive...");
        const extractedSqlFile = await decryptAndUnzip(encFile, zipFile, restoreDir);

        // Validation: Ensure the SQL file was successfully extracted from the ZIP
        if (!fs.existsSync(extractedSqlFile)) {
            throw new Error("Extraction corrupted: 'backup.sql' was not found in the archive.");
        }

        // 3. Restore Database
        console.log("[RESTORE] Applying database payload...");
        await executeDatabaseRestore(extractedSqlFile, config.db_database, config.db_user, config.db_password);

        // 4. Cleanup temporary files
        console.log("[RESTORE] Scrubbing temporary files...");
        [encFile, zipFile, sqlFile].forEach(file => {
            if (fs.existsSync(file)) {
                fs.unlinkSync(file);
            }
        });
        if (fs.existsSync(restoreDir)) {
            fs.rmSync(restoreDir, { recursive: true, force: true });
        }

        console.log("[RESTORE] Database recovery sequence completed successfully.");

    } catch (error) {
        console.error(`[RESTORE] Workflow Interrupted: ${error.message}`);

        // Safety mechanism
        [encFile, zipFile, sqlFile].forEach(file => {
            if (fs.existsSync(file)) {
                try { fs.unlinkSync(file); } catch (e) { }
            }
        });
        if (fs.existsSync(restoreDir)) {
            try { fs.rmSync(restoreDir, { recursive: true, force: true }); } catch (e) { }
        }

        throw error;
    }
}

module.exports = { autoRestoreLatest };
