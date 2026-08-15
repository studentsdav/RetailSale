const db = require('../db/models');
const migrations = require('../utils/migrations');
const runMigrations = require('../utils/migrationRunner');

async function restore() {
    try {
        await db.authenticate();
        console.log('Connected to database.');

        console.log('Truncating schema_version...');
        await db.query('TRUNCATE TABLE schema_version CASCADE');

        console.log('Inserting schema_version entries up to 95 (deduplicated)...');
        const added = new Set();
        for (const m of migrations) {
            if (m.version <= 95 && !added.has(m.version)) {
                await db.query('INSERT INTO schema_version(version) VALUES ($1)', {
                    bind: [m.version]
                });
                added.add(m.version);
            }
        }
        console.log('Entries restored.');

        console.log('Running pending migrations...');
        await runMigrations(db);
        console.log('Migrations completed successfully.');

    } catch (err) {
        console.error('Error:', err);
    } finally {
        process.exit(0);
    }
}

restore();
