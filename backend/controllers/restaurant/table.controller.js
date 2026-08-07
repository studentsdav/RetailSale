const { Op } = require('sequelize');
const audit = require('../../services/audit.service');

/* =========================================================================
   FLOORS CONTROLLER
   ========================================================================= */

exports.listFloors = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const floors = await req.propertyDb.models.floors.findAll({
            where: { outlet_id },
            order: [['name', 'ASC']]
        });
        res.json({ success: true, data: floors });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.createFloor = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { name, status } = req.body;
        const floor = await req.propertyDb.models.floors.create({
            outlet_id,
            name,
            status: status || 'ACTIVE'
        });
        res.json({ success: true, data: floor });
    } catch (err) {
        res.status(400).json({ success: false, error: err.message });
    }
};

exports.updateFloor = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { id } = req.params;
        const { name, status } = req.body;
        const floor = await req.propertyDb.models.floors.findOne({ where: { id, outlet_id } });
        if (!floor) return res.status(404).json({ success: false, message: 'Floor not found' });

        await floor.update({ name, status });
        res.json({ success: true, data: floor });
    } catch (err) {
        res.status(400).json({ success: false, error: err.message });
    }
};

exports.deleteFloor = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { id } = req.params;
        const floor = await req.propertyDb.models.floors.findOne({ where: { id, outlet_id } });
        if (!floor) return res.status(404).json({ success: false, message: 'Floor not found' });

        await floor.destroy();
        res.json({ success: true, message: 'Floor deleted successfully' });
    } catch (err) {
        res.status(400).json({ success: false, error: err.message });
    }
};

/* =========================================================================
   DINING AREAS CONTROLLER
   ========================================================================= */

exports.listDiningAreas = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const areas = await req.propertyDb.models.dining_areas.findAll({
            where: { outlet_id },
            order: [['name', 'ASC']]
        });
        res.json({ success: true, data: areas });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.createDiningArea = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { name, description, status } = req.body;
        const area = await req.propertyDb.models.dining_areas.create({
            outlet_id,
            name,
            description,
            status: status || 'ACTIVE'
        });
        res.json({ success: true, data: area });
    } catch (err) {
        res.status(400).json({ success: false, error: err.message });
    }
};

exports.updateDiningArea = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { id } = req.params;
        const { name, description, status } = req.body;
        const area = await req.propertyDb.models.dining_areas.findOne({ where: { id, outlet_id } });
        if (!area) return res.status(404).json({ success: false, message: 'Dining Area not found' });

        await area.update({ name, description, status });
        res.json({ success: true, data: area });
    } catch (err) {
        res.status(400).json({ success: false, error: err.message });
    }
};

exports.deleteDiningArea = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { id } = req.params;
        const area = await req.propertyDb.models.dining_areas.findOne({ where: { id, outlet_id } });
        if (!area) return res.status(404).json({ success: false, message: 'Dining Area not found' });

        await area.destroy();
        res.json({ success: true, message: 'Dining Area deleted successfully' });
    } catch (err) {
        res.status(400).json({ success: false, error: err.message });
    }
};

/* =========================================================================
   TABLE TYPES CONTROLLER
   ========================================================================= */

exports.listTableTypes = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const types = await req.propertyDb.models.table_types.findAll({
            where: { outlet_id },
            order: [['name', 'ASC']]
        });
        res.json({ success: true, data: types });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.createTableType = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { name, charge_type, charge_amount } = req.body;
        const type = await req.propertyDb.models.table_types.create({
            outlet_id,
            name,
            charge_type: charge_type || 'FLAT',
            charge_amount: charge_amount || 0.00
        });
        res.json({ success: true, data: type });
    } catch (err) {
        res.status(400).json({ success: false, error: err.message });
    }
};

exports.updateTableType = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { id } = req.params;
        const { name, charge_type, charge_amount } = req.body;
        const type = await req.propertyDb.models.table_types.findOne({ where: { id, outlet_id } });
        if (!type) return res.status(404).json({ success: false, message: 'Table Type not found' });

        await type.update({ name, charge_type, charge_amount });
        res.json({ success: true, data: type });
    } catch (err) {
        res.status(400).json({ success: false, error: err.message });
    }
};

exports.deleteTableType = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { id } = req.params;
        const type = await req.propertyDb.models.table_types.findOne({ where: { id, outlet_id } });
        if (!type) return res.status(404).json({ success: false, message: 'Table Type not found' });

        await type.destroy();
        res.json({ success: true, message: 'Table Type deleted successfully' });
    } catch (err) {
        res.status(400).json({ success: false, error: err.message });
    }
};

/* =========================================================================
   TABLES CONTROLLER & ACTIONS
   ========================================================================= */

