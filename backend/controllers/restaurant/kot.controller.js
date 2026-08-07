const { Op } = require('sequelize');
const audit = require('../../services/audit.service');

exports.getNextKotNo = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const today = new Date();
        const dateStr = `${today.getFullYear()}${String(today.getMonth() + 1).padStart(2, '0')}${String(today.getDate()).padStart(2, '0')}`;

        const count = await req.propertyDb.models.kot_headers.count({
            where: {
                outlet_id,
                created_at: {
                    [Op.gte]: new Date(today.setHours(0, 0, 0, 0))
                }
            }
        });

        const seq = String(count + 1).padStart(4, '0');
        const nextNo = `KOT-${dateStr}-${seq}`;

        res.json({ success: true, data: nextNo });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.listKots = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { status, table_id, active_only } = req.query;

        const whereClause = { outlet_id };
        if (status) whereClause.status = status;
        if (table_id) whereClause.table_id = table_id;
        if (active_only === 'true') {
            whereClause.status = { [Op.ne]: 'Closed' };
        }

        const kots = await req.propertyDb.models.kot_headers.findAll({
            where: whereClause,
            logging: console.log,
            include: [
                { model: req.propertyDb.models.restaurant_tables, as: 'table', attributes: ['table_name'], required: false },
                { model: req.propertyDb.models.hr_employees, as: 'waiter', attributes: [['full_name', 'employee_name']], required: false },
                { model: req.propertyDb.models.hr_employees, as: 'captain', attributes: [['full_name', 'employee_name']], required: false },
                {
                    model: req.propertyDb.models.kot_items,
                    as: 'items',
                    required: false,
                    include: [
                        { model: req.propertyDb.models.kitchen_stations, as: 'station', attributes: ['station_name'], required: false }
                    ]
                }
            ],
            order: [['created_time', 'DESC']]
        });

        res.json({ success: true, data: kots });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.getKotDetails = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { id } = req.params;

        const kot = await req.propertyDb.models.kot_headers.findOne({
            where: { id, outlet_id },
            include: [
                { model: req.propertyDb.models.restaurant_tables, as: 'table', attributes: ['table_name'], required: false },
                { model: req.propertyDb.models.hr_employees, as: 'waiter', attributes: [['full_name', 'employee_name']], required: false },
                { model: req.propertyDb.models.hr_employees, as: 'captain', attributes: [['full_name', 'employee_name']], required: false },
                { model: req.propertyDb.models.kot_items, as: 'items' },
                { model: req.propertyDb.models.kot_revisions, as: 'revisions' }
            ]
        });

        if (!kot) return res.status(404).json({ success: false, message: 'KOT not found' });
        res.json({ success: true, data: kot });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.createKot = async (req, res) => {
    const t = await req.propertyDb.transaction();
    try {
        const outlet_id = req.user.outlet_id;
        const user_id = req.user.user_id || req.user.id;
        const { table_id, service_type, waiter_id, captain_id, remarks, items } = req.body;

        if (!items || items.length === 0) throw new Error('Cannot create KOT without items');

        // Verify table status
        let table = null;
        if (table_id) {
            table = await req.propertyDb.models.restaurant_tables.findOne({
                where: { id: table_id, outlet_id },
                transaction: t
            });
            if (!table) throw new Error('Table not found');
            await table.update({ status: 'Occupied' }, { transaction: t });
        }

        // Generate KOT number
        const today = new Date();
        const dateStr = `${today.getFullYear()}${String(today.getMonth() + 1).padStart(2, '0')}${String(today.getDate()).padStart(2, '0')}`;
        const count = await req.propertyDb.models.kot_headers.count({
            where: {
                outlet_id,
                created_at: { [Op.gte]: new Date(today.setHours(0, 0, 0, 0)) }
            },
            transaction: t
        });
        const seq = String(count + 1).padStart(4, '0');
        const kot_no = `KOT-${dateStr}-${seq}`;

        // Validate waiter and captain exist
        let validWaiterId = null;
        if (waiter_id && waiter_id !== 'null' && waiter_id !== 'undefined' && Number(waiter_id) > 0) {
            const waiterExists = await req.propertyDb.models.hr_employees.findOne({
                where: { id: waiter_id, outlet_id },
                transaction: t
            });
            if (waiterExists) validWaiterId = waiter_id;
        }

        let validCaptainId = null;
        if (captain_id && captain_id !== 'null' && captain_id !== 'undefined' && Number(captain_id) > 0) {
            const captainExists = await req.propertyDb.models.hr_employees.findOne({
                where: { id: captain_id, outlet_id },
                transaction: t
            });
            if (captainExists) validCaptainId = captain_id;
        }

        // Create KOT Header
        const header = await req.propertyDb.models.kot_headers.create({
            outlet_id,
            kot_no,
            table_id,
            service_type: service_type || 'Dine In',
            status: 'New',
            waiter_id: validWaiterId,
            captain_id: validCaptainId,
            remarks,
            revision_no: 1,
            created_time: new Date()
        }, { transaction: t });

        // Save Items and assign stations automatically based on item_master
        const itemsToCreate = [];
        for (const element of items) {
            const itemDef = await req.propertyDb.models.item_master.findOne({
                where: { id: element.item_id, outlet_id },
                transaction: t
            });

            if (!itemDef) throw new Error(`Item ${element.item_name} not found`);

            itemsToCreate.push({
                outlet_id,
                kot_header_id: header.id,
                item_id: element.item_id,
                item_name: itemDef.item_name,
                qty: Number(element.qty) || 1.0000,
                status: 'New',
                item_remark: element.item_remark || '',
                modifier_details: element.modifier_details || [],
                kitchen_station_id: itemDef.kitchen_station_id
            });
        }

        const createdItems = await req.propertyDb.models.kot_items.bulkCreate(itemsToCreate, { transaction: t });

        await audit.log({
            req,
            module: 'RESTAURANT',
            action: 'KOT_CREATE',
            table: 'kot_headers',
            recordId: header.id,
            description: `Generated KOT ${kot_no} for Table ${table ? table.table_name : 'Counter Sale'}`,
            outlet_id,
            user_id
        });

        await t.commit();
        res.json({ success: true, data: { header, items: createdItems } });
    } catch (err) {
        await t.rollback();
        res.status(400).json({ success: false, error: err.message });
    }
};

