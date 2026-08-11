const db = require('./db/models');

(async () => {
  try {
    // 1. Update all item_master rows matching A4 Paper to set is_happy_hour = true, is_tax_inclusive = true
    const [updateResult] = await db.query(`
      UPDATE item_master
      SET is_tax_inclusive = true,
          is_happy_hour = true
      WHERE item_name LIKE '%A4 Paper%'
    `);
    console.log('✅ Updated all A4 Paper items in item_master with is_tax_inclusive = true and is_happy_hour = true');

    // 2. Check and print all A4 Paper rows
    const [rows] = await db.query(
      "SELECT id, item_code, item_name, rate, retail_sale_price, mrp, is_tax_inclusive, is_happy_hour, updated_at FROM item_master WHERE item_name LIKE '%A4 Paper%'"
    );
    console.log('\nVerified A4 Paper rows in DB:');
    console.log(JSON.stringify(rows, null, 2));

    process.exit(0);
  } catch(e) {
    console.error('ERROR:', e.message);
    process.exit(1);
  }
})();
