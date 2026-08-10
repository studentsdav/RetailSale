const db = require('./db/models');

(async () => {
  try {
    const [rows] = await db.query(
      "SELECT id, item_code, item_name, rate, retail_sale_price, mrp, is_tax_inclusive, is_happy_hour, updated_at FROM item_master WHERE item_name LIKE '%A4 Paper%'"
    );
    console.log('A4 Paper Rim rows in DB:');
    console.log(JSON.stringify(rows, null, 2));

    process.exit(0);
  } catch(e) {
    console.error('ERROR:', e.message);
    process.exit(1);
  }
})();
