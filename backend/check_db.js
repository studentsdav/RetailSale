const Sequelize = require('sequelize');
const loadConfig = require('./utils/decryptConfig');

async function check() {
    try {
        const config = loadConfig();
        const db = new Sequelize(config.db_database, config.db_user, config.db_password, {
            host: config.db_host || "127.0.0.1",
            port: Number(config.db_port || 5432),
            dialect: "postgres",
            logging: false
        });

        await db.authenticate();
        console.log("✅ DB Connected successfully.");

        const [vRows] = await db.query("SELECT MAX(version) as version FROM schema_version");
        console.log("Current schema version:", vRows[0].version);

        const [cols] = await db.query(
            "SELECT column_name FROM information_schema.columns WHERE table_name = 'property_info'"
        );
        console.log("Columns in property_info:");
        console.log(cols.map(c => c.column_name).join(', '));

        await db.close();
    } catch (e) {
        console.error("❌ Diagnostic error:", e);
    }
}

check();
