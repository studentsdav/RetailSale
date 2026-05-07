const migrations = require('./migrations');

async function runMigrations(db) {

    await db.query(`
    CREATE TABLE IF NOT EXISTS schema_version (
      version INT PRIMARY KEY,
      applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  `);

    const [rows] = await db.query(
        "SELECT MAX(version) as version FROM schema_version"
    );

    let currentVersion = rows[0].version || 0;

    for (const migration of migrations) {

        if (migration.version > currentVersion) {

            console.log("Running migration:", migration.version);

            await migration.up(db);

            await db.query(
                "INSERT INTO schema_version(version) VALUES ($1)",
                { bind: [migration.version] }
            );

            currentVersion = migration.version;
        }
    }
}

module.exports = runMigrations;