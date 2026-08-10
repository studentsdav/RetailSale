const db = require('./db/models');
(async () => {
  try {
    const [indexes] = await db.query(`
      SELECT indexname, indexdef
      FROM pg_indexes
      WHERE tablename = 'sales_headers' AND schemaname = 'public'
    `);
    console.log('sales_headers indexes:');
    console.log(JSON.stringify(indexes, null, 2));
    process.exit(0);
  } catch(e) {
    console.error('ERROR:', e.message);
    process.exit(1);
  }
})();
