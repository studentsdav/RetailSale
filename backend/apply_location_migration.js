const db = require('./db/models');

(async () => {
  try {
    console.log('Applying location column migration to item_master table...');
    await db.query("ALTER TABLE item_master ADD COLUMN IF NOT EXISTS location VARCHAR(100) DEFAULT 'Kitchen'");
    console.log('Successfully added location column to item_master table!');

    const [cols] = await db.query(
      "SELECT column_name FROM information_schema.columns WHERE table_name='item_master' AND column_name='location'"
    );
    console.log('Location column status in DB:', cols);

    process.exit(0);
  } catch(e) {
    console.error('ERROR:', e.message);
    process.exit(1);
  }
})();
