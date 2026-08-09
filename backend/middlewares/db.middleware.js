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
                    ALTER TABLE restaurant_tables ADD COLUMN IF NOT EXISTS x_coordinate INTEGER NULL;
                    ALTER TABLE restaurant_tables ADD COLUMN IF NOT EXISTS y_coordinate INTEGER NULL;
                    ALTER TABLE item_master ADD COLUMN IF NOT EXISTS is_recipe_based BOOLEAN DEFAULT FALSE;
                    ALTER TABLE item_master ADD COLUMN IF NOT EXISTS is_tax_inclusive BOOLEAN DEFAULT FALSE;
                    ALTER TABLE sales_headers ADD COLUMN IF NOT EXISTS coupon_discount_amount DECIMAL(12, 2) NULL;
                    ALTER TABLE sales_schemes ADD COLUMN IF NOT EXISTS free_item_id INTEGER NULL;
                    ALTER TABLE sales_schemes ADD COLUMN IF NOT EXISTS days_of_week VARCHAR(255) NULL;
                    ALTER TABLE sales_items ADD COLUMN IF NOT EXISTS original_rate DECIMAL(12, 2) NULL;
                    ALTER TABLE sales_items ADD COLUMN IF NOT EXISTS scheme_discount_per_unit DECIMAL(12, 2) NULL;
                    ALTER TABLE system_settings ADD COLUMN IF NOT EXISTS enable_salesperson_tagging BOOLEAN DEFAULT FALSE;
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
