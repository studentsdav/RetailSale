/**
 * Timing test for Sequelize model operations inside a transaction.
 * This helps identify whether the overhead is from Sequelize or PostgreSQL.
 */
const db = require('./db/models');
const { Sequelize } = require('sequelize');

(async () => {
  try {
    // Test inside a real transaction
    const t = await db.transaction();
    
    let start = Date.now();
    // Test raw INSERT vs Sequelize create
    const [rawResult] = await db.query(
      `INSERT INTO sales_headers (outlet_id, sale_no, status, sale_date, payment_mode, net_amount, is_deleted)
       VALUES (1, 'TEST-TIMING-DEL', 'DRAFT', NOW(), 'CASH', 0, true)
       RETURNING id`,
      { transaction: t }
    );
    const newId = rawResult[0].id;
    console.log('Raw INSERT in transaction:', Date.now() - start, 'ms, id=', newId);

    start = Date.now();
    await db.query(
      `UPDATE sales_headers SET original_sale_id = $1 WHERE id = $1`,
      { bind: [newId], transaction: t }
    );
    console.log('Raw UPDATE single field in transaction:', Date.now() - start, 'ms');

    start = Date.now();
    const instance = await db.models.sales_headers.findOne({ where: { id: newId }, transaction: t });
    console.log('Sequelize findOne in transaction:', Date.now() - start, 'ms');

    start = Date.now();
    await instance.update({ notes: 'test' }, { transaction: t });
    console.log('Sequelize instance.update in transaction:', Date.now() - start, 'ms');

    start = Date.now();
    await db.models.sales_headers.update({ notes: 'test2' }, { where: { id: newId }, transaction: t });
    console.log('Sequelize Model.update (class method) in transaction:', Date.now() - start, 'ms');

    await t.rollback();
    console.log('Transaction rolled back (no data saved)');
    process.exit(0);
  } catch(e) {
    console.error('ERROR:', e.message);
    process.exit(1);
  }
})();
