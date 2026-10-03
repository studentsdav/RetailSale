import { Request, Response } from 'express';
import { Op } from 'sequelize';
const audit = require('../../services/audit.service');

/* =========================================================================
   FLOORS CONTROLLER
   ========================================================================= */

export const listFloors = async (req: Request, res: Response) => {
    try {
        const outlet_id = (req as any).user?.outlet_id;
        const floors = await (req as any).propertyDb.models.floors.findAll({
            where: { outlet_id },
            order: [['name', 'ASC']]
        });
        res.json({ success: true, data: floors });
    } catch (err: any) {
        res.status(500).json({ success: false, error: err.message });
    }
};

export const createFloor = async (req: Request, res: Response) => {
    try {
        const outlet_id = (req as any).user?.outlet_id;
        const { name, status } = req.body;
        const floor = await (req as any).propertyDb.models.floors.create({
            outlet_id,
            name,
            status: status || 'ACTIVE'
        });
        res.json({ success: true, data: floor });
    } catch (err: any) {
        res.status(400).json({ success: false, error: err.message });
    }
};

export const updateFloor = async (req: Request, res: Response) => {
    try {
        const outlet_id = (req as any).user?.outlet_id;
        const { id } = req.params;
        const { name, status } = req.body;
        const floor = await (req as any).propertyDb.models.floors.findOne({ where: { id, outlet_id } });
        if (!floor) return res.status(404).json({ success: false, message: 'Floor not found' });

        await floor.update({ name, status });
        res.json({ success: true, data: floor });
    } catch (err: any) {
        res.status(400).json({ success: false, error: err.message });
    }
};

export const deleteFloor = async (req: Request, res: Response) => {
    try {
        const outlet_id = (req as any).user?.outlet_id;
        const { id } = req.params;
        const floor = await (req as any).propertyDb.models.floors.findOne({ where: { id, outlet_id } });
        if (!floor) return res.status(404).json({ success: false, message: 'Floor not found' });

        await floor.destroy();
        res.json({ success: true, message: 'Floor deleted successfully' });
    } catch (err: any) {
        res.status(400).json({ success: false, error: err.message });
    }
};

/* =========================================================================
   DINING AREAS CONTROLLER
   ========================================================================= */

export const listDiningAreas = async (req: Request, res: Response) => {
    try {
        const outlet_id = (req as any).user?.outlet_id;
        const areas = await (req as any).propertyDb.models.dining_areas.findAll({
            where: { outlet_id },
            order: [['name', 'ASC']]
        });
        res.json({ success: true, data: areas });
    } catch (err: any) {
        res.status(500).json({ success: false, error: err.message });
    }
};

export const createDiningArea = async (req: Request, res: Response) => {
    try {
        const outlet_id = (req as any).user?.outlet_id;
        const { name, description, status } = req.body;
        const area = await (req as any).propertyDb.models.dining_areas.create({
            outlet_id,
            name,
            description,
            status: status || 'ACTIVE'
        });
        res.json({ success: true, data: area });
    } catch (err: any) {
        res.status(400).json({ success: false, error: err.message });
    }
};

export const updateDiningArea = async (req: Request, res: Response) => {
    try {
        const outlet_id = (req as any).user?.outlet_id;
        const { id } = req.params;
        const { name, description, status } = req.body;
        const area = await (req as any).propertyDb.models.dining_areas.findOne({ where: { id, outlet_id } });
        if (!area) return res.status(404).json({ success: false, message: 'Dining Area not found' });

        await area.update({ name, description, status });
        res.json({ success: true, data: area });
    } catch (err: any) {
        res.status(400).json({ success: false, error: err.message });
    }
};

export const deleteDiningArea = async (req: Request, res: Response) => {
    try {
        const outlet_id = (req as any).user?.outlet_id;
        const { id } = req.params;
        const area = await (req as any).propertyDb.models.dining_areas.findOne({ where: { id, outlet_id } });
        if (!area) return res.status(404).json({ success: false, message: 'Dining Area not found' });

        await area.destroy();
        res.json({ success: true, message: 'Dining Area deleted successfully' });
    } catch (err: any) {
        res.status(400).json({ success: false, error: err.message });
    }
};

