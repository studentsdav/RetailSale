const db = require('./db/models');

(async () => {
  try {
    const [res] = await db.query(`
      UPDATE sales_headers
      SET order_type = COALESCE(order_type, 'STORE'),
          sale_source = COALESCE(sale_source, order_type, 'STORE')
      WHERE order_type IS NULL OR sale_source IS NULL
    `);
    console.log('✅ Backfilled order_type and sale_source for existing bills in DB!');

    const [check] = await db.query(`
      SELECT id, sale_no, order_type, sale_source
      FROM sales_headers
      ORDER BY id DESC LIMIT 10
    `);
    console.log(JSON.stringify(check, null, 2));

    process.exit(0);
  } catch(e) {
    console.error('ERROR:', e.message);
    process.exit(1);
  }
})();
