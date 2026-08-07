const db = require('../db/models');
const runMigrations = require('../utils/migrationRunner');

async function run() {
    try {
        console.log("Starting migrations manually...");
        await db.authenticate();
        await runMigrations(db);
        console.log("✔ Migrations completed successfully!");
        process.exit(0);
    } catch (err) {
        console.error("❌ Migration execution failed: " + err.message);
        if (err.parent) {
            console.error("❌ DB Parent Error: " + err.parent.message);
        }
        process.exit(1);
    }
}

run();
