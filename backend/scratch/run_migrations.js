const db = require('../db/models');
const runMigrations = require('../utils/migrationRunner');

async function main() {
    try {
        await db.authenticate();
        console.log('Connected to database.');
        await runMigrations(db);
        console.log('Migrations completed successfully!');
    } catch (err) {
        console.error('Error running migrations:', err);
    } finally {
        process.exit(0);
    }
}

main();
