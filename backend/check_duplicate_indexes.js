const db = require('./db/models');

(async () => {
  try {
    const [dupes] = await db.query(`
      SELECT tablename, count(*) as index_count
      FROM pg_indexes
      WHERE schemaname = 'public'
      GROUP BY tablename
      HAVING count(*) > 5
      ORDER BY count(*) DESC
    `);
    console.log('TABLES WITH EXCESSIVE INDEXES:\n', JSON.stringify(dupes, null, 2));

    process.exit(0);
  } catch(e) {
    console.error('ERROR:', e.message);
    process.exit(1);
  }
})();
