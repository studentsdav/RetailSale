const db = require('../db/models');
async function run() {
  try {
    await db.query("UPDATE sales_items SET modifier_details = jsonb_build_array('extra cheease x1 @€100.00') WHERE sale_id = 132 AND item_id = 30;");
    console.log('Successfully updated sale 132 item with modifier_details!');
    process.exit(0);
  } catch(e) {
    console.error('ERROR:', e.message);
    process.exit(1);
  }
}
run();
