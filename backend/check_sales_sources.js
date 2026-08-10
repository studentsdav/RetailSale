const db = require('./db/models');

(async () => {
  try {
    const [recent] = await db.query(`
      SELECT id, sale_no, order_type, COALESCE(order_type, 'STORE') as tag
      FROM sales_headers
      ORDER BY id DESC LIMIT 10
    `);
    console.log('Recent sales order_type:');
    console.log(JSON.stringify(recent, null, 2));

    const [cols] = await db.query(`
      SELECT column_name
      FROM information_schema.columns
      WHERE table_name = 'sales_headers' AND column_name LIKE '%type%' OR column_name LIKE '%source%' OR column_name LIKE '%mode%'
    `);
    console.log('\nRelevant columns:');
    console.log(JSON.stringify(cols, null, 2));

    process.exit(0);
  } catch(e) {
    console.error('ERROR:', e.message);
    process.exit(1);
  }
})();
