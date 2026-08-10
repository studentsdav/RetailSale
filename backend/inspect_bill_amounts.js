const db = require('./db/models');

(async () => {
  try {
    const [sales] = await db.query(
      "SELECT id, sale_no, net_amount, sub_total, total_discount, amount_paid, initial_amount_paid, change_amount, balance_due, payment_mode FROM sales_headers WHERE sale_no IN ('FAM-1-26', 'FAM-2-26', 'FAM-3-26', 'FAM-4-26')"
    );
    console.log('SALES HEADERS:');
    console.log(JSON.stringify(sales, null, 2));

    const [items] = await db.query(
      "SELECT sale_id, item_name, qty, rate, amount, line_discount, net_amount FROM sales_items WHERE sale_id IN (SELECT id FROM sales_headers WHERE sale_no IN ('FAM-1-26', 'FAM-2-26', 'FAM-3-26', 'FAM-4-26'))"
    );
    console.log('\nSALES ITEMS:');
    console.log(JSON.stringify(items, null, 2));

    const [ledger] = await db.query(
      "SELECT * FROM cash_ledger WHERE reference_no IN ('FAM-1-26', 'FAM-2-26', 'FAM-3-26', 'FAM-4-26')"
    );
    console.log('\nCASH LEDGER:');
    console.log(JSON.stringify(ledger, null, 2));

    process.exit(0);
  } catch(e) {
    console.error('ERROR:', e.message);
    process.exit(1);
  }
})();
