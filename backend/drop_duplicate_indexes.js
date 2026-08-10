const db = require('./db/models');

(async () => {
  try {
    // Find all auto-generated duplicate indexes matching _key\d+
    const [indexes] = await db.query(`
      SELECT indexname, tablename
      FROM pg_indexes
      WHERE schemaname = 'public'
        AND indexname ~ '_key[0-9]+$'
    `);

    console.log(`Found ${indexes.length} duplicate indexes to drop...`);

    let dropped = 0;
    for (const idx of indexes) {
      try {
        await db.query(`DROP INDEX IF EXISTS "${idx.indexname}"`);
        dropped++;
        if (dropped % 100 === 0) {
          console.log(`Dropped ${dropped}/${indexes.length} indexes...`);
        }
      } catch (e) {
        console.error(`Failed to drop ${idx.indexname}: ${e.message}`);
      }
    }

    console.log(`✅ Successfully dropped ${dropped} duplicate indexes!`);

    // Verify index counts now
    const [dupes] = await db.query(`
      SELECT tablename, count(*) as index_count
      FROM pg_indexes
      WHERE schemaname = 'public'
      GROUP BY tablename
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
