const db = require('./db/models');

(async () => {
  try {
    const [res] = await db.query("SELECT current_database()");
    const dbName = res[0].current_database;
    console.log('Current Database Name:', dbName);

    await db.query(`ALTER DATABASE "${dbName}" SET synchronous_commit = 'off'`);
    console.log(`✅ Set synchronous_commit = 'off' on database "${dbName}"`);

    process.exit(0);
  } catch(e) {
    console.error('ERROR:', e.message);
    process.exit(1);
  }
})();
