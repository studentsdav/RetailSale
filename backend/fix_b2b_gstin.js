const propertyDb = require('./db/propertyDb');

async function fixB2bGstin() {
    console.log('[FIX_B2B_GSTIN] Starting backfill process for past sales headers...');
    try {
        const [results, metadata] = await propertyDb.query(`
            UPDATE sales_headers sh
            SET 
                customer_gstin = UPPER(TRIM(c.customer_gstin)),
                customer_address = COALESCE(NULLIF(TRIM(sh.customer_address), ''), TRIM(c.customer_address)),
                order_type = 'B2B'
            FROM customers c
            WHERE c.customer_gstin IS NOT NULL 
              AND TRIM(c.customer_gstin) <> ''
              AND (
                (
                  sh.customer_phone IS NOT NULL AND sh.customer_phone <> '' AND
                  c.customer_phone IS NOT NULL AND c.customer_phone <> '' AND
                  RIGHT(REGEXP_REPLACE(c.customer_phone, '\\D', 'g'), 10) = RIGHT(REGEXP_REPLACE(sh.customer_phone, '\\D', 'g'), 10)
                )
                OR 
                (
                  sh.customer_name IS NOT NULL AND sh.customer_name <> '' AND
                  c.customer_name IS NOT NULL AND c.customer_name <> '' AND
                  UPPER(TRIM(sh.customer_name)) = UPPER(TRIM(c.customer_name))
                )
              );
        `);
        console.log('[FIX_B2B_GSTIN] Updated sales_headers count:', metadata?.rowCount ?? metadata ?? results);
    } catch (e) {
        console.error('[FIX_B2B_GSTIN] Error during backfill:', e.message);
    }
}

if (require.main === module) {
    fixB2bGstin().then(() => process.exit(0));
}

module.exports = { fixB2bGstin };
