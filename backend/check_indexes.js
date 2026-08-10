const db = require('./db/models');

(async () => {
  try {
    let t = Date.now();
    await db.query("SET synchronous_commit = 'off'");
    console.log('SET synchronous_commit off took:', Date.now() - t, 'ms');

    t = Date.now();
    const txn = await db.transaction();
    await db.query("INSERT INTO sales_headers (outlet_id, sale_no, status, sale_date, payment_mode, net_amount, is_deleted, created_at, updated_at) VALUES (1, 'TEST-PERF-1', 'DRAFT', NOW(), 'CASH', 100, true, NOW(), NOW())", { transaction: txn });
    console.log('INSERT in txn with sync_commit off took:', Date.now() - t, 'ms');

    t = Date.now();
    await txn.commit();
    console.log('COMMIT with sync_commit off took:', Date.now() - t, 'ms');

    // Clean up test row
    await db.query("DELETE FROM sales_headers WHERE sale_no = 'TEST-PERF-1'");

    process.exit(0);
  } catch(e) {
    console.error('ERROR:', e.message);
    process.exit(1);
  }
})();
