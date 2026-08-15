const db = require('../db/models');
const { Op } = require('sequelize');

async function fix() {
    try {
        await db.authenticate();
        const [result] = await db.query(`
            UPDATE kot_headers 
            SET kds_dismissed = true 
            WHERE status IN ('NC Cleared', 'nc_cleared', 'NC_CLEARED', 'Closed', 'closed', 'billed', 'Billed', 'BILLED', 'cancelled', 'Cancelled')
              OR sales_header_id IS NOT NULL;
        `);
        console.log("=== DB CLEANUP FIXED NON-ACTIVE KOTS ===");
        console.log(result);
        process.exit(0);
    } catch (e) {
        console.error(e);
        process.exit(1);
    }
}

fix();
