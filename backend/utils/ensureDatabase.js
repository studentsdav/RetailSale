const { Sequelize } = require("sequelize");
const loadConfig = require("../utils/decryptConfig");

async function ensureDatabase() {

    const config = loadConfig();

    // ✅ validation
    if (!config.db_database) throw new Error("❌ db_database missing");
    if (!config.db_user) throw new Error("❌ db_user missing");
    if (!config.db_password) throw new Error("❌ db_password missing");

    const dbName = config.db_database;
    const host = config.db_host || "127.0.0.1";

    const portsToTry = [
        Number(config.db_port) || 5432,
        5432,
        5433
    ];

    let connected = false;
    let sequelize;

    // ✅ try multiple ports
    for (const port of portsToTry) {

        try {

            sequelize = new Sequelize(
                "postgres",
                config.db_user,
                config.db_password,
                {
                    host: host,
                    port: port,
                    dialect: "postgres",
                    logging: false,
                    dialectOptions: {
                        connectTimeout: 3000
                    }
                }
            );

            await sequelize.authenticate();

            console.log(`✅ Connected to PostgreSQL on ${host}:${port}`);

            connected = true;
            break;

        } catch (err) {

            console.log(`❌ Failed on port ${port}: ${err.message}`);
        }
    }

    if (!connected) {
        throw new Error("❌ Unable to connect to PostgreSQL");
    }

    try {

        // ✅ check database existence safely
        const [rows] = await sequelize.query(
            "SELECT 1 FROM pg_database WHERE datname = $1",
            { bind: [dbName] }
        );

        if (rows.length === 0) {

            console.log("🟡 Creating database:", dbName);

            // ⚠️ CREATE DATABASE cannot use bind, so sanitize manually
            const safeDbName = dbName.replace(/[^a-zA-Z0-9_]/g, "");

            await sequelize.query(`CREATE DATABASE "${safeDbName}"`);

            console.log("✅ Database created");

        } else {

            console.log("✅ Database already exists");
        }

    } catch (err) {

        console.error("❌ Database check/create failed:", err.message);
        throw err;

    } finally {

        if (sequelize) {
            await sequelize.close();
        }
    }
}

module.exports = ensureDatabase;