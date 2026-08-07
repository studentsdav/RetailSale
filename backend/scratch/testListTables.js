const db = require('../db/models');

async function test() {
    try {
        await db.authenticate();
        console.log("Simulating listTables include query...");
        
        const tables = await db.models.restaurant_tables.findAll({
            where: { outlet_id: '1' },
            include: [
                { model: db.models.floors, as: 'floor', attributes: ['name'] },
                { model: db.models.dining_areas, as: 'dining_area', attributes: ['name'] },
                { model: db.models.table_types, as: 'table_type', attributes: ['name', 'charge_type', 'charge_amount'] },
                { model: db.models.hr_employees, as: 'waiter', attributes: [['full_name', 'employee_name']] },
                { model: db.models.hr_employees, as: 'captain', attributes: [['full_name', 'employee_name']] }
            ],
            order: [['table_name', 'ASC']]
        });
        
        console.log("✔ Query succeeded. Row count:", tables.length);
        console.log(JSON.stringify(tables.map(t => t.toJSON()), null, 2));
        process.exit(0);
    } catch (err) {
        console.error("❌ ListTables query failed:", err.message);
        console.error(err);
        process.exit(1);
    }
}

test();
