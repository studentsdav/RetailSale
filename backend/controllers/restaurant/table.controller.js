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

        const todayStart = new Date();
        todayStart.setHours(0,0,0,0);
        const todayEnd = new Date();
        todayEnd.setHours(23,59,59,999);

        const todayReservations = await req.propertyDb.models.table_reservations.findAll({
            where: {
                outlet_id,
                status: { [Op.in]: ['Pending', 'Confirmed', 'Reserved'] },
                reservation_time: {
                    [Op.between]: [todayStart, todayEnd]
                }
            }
        });

        function isReservationTimeActive(reservationTimeStr) {
            const now = new Date();
            const resvDate = new Date(reservationTimeStr);
            
            if (resvDate.getFullYear() !== now.getFullYear() ||
                resvDate.getMonth() !== now.getMonth() ||
                resvDate.getDate() !== now.getDate()) {
                return false;
            }
            
            const resvHours = resvDate.getHours();
            const resvMins = resvDate.getMinutes();
            const resvTotalMins = resvHours * 60 + resvMins;
            
            const nowHours = now.getHours();
            const nowMins = now.getMinutes();
            const nowTotalMins = nowHours * 60 + nowMins;
            
            let slotDuration = 60; 
            
            if (resvTotalMins === 1350) { 
                slotDuration = 30; 
            } else if (resvTotalMins === 660) { 
                slotDuration = 60;
            } else if (resvTotalMins === 960) { 
                slotDuration = 120;
            } else if (resvTotalMins === 1380) { 
                slotDuration = 120;
            } else {
                slotDuration = 60;
            }
            
            return nowTotalMins >= resvTotalMins && nowTotalMins < (resvTotalMins + slotDuration);
        }

        const now = new Date();
        const activeTableIds = new Set();
        const autoSeatedTableIds = new Map();
        for (const resv of todayReservations) {
            const resvTime = new Date(resv.reservation_time);
            if (resvTime <= now) {
                await resv.update({ status: 'Seated' });
                await req.propertyDb.models.restaurant_tables.update(
                    { status: 'Occupied', current_guest_count: resv.guest_count },
                    { where: { id: resv.table_id, outlet_id } }
                );
                autoSeatedTableIds.set(resv.table_id, resv.guest_count);
                console.log(`[AUTO SEAT RESERVATION] Marked reservation #${resv.id} as Seated and Table #${resv.table_id} as Occupied`);
            } else if (isReservationTimeActive(resv.reservation_time)) {
                activeTableIds.add(resv.table_id);
            }
        }

        const data = tables.map(t => {
            const plain = t.get({ plain: true });
            if (autoSeatedTableIds.has(plain.id)) {
                plain.status = 'Occupied';
                plain.current_guest_count = autoSeatedTableIds.get(plain.id);
            } else if (plain.status === 'Reserved' || plain.status === 'Available') {
                plain.status = activeTableIds.has(plain.id) ? 'Reserved' : 'Available';
            }
            return plain;
        });

        console.log(`✔ [API listTables] Returning ${tables.length} tables successfully.`);
        res.json({ success: true, data });
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

        if (status === 'Occupied') {
            try {
                const { Op } = require('sequelize');
                const now = new Date();
                const windowStart = new Date(now.getTime() - 60 * 60 * 1000);
                const windowEnd = new Date(now.getTime() + 60 * 60 * 1000);

                const activeResvs = await req.propertyDb.models.table_reservations.findAll({
                    where: {
                        table_id: id,
                        outlet_id,
                        status: { [Op.in]: ['Pending', 'Confirmed', 'Reserved'] },
                        reservation_time: {
                            [Op.between]: [windowStart, windowEnd]
                        }
                    }
                });

                if (activeResvs && activeResvs.length > 0) {
                    activeResvs.sort((a, b) => {
                        const diffA = Math.abs(new Date(a.reservation_time).getTime() - now.getTime());
                        const diffB = Math.abs(new Date(b.reservation_time).getTime() - now.getTime());
                        return diffA - diffB;
                    });

                    const closest = activeResvs[0];
                    await closest.update({ status: 'Seated' });
                    console.log(`[AUTO SEAT RESERVATION] Marked reservation #${closest.id} for table #${id} as Seated`);
                }
            } catch (resvErr) {
                console.error('[AUTO SEAT RESERVATION FAIL]', resvErr.message);
            }
        }

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
        const { table_id, customer_name, customer_phone, reservation_time, guest_count, remarks, address, gstin } = req.body;
        const phone = (customer_phone || req.body.phone || '').toString().trim();

        const table = await req.propertyDb.models.restaurant_tables.findOne({
            where: { id: table_id, outlet_id },
            transaction: t
        });
        if (!table) throw new Error('Table not found');

        const reservation = await req.propertyDb.models.table_reservations.create({
            outlet_id,
            table_id,
            customer_name,
            customer_phone: phone,
            reservation_time,
            guest_count: guest_count || 1,
            status: 'Pending',
            remarks,
            address,
            gstin
        }, { transaction: t });

        // Update table status to Reserved
        await table.update({ status: 'Reserved' }, { transaction: t });

        // Auto-add or update reservation customer details in customer database
        if (phone || customer_name) {
            try {
                const { Op } = require('sequelize');
                const cleanPhone = String(phone || '').trim();
                const scope = {};
                if (cleanPhone) {
                    scope.customer_phone = cleanPhone;
                } else if (customer_name) {
                    scope.customer_name = String(customer_name).trim();
                }

                if (Object.keys(scope).length > 0) {
                    const existing = await req.propertyDb.models.customers.findOne({
                        where: {
                            outlet_id,
                            ...scope
                        },
                        transaction: t
                    });

                    if (!existing) {
                        await req.propertyDb.models.customers.create({
                            outlet_id,
                            customer_name: customer_name ? String(customer_name).trim() : null,
                            customer_phone: cleanPhone || null,
                            customer_address: address ? String(address).trim() : null,
                            customer_gstin: gstin ? String(gstin).trim() : null
                        }, { transaction: t });
                    } else {
                        const updateData = {};
                        if (!existing.customer_name && customer_name) updateData.customer_name = String(customer_name).trim();
                        if (!existing.customer_address && address) updateData.customer_address = String(address).trim();
                        if (!existing.customer_gstin && gstin) updateData.customer_gstin = String(gstin).trim();
                        if (Object.keys(updateData).length > 0) {
                            await existing.update(updateData, { transaction: t });
                        }
                    }
                }
            } catch (custErr) {
                console.error('[AUTO ADD RESERVATION CUSTOMER FAIL]', custErr.message);
            }
        }

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
