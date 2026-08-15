const db = require('../db/models');

async function test() {
    try {
        await db.authenticate();
        const [items] = await db.query(`
            SELECT 
                im.id, im.item_name,
                GREATEST(0,
                    COALESCE(
                        (SELECT sl.balance FROM stock_ledger sl 
                         WHERE sl.outlet_id = im.outlet_id AND sl.item_code = im.item_code 
                         ORDER BY sl.id DESC LIMIT 1),
                        im.opening_balance,
                        0
                    ) - COALESCE(
                        (SELECT SUM(ki.qty)
                         FROM kot_items ki
                         INNER JOIN kot_headers kh ON ki.kot_header_id = kh.id
                         WHERE ki.item_id = im.id
                           AND ki.status NOT IN ('Cancelled', 'Rejected')
                           AND kh.sales_header_id IS NULL
                           AND kh.status NOT IN ('Closed', 'closed', 'billed', 'Billed', 'BILLED', 'Cancelled', 'cancelled', 'Rejected')
                           AND kh.outlet_id = im.outlet_id),
                        0
                    )
                ) AS current_stock
            FROM item_master im
            WHERE im.item_name LIKE '%Paper%'
        `);
        console.log("=== CATALOG QUERY TEST RESULT ===");
        console.log(JSON.stringify(items, null, 2));
        process.exit(0);
    } catch (e) {
        console.error(e);
        process.exit(1);
    }
}

test();
