const db = require('./db/models');

(async () => {
  try {
    // 1. Create temporary item with is_happy_hour = true, is_tax_inclusive = true, mrp = 999.00
    const created = await db.models.item_master.create({
      outlet_id: 1,
      item_code: 'TEST_PERSIST_01',
      item_name: 'Test Persistence Item',
      item_group: 'General',
      sub_category: 'General',
      brand: 'Test',
      unit: 'PCS',
      rate: 100,
      retail_sale_price: 150,
      mrp: 999.00,
      is_tax_inclusive: true,
      is_happy_hour: true,
      is_active: true
    });

    console.log('✅ Created item ID:', created.id);

    // 2. Fetch directly from DB
    const fetched = await db.models.item_master.findByPk(created.id);
    console.log('Fetched created item from DB:');
    console.log({
      id: fetched.id,
      item_code: fetched.item_code,
      mrp: fetched.mrp,
      is_tax_inclusive: fetched.is_tax_inclusive,
      is_happy_hour: fetched.is_happy_hour
    });

    if (fetched.is_tax_inclusive === true && fetched.is_happy_hour === true && Number(fetched.mrp) === 999.00) {
      console.log('🎉 SUCCESS: All fields (is_tax_inclusive, is_happy_hour, mrp) correctly persisted!');
    } else {
      console.error('❌ FAILED: Persistence check failed');
    }

    // 3. Clean up test item
    await fetched.destroy();
    console.log('✅ Cleaned up test item');

    process.exit(0);
  } catch(e) {
    console.error('ERROR:', e.message);
    process.exit(1);
  }
})();