exports.updateKotStatus = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { id } = req.params;
        const { status } = req.body;

        const kot = await req.propertyDb.models.kot_headers.findOne({ where: { id, outlet_id } });
        if (!kot) return res.status(404).json({ success: false, message: 'KOT not found' });

        const updateData = { status };
        const now = new Date();
        if (status === 'Accepted') updateData.accepted_time = now;
        else if (status === 'Preparing') updateData.cooking_start = now;
        else if (status === 'Ready') updateData.ready_time = now;
        else if (status === 'Served') updateData.served_time = now;
        else if (status === 'Closed') updateData.closed_time = now;

        await kot.update(updateData);
        res.json({ success: true, data: kot });
    } catch (err) {
        res.status(400).json({ success: false, error: err.message });
    }
};

exports.updateKotItemStatus = async (req, res) => {
    const t = await req.propertyDb.transaction();
    try {
        const outlet_id = req.user.outlet_id;
        const { itemId } = req.params;
        const { status, cancel_reason } = req.body;

        const item = await req.propertyDb.models.kot_items.findOne({
            where: { id: itemId, outlet_id },
            include: [{ model: req.propertyDb.models.kot_headers, as: 'header' }],
            transaction: t
        });

        if (!item) return res.status(404).json({ success: false, message: 'KOT item not found' });

        if (status === 'Cancelled' && !cancel_reason) {
            throw new Error('Cancellation reason is required');
        }

        const updateData = { status };
        await item.update(updateData, { transaction: t });

        // If cancelled, write audit log
        if (status === 'Cancelled') {
            await req.propertyDb.models.restaurant_audit_trail.create({
                outlet_id,
                user_id: req.user.id,
                action_type: 'ITEM_CANCEL',
                description: `Cancelled item "${item.item_name}" from KOT ${item.header.kot_no}. Reason: ${cancel_reason}`
            }, { transaction: t });
        }

        await t.commit();
        res.json({ success: true, data: item });
    } catch (err) {
        await t.rollback();
        res.status(400).json({ success: false, error: err.message });
    }
};

