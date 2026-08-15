const db = require('../db/models');
const runMigrations = require('../utils/migrationRunner');

async function fix() {
    try {
        await db.authenticate();
        console.log('Connected to database.');

        console.log('Deleting schema_version records >= 95...');
        await db.query('DELETE FROM schema_version WHERE version >= 95');

        console.log('Re-running migrations...');
        await runMigrations(db);
        console.log('Migrations completed successfully.');

    } catch (err) {
        console.error('Error running migrations:', err);
    } finally {
        process.exit(0);
    }
}

fix();
