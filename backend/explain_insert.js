const db = require('./db/models');

(async () => {
  try {
    const t = await db.transaction();

    const [explain] = await db.query(`
      EXPLAIN (ANALYZE, BUFFERS)
      INSERT INTO sales_headers (
        outlet_id, sale_no, sale_date, customer_name, customer_phone,
        payment_mode, initial_amount_paid, amount_paid, change_amount, balance_due,
        total_qty, sub_total, taxable_amount, cgst_amount, sgst_amount, igst_amount,
        total_tax, total_discount, round_off_amount, net_amount, status, created_by,
        is_latest, is_deleted, created_at, updated_at
      ) VALUES (
        1, 'TEST-EXPLAIN-1', NOW(), 'Test Customer', '9999999999',
        'CASH', 100, 100, 0, 0,
        1, 100, 100, 0, 0, 0,
        0, 0, 0, 100, 'COMPLETED', 1,
        true, true, NOW(), NOW()
      )
    `, { transaction: t });
    console.log('EXPLAIN ANALYZE result:\n', explain.map(r => r['QUERY PLAN']).join('\n'));

    await t.rollback();
    process.exit(0);
  } catch(e) {
    console.error('ERROR:', e.message);
    process.exit(1);
  }
})();
