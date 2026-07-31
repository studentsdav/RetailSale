const propertyDb = require('../db/models');

let selfHealed = false;

module.exports = async (req, res, next) => {
    try {
        req.propertyDb = propertyDb;
        
        if (!selfHealed) {
            try {
                // Dynamically ensure columns exist
                await propertyDb.query(`
                    ALTER TABLE sales_headers ADD COLUMN IF NOT EXISTS salesman_id INTEGER NULL;
                    ALTER TABLE hr_attendance_punches ADD COLUMN IF NOT EXISTS leave_type_id INTEGER NULL;
                `);
                console.log('✅ Self-healed: Checked and added missing columns to tables');

                const runMigrations = require('../utils/migrationRunner');
                await runMigrations(propertyDb);
                console.log('✅ Self-healed: Checked and ran database schema migrations');

                selfHealed = true;
            } catch (healErr) {
                console.warn('⚠️ Self-healing column check warning:', healErr.message);
            }
        }
        
        next();
    } catch (err) {
        console.error('DB Middleware Error:', err);
        res.status(500).json({
            success: false,
            message: 'Database connection failed'
        });
    }
};
