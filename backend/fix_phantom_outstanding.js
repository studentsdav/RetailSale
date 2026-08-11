/**
 * Fix phantom outstanding balances caused by the round_off_amount double-subtraction bug.
 *
 * Bug: balance_due was computed as: net_amount - round_off_amount - amount_paid
 *      But net_amount already includes round_off_amount, so it was subtracted twice.
 * Fix: balance_due = net_amount - amount_paid
 *
 * This script finds all COMPLETED sales where balance_due > 0 but the
 * amount_paid already covers net_amount (i.e., phantom outstanding from rounding),
 * and corrects their balance_due to 0.
 */
const db = require('./db/models');

function roundAmount(v) {
    return Number((Number(v) || 0).toFixed(2));
}

(async () => {
    try {
        // Find all completed sales that have balance_due > 0
        const [sales] = await db.query(`
            SELECT id, sale_no, customer_name, customer_phone, net_amount, amount_paid,
                   initial_amount_paid, round_off_amount, balance_due
            FROM sales_headers
            WHERE status = 'COMPLETED'
              AND is_latest = TRUE
              AND is_deleted = FALSE
              AND balance_due > 0
        `);

        console.log(`Found ${sales.length} sales with balance_due > 0`);

        let fixed = 0;
        let skipped = 0;

        for (const sale of sales) {
            const netAmount = roundAmount(sale.net_amount);
            const amountPaid = roundAmount(sale.amount_paid);
            const currentBalance = roundAmount(sale.balance_due);

            // Correct balance: net_amount - amount_paid (no round_off subtraction)
            const correctBalance = Math.max(0, roundAmount(netAmount - amountPaid));

            // Was the balance inflated by exactly round_off_amount (the bug)?
            const roundOff = roundAmount(sale.round_off_amount);
            const phantomAmount = roundAmount(Math.abs(correctBalance - currentBalance));

            if (correctBalance < currentBalance && phantomAmount <= Math.abs(roundOff) + 0.01) {
                // This is a phantom balance from the bug - fix it
                await db.query(
                    `UPDATE sales_headers SET balance_due = :bal WHERE id = :id`,
                    { replacements: { bal: correctBalance, id: sale.id } }
                );
                console.log(`✅ Fixed sale ${sale.sale_no} (id=${sale.id}): balance_due ${currentBalance} → ${correctBalance} (round_off was ${roundOff})`);
                fixed++;
            } else {
                // Real outstanding, leave it alone
                skipped++;
            }
        }

        console.log(`\nDone. Fixed: ${fixed}, Skipped (real outstanding): ${skipped}`);
        process.exit(0);
    } catch(e) {
        console.error('ERROR:', e.message);
        process.exit(1);
    }
})();
