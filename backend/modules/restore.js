const fs = require("fs");
const path = require("path");
const { spawn } = require("child_process");
const { Client } = require("pg");
const { sendToGoogleScript } = require("./driveService");
const { decryptAndUnzip } = require("../utils/decrypt");
const loadConfig = require("../utils/decryptConfig");
const { findPostgresBinary } = require("../utils/pgBinaries");
const runMigrations = require("../utils/migrationRunner");
const propertyDb = require("../db/models");

const isCompiled = typeof process.pkg !== 'undefined';
const baseDir = isCompiled ? path.dirname(process.execPath) : path.join(__dirname, '..');

function getDbClientConfig(db_name, db_user, db_pass, host, port) {
    const config = loadConfig();
    const dbUrl = process.env.DATABASE_URL || config.DATABASE_URL;
    if (dbUrl) {
        return {
            connectionString: dbUrl,
            ssl: (process.env.DB_SSL === 'true' || dbUrl.includes('render.com')) ? { rejectUnauthorized: false } : false
        };
    }
    return {
        host: host || config.db_host || "127.0.0.1",
        port: Number(port || config.db_port || 5432),
        user: db_user || config.db_user || "postgres",
        password: String(db_pass || config.db_password || ""),
        database: db_name || config.db_database || "postgres"
    };
}

async function cleanDatabaseSchema(db_name, db_user, db_pass, host, port) {
    const psqlPath = findPostgresBinary("psql");
    const h = host || "127.0.0.1";
    const p = String(port || 5432);

    console.log(`🧹 Cleaning database schema for ${db_name}...`);

    try {
        await new Promise((resolve, reject) => {
            const env = { ...process.env, PGPASSWORD: db_pass };
            const args = [
                "-h", h,
                "-p", p,
                "-U", db_user,
                "-d", db_name,
                "-c", "DROP SCHEMA IF EXISTS public CASCADE; CREATE SCHEMA public; GRANT ALL ON SCHEMA public TO public;"
            ];

            const cleanProcess = spawn(psqlPath, args, { env });

            cleanProcess.stderr.on("data", (data) => console.log(`🧹 psql cleanup: ${data.toString().trim()}`));

            cleanProcess.on("close", (code) => {
                if (code === 0) {
                    console.log("✅ Database schema cleaned successfully via psql!");
                    resolve();
                } else {
                    reject(new Error("psql schema cleanup exited with code " + code));
                }
            });

            cleanProcess.on("error", (err) => {
                reject(err);
            });
        });
    } catch (psqlErr) {
        console.warn(`⚠️ psql schema cleanup failed (${psqlErr.message}). Using direct Node.js DB connection...`);
        const client = new Client(getDbClientConfig(db_name, db_user, db_pass, host, port));
        await client.connect();
        try {
            await client.query("DROP SCHEMA IF EXISTS public CASCADE; CREATE SCHEMA public; GRANT ALL ON SCHEMA public TO public;");
            console.log("✅ Database schema cleaned successfully via Node.js client!");
        } finally {
            await client.end().catch(() => {});
        }
    }
}

async function executeSqlFileViaNode(sqlFilePath, db_name, db_user, db_pass, host, port) {
    console.log("⚡ Executing SQL restore payload via pure Node.js PG client...");
    const client = new Client(getDbClientConfig(db_name, db_user, db_pass, host, port));
    await client.connect();

    try {
        const sqlContent = fs.readFileSync(sqlFilePath, "utf8");

        // If the SQL file does not create tables (e.g. Node fallback dump), run migrations first
        const hasCreateTable = /CREATE\s+TABLE/i.test(sqlContent);
        if (!hasCreateTable) {
            console.log("📦 Backup contains data-only dump. Generating schema migrations first...");
            await runMigrations(propertyDb);
        }

        await client.query(sqlContent);
        console.log("✅ SQL restore completed via Node.js client");
    } finally {
        await client.end().catch(() => {});
    }
}

