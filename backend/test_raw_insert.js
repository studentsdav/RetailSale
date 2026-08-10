const db = require('./db/models');

(async () => {
  try {
    const t = await db.transaction();

    let start = Date.now();
    // Raw SQL INSERT with named parameters
    const [rawRes] = await db.query(`
      INSERT INTO sales_headers (
        outlet_id, sale_no, sale_date, customer_name, customer_phone,
        payment_mode, initial_amount_paid, amount_paid, change_amount, balance_due,
        total_qty, sub_total, taxable_amount, cgst_amount, sgst_amount, igst_amount,
        total_tax, total_discount, round_off_amount, net_amount, status, created_by,
        is_latest, is_deleted, created_at, updated_at
      ) VALUES (
        1, 'TEST-RAW-PERF-1', NOW(), 'Test Customer', '9999999999',
        'CASH', 100, 100, 0, 0,
        1, 100, 100, 0, 0, 0,
        0, 0, 0, 100, 'COMPLETED', 1,
        true, true, NOW(), NOW()
      ) RETURNING id, sale_no, status, outlet_id, net_amount, change_amount, balance_due
    `, { transaction: t });
    console.log('⚡ Raw SQL INSERT took:', Date.now() - start, 'ms, inserted id=', rawRes[0].id);

    start = Date.now();
    await t.rollback();
    console.log('Rollback took:', Date.now() - start, 'ms');

    process.exit(0);
  } catch(e) {
    console.error('ERROR:', e.message);
    process.exit(1);
  }
})();
