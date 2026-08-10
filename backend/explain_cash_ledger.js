const db = require('./db/models');

(async () => {
  try {
    const t = await db.transaction();

    const [explain] = await db.query(`
      EXPLAIN (ANALYZE, BUFFERS)
      INSERT INTO cash_ledger (
        outlet_id, txn_date, transaction_type, amount_in, amount_out, adjustment_amount, balance, created_at
      ) VALUES (
        1, NOW(), 'TEST_EXPLAIN', 100, 0, 0, 100, NOW()
      )
    `, { transaction: t });
    console.log('EXPLAIN ANALYZE cash_ledger result:\n', explain.map(r => r['QUERY PLAN']).join('\n'));

    await t.rollback();
    process.exit(0);
  } catch(e) {
    console.error('ERROR:', e.message);
    process.exit(1);
  }
})();