exports.modifyKot = async (req, res) => {
    const t = await req.propertyDb.transaction();
    try {
        const outlet_id = req.user.outlet_id;
        const { id } = req.params;
        const { items, modification_reason } = req.body; // Full updated list of items

        if (!items || items.length === 0) throw new Error('Modified KOT must contain items');

        const kot = await req.propertyDb.models.kot_headers.findOne({
            where: { id, outlet_id },
            transaction: t
        });
        if (!kot) throw new Error('KOT not found');

        const oldItems = await req.propertyDb.models.kot_items.findAll({
            where: { kot_header_id: id, outlet_id },
            transaction: t
        });

        const nextRevision = Number(kot.revision_no) + 1;
        const changes = { added: [], removed: [], updated: [] };

        // Process differences to calculate revision details
        for (const oldItem of oldItems) {
            const match = items.find(i => i.item_id === oldItem.item_id);
            if (!match) {
                // Item removed
                changes.removed.push({ item_id: oldItem.item_id, item_name: oldItem.item_name, qty: oldItem.qty });
                await oldItem.destroy({ transaction: t });
            } else if (Number(match.qty) !== Number(oldItem.qty) || match.item_remark !== oldItem.item_remark) {
                // Item qty/remark updated
                changes.updated.push({
                    item_id: oldItem.item_id,
                    item_name: oldItem.item_name,
                    old_qty: oldItem.qty,
                    new_qty: match.qty,
                    old_remark: oldItem.item_remark,
                    new_remark: match.item_remark
                });
                await oldItem.update({
                    qty: Number(match.qty),
                    item_remark: match.item_remark || '',
                    modifier_details: match.modifier_details || []
                }, { transaction: t });
            }
        }

        for (const newItem of items) {
            const exists = oldItems.find(i => i.item_id === newItem.item_id);
            if (!exists) {
                // New item added
                const itemDef = await req.propertyDb.models.item_master.findOne({
                    where: { id: newItem.item_id, outlet_id },
                    transaction: t
                });
                if (!itemDef) throw new Error(`Item ${newItem.item_name} not found`);

                changes.added.push({ item_id: newItem.item_id, item_name: itemDef.item_name, qty: newItem.qty });

                await req.propertyDb.models.kot_items.create({
                    outlet_id,
                    kot_header_id: id,
                    item_id: newItem.item_id,
                    item_name: itemDef.item_name,
                    qty: Number(newItem.qty),
                    status: 'New',
                    item_remark: newItem.item_remark || '',
                    modifier_details: newItem.modifier_details || [],
                    kitchen_station_id: itemDef.kitchen_station_id
                }, { transaction: t });
            }
        }

        // Save Revision record
        await req.propertyDb.models.kot_revisions.create({
            kot_header_id: id,
            revision_no: nextRevision,
            change_details: changes,
            modified_by: req.user.id,
            modification_reason: modification_reason || 'Order update'
        }, { transaction: t });

        // Update Header revision index
        await kot.update({ revision_no: nextRevision, status: 'New' }, { transaction: t });

        await t.commit();
        res.json({ success: true, message: 'KOT modified successfully', revision: nextRevision, changes });
    } catch (err) {
        await t.rollback();
        res.status(400).json({ success: false, error: err.message });
    }
};

exports.reprintKot = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { id } = req.params;

        const kot = await req.propertyDb.models.kot_headers.findOne({
            where: { id, outlet_id }
        });
        if (!kot) return res.status(404).json({ success: false, message: 'KOT not found' });

        // Record audit
        await req.propertyDb.models.restaurant_audit_trail.create({
            outlet_id,
            user_id: req.user.id,
            action_type: 'KOT_REPRINT',
            description: `Reprinted KOT ${kot.kot_no}`
        });

        res.json({ success: true, message: 'Reprint logged successfully' });
    } catch (err) {
        res.status(400).json({ success: false, error: err.message });
    }
};
