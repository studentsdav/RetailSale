const { spawn } = require("child_process");
const { zipAndEncrypt } = require("../utils/zip");
const path = require("path");
const fs = require("fs").promises;
const loadConfig = require("../utils/decryptConfig");

const pgDumpPath = "C:\\Program Files\\PostgreSQL\\18\\bin\\pg_dump.exe";
const isCompiled = typeof process.pkg !== "undefined";
const baseDir = isCompiled ? path.dirname(process.execPath) : path.join(__dirname, "..");

function makeBackupStem() {
    return `backup_${new Date().toISOString().replace(/[:.]/g, "-")}_${process.pid}_${Math.random().toString(36).slice(2, 8)}`;
}

function createBackup(dbName, backupStem) {
    const config = loadConfig();

    return new Promise((resolve, reject) => {
        const file = path.join(baseDir, "backups", `${backupStem}.sql`);
        const env = {
            ...process.env,
            PGPASSWORD: config.db_password
        };

        const args = [
            "-U", config.db_user,
            "-F", "p",
            "-c",
            "-f", file,
            dbName
        ];

        const dump = spawn(pgDumpPath, args, { env });

        console.log("🚀 Backup started...");

        dump.stderr.on("data", (data) => {
            console.log(`📦 pg_dump: ${data.toString()}`);
        });

        dump.on("close", (code) => {
            if (code === 0) {
                console.log("✅ Backup completed");
                resolve(file);
            } else {
                reject(new Error("Backup failed with code " + code));
            }
        });

        dump.on("error", (err) => {
            reject(err);
        });
    });
}

async function processBackup(dbName) {
    const backupStem = makeBackupStem();
    const sql = await createBackup(dbName, backupStem);

    try {
        const enc = await zipAndEncrypt(sql, backupStem);
        return enc;
    } finally {
        try {
            await fs.unlink(sql);
            console.log(`🗑️ Raw backup deleted: ${sql}`);
        } catch (cleanupErr) {
            console.error(`⚠️ Warning: Failed to delete raw backup file ${sql}:`, cleanupErr.message);
        }
    }
}

module.exports = { processBackup };
