import { spawn } from "child_process";
import { zipAndEncrypt } from "../utils/zip";
import path from "path";
import fs from "fs/promises";
import fsSync from "fs";
import loadConfig from "../utils/decryptConfig";
import { Sequelize, QueryTypes } from "sequelize";
import { findPostgresBinary } from "../utils/pgBinaries";

const isCompiled = typeof (process as any).pkg !== "undefined";
const baseDir = isCompiled ? path.dirname(process.execPath) : path.join(__dirname, "..");

function makeBackupStem(): string {
    return `backup_${new Date().toISOString().replace(/[:.]/g, "-")}_${process.pid}_${Math.random().toString(36).slice(2, 8)}`;
}

function escapeSqlString(val: any): string | number | boolean {
    if (val === null || val === undefined) return "NULL";
    if (typeof val === "boolean" || typeof val === "number") return val;
    if (val instanceof Date) return `'${val.toISOString()}'`;
    if (Buffer.isBuffer(val)) return `E'\\\\x${val.toString('hex')}'`;
    if (typeof val === "object") return `'${JSON.stringify(val).replace(/'/g, "''")}'`;
    return `'${String(val).replace(/'/g, "''")}'`;
}

async function createFallbackNodeBackup(dbName: string, backupStem: string): Promise<string> {
    console.log("⚡ Utilizing Node.js Pure Database Exporter fallback...");
    const backupsDir = path.join(baseDir, "backups");
    if (!fsSync.existsSync(backupsDir)) {
        await fs.mkdir(backupsDir, { recursive: true });
    }
    const file = path.join(backupsDir, `${backupStem}.sql`);
    
    const dbConfig = loadConfig();

    let sequelize: Sequelize;
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
        sequelize = new Sequelize(dbName || dbConfig.db_database, dbConfig.db_user || "postgres", dbConfig.db_password, {
            host: dbConfig.db_host || "127.0.0.1",
            port: Number(dbConfig.db_port || 5432),
            dialect: "postgres",
            logging: false
        });
    }

    try {
        const tables: any[] = await sequelize.query(
            "SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE' ORDER BY table_name;",
            { type: QueryTypes.SELECT }
        );

        let sqlOutput = `-- Pure Node.js Database Dump\n-- Generated: ${new Date().toISOString()}\n\n`;
        sqlOutput += `SET statement_timeout = 0;\n`;
        sqlOutput += `SET client_encoding = 'UTF8';\n`;
        sqlOutput += `SET standard_conforming_strings = on;\n`;
        sqlOutput += `SET check_function_bodies = false;\n`;
        sqlOutput += `SET client_min_messages = warning;\n`;
        sqlOutput += `SET row_security = off;\n`;
        sqlOutput += `SET session_replication_role = replica;\n\n`; // Bypass FK constraint order issues

        for (const t of tables) {
            const tableName = t.table_name;
            if (tableName === 'spatial_ref_sys') continue;

            const rows: any[] = await sequelize.query(`SELECT * FROM "${tableName}";`, { type: QueryTypes.SELECT });
            if (!rows || rows.length === 0) continue;

            sqlOutput += `-- Data for table: ${tableName}\n`;
            for (const row of rows) {
                const keys = Object.keys(row).map(k => `"${k}"`).join(", ");
                const vals = Object.values(row).map(escapeSqlString).join(", ");

                sqlOutput += `INSERT INTO "${tableName}" (${keys}) VALUES (${vals}) ON CONFLICT DO NOTHING;\n`;
            }
            sqlOutput += "\n";
        }

        // Sequence update block
        sqlOutput += `-- Reset all serial sequences to max value\n`;
        sqlOutput += `DO $$\n`;
        sqlOutput += `DECLARE\n`;
        sqlOutput += `    r RECORD;\n`;
        sqlOutput += `BEGIN\n`;
        sqlOutput += `    FOR r IN (\n`;
        sqlOutput += `        SELECT c.table_name, c.column_name, pg_get_serial_sequence(c.table_name, c.column_name) AS seq_name\n`;
        sqlOutput += `        FROM information_schema.columns c\n`;
        sqlOutput += `        WHERE c.table_schema = 'public' AND pg_get_serial_sequence(c.table_name, c.column_name) IS NOT NULL\n`;
        sqlOutput += `    ) LOOP\n`;
        sqlOutput += `        EXECUTE format('SELECT setval(''%s'', COALESCE((SELECT MAX(%I) FROM %I), 1), true)', r.seq_name, r.column_name, r.table_name);\n`;
        sqlOutput += `    END LOOP;\n`;
        sqlOutput += `END $$;\n\n`;
        sqlOutput += `SET session_replication_role = DEFAULT;\n`;

        await fs.writeFile(file, sqlOutput, "utf8");
        console.log("✅ Fallback Node.js dump created successfully");
        return file;
    } catch (err: any) {
        console.error("❌ Fallback Node.js dump failed:", err.message);
        throw err;
    } finally {
        await sequelize.close().catch(() => {});
    }
}

function createBackup(dbName: string, backupStem: string): Promise<string> {
    const config = loadConfig();
    const dbUrl = process.env.DATABASE_URL || config.DATABASE_URL;
    const pgDumpPath = findPostgresBinary("pg_dump");

    const backupsDir = path.join(baseDir, "backups");
    if (!fsSync.existsSync(backupsDir)) {
        fsSync.mkdirSync(backupsDir, { recursive: true });
    }

    return new Promise((resolve, reject) => {
        const file = path.join(backupsDir, `${backupStem}.sql`);
        const env: any = {
            ...process.env,
            PGPASSWORD: config.db_password || "",
            PGSSLMODE: (process.env.DB_SSL === 'true' || (dbUrl && dbUrl.includes('render.com'))) ? 'require' : 'prefer'
        };

        let args: string[] = [];
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

        console.log(`🚀 Backup started via pg_dump (${pgDumpPath})...`);

        let dump: any;
        try {
            dump = spawn(pgDumpPath, args, { env });
        } catch (spawnErr: any) {
            console.warn(`⚠️ Failed to spawn pg_dump (${spawnErr.message}). Using Node.js exporter...`);
            return createFallbackNodeBackup(dbName, backupStem).then(resolve).catch(reject);
        }

        let stderrLogs = "";

        dump.stderr.on("data", (data: any) => {
            const str = data.toString();
            stderrLogs += str;
            console.log(`📦 pg_dump: ${str.trim()}`);
        });

        dump.on("close", (code: number) => {
            if (code === 0) {
                console.log("✅ Backup completed via pg_dump");
                resolve(file);
            } else {
                console.warn(`⚠️ pg_dump exited with code ${code}. Error logs: ${stderrLogs}`);
                // Fallback to pure Node.js dump on pg_dump failure
                createFallbackNodeBackup(dbName, backupStem).then(resolve).catch(reject);
            }
        });

        dump.on("error", (err: any) => {
            console.warn(`⚠️ pg_dump process error: ${err.message}. Triggering Node.js fallback...`);
            createFallbackNodeBackup(dbName, backupStem).then(resolve).catch(reject);
        });
    });
}

export async function processBackup(dbName: string): Promise<string> {
    const backupStem = makeBackupStem();
    const sql = await createBackup(dbName, backupStem);

    try {
        const enc = await zipAndEncrypt(sql, backupStem);
        return enc;
    } finally {
        try {
            await fs.unlink(sql);
            console.log(`🗑️ Raw backup deleted: ${sql}`);
        } catch (cleanupErr: any) {
            console.error(`⚠️ Warning: Failed to delete raw backup file ${sql}:`, cleanupErr.message);
        }
    }
}

export default { processBackup };
