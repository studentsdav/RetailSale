const { Sequelize } = require("sequelize");
require("pg");
const loadConfig = require("./decryptConfig");

async function waitForPostgres() {

    const config = loadConfig();

    const host = config.db_host || "127.0.0.1";
    const user = config.db_user || "postgres";
    const password = config.db_password;

    const portsToTry = [
        Number(config.db_port) || 5432,
        5432,
        5433
    ];

    let retries = 30;

    while (retries > 0) {

        for (const port of portsToTry) {

            try {

                if (!config.db_database) {
                    console.log("🔥 Config:", config);
                    throw new Error("❌ Database name missing in config.enc");
                }

                const sequelize = new Sequelize(
                    "postgres",
                    user,
                    password,
                    {
                        host: host,
                        port: port,
                        dialect: "postgres",
                        logging: false,
                        dialectOptions: { connectTimeout: 3000 }
                    }
                );

                await sequelize.authenticate();
                await sequelize.close();

                console.log(`✅ PostgreSQL ready on ${host}:${port}`);

                return true;

            } catch (err) {

                console.log(`❌ Failed on port ${port}:`, err.message);

            }
        }

        retries--;

        console.log(`⏳ Waiting for PostgreSQL... (${retries} retries left)`);

        await new Promise(r => setTimeout(r, 3000));
    }

    throw new Error("PostgreSQL not reachable");
}

module.exports = waitForPostgres;