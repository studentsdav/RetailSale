const db = require('../db/models');

async function fixDb() {
    try {
        await db.authenticate();
        console.log('Connected to database.');

        console.log('Adding kds_dismissed to kot_headers...');
        await db.query(`
            ALTER TABLE kot_headers ADD COLUMN IF NOT EXISTS kds_dismissed BOOLEAN DEFAULT FALSE;
        `);
        console.log('kds_dismissed added.');

        console.log('Adding columns to sales_headers...');
        await db.query(`
            ALTER TABLE sales_headers 
              ADD COLUMN IF NOT EXISTS table_id INTEGER REFERENCES restaurant_tables(id) ON DELETE SET NULL,
              ADD COLUMN IF NOT EXISTS waiter_id INTEGER REFERENCES hr_employees(id) ON DELETE SET NULL,
              ADD COLUMN IF NOT EXISTS captain_id INTEGER REFERENCES hr_employees(id) ON DELETE SET NULL,
              ADD COLUMN IF NOT EXISTS restaurant_service_type VARCHAR(50),
              ADD COLUMN IF NOT EXISTS guest_count INTEGER DEFAULT 0,
              ADD COLUMN IF NOT EXISTS credit_note_redeemed_id INTEGER,
              ADD COLUMN IF NOT EXISTS credit_note_amount DECIMAL(12, 2) DEFAULT 0.00;
        `);
        console.log('sales_headers columns added successfully.');

    } catch (err) {
        console.error('Error fixing database schema:', err);
    } finally {
        process.exit(0);
    }
}

fixDb();
