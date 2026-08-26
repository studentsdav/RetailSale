const Sequelize = require('sequelize');
const loadConfig = require('./utils/decryptConfig');

async function cleanLedger() {
    try {
        const config = loadConfig();
        const db = new Sequelize(config.db_database, config.db_user, config.db_password, {
            host: config.db_host || '127.0.0.1',
            port: Number(config.db_port || 5432),
            dialect: 'postgres',
            logging: false
        });

        await db.authenticate();
        console.log('✅ DB Connected.');

        // Delete duplicate 'Advance adjusted for subscription sale %' ledger entries
        const [duplicates] = await db.query(
            "SELECT id, reference_no, notes FROM cash_ledger WHERE notes LIKE 'Advance adjusted for subscription sale %'"
        );
        for (const dup of duplicates) {
            await db.query("DELETE FROM cash_ledger WHERE id = :id", { replacements: { id: dup.id } });
            console.log(`Deleted duplicate ledger entry id=${dup.id} (${dup.notes})`);
        }

        // Recalculate running balance in cash_ledger using raw query
        const [rows] = await db.query(
            "SELECT id, amount_in, amount_out, adjustment_amount FROM cash_ledger ORDER BY txn_date ASC, id ASC"
        );

        let currentBalance = 0;
        for (const r of rows) {
            const delta = (parseFloat(r.amount_in || 0) - parseFloat(r.amount_out || 0) + parseFloat(r.adjustment_amount || 0));
            currentBalance = Number((currentBalance + delta).toFixed(2));
            await db.query("UPDATE cash_ledger SET balance = :bal WHERE id = :id", {
                replacements: { bal: currentBalance, id: r.id }
            });
        }
        console.log(`Recalculated running balances for ${rows.length} rows. Final balance: ${currentBalance}`);

        await db.close();
        console.log('✅ Ledger cleanup complete!');
    } catch (err) {
        console.error('❌ Ledger cleanup failed:', err);
    }
}

cleanLedger();
