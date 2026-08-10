const db = require('./db/models');

(async () => {
  try {
    const [constraints] = await db.query(`
      SELECT conname, relname
      FROM pg_constraint c
      JOIN pg_class cl ON cl.oid = c.conrelid
      WHERE conname ~ '_key[0-9]+$'
    `);

    console.log(`Found ${constraints.length} duplicate constraints to drop...`);

    let dropped = 0;
    for (const con of constraints) {
      try {
        await db.query(`ALTER TABLE "${con.relname}" DROP CONSTRAINT IF EXISTS "${con.conname}"`);
        dropped++;
        if (dropped % 50 === 0) {
          console.log(`Dropped ${dropped}/${constraints.length} constraints...`);
        }
      } catch (e) {
        console.error(`Failed to drop constraint ${con.conname} on ${con.relname}: ${e.message}`);
      }
    }

    console.log(`✅ Successfully dropped ${dropped} duplicate constraints!`);

    // Verify index counts now
    const [dupes] = await db.query(`
      SELECT tablename, count(*) as index_count
      FROM pg_indexes
      WHERE schemaname = 'public'
      GROUP BY tablename
      HAVING count(*) > 5
      ORDER BY count(*) DESC
    `);
    console.log('\nUPDATED INDEX COUNTS:\n', JSON.stringify(dupes, null, 2));

    // Measure query performance on outlets and users now!
    let t = Date.now();
    await db.query("SELECT * FROM outlets WHERE id = 1");
    console.log('\n⚡ SELECT * FROM outlets WHERE id = 1 NOW took:', Date.now() - t, 'ms');

    t = Date.now();
    await db.query("SELECT * FROM users WHERE id = 1");
    console.log('⚡ SELECT * FROM users WHERE id = 1 NOW took:', Date.now() - t, 'ms');

    process.exit(0);
  } catch(e) {
    console.error('ERROR:', e.message);
    process.exit(1);
  }
})();