async function executeDatabaseRestore(sqlFilePath, db_name, db_user, db_pass, host, port) {
    const config = loadConfig();
    const targetDb = db_name || config.db_database;
    const targetUser = db_user || config.db_user || "postgres";
    const targetPass = db_pass || config.db_password || "";
    const targetHost = host || config.db_host || "127.0.0.1";
    const targetPort = port || config.db_port || 5432;

    // 1. Clean the schema first to prevent foreign key and constraint conflicts
    await cleanDatabaseSchema(targetDb, targetUser, targetPass, targetHost, targetPort);

    // 2. Perform the actual restore
    let restoreSuccess = false;
    const psqlPath = findPostgresBinary("psql");

    try {
        console.log(`🚀 Starting database restore for ${targetDb} via psql (${psqlPath})...`);
        await new Promise((resolve, reject) => {
            const env = { ...process.env, PGPASSWORD: targetPass };
            const args = [
                "-h", targetHost,
                "-p", String(targetPort),
                "-U", targetUser,
                "-d", targetDb,
                "-f", sqlFilePath
            ];

            const restoreProcess = spawn(psqlPath, args, { env });

            restoreProcess.stderr.on("data", (data) => console.log(`📦 psql: ${data.toString().trim()}`));

            restoreProcess.on("close", (code) => {
                if (code === 0) {
                    console.log("✅ Database restored completely via psql!");
                    resolve();
                } else {
                    reject(new Error("psql failed with code " + code));
                }
            });

            restoreProcess.on("error", (err) => {
                reject(err);
            });
        });
        restoreSuccess = true;
    } catch (psqlErr) {
        console.warn(`⚠️ psql restore failed (${psqlErr.message}). Triggering Node.js SQL restore runner fallback...`);
        await executeSqlFileViaNode(sqlFilePath, targetDb, targetUser, targetPass, targetHost, targetPort);
        restoreSuccess = true;
    }

    // 3. Post-Restore Schema Alignment & Migration verification
    try {
        console.log("🔄 Reconciling database schema and running migrations after restore...");
        await runMigrations(propertyDb);
        console.log("✅ Post-restore migrations verified successfully");
    } catch (migErr) {
        console.warn("⚠️ Notice during post-restore migration check:", migErr.message);
    }
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
        await executeDatabaseRestore(
            extractedSqlFile,
            config.db_database,
            config.db_user,
            config.db_password,
            config.db_host,
            config.db_port
        );

        // 4. Cleanup temporary files
        console.log("[RESTORE] Scrubbing temporary files...");
        [encFile, zipFile, sqlFile, extractedSqlFile].forEach(file => {
            if (file && fs.existsSync(file)) {
                try { fs.unlinkSync(file); } catch (_) {}
            }
        });
        if (fs.existsSync(restoreDir)) {
            fs.rmSync(restoreDir, { recursive: true, force: true });
        }

        console.log("[RESTORE] Database recovery sequence completed successfully.");

    } catch (error) {
        console.error(`[RESTORE] Workflow Interrupted: ${error.message}`);

        // Safety cleanup
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

async function restoreFromEncBuffer(encBuffer) {
    const config = loadConfig();
    const restoreDir = path.join(baseDir, "backups", `restore-local-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`);
    const encFile = path.join(restoreDir, "restore.enc");
    const zipFile = path.join(restoreDir, "restore.zip");

    try {
        fs.mkdirSync(restoreDir, { recursive: true });
        fs.writeFileSync(encFile, encBuffer);

        const extractedSqlFile = await decryptAndUnzip(encFile, zipFile, restoreDir);
        if (!fs.existsSync(extractedSqlFile)) {
            throw new Error("Extraction corrupted: 'backup.sql' was not found in the archive.");
        }

        await executeDatabaseRestore(
            extractedSqlFile,
            config.db_database,
            config.db_user,
            config.db_password,
            config.db_host,
            config.db_port
        );
    } finally {
        if (fs.existsSync(restoreDir)) {
            try { fs.rmSync(restoreDir, { recursive: true, force: true }); } catch (_) { }
        }
    }
}

module.exports = { autoRestoreLatest, restoreFromEncBuffer, executeDatabaseRestore, cleanDatabaseSchema };
