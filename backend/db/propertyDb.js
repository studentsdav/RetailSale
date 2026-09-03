const { Sequelize } = require('sequelize');
const pg = require('pg');

// Override parsing for TIMESTAMP WITHOUT TIME ZONE (OID 1114) to parse in local timezone
pg.types.setTypeParser(pg.types.builtins.TIMESTAMP, (stringValue) => {
    return stringValue ? new Date(stringValue.replace(' ', 'T')) : null;
});

const loadConfig = require("../utils/decryptConfig");

// Calculate local timezone offset dynamically or respect TZ environment variable
const envTz = process.env.TZ;
const offsetMinutes = new Date().getTimezoneOffset();
const offsetHours = Math.abs(Math.floor(offsetMinutes / 60));
const offsetMins = Math.abs(offsetMinutes % 60);
const sign = offsetMinutes <= 0 ? '+' : '-';
const localTimezone = envTz || `${sign}${String(offsetHours).padStart(2, '0')}:${String(offsetMins).padStart(2, '0')}`;

let propertyDb;

try {
    if (process.env.DATABASE_URL) {
        console.log("🔗 Connecting to PostgreSQL using DATABASE_URL...");
        const useSSL = process.env.DB_SSL !== 'false';
        propertyDb = new Sequelize(process.env.DATABASE_URL, {
            dialect: "postgres",
            logging: false,
            timezone: localTimezone,
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
                timezone: localTimezone,
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
        timezone: localTimezone
    });
}

module.exports = propertyDb;