exports.listTables = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { floor_id, dining_area_id } = req.query;
        console.log(`[API listTables] GET called. outlet_id: ${outlet_id}, floor_id: ${floor_id}, dining_area_id: ${dining_area_id}`);

        const whereClause = { outlet_id };
        if (floor_id && floor_id !== 'undefined' && floor_id !== 'null' && floor_id !== '') {
            whereClause.floor_id = floor_id;
        }
        if (dining_area_id && dining_area_id !== 'undefined' && dining_area_id !== 'null' && dining_area_id !== '') {
            whereClause.dining_area_id = dining_area_id;
        }

        const tables = await req.propertyDb.models.restaurant_tables.findAll({
            where: whereClause,
            logging: console.log,
            include: [
                { model: req.propertyDb.models.floors, as: 'floor', attributes: ['name'], required: false },
                { model: req.propertyDb.models.dining_areas, as: 'dining_area', attributes: ['name'], required: false },
                { model: req.propertyDb.models.table_types, as: 'table_type', attributes: ['name', 'charge_type', 'charge_amount'], required: false },
                { model: req.propertyDb.models.hr_employees, as: 'waiter', attributes: [['full_name', 'employee_name']], required: false },
                { model: req.propertyDb.models.hr_employees, as: 'captain', attributes: [['full_name', 'employee_name']], required: false }
            ],
            order: [['table_name', 'ASC']]
        });
        console.log(`✔ [API listTables] Returning ${tables.length} tables successfully.`);
        res.json({ success: true, data: tables });
    } catch (err) {
        console.error("❌ [API listTables] Error loading tables:", err);
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.createTable = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { floor_id, dining_area_id, table_type_id, table_name, capacity, x_coordinate, y_coordinate } = req.body;
        console.log("-> [API createTable] POST called with payload:", req.body);

        const table = await req.propertyDb.models.restaurant_tables.create({
            outlet_id,
            floor_id,
            dining_area_id,
            table_type_id,
            table_name,
            capacity: capacity || 4,
            status: 'Available',
            x_coordinate,
            y_coordinate
        });
        console.log("✔ [API createTable] Table created successfully in database. ID:", table.id);
        res.json({ success: true, data: table });
    } catch (err) {
        console.error("❌ [API createTable] Error creating table in database:", err);
        res.status(400).json({ success: false, error: err.message });
    }
};

exports.updateTable = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { id } = req.params;
        const { floor_id, dining_area_id, table_type_id, table_name, capacity, x_coordinate, y_coordinate } = req.body;
        const table = await req.propertyDb.models.restaurant_tables.findOne({ where: { id, outlet_id } });
        if (!table) return res.status(404).json({ success: false, message: 'Table not found' });

        await table.update({ floor_id, dining_area_id, table_type_id, table_name, capacity, x_coordinate, y_coordinate });
        res.json({ success: true, data: table });
    } catch (err) {
        res.status(400).json({ success: false, error: err.message });
    }
};

exports.deleteTable = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { id } = req.params;
        const table = await req.propertyDb.models.restaurant_tables.findOne({ where: { id, outlet_id } });
        if (!table) return res.status(404).json({ success: false, message: 'Table not found' });

        await table.destroy();
        res.json({ success: true, message: 'Table deleted successfully' });
    } catch (err) {
        res.status(400).json({ success: false, error: err.message });
    }
};

exports.updateTableStatus = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { id } = req.params;
        const { status, guest_count, waiter_id, captain_id, active_sale_id } = req.body;

        const table = await req.propertyDb.models.restaurant_tables.findOne({ where: { id, outlet_id } });
        if (!table) return res.status(404).json({ success: false, message: 'Table not found' });

        const updateData = {};
        if (status) updateData.status = status;
        if (guest_count !== undefined) updateData.current_guest_count = guest_count;
        if (waiter_id !== undefined) updateData.current_waiter_id = waiter_id;
        if (captain_id !== undefined) updateData.current_captain_id = captain_id;
        if (active_sale_id !== undefined) updateData.active_sale_id = active_sale_id;

        await table.update(updateData);
        res.json({ success: true, data: table });
    } catch (err) {
        res.status(400).json({ success: false, error: err.message });
    }
};

exports.transferTable = async (req, res) => {
    const t = await req.propertyDb.transaction();
    try {
        const outlet_id = req.user.outlet_id;
        const { source_table_id, target_table_id } = req.body;

        const source = await req.propertyDb.models.restaurant_tables.findOne({
            where: { id: source_table_id, outlet_id },
            transaction: t
        });
        const target = await req.propertyDb.models.restaurant_tables.findOne({
            where: { id: target_table_id, outlet_id },
            transaction: t
        });

        if (!source || !target) throw new Error('Source or Target table not found');
        if (source.status === 'Available') throw new Error('Source table is empty');
        if (target.status !== 'Available') throw new Error('Target table is occupied/reserved');

        // Move metadata and sale reference
        await target.update({
            status: source.status,
            current_guest_count: source.current_guest_count,
            current_waiter_id: source.current_waiter_id,
            current_captain_id: source.current_captain_id,
            active_sale_id: source.active_sale_id
        }, { transaction: t });

        // Update KOT headers linked to this table
        await req.propertyDb.models.kot_headers.update(
            { table_id: target_table_id },
            { where: { table_id: source_table_id, status: { [Op.ne]: 'Closed' }, outlet_id }, transaction: t }
        );

        // Reset source table
        await source.update({
            status: 'Available',
            current_guest_count: 0,
            current_waiter_id: null,
            current_captain_id: null,
            active_sale_id: null
        }, { transaction: t });

        await audit.log({
            req,
            module: 'RESTAURANT',
            action: 'TABLE_TRANSFER',
            table: 'restaurant_tables',
            recordId: source_table_id,
            description: `Transferred Table ${source.table_name} to ${target.table_name}`,
            outlet_id,
            user_id: req.user.id
        });

        await t.commit();
        res.json({ success: true, message: `Table ${source.table_name} transferred to ${target.table_name}` });
    } catch (err) {
        await t.rollback();
        res.status(400).json({ success: false, error: err.message });
    }
};

