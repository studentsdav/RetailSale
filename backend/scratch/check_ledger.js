const db = require('../db/models');
const { Op } = require('sequelize');

async function testUpdate() {
    try {
        await db.authenticate();
        console.log('Connected to database.');

        const tableId = 23;
        const outlet_id = 1;
        const sales_header_id = 1060; // FAM-6-26

        console.log('Running table update...');
        const tblResult = await db.models.restaurant_tables.update({
            status: 'Available',
            current_guest_count: 0,
            current_waiter_id: null,
            current_captain_id: null,
            active_sale_id: null
        }, {
            where: { id: tableId, outlet_id }
        });
        console.log('Table update result:', tblResult);

        console.log('Running KOT headers update...');
        const kotResult = await db.models.kot_headers.update({
            status: 'Closed',
            sales_header_id: sales_header_id
        }, {
            where: { table_id: tableId, status: { [Op.ne]: 'Closed' }, outlet_id }
        });
        console.log('KOT headers update result:', kotResult);

    } catch (err) {
        console.error('Error during update:', err);
    } finally {
        process.exit(0);
    }
}

testUpdate();
