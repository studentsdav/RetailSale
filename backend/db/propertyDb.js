const { Sequelize } = require('sequelize');
const pg = require('pg');

// Override parsing for TIMESTAMP WITHOUT TIME ZONE (OID 1114) to parse in local timezone
pg.types.setTypeParser(pg.types.builtins.TIMESTAMP, (stringValue) => {
    return stringValue ? new Date(stringValue.replace(' ', 'T')) : null;
});

const loadConfig = require("../utils/decryptConfig");

// Calculate local timezone offset dynamically (e.g., +05:30 or -05:00)
const offsetMinutes = new Date().getTimezoneOffset();
const offsetHours = Math.abs(Math.floor(offsetMinutes / 60));
const offsetMins = Math.abs(offsetMinutes % 60);
const sign = offsetMinutes <= 0 ? '+' : '-';
const localTimezone = `${sign}${String(offsetHours).padStart(2, '0')}:${String(offsetMins).padStart(2, '0')}`;

let propertyDb;

try {
    const config = loadConfig();

    if (!config.db_database) {
        throw new Error("❌ Database name missing in config.enc");
    }


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
            pool: {
                max: 10,
                min: 0,
                acquire: 30000,
                idle: 10000
            }
        }
    );

} catch (error) {
    console.log("⚠️ [SYSTEM] config.enc missing or invalid. Booting database in safe-mode for recovery.");
    propertyDb = new Sequelize('recovery_db', 'recovery_user', 'recovery_pass', {
        host: '127.0.0.1',
        dialect: 'postgres',
        logging: false,
        timezone: localTimezone
    });

}

module.exports = propertyDb;