const db = require('./db/models');

(async () => {
  try {
    const [idxOutlets] = await db.query(
      "SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'outlets'"
    );
    console.log('INDEXES on outlets:\n', JSON.stringify(idxOutlets, null, 2));

    const [idxUsers] = await db.query(
      "SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'users'"
    );
    console.log('INDEXES on users:\n', JSON.stringify(idxUsers, null, 2));

    // Time a direct SELECT by ID on outlets
    let t = Date.now();
    await db.query("SELECT * FROM outlets WHERE id = 1");
    console.log('SELECT * FROM outlets WHERE id = 1 took:', Date.now() - t, 'ms');

    // Time a direct SELECT by ID on users
    t = Date.now();
    await db.query("SELECT * FROM users WHERE id = 1");
    console.log('SELECT * FROM users WHERE id = 1 took:', Date.now() - t, 'ms');

    process.exit(0);
  } catch(e) {
    console.error('ERROR:', e.message);
    process.exit(1);
  }
})();
