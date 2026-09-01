const { spawn } = require("child_process");
const { zipAndEncrypt } = require("../utils/zip");
const path = require("path");
const fs = require("fs").promises;
const fsSync = require("fs");
const loadConfig = require("../utils/decryptConfig");
const { Sequelize, QueryTypes } = require("sequelize");

let pgDumpPath = "pg_dump";
if (process.platform === "win32") {
    const candidateWinPaths = [
        "C:\\Program Files\\PostgreSQL\\18\\bin\\pg_dump.exe",
        "C:\\Program Files\\PostgreSQL\\17\\bin\\pg_dump.exe",
        "C:\\Program Files\\PostgreSQL\\16\\bin\\pg_dump.exe",
        "C:\\Program Files\\PostgreSQL\\15\\bin\\pg_dump.exe"
    ];
    const foundWinPath = candidateWinPaths.find(p => fsSync.existsSync(p));
    if (foundWinPath) {
        pgDumpPath = foundWinPath;
    }
}

const isCompiled = typeof process.pkg !== "undefined";
const baseDir = isCompiled ? path.dirname(process.execPath) : path.join(__dirname, "..");

function makeBackupStem() {
    return `backup_${new Date().toISOString().replace(/[:.]/g, "-")}_${process.pid}_${Math.random().toString(36).slice(2, 8)}`;
}

async function createFallbackNodeBackup(dbName, backupStem) {
    console.log("⚡ pg_dump unavailable or socket failed. Utilizing Node.js Pure Database Exporter fallback...");
    const backupsDir = path.join(baseDir, "backups");
    if (!fsSync.existsSync(backupsDir)) {
        await fs.mkdir(backupsDir, { recursive: true });
    }
    const file = path.join(backupsDir, `${backupStem}.sql`);
    
    const dbConfig = loadConfig();

    let sequelize;
    const dbUrl = process.env.DATABASE_URL || dbConfig.DATABASE_URL;
    if (dbUrl) {
        sequelize = new Sequelize(dbUrl, {
            logging: false,
            dialectOptions: {
                ssl: (process.env.DB_SSL === 'true' || dbUrl.includes('render.com')) ? {
                    require: true,
                    rejectUnauthorized: false
                } : false
            }
        });
    } else {
        sequelize = new Sequelize(dbName || dbConfig.db_database, dbConfig.db_user, dbConfig.db_password, {
            host: dbConfig.db_host || "127.0.0.1",
            port: dbConfig.db_port || 5432,
            dialect: "postgres",
            logging: false
        });
    }

    try {
        const tables = await sequelize.query(
            "SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE';",
            { type: QueryTypes.SELECT }
        );

        let sqlOutput = `-- Pure Node.js Database Dump\n-- Generated: ${new Date().toISOString()}\n\n`;

        for (const t of tables) {
            const tableName = t.table_name;
            if (tableName === 'spatial_ref_sys') continue;

            const rows = await sequelize.query(`SELECT * FROM "${tableName}";`, { type: QueryTypes.SELECT });
            if (!rows || rows.length === 0) continue;

            sqlOutput += `-- Data for table: ${tableName}\n`;
            for (const row of rows) {
                const keys = Object.keys(row).map(k => `"${k}"`).join(", ");
                const vals = Object.values(row).map(v => {
                    if (v === null || v === undefined) return "NULL";
                    if (typeof v === "boolean" || typeof v === "number") return v;
                    if (v instanceof Date) return `'${v.toISOString()}'`;
                    if (typeof v === "object") return `'${JSON.stringify(v).replace(/'/g, "''")}'`;
                    return `'${String(v).replace(/'/g, "''")}'`;
                }).join(", ");

                sqlOutput += `INSERT INTO "${tableName}" (${keys}) VALUES (${vals}) ON CONFLICT DO NOTHING;\n`;
            }
            sqlOutput += "\n";
        }

        await fs.writeFile(file, sqlOutput, "utf8");
        console.log("✅ Fallback Node.js dump created successfully");
        return file;
    } catch (err) {
        console.error("❌ Fallback Node.js dump failed:", err.message);
        throw err;
    } finally {
        await sequelize.close().catch(() => {});
    }
}

function createBackup(dbName, backupStem) {
    const config = loadConfig();
    const dbUrl = process.env.DATABASE_URL || config.DATABASE_URL;

    const backupsDir = path.join(baseDir, "backups");
    if (!fsSync.existsSync(backupsDir)) {
        fsSync.mkdirSync(backupsDir, { recursive: true });
    }

    return new Promise((resolve, reject) => {
        const file = path.join(backupsDir, `${backupStem}.sql`);
        const env = {
            ...process.env,
            PGPASSWORD: config.db_password || "",
            PGSSLMODE: (process.env.DB_SSL === 'true' || (dbUrl && dbUrl.includes('render.com'))) ? 'require' : 'prefer'
        };

        let args = [];
        if (dbUrl) {
            args = [
                "--dbname=" + dbUrl,
                "-F", "p",
                "-c",
                "-f", file
            ];
        } else {
            args = [
                "-h", config.db_host || "127.0.0.1",
                "-p", String(config.db_port || 5432),
                "-U", config.db_user || "postgres",
                "-F", "p",
                "-c",
                "-f", file,
                dbName || config.db_database || "postgres"
            ];
        }

        console.log(`🚀 Backup started via pg_dump...`);

        const dump = spawn(pgDumpPath, args, { env });

        let stderrLogs = "";

        dump.stderr.on("data", (data) => {
            const str = data.toString();
            stderrLogs += str;
            console.log(`📦 pg_dump: ${str.trim()}`);
        });

        dump.on("close", (code) => {
            if (code === 0) {
                console.log("✅ Backup completed via pg_dump");
                resolve(file);
            } else {
                console.warn(`⚠️ pg_dump exited with code ${code}. Error logs: ${stderrLogs}`);
                // Fallback to pure Node.js dump on pg_dump failure
                createFallbackNodeBackup(dbName, backupStem).then(resolve).catch(reject);
            }
        });

        dump.on("error", (err) => {
            console.warn(`⚠️ pg_dump process error: ${err.message}. Triggering Node.js fallback...`);
            createFallbackNodeBackup(dbName, backupStem).then(resolve).catch(reject);
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