exports.mergeTables = async (req, res) => {
    const t = await req.propertyDb.transaction();
    try {
        const outlet_id = req.user.outlet_id;
        const { main_table_id, table_to_merge_id } = req.body;

        const mainTable = await req.propertyDb.models.restaurant_tables.findOne({
            where: { id: main_table_id, outlet_id },
            transaction: t
        });
        const mergeTable = await req.propertyDb.models.restaurant_tables.findOne({
            where: { id: table_to_merge_id, outlet_id },
            transaction: t
        });

        if (!mainTable || !mergeTable) throw new Error('Main or Merge table not found');
        if (mainTable.status === 'Available') throw new Error('Main table must be occupied first');
        if (mergeTable.status === 'Available') throw new Error('Merge table has no orders to merge');

        // Link KOT headers from merged table to the main table
        await req.propertyDb.models.kot_headers.update(
            { table_id: main_table_id },
            { where: { table_id: table_to_merge_id, status: { [Op.ne]: 'Closed' }, outlet_id }, transaction: t }
        );

        // Update guest count in main table
        const totalGuests = Number(mainTable.current_guest_count) + Number(mergeTable.current_guest_count);
        await mainTable.update({
            current_guest_count: totalGuests
        }, { transaction: t });

        // Reset the merged table
        await mergeTable.update({
            status: 'Available',
            current_guest_count: 0,
            current_waiter_id: null,
            current_captain_id: null,
            active_sale_id: null
        }, { transaction: t });

        await audit.log({
            req,
            module: 'RESTAURANT',
            action: 'TABLE_MERGE',
            table: 'restaurant_tables',
            recordId: main_table_id,
            description: `Merged Table ${mergeTable.table_name} into ${mainTable.table_name}`,
            outlet_id,
            user_id: req.user.id
        });

        await t.commit();
        res.json({ success: true, message: `Table ${mergeTable.table_name} merged into ${mainTable.table_name}` });
    } catch (err) {
        await t.rollback();
        res.status(400).json({ success: false, error: err.message });
    }
};

/* =========================================================================
   TABLE RESERVATIONS CONTROLLER
   ========================================================================= */

exports.listReservations = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const reservations = await req.propertyDb.models.table_reservations.findAll({
            where: { outlet_id },
            include: [
                { model: req.propertyDb.models.restaurant_tables, as: 'table', attributes: ['table_name'] }
            ],
            order: [['reservation_time', 'ASC']]
        });
        res.json({ success: true, data: reservations });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.createReservation = async (req, res) => {
    const t = await req.propertyDb.transaction();
    try {
        const outlet_id = req.user.outlet_id;
        const { table_id, customer_name, customer_phone, reservation_time, guest_count, remarks } = req.body;

        const table = await req.propertyDb.models.restaurant_tables.findOne({
            where: { id: table_id, outlet_id },
            transaction: t
        });
        if (!table) throw new Error('Table not found');

        const reservation = await req.propertyDb.models.table_reservations.create({
            outlet_id,
            table_id,
            customer_name,
            customer_phone,
            reservation_time,
            guest_count: guest_count || 1,
            status: 'Pending',
            remarks
        }, { transaction: t });

        // Update table status to Reserved
        await table.update({ status: 'Reserved' }, { transaction: t });

        await t.commit();
        res.json({ success: true, data: reservation });
    } catch (err) {
        await t.rollback();
        res.status(400).json({ success: false, error: err.message });
    }
};

exports.updateReservationStatus = async (req, res) => {
    const t = await req.propertyDb.transaction();
    try {
        const outlet_id = req.user.outlet_id;
        const { id } = req.params;
        const { status } = req.body;

        const reservation = await req.propertyDb.models.table_reservations.findOne({
            where: { id, outlet_id },
            transaction: t
        });
        if (!reservation) throw new Error('Reservation not found');

        await reservation.update({ status }, { transaction: t });

        const table = await req.propertyDb.models.restaurant_tables.findOne({
            where: { id: reservation.table_id, outlet_id },
            transaction: t
        });

        if (status === 'Seated') {
            await table.update({ status: 'Occupied', current_guest_count: reservation.guest_count }, { transaction: t });
        } else if (status === 'Cancelled') {
            await table.update({ status: 'Available' }, { transaction: t });
        }

        await t.commit();
        res.json({ success: true, data: reservation });
    } catch (err) {
        await t.rollback();
        res.status(400).json({ success: false, error: err.message });
    }
};
