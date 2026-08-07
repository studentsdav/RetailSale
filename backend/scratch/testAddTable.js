const db = require('../db/models');

async function run() {
    try {
        await db.authenticate();
        console.log("✔ Connected to database");

        // Simulate POST /api/restaurant/tables
        console.log("Simulating Table creation...");
        const newTable = await db.models.restaurant_tables.create({
            outlet_id: 1,
            floor_id: 9,
            dining_area_id: 9,
            table_name: "Test Table Auto",
            capacity: 4,
            status: "Available"
        });
        console.log("✔ Table created successfully. ID:", newTable.id);

        // Simulate GET /api/restaurant/tables
        console.log("Simulating Table list...");
        const tables = await db.models.restaurant_tables.findAll({
            where: { outlet_id: 1 },
            include: [
                { model: db.models.floors, as: 'floor', attributes: ['name'] },
                { model: db.models.dining_areas, as: 'dining_area', attributes: ['name'] },
                { model: db.models.table_types, as: 'table_type', attributes: ['name', 'charge_type', 'charge_amount'] },
                { model: db.models.hr_employees, as: 'waiter', attributes: [['full_name', 'employee_name']] },
                { model: db.models.hr_employees, as: 'captain', attributes: [['full_name', 'employee_name']] }
            ]
        });
        console.log("✔ Table listing successful. Row count:", tables.length);
        
        // Clean up the created table
        await newTable.destroy();
        console.log("✔ Cleaned up test table");
        process.exit(0);
    } catch (e) {
        console.error("❌ Test failed:", e.message);
        console.error(e);
        process.exit(1);
    }
}

run();
