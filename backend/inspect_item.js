const db = require('./db/models');

(async () => {
  try {
    const [item] = await db.query(
      "SELECT * FROM item_master WHERE item_name LIKE '%A4 Paper%' LIMIT 1"
    );
    console.log('ITEM MASTER RECORD:');
    console.log(JSON.stringify(item, null, 2));

    process.exit(0);
  } catch(e) {
    console.error('ERROR:', e.message);
    process.exit(1);
  }
})();
