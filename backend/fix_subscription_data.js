const Sequelize = require('sequelize');
const loadConfig = require('./utils/decryptConfig');

async function fixData() {
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

        // 1. Fix covered_amount in milk_subscription_consumptions where tax was added on top of inclusive price
        const [consumptions] = await db.query(
            "SELECT c.id, c.subscription_id, c.covered_qty, c.covered_amount, c.rate, i.is_tax_inclusive, i.tax_type FROM milk_subscription_consumptions c JOIN item_master i ON c.item_id = i.id WHERE (i.is_tax_inclusive = true OR i.tax_type = 'GST_INCLUSIVE') AND c.covered_amount > (c.covered_qty * c.rate)"
        );
        console.log(`Found ${consumptions.length} consumption records with extra tax added on inclusive items.`);

        for (const row of consumptions) {
            const correctedAmount = parseFloat(row.covered_qty) * parseFloat(row.rate);
            await db.query(
                "UPDATE milk_subscription_consumptions SET covered_amount = :amt WHERE id = :id",
                { replacements: { amt: correctedAmount, id: row.id } }
            );
            console.log(`Updated consumption id=${row.id} covered_amount: ${row.covered_amount} -> ${correctedAmount}`);
        }

        // 2. Sync customer_advances for active subscriptions based on actual covered consumptions
        const [subs] = await db.query("SELECT id, customer_name, total_payment_amount FROM milk_subscriptions");
        for (const sub of subs) {
            const [cRows] = await db.query(
                "SELECT COALESCE(SUM(covered_amount), 0) AS total_consumed, COALESCE(SUM(covered_qty), 0) as total_qty FROM milk_subscription_consumptions WHERE subscription_id = :subId AND status <> 'CANCELLED'",
                { replacements: { subId: sub.id } }
            );
            const totalConsumedAmt = parseFloat(cRows[0].total_consumed || 0);
            const totalConsumedQty = parseFloat(cRows[0].total_qty || 0);
            const origPayment = parseFloat(sub.total_payment_amount || 0);
            const newAvailableAmt = Math.max(origPayment - totalConsumedAmt, 0);

            // Update customer_advances
            await db.query(
                "UPDATE customer_advances SET available_amount = :avail WHERE reference_no = :ref",
                { replacements: { avail: newAvailableAmt, ref: `SUBSCRIPTION-${sub.id}` } }
            );
            console.log(`Subscription #${sub.id} (${sub.customer_name}): Total Consumed Amt = ${totalConsumedAmt}. Updated customer_advances available_amount to ${newAvailableAmt}`);

            // Update customer_item_advances
            const [itemAdvRows] = await db.query(
                "SELECT id, original_qty FROM customer_item_advances WHERE note LIKE :pat",
                { replacements: { pat: `%Subscription #${sub.id}%` } }
            );
            for (const itemAdv of itemAdvRows) {
                const origQty = parseFloat(itemAdv.original_qty || 0);
                const newAvailQty = Math.max(origQty - totalConsumedQty, 0);
                await db.query(
                    "UPDATE customer_item_advances SET available_qty = :availQty WHERE id = :id",
                    { replacements: { availQty: newAvailQty, id: itemAdv.id } }
                );
                console.log(`Updated customer_item_advances id=${itemAdv.id} available_qty to ${newAvailQty}`);
            }
        }

        await db.close();
        console.log('✅ Data fix complete!');
    } catch (err) {
        console.error('❌ Data fix failed:', err);
    }
}

fixData();