/* =========================================================================
   TABLE TYPES CONTROLLER
   ========================================================================= */

export const listTableTypes = async (req: Request, res: Response) => {
    try {
        const outlet_id = (req as any).user?.outlet_id;
        const types = await (req as any).propertyDb.models.table_types.findAll({
            where: { outlet_id },
            order: [['name', 'ASC']]
        });
        res.json({ success: true, data: types });
    } catch (err: any) {
        res.status(500).json({ success: false, error: err.message });
    }
};

export const createTableType = async (req: Request, res: Response) => {
    try {
        const outlet_id = (req as any).user?.outlet_id;
        const { name, charge_type, charge_amount } = req.body;
        const type = await (req as any).propertyDb.models.table_types.create({
            outlet_id,
            name,
            charge_type: charge_type || 'FLAT',
            charge_amount: charge_amount || 0.00
        });
        res.json({ success: true, data: type });
    } catch (err: any) {
        res.status(400).json({ success: false, error: err.message });
    }
};

export const updateTableType = async (req: Request, res: Response) => {
    try {
        const outlet_id = (req as any).user?.outlet_id;
        const { id } = req.params;
        const { name, charge_type, charge_amount } = req.body;
        const type = await (req as any).propertyDb.models.table_types.findOne({ where: { id, outlet_id } });
        if (!type) return res.status(404).json({ success: false, message: 'Table Type not found' });

        await type.update({ name, charge_type, charge_amount });
        res.json({ success: true, data: type });
    } catch (err: any) {
        res.status(400).json({ success: false, error: err.message });
    }
};

export const deleteTableType = async (req: Request, res: Response) => {
    try {
        const outlet_id = (req as any).user?.outlet_id;
        const { id } = req.params;
        const type = await (req as any).propertyDb.models.table_types.findOne({ where: { id, outlet_id } });
        if (!type) return res.status(404).json({ success: false, message: 'Table Type not found' });

        await type.destroy();
        res.json({ success: true, message: 'Table Type deleted successfully' });
    } catch (err: any) {
        res.status(400).json({ success: false, error: err.message });
    }
};

/* =========================================================================
   TABLES CONTROLLER & ACTIONS
   ========================================================================= */

