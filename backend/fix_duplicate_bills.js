const db = require('./db/models');
(async () => {
  try {
    // Step 1: Find all duplicate COMPLETED bills (same outlet_id + sale_no)
    const [dupes] = await db.query(`
      SELECT outlet_id, sale_no, COUNT(*) as cnt, ARRAY_AGG(id ORDER BY id ASC) as ids
      FROM sales_headers
      WHERE status = 'COMPLETED' AND is_latest = true AND is_deleted = false
      GROUP BY outlet_id, sale_no
      HAVING COUNT(*) > 1
    `);
    console.log('Duplicate bill groups found:', JSON.stringify(dupes, null, 2));

    // Step 2: For each duplicate group, keep the FIRST (lowest id), soft-delete the rest
    let totalDeleted = 0;
    for (const group of dupes) {
      const ids = group.ids; // array from ARRAY_AGG
      const keepId = ids[0];
      const deleteIds = ids.slice(1);
      await db.query(
        `UPDATE sales_headers SET is_deleted = true, is_latest = false WHERE id = ANY($1::int[])`,
        { bind: [deleteIds] }
      );
      console.log(`✅ sale_no="${group.sale_no}": kept id=${keepId}, soft-deleted: ${deleteIds.join(', ')}`);
      totalDeleted += deleteIds.length;
    }
    console.log(`\nTotal duplicates soft-deleted: ${totalDeleted}`);

    // Step 3: Now create the unique index safely
    await db.query(`
      CREATE UNIQUE INDEX IF NOT EXISTS idx_sales_headers_unique_sale_no
      ON sales_headers (outlet_id, sale_no)
      WHERE status = 'COMPLETED' AND is_latest = true AND is_deleted = false
    `);
    console.log('✅ Unique index idx_sales_headers_unique_sale_no created!');

    // Step 4: Verify remaining COMPLETED bills
    const [remaining] = await db.query(`
      SELECT id, sale_no, status, is_latest, is_deleted
      FROM sales_headers WHERE status = 'COMPLETED'
      ORDER BY id DESC LIMIT 10
    `);
    console.log('\nRemaining COMPLETED bills:');
    console.log(JSON.stringify(remaining, null, 2));

    process.exit(0);
  } catch(e) {
    console.error('ERROR:', e.message, e.stack);
    process.exit(1);
  }
})();
