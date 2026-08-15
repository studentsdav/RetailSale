const db = require('../db/models');
const runMigrations = require('../utils/migrationRunner');

async function forceMigrations() {
    try {
        await db.authenticate();
        console.log('Connected to database.');

        console.log('Truncating schema_version to force rerun...');
        await db.query('TRUNCATE TABLE schema_version CASCADE');

        console.log('Running migrations...');
        await runMigrations(db);
        console.log('Migrations completed successfully.');

    } catch (err) {
        console.error('Error:', err);
    } finally {
        process.exit(0);
    }
}

forceMigrations();
