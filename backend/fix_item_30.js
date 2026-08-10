const db = require('./db/models');

(async () => {
  try {
    // 1. Update id=30 A4 Paper Rim item to set retail_sale_price = 500.00
    await db.query(`
      UPDATE item_master
      SET retail_sale_price = 500.00,
          rate = 121.73,
          mrp = 600.00,
          is_tax_inclusive = true,
          is_happy_hour = true
      WHERE id = 30
    `);
    console.log('✅ Updated item_master id=30: retail_sale_price = 500.00, is_tax_inclusive = true, mrp = 600.00, is_happy_hour = true');

    // 2. Verify
    const [check] = await db.query(
      "SELECT id, item_code, item_name, rate, retail_sale_price, mrp, is_tax_inclusive, is_happy_hour FROM item_master WHERE id = 30"
    );
    console.log('\nVerified Item 30 DB row:');
    console.log(JSON.stringify(check, null, 2));

    process.exit(0);
  } catch(e) {
    console.error('ERROR:', e.message);
    process.exit(1);
  }
})();