export const listTables = async (req: Request, res: Response) => {
    try {
        const outlet_id = (req as any).user?.outlet_id;
        const { floor_id, dining_area_id } = req.query as any;
        console.log(`[API listTables] GET called. outlet_id: ${outlet_id}, floor_id: ${floor_id}, dining_area_id: ${dining_area_id}`);

        const whereClause: any = { outlet_id };
        if (floor_id && floor_id !== 'undefined' && floor_id !== 'null' && floor_id !== '') {
            whereClause.floor_id = floor_id;
        }
        if (dining_area_id && dining_area_id !== 'undefined' && dining_area_id !== 'null' && dining_area_id !== '') {
            whereClause.dining_area_id = dining_area_id;
        }

        const tables = await (req as any).propertyDb.models.restaurant_tables.findAll({
            where: whereClause,
            logging: console.log,
            include: [
                { model: (req as any).propertyDb.models.floors, as: 'floor', attributes: ['name'], required: false },
                { model: (req as any).propertyDb.models.dining_areas, as: 'dining_area', attributes: ['name'], required: false },
                { model: (req as any).propertyDb.models.table_types, as: 'table_type', attributes: ['name', 'charge_type', 'charge_amount'], required: false },
                { model: (req as any).propertyDb.models.hr_employees, as: 'waiter', attributes: [['full_name', 'employee_name']], required: false },
                { model: (req as any).propertyDb.models.hr_employees, as: 'captain', attributes: [['full_name', 'employee_name']], required: false }
            ],
            order: [['table_name', 'ASC']]
        });

        const todayStart = new Date();
        todayStart.setHours(0, 0, 0, 0);
        const todayEnd = new Date();
        todayEnd.setHours(23, 59, 59, 999);

        const todayReservations = await (req as any).propertyDb.models.table_reservations.findAll({
            where: {
                outlet_id,
                status: { [Op.in]: ['Pending', 'Confirmed', 'Reserved'] },
                reservation_time: {
                    [Op.between]: [todayStart, todayEnd]
                }
            }
        });

        function isReservationTimeActive(reservationTimeStr: any) {
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
                await (req as any).propertyDb.models.restaurant_tables.update(
                    { status: 'Occupied', current_guest_count: resv.guest_count },
                    { where: { id: resv.table_id, outlet_id } }
                );
                autoSeatedTableIds.set(resv.table_id, resv.guest_count);
                console.log(`[AUTO SEAT RESERVATION] Marked reservation #${resv.id} as Seated and Table #${resv.table_id} as Occupied`);
            } else if (isReservationTimeActive(resv.reservation_time)) {
                activeTableIds.add(resv.table_id);
            }
        }

        const activeKots = await (req as any).propertyDb.models.kot_headers.findAll({
            where: {
                outlet_id,
                status: {
                    [Op.notIn]: ['Cancelled', 'cancelled', 'Rejected', 'rejected', 'Billed', 'billed', 'Closed', 'closed', 'NC Cleared', 'nc_cleared', 'NC_CLEARED', 'Settled', 'settled']
                }
            },
            include: [
                {
                    model: (req as any).propertyDb.models.kot_items,
                    as: 'items',
                    required: false
                }
            ]
        });

        const tablesWithActiveKots = new Set<number>();
        for (const k of activeKots) {
            if (!k.table_id) continue;
            const items = k.items || [];
            const activeItems = items.filter((it: any) => {
                const s = (it.status || '').toLowerCase();
                return s !== 'cancelled' && s !== 'rejected';
            });
            if (activeItems.length > 0) {
                tablesWithActiveKots.add(Number(k.table_id));
            }
        }

        const data = tables.map((t: any) => {
            const plain = t.get({ plain: true });
            const tableIdNum = Number(plain.id);
            const hasActiveKot = tablesWithActiveKots.has(tableIdNum);

            if (autoSeatedTableIds.has(plain.id)) {
                plain.status = 'Occupied';
                plain.current_guest_count = autoSeatedTableIds.get(plain.id);
            } else if (!hasActiveKot && (plain.status === 'Occupied' || plain.status === 'Billing')) {
                // Table has 0 active KOT items remaining -> auto heal to Available
                plain.status = 'Available';
                plain.current_guest_count = 0;
                (req as any).propertyDb.models.restaurant_tables.update(
                    { status: 'Available', current_guest_count: 0 },
                    { where: { id: plain.id, outlet_id } }
                ).catch((e: any) => console.error(`[AUTO HEAL TABLE ERR]`, e.message));
            } else if (plain.status === 'Reserved' || plain.status === 'Available') {
                plain.status = activeTableIds.has(plain.id) ? 'Reserved' : 'Available';
            }
            return plain;
        });

        console.log(`✔ [API listTables] Returning ${tables.length} tables successfully.`);
        res.json({ success: true, data });
    } catch (err: any) {
        console.error("❌ [API listTables] Error loading tables:", err);
        res.status(500).json({ success: false, error: err.message });
    }
};

