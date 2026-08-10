const db = require('./db/models');

(async () => {
  try {
    // 1. Fix sales_headers for fully paid cash bills where balance_due was incorrectly set to > 0
    const [fixedSales] = await db.query(`
      UPDATE sales_headers
      SET balance_due = 0
      WHERE payment_mode = 'CASH'
        AND status = 'COMPLETED'
        AND amount_paid >= (sub_total - total_discount)
        AND balance_due > 0
      RETURNING id, sale_no, net_amount, amount_paid, balance_due
    `);
    console.log('Fixed sales_headers (set balance_due = 0):');
    console.log(JSON.stringify(fixedSales, null, 2));

    // 2. Fix sales_items for bills where net_amount was computed as 590 instead of 500
    // Fix net_amount on sales_headers for FAM-1-26, FAM-3-26, FAM-4-26
    const [fixedHeaders] = await db.query(`
      UPDATE sales_headers
      SET net_amount = amount_paid,
          sub_total = amount_paid,
          taxable_amount = ROUND(amount_paid / 1.18, 2),
          total_tax = amount_paid - ROUND(amount_paid / 1.18, 2),
          cgst_amount = ROUND((amount_paid - ROUND(amount_paid / 1.18, 2)) / 2, 2),
          sgst_amount = ROUND((amount_paid - ROUND(amount_paid / 1.18, 2)) / 2, 2),
          balance_due = 0
      WHERE sale_no IN ('FAM-1-26', 'FAM-3-26', 'FAM-4-26')
      RETURNING id, sale_no, net_amount, balance_due
    `);
    console.log('\nCorrected tax-inclusive amounts for FAM bills:');
    console.log(JSON.stringify(fixedHeaders, null, 2));

    // 3. Fix cash_ledger notes and amounts for these sales
    await db.query(`
      UPDATE cash_ledger
      SET notes = 'Payment received for sale ' || reference_no
      WHERE reference_no IN ('FAM-1-26', 'FAM-2-26', 'FAM-3-26', 'FAM-4-26')
    `);
    console.log('\nUpdated cash_ledger notes!');

    process.exit(0);
  } catch(e) {
    console.error('ERROR:', e.message, e.stack);
    process.exit(1);
  }
})();
