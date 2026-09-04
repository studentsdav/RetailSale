const { Sequelize } = require('sequelize');
const pg = require('pg');

const loadConfig = require("../utils/decryptConfig");

// Standardize database session timezone to UTC (+00:00) so all stored timestamps
// have a single, unified baseline across cloud containers and local workstations.
const dbTimezone = '+00:00';

let propertyDb;

try {
    if (process.env.DATABASE_URL) {
        console.log("🔗 Connecting to PostgreSQL using DATABASE_URL...");
        const useSSL = process.env.DB_SSL !== 'false';
        propertyDb = new Sequelize(process.env.DATABASE_URL, {
            dialect: "postgres",
            logging: false,
            timezone: dbTimezone,
            dialectOptions: useSSL ? {
                ssl: {
                    require: true,
                    rejectUnauthorized: false
                }
            } : {
                options: '-c synchronous_commit=off'
            },
            pool: {
                max: 20,
                min: 2,
                acquire: 60000,
                idle: 86400000,
                evict: 60000
            }
        });
    } else {
        const config = loadConfig();

        if (!config.db_database) {
            throw new Error("❌ Database name missing in config");
        }

        const useSSL = process.env.DB_SSL === 'true';

        propertyDb = new Sequelize(
            config.db_database,
            config.db_user,
            config.db_password,
            {
                host: config.db_host || "127.0.0.1",
                port: Number(config.db_port || 5432),
                dialect: "postgres",
                logging: false,
                timezone: dbTimezone,
                dialectOptions: useSSL ? {
                    ssl: {
                        require: true,
                        rejectUnauthorized: false
                    }
                } : {
                    options: '-c synchronous_commit=off'
                },
                pool: {
                    max: 20,
                    min: 4,
                    acquire: 60000,
                    idle: 86400000,
                    evict: 60000
                }
            }
        );
    }

} catch (error) {
    console.log("⚠️ [SYSTEM] Database configuration error. Booting in recovery mode:", error.message);
    propertyDb = new Sequelize('recovery_db', 'recovery_user', 'recovery_pass', {
        host: '127.0.0.1',
        dialect: 'postgres',
        logging: false,
        timezone: dbTimezone
    });
}

module.exports = propertyDb;