export const createTable = async (req: Request, res: Response) => {
    try {
        const outlet_id = (req as any).user?.outlet_id;
        const { floor_id, dining_area_id, table_type_id, table_name, capacity, x_coordinate, y_coordinate } = req.body;
        console.log("-> [API createTable] POST called with payload:", req.body);

        const table = await (req as any).propertyDb.models.restaurant_tables.create({
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
    } catch (err: any) {
        console.error("❌ [API createTable] Error creating table in database:", err);
        res.status(400).json({ success: false, error: err.message });
    }
};

export const updateTable = async (req: Request, res: Response) => {
    try {
        const outlet_id = (req as any).user?.outlet_id;
        const { id } = req.params;
        const { floor_id, dining_area_id, table_type_id, table_name, capacity, x_coordinate, y_coordinate } = req.body;
        const table = await (req as any).propertyDb.models.restaurant_tables.findOne({ where: { id, outlet_id } });
        if (!table) return res.status(404).json({ success: false, message: 'Table not found' });

        await table.update({ floor_id, dining_area_id, table_type_id, table_name, capacity, x_coordinate, y_coordinate });
        res.json({ success: true, data: table });
    } catch (err: any) {
        res.status(400).json({ success: false, error: err.message });
    }
};

export const deleteTable = async (req: Request, res: Response) => {
    try {
        const outlet_id = (req as any).user?.outlet_id;
        const { id } = req.params;
        const table = await (req as any).propertyDb.models.restaurant_tables.findOne({ where: { id, outlet_id } });
        if (!table) return res.status(404).json({ success: false, message: 'Table not found' });

        await table.destroy();
        res.json({ success: true, message: 'Table deleted successfully' });
    } catch (err: any) {
        res.status(400).json({ success: false, error: err.message });
    }
};

export const updateTableStatus = async (req: Request, res: Response) => {
    try {
        const outlet_id = (req as any).user?.outlet_id;
        const { id } = req.params;
        const { status, guest_count, waiter_id, captain_id, active_sale_id, assigned_user_id, assigned_user_name } = req.body;

        const table = await (req as any).propertyDb.models.restaurant_tables.findOne({ where: { id, outlet_id } });
        if (!table) return res.status(404).json({ success: false, message: 'Table not found' });

        const updateData: any = {};
        if (status) updateData.status = status;
        if (guest_count !== undefined) updateData.current_guest_count = guest_count;
        if (waiter_id !== undefined) updateData.current_waiter_id = waiter_id;
        if (captain_id !== undefined) updateData.current_captain_id = captain_id;
        if (active_sale_id !== undefined) updateData.active_sale_id = active_sale_id;
        if (assigned_user_id !== undefined) updateData.assigned_user_id = assigned_user_id ? Number(assigned_user_id) : null;
        if (assigned_user_name !== undefined) updateData.assigned_user_name = assigned_user_name ? String(assigned_user_name) : null;

        await table.update(updateData);

        if (status === 'Occupied') {
            try {
                const now = new Date();
                const windowStart = new Date(now.getTime() - 60 * 60 * 1000);
                const windowEnd = new Date(now.getTime() + 60 * 60 * 1000);

                const activeResvs = await (req as any).propertyDb.models.table_reservations.findAll({
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
                    activeResvs.sort((a: any, b: any) => {
                        const diffA = Math.abs(new Date(a.reservation_time).getTime() - now.getTime());
                        const diffB = Math.abs(new Date(b.reservation_time).getTime() - now.getTime());
                        return diffA - diffB;
                    });

                    const closest = activeResvs[0];
                    await closest.update({ status: 'Seated' });
                    console.log(`[AUTO SEAT RESERVATION] Marked reservation #${closest.id} for table #${id} as Seated`);
                }
            } catch (resvErr: any) {
                console.error('[AUTO SEAT RESERVATION FAIL]', resvErr.message);
            }
        }

        res.json({ success: true, data: table });
    } catch (err: any) {
        res.status(400).json({ success: false, error: err.message });
    }
};

export const transferTable = async (req: Request, res: Response) => {
    const t = await (req as any).propertyDb.transaction();
    try {
        const outlet_id = (req as any).user?.outlet_id;
        const { source_table_id, target_table_id } = req.body;

        const source = await (req as any).propertyDb.models.restaurant_tables.findOne({
            where: { id: source_table_id, outlet_id },
            transaction: t
        });
        const target = await (req as any).propertyDb.models.restaurant_tables.findOne({
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
        await (req as any).propertyDb.models.kot_headers.update(
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
            user_id: (req as any).user?.id
        });

        await t.commit();
        res.json({ success: true, message: `Table ${source.table_name} transferred to ${target.table_name}` });
    } catch (err: any) {
        await t.rollback();
        res.status(400).json({ success: false, error: err.message });
    }
};

export const mergeTables = async (req: Request, res: Response) => {
    const t = await (req as any).propertyDb.transaction();
    try {
        const outlet_id = (req as any).user?.outlet_id;
        const { main_table_id, table_to_merge_id } = req.body;

        const mainTable = await (req as any).propertyDb.models.restaurant_tables.findOne({
            where: { id: main_table_id, outlet_id },
            transaction: t
        });
        const mergeTable = await (req as any).propertyDb.models.restaurant_tables.findOne({
            where: { id: table_to_merge_id, outlet_id },
            transaction: t
        });

        if (!mainTable || !mergeTable) throw new Error('Main or Merge table not found');
        if (mainTable.status === 'Available') throw new Error('Main table must be occupied first');
        if (mergeTable.status === 'Available') throw new Error('Merge table has no orders to merge');

        // Link KOT headers from merged table to the main table
        await (req as any).propertyDb.models.kot_headers.update(
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
            user_id: (req as any).user?.id
        });

        await t.commit();
        res.json({ success: true, message: `Table ${mergeTable.table_name} merged into ${mainTable.table_name}` });
    } catch (err: any) {
        await t.rollback();
        res.status(400).json({ success: false, error: err.message });
    }
};

/* =========================================================================
   TABLE RESERVATIONS CONTROLLER
   ========================================================================= */

export const listReservations = async (req: Request, res: Response) => {
    try {
        const outlet_id = (req as any).user?.outlet_id;
        const reservations = await (req as any).propertyDb.models.table_reservations.findAll({
            where: { outlet_id },
            include: [
                { model: (req as any).propertyDb.models.restaurant_tables, as: 'table', attributes: ['table_name'] }
            ],
            order: [['reservation_time', 'ASC']]
        });
        res.json({ success: true, data: reservations });
    } catch (err: any) {
        res.status(500).json({ success: false, error: err.message });
    }
};

export const createReservation = async (req: Request, res: Response) => {
    const t = await (req as any).propertyDb.transaction();
    try {
        const outlet_id = (req as any).user?.outlet_id;
        const { table_id, customer_name, customer_phone, reservation_time, guest_count, remarks, address, gstin } = req.body;
        const phone = (customer_phone || req.body.phone || '').toString().trim();

        const table = await (req as any).propertyDb.models.restaurant_tables.findOne({
            where: { id: table_id, outlet_id },
            transaction: t
        });
        if (!table) throw new Error('Table not found');

        const reservation = await (req as any).propertyDb.models.table_reservations.create({
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
                const cleanPhone = String(phone || '').trim();
                const scope: any = {};
                if (cleanPhone) {
                    scope.customer_phone = cleanPhone;
                } else if (customer_name) {
                    scope.customer_name = String(customer_name).trim();
                }

                if (Object.keys(scope).length > 0) {
                    const existing = await (req as any).propertyDb.models.customers.findOne({
                        where: {
                            outlet_id,
                            ...scope
                        },
                        transaction: t
                    });

                    if (!existing) {
                        await (req as any).propertyDb.models.customers.create({
                            outlet_id,
                            customer_name: customer_name ? String(customer_name).trim() : null,
                            customer_phone: cleanPhone || null,
                            customer_address: address ? String(address).trim() : null,
                            customer_gstin: gstin ? String(gstin).trim() : null
                        }, { transaction: t });
                    } else {
                        const updateData: any = {};
                        if (!existing.customer_name && customer_name) updateData.customer_name = String(customer_name).trim();
                        if (!existing.customer_address && address) updateData.customer_address = String(address).trim();
                        if (!existing.customer_gstin && gstin) updateData.customer_gstin = String(gstin).trim();
                        if (Object.keys(updateData).length > 0) {
                            await existing.update(updateData, { transaction: t });
                        }
                    }
                }
            } catch (custErr: any) {
                console.error('[AUTO ADD RESERVATION CUSTOMER FAIL]', custErr.message);
            }
        }

        await t.commit();
        res.json({ success: true, data: reservation });
    } catch (err: any) {
        await t.rollback();
        res.status(400).json({ success: false, error: err.message });
    }
};

export const updateReservationStatus = async (req: Request, res: Response) => {
    const t = await (req as any).propertyDb.transaction();
    try {
        const outlet_id = (req as any).user?.outlet_id;
        const { id } = req.params;
        const { status } = req.body;

        const reservation = await (req as any).propertyDb.models.table_reservations.findOne({
            where: { id, outlet_id },
            transaction: t
        });
        if (!reservation) throw new Error('Reservation not found');

        await reservation.update({ status }, { transaction: t });

        const table = await (req as any).propertyDb.models.restaurant_tables.findOne({
            where: { id: reservation.table_id, outlet_id },
            transaction: t
        });

        if (status === 'Seated' && table) {
            await table.update({ status: 'Occupied', current_guest_count: reservation.guest_count }, { transaction: t });
        } else if (status === 'Cancelled' && table) {
            await table.update({ status: 'Available' }, { transaction: t });
        }

        await t.commit();
        res.json({ success: true, data: reservation });
    } catch (err: any) {
        await t.rollback();
        res.status(400).json({ success: false, error: err.message });
    }
};

export const importTables = async (req: Request, res: Response) => {
    const t = await (req as any).propertyDb.transaction();
    try {
        const outlet_id = (req as any).user?.outlet_id;
        if (!outlet_id) {
            await t.rollback();
            return res.status(400).json({ success: false, message: 'Invalid outlet session' });
        }

        const { tables } = req.body;

        if (!tables || !Array.isArray(tables) || tables.length === 0) {
            await t.rollback();
            return res.status(400).json({ success: false, message: 'No table records provided for import' });
        }

        let importedCount = 0;
        let updatedCount = 0;

        // Cache created/found floors, areas, types and employees in memory during this transaction
        const floorCache = new Map<string, any>();
        const areaCache = new Map<string, any>();
        const typeCache = new Map<string, any>();
        const employeeCache = new Map<string, any>();

        for (const row of tables) {
            const tableName = (
                row.table_name || 
                row['Table Name'] || 
                row['Table Number'] || 
                row['Table No'] || 
                row.tableName || 
                row.name || 
                row.Table || 
                ''
            ).toString().trim();

            if (!tableName) continue;

            const capacity = parseInt(
                row.capacity || 
                row['Capacity'] || 
                row['Seats'] || 
                row['Capacity (Seats)'] || 
                row.seats || 
                4, 
                10
            ) || 4;

            const floorName = (
                row.floor || 
                row['Floor'] || 
                row['Floor Name'] || 
                row.floor_name || 
                'Main Floor'
            ).toString().trim();

            const areaName = (
                row.dining_area || 
                row['Dining Area'] || 
                row['Area'] || 
                row.area_name || 
                row.area || 
                'General Dining'
            ).toString().trim();

            const typeName = (
                row.table_type || 
                row['Table Type'] || 
                row['Type'] || 
                row.type || 
                row.table_type_name || 
                'Standard'
            ).toString().trim();

            const waiterIdentifier = (
                row.waiter || 
                row['Waiter'] || 
                row['Assigned Waiter'] || 
                row.waiter_name || 
                row.current_waiter_id || 
                ''
            ).toString().trim();

            const captainIdentifier = (
                row.captain || 
                row['Captain'] || 
                row['Assigned Captain'] || 
                row.captain_name || 
                row.current_captain_id || 
                ''
            ).toString().trim();

            const statusVal = (
                row.status || 
                row['Status'] || 
                'Available'
            ).toString().trim();

            // 1. Find or auto-create Floor
            let floor = null;
            if (floorName) {
                const floorKey = floorName.toLowerCase();
                if (floorCache.has(floorKey)) {
                    floor = floorCache.get(floorKey);
                } else {
                    floor = await (req as any).propertyDb.models.floors.findOne({
                        where: {
                            outlet_id,
                            name: { [Op.iLike]: floorName }
                        },
                        transaction: t
                    });
                    if (!floor) {
                        floor = await (req as any).propertyDb.models.floors.create({
                            outlet_id,
                            name: floorName,
                            status: 'ACTIVE'
                        }, { transaction: t });
                    }
                    floorCache.set(floorKey, floor);
                }
            }

            // 2. Find or auto-create Dining Area
            let area = null;
            if (areaName) {
                const areaKey = areaName.toLowerCase();
                if (areaCache.has(areaKey)) {
                    area = areaCache.get(areaKey);
                } else {
                    area = await (req as any).propertyDb.models.dining_areas.findOne({
                        where: {
                            outlet_id,
                            name: { [Op.iLike]: areaName }
                        },
                        transaction: t
                    });
                    if (!area) {
                        area = await (req as any).propertyDb.models.dining_areas.create({
                            outlet_id,
                            name: areaName,
                            description: 'Auto-created from Excel import',
                            status: 'ACTIVE'
                        }, { transaction: t });
                    }
                    areaCache.set(areaKey, area);
                }
            }

            // 3. Find or auto-create Table Type
            let tableType = null;
            if (typeName) {
                const typeKey = typeName.toLowerCase();
                if (typeCache.has(typeKey)) {
                    tableType = typeCache.get(typeKey);
                } else {
                    tableType = await (req as any).propertyDb.models.table_types.findOne({
                        where: {
                            outlet_id,
                            name: { [Op.iLike]: typeName }
                        },
                        transaction: t
                    });
                    if (!tableType) {
                        tableType = await (req as any).propertyDb.models.table_types.create({
                            outlet_id,
                            name: typeName,
                            charge_type: 'FLAT',
                            charge_amount: 0.00
                        }, { transaction: t });
                    }
                    typeCache.set(typeKey, tableType);
                }
            }

            // 4. Resolve Waiter (optional)
            let waiterId: number | null = null;
            if (waiterIdentifier) {
                const wKey = waiterIdentifier.toLowerCase();
                if (employeeCache.has(wKey)) {
                    waiterId = employeeCache.get(wKey);
                } else {
                    const emp = await (req as any).propertyDb.models.hr_employees.findOne({
                        where: {
                            outlet_id,
                            [Op.or]: [
                                { full_name: { [Op.iLike]: waiterIdentifier } },
                                { employee_code: { [Op.iLike]: waiterIdentifier } }
                            ]
                        },
                        transaction: t
                    });
                    if (emp) {
                        waiterId = emp.id;
                        employeeCache.set(wKey, waiterId);
                    }
                }
            }

            // 5. Resolve Captain (optional)
            let captainId: number | null = null;
            if (captainIdentifier) {
                const cKey = captainIdentifier.toLowerCase();
                if (employeeCache.has(cKey)) {
                    captainId = employeeCache.get(cKey);
                } else {
                    const emp = await (req as any).propertyDb.models.hr_employees.findOne({
                        where: {
                            outlet_id,
                            [Op.or]: [
                                { full_name: { [Op.iLike]: captainIdentifier } },
                                { employee_code: { [Op.iLike]: captainIdentifier } }
                            ]
                        },
                        transaction: t
                    });
                    if (emp) {
                        captainId = emp.id;
                        employeeCache.set(cKey, captainId);
                    }
                }
            }

            // 6. Duplicate Prevention & Upsert on (outlet_id, table_name)
            let table = await (req as any).propertyDb.models.restaurant_tables.findOne({
                where: {
                    outlet_id,
                    table_name: { [Op.iLike]: tableName }
                },
                transaction: t
            });

            if (table) {
                const updatePayload: any = {
                    capacity,
                    floor_id: floor ? floor.id : table.floor_id,
                    dining_area_id: area ? area.id : table.dining_area_id,
                    table_type_id: tableType ? tableType.id : table.table_type_id,
                };
                if (waiterId !== null) updatePayload.current_waiter_id = waiterId;
                if (captainId !== null) updatePayload.current_captain_id = captainId;
                if (statusVal && statusVal !== 'Available' && statusVal !== 'Occupied' && statusVal !== 'Reserved') {
                    updatePayload.status = statusVal;
                }

                await table.update(updatePayload, { transaction: t });
                updatedCount++;
            } else {
                await (req as any).propertyDb.models.restaurant_tables.create({
                    outlet_id,
                    table_name: tableName,
                    capacity,
                    status: (statusVal && ['Available', 'Occupied', 'Reserved', 'Billed'].includes(statusVal)) ? statusVal : 'Available',
                    floor_id: floor ? floor.id : null,
                    dining_area_id: area ? area.id : null,
                    table_type_id: tableType ? tableType.id : null,
                    current_waiter_id: waiterId,
                    current_captain_id: captainId,
                }, { transaction: t });
                importedCount++;
            }
        }

        await t.commit();
        res.json({
            success: true,
            message: `Successfully imported ${importedCount} new tables and updated ${updatedCount} existing tables.`,
            imported: importedCount,
            updated: updatedCount
        });
    } catch (err: any) {
        await t.rollback();
        console.error('Error importing tables:', err);
        res.status(500).json({ success: false, message: 'Failed to import tables: ' + err.message });
    }
};

export const assignTableUser = async (req: Request, res: Response) => {
    try {
        const outlet_id = (req as any).user?.outlet_id;
        const { id } = req.params;
        const { waiter_id, captain_id, assigned_user_id, assigned_user_name } = req.body;

        const table = await (req as any).propertyDb.models.restaurant_tables.findOne({
            where: { id, outlet_id }
        });

        if (!table) {
            return res.status(404).json({ success: false, message: 'Table not found' });
        }

        const updateData: any = {};
        if (waiter_id !== undefined) updateData.current_waiter_id = waiter_id ? Number(waiter_id) : null;
        if (captain_id !== undefined) updateData.current_captain_id = captain_id ? Number(captain_id) : null;
        if (assigned_user_id !== undefined) updateData.assigned_user_id = assigned_user_id ? Number(assigned_user_id) : null;
        if (assigned_user_name !== undefined) updateData.assigned_user_name = assigned_user_name ? String(assigned_user_name) : null;

        await table.update(updateData);

        res.json({
            success: true,
            message: 'Table assigned successfully',
            data: table
        });
    } catch (err: any) {
        console.error('Error assigning table:', err);
        res.status(500).json({ success: false, message: 'Failed to assign table: ' + err.message });
    }
};

export const getTableTransactions = async (req: Request, res: Response) => {
    try {
        const outlet_id = (req as any).user?.outlet_id;
        const { id } = req.params;

        const kots = await (req as any).propertyDb.models.kot_headers.findAll({
            where: {
                outlet_id,
                table_id: id,
                status: { [Op.ne]: 'c' }
            },
            include: [
                {
                    model: (req as any).propertyDb.models.kot_items,
                    as: 'items'
                }
            ],
            order: [['created_at', 'ASC']]
        });

        res.json({
            success: true,
            data: kots
        });
    } catch (err: any) {
        console.error('Error fetching table transactions:', err);
        res.status(500).json({ success: false, message: 'Failed to load table transactions' });
    }
};

export default {
    listFloors,
    createFloor,
    updateFloor,
    deleteFloor,
    listDiningAreas,
    createDiningArea,
    updateDiningArea,
    deleteDiningArea,
    listTableTypes,
    createTableType,
    updateTableType,
    deleteTableType,
    listTables,
    createTable,
    importTables,
    updateTable,
    deleteTable,
    updateTableStatus,
    assignTableUser,
    getTableTransactions,
    transferTable,
    mergeTables,
    listReservations,
    createReservation,
    updateReservationStatus
};

module.exports = {
    listFloors,
    createFloor,
    updateFloor,
    deleteFloor,
    listDiningAreas,
    createDiningArea,
    updateDiningArea,
    deleteDiningArea,
    listTableTypes,
    createTableType,
    updateTableType,
    deleteTableType,
    listTables,
    createTable,
    importTables,
    updateTable,
    deleteTable,
    updateTableStatus,
    assignTableUser,
    getTableTransactions,
    transferTable,
    mergeTables,
    listReservations,
    createReservation,
    updateReservationStatus
};
