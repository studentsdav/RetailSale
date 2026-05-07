const { Sequelize } = require('sequelize');
require('pg');
const loadConfig = require("../utils/decryptConfig");

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
        logging: false
    });

}

module.exports = propertyDb;