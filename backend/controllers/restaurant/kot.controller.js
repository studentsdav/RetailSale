const { Op } = require('sequelize');
const audit = require('../../services/audit.service');
const { insertLedger } = require('../../services/stockLedger.service');
const numberingHelper = require('../inventory/numberingSettingsV2.controller');

exports.getNextKotNo = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        let nextNo;

        try {
            const resolved = await numberingHelper.resolveNextNumber({
                req,
                module: 'KOT',
                date: new Date(),
                outlet_id
            });
            if (resolved && resolved.number) {
                nextNo = resolved.number;
            }
        } catch (numErr) {
            console.error('[NEXT KOT NO HELPER ERR]', numErr.message);
        }

        if (!nextNo) {
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
            nextNo = `KOT-${dateStr}-${seq}`;
        }

        res.json({ success: true, data: nextNo });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.listKots = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { status, table_id, active_only, from_date, to_date } = req.query;

        const whereClause = { outlet_id };
        if (status) {
            whereClause.status = status;
        }
        if (table_id) whereClause.table_id = table_id;
        if (active_only === 'true') {
            whereClause.sales_header_id = null;
            whereClause.status = { [Op.notIn]: ['Closed', 'closed', 'billed', 'Billed', 'BILLED', 'NC Cleared', 'nc_cleared', 'NC_CLEARED', 'cancelled', 'Cancelled', 'Rejected'] };
            whereClause.kds_dismissed = { [Op.ne]: true };
        }
        if (from_date && to_date) {
            whereClause.created_time = {
                [Op.between]: [new Date(from_date), new Date(to_date)]
            };
        }

        const kots = await req.propertyDb.models.kot_headers.findAll({
            where: whereClause,
            logging: console.log,
            include: [
                { model: req.propertyDb.models.restaurant_tables, as: 'table', attributes: ['table_name', 'status'], required: false },
                { model: req.propertyDb.models.hr_employees, as: 'waiter', attributes: [['full_name', 'employee_name']], required: false },
                { model: req.propertyDb.models.hr_employees, as: 'captain', attributes: [['full_name', 'employee_name']], required: false },
                { model: req.propertyDb.models.kot_revisions, as: 'revisions', required: false },
                {
                    model: req.propertyDb.models.kot_items,
                    as: 'items',
                    required: false,
                    include: [
                        { model: req.propertyDb.models.kitchen_stations, as: 'station', attributes: ['station_name'], required: false },
                        { model: req.propertyDb.models.item_master, as: 'item', attributes: ['brand'], required: false }
                    ]
                }
            ],
            order: [['created_time', 'DESC']]
        });

        let resultData = kots.map(kot => {
            const plain = kot.get({ plain: true });
            // Format captain name to 'N/A' if null/empty/dummy
            if (!plain.captain || !plain.captain.employee_name || plain.captain.employee_name.toString().toLowerCase().includes('dummy')) {
                plain.captain = { employee_name: 'N/A' };
            }
            return plain;
        });

        if (active_only === 'true') {
            resultData = resultData.filter(kot => {
                if (kot.sales_header_id != null) return false;
                const s = (kot.status || '').toLowerCase();
                if (s === 'billed' || s === 'closed' || s === 'cancelled') return false;
                if (kot.table) {
                    const tableStatus = (kot.table.status || '').toLowerCase();
                    if (tableStatus === 'billed' || tableStatus === 'available' || tableStatus === 'dirty' || tableStatus === 'cleaning' || tableStatus === 'needs cleaning') {
                        return false;
                    }
                }
                return true;
            });
        }

        res.json({ success: true, data: resultData });
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
                {
                    model: req.propertyDb.models.kot_items,
                    as: 'items',
                    required: false,
                    include: [
                        { model: req.propertyDb.models.kitchen_stations, as: 'station', attributes: ['station_name'], required: false },
                        { model: req.propertyDb.models.item_master, as: 'item', attributes: ['brand'], required: false }
                    ]
                },
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
        const { table_id: rawTableId, service_type, kottype, waiter_id, captain_id, remarks, items } = req.body;

        if (!items || items.length === 0) throw new Error('Cannot create KOT without items');

        let validTableId = null;
        if (rawTableId !== null && rawTableId !== undefined && rawTableId !== 'null' && rawTableId !== 'undefined' && Number(rawTableId) > 0) {
            validTableId = Number(rawTableId);
        }

        let determinedKotType = kottype;
        if (!determinedKotType) {
            const st = (service_type || '').toLowerCase();
            if (st.includes('nc')) determinedKotType = 'nc';
            else if (st.includes('pack') || st.includes('takeaway')) determinedKotType = 'packing';
            else determinedKotType = 'g';
        }

        let table = null;
        if (validTableId) {
            table = await req.propertyDb.models.restaurant_tables.findOne({
                where: { id: validTableId, outlet_id },
                transaction: t
            });
            if (!table) throw new Error('Table not found');
            await table.update({ status: 'Occupied' }, { transaction: t });

            // Auto-seat reservation
            try {
                const todayStart = new Date();
                todayStart.setHours(0, 0, 0, 0);
                const todayEnd = new Date();
                todayEnd.setHours(23, 59, 59, 999);

                await req.propertyDb.models.table_reservations.update(
                    { status: 'Seated' },
                    {
                        where: {
                            table_id,
                            outlet_id,
                            status: { [Op.in]: ['Pending', 'Confirmed', 'Reserved'] },
                            reservation_time: {
                                [Op.between]: [todayStart, todayEnd]
                            }
                        },
                        transaction: t
                    }
                );
            } catch (resvErr) {
                console.error('[AUTO SEAT RESERVATION FAIL]', resvErr.message);
            }
        }

        // Generate KOT number using Document Sequence Settings
        let kot_no;
        try {
            const resolved = await numberingHelper.resolveNextNumber({
                req,
                module: 'KOT',
                date: new Date(),
                outlet_id
            });
            if (resolved && resolved.number) {
                kot_no = resolved.number;
            }
        } catch (numErr) {
            console.error('[CREATE KOT NUMBERING HELPER ERR]', numErr.message);
        }

        if (!kot_no) {
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
            kot_no = `KOT-${dateStr}-${seq}`;
        }

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

        // Create KOT Header with status = 'p' (pending) and kottype ('g', 'nc', 'packing')
        const header = await req.propertyDb.models.kot_headers.create({
            outlet_id,
            kot_no,
            table_id: validTableId,
            service_type: service_type || 'Dine In',
            kottype: determinedKotType,
            status: req.body.status || 'p',
            waiter_id: validWaiterId,
            captain_id: validCaptainId,
            remarks,
            revision_no: 1,
            created_time: new Date()
        }, { transaction: t });

        // Save Items and assign stations automatically based on item_master location
        const itemsToCreate = [];
        for (const element of items) {
            const itemDef = await req.propertyDb.models.item_master.findOne({
                where: { id: element.item_id, outlet_id },
                transaction: t
            });

            if (!itemDef) throw new Error(`Item ${element.item_name} not found`);

            let stationId = itemDef.kitchen_station_id;
            if (!stationId) {
                const itemLoc = (itemDef.location || element.location || 'Kitchen').trim();
                const stationMatch = await req.propertyDb.models.kitchen_stations.findOne({
                    where: {
                        outlet_id,
                        station_name: { [Op.iLike]: itemLoc }
                    },
                    transaction: t
                });
                if (stationMatch) stationId = stationMatch.id;
            }

            itemsToCreate.push({
                outlet_id,
                kot_header_id: header.id,
                item_id: element.item_id,
                item_name: itemDef.item_name,
                qty: Number(element.qty) || 1.0000,
                status: 'New',
                item_remark: element.item_remark || '',
                modifier_details: element.modifier_details || [],
                kitchen_station_id: stationId
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
        const { status, kds_dismissed, remarks } = req.body;

        const kot = await req.propertyDb.models.kot_headers.findOne({ where: { id, outlet_id } });
        if (!kot) return res.status(404).json({ success: false, message: 'KOT not found' });

        const updateData = { status };
        if (kds_dismissed !== undefined) {
            updateData.kds_dismissed = kds_dismissed;
        }
        if (remarks !== undefined) {
            updateData.remarks = remarks;
        }
        const now = new Date();
        if (status === 'Accepted') updateData.accepted_time = now;
        else if (status === 'Preparing') {
            updateData.cooking_start = now;
            await req.propertyDb.models.kot_items.update(
                { status: 'Preparing' },
                { where: { kot_header_id: id, status: 'New', outlet_id } }
            );
        }
        else if (status === 'Ready') {
            updateData.ready_time = now;
            await req.propertyDb.models.kot_items.update(
                { status: 'Ready' },
                { where: { kot_header_id: id, status: { [Op.in]: ['New', 'Preparing'] }, outlet_id } }
            );
        }
        else if (status === 'Served') {
            updateData.served_time = now;
            updateData.kds_dismissed = true;
            await req.propertyDb.models.kot_items.update(
                { status: 'Served' },
                { where: { kot_header_id: id, status: { [Op.in]: ['New', 'Preparing', 'Ready'] }, outlet_id } }
            );
        }
        else if (status === 'Closed') {
            updateData.closed_time = now;
            updateData.kds_dismissed = true;
            await req.propertyDb.models.kot_items.update(
                { status: 'Served' },
                { where: { kot_header_id: id, status: { [Op.in]: ['New', 'Preparing', 'Ready', 'Served'] }, outlet_id } }
            );
        }
        else if (status === 'Cancelled' || status === 'cancelled' || status === 'Rejected') {
            await req.propertyDb.models.kot_items.update(
                { 
                    status: 'cancelled',
                    cancel_reason: remarks || `KOT ${status}`
                },
                { where: { kot_header_id: id, outlet_id } }
            );
        }
        else if (status === 'billed' || status === 'Billed' || status === 'Closed' || status === 'NC Cleared' || status === 'nc_cleared' || status === 'NC_CLEARED') {
            updateData.closed_time = now;
            updateData.kds_dismissed = true;
        }

        // Handle House KOT stock deduction upon clearance (status becomes Served or Closed)
        if ((status === 'Served' || status === 'Closed') && kot.service_type === 'House KOT') {
            // Check if stock ledger entry already exists for this KOT to prevent double deduction
            const alreadyDeducted = await req.propertyDb.models.stock_ledger.findOne({
                where: {
                    outlet_id,
                    ref_no: kot.kot_no,
                    txn_type: 'KOT Consumption'
                }
            });

            if (!alreadyDeducted) {
                const kotItems = await req.propertyDb.models.kot_items.findAll({
                    where: {
                        kot_header_id: id,
                        status: { [Op.notIn]: ['Cancelled', 'Rejected'] },
                        outlet_id
                    },
                    include: [
                        {
                            model: req.propertyDb.models.item_master,
                            as: 'item'
                        }
                    ]
                });

                for (const item of kotItems) {
                    if (item.item) {
                        await insertLedger({
                            db: req.propertyDb,
                            outlet_id,
                            item_code: item.item.item_code,
                            txn_date: now.toISOString(),
                            txn_type: 'KOT Consumption',
                            ref_no: kot.kot_no,
                            qty_in: 0,
                            qty_out: Number(item.qty),
                            allow_negative: false,
                            item_name: item.item.item_name,
                            brand: item.item.brand
                        });
                    }
                }
            }
        }

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
        const { status, cancel_reason, qty } = req.body;

        const item = await req.propertyDb.models.kot_items.findOne({
            where: { id: itemId, outlet_id },
            include: [{ model: req.propertyDb.models.kot_headers, as: 'header' }],
            transaction: t
        });

        if (!item) return res.status(404).json({ success: false, message: 'KOT item not found' });

        const updateData = {};
        if (status !== undefined) {
            updateData.status = status;
        }
        if (qty !== undefined) {
            updateData.qty = Number(qty);
            if (Number(qty) <= 0) {
                updateData.status = 'Cancelled';
            }
        }

        if (updateData.status === 'Cancelled' || updateData.status === 'Rejected') {
            if (!cancel_reason) {
                throw new Error('Cancellation/Rejection reason is required');
            }
            updateData.cancel_reason = cancel_reason;
        }

        const oldQty = item.qty;
        await item.update(updateData, { transaction: t });

        // If cancelled/rejected or reduced, write audit log
        if (updateData.status === 'Cancelled' || updateData.status === 'Rejected' || qty !== undefined) {
            const isFullyCancelled = updateData.status === 'Cancelled' || updateData.status === 'Rejected';
            const desc = isFullyCancelled
                ? `Cancelled/Rejected item "${item.item_name}" from KOT ${item.header.kot_no}. Reason: ${cancel_reason || 'No reason'}`
                : `Reduced item "${item.item_name}" qty from ${oldQty} to ${qty} in KOT ${item.header.kot_no}. Reason: ${cancel_reason || 'No reason'}`;

            await req.propertyDb.models.restaurant_audit_trail.create({
                outlet_id,
                user_id: req.user.id,
                action_type: isFullyCancelled ? 'ITEM_CANCEL' : 'ITEM_QTY_REDUCE',
                description: desc
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
                // Item removed: mark as Cancelled
                if (oldItem.status !== 'Cancelled') {
                    changes.removed.push({ item_id: oldItem.item_id, item_name: oldItem.item_name, qty: oldItem.qty });
                    await oldItem.update({ 
                        status: 'Cancelled',
                        cancel_reason: modification_reason || 'Removed by staff during modification'
                    }, { transaction: t });
                }
            } else {
                // Reactivate if it was previously Cancelled
                if (oldItem.status === 'Cancelled') {
                    changes.added.push({ item_id: oldItem.item_id, item_name: oldItem.item_name, qty: match.qty });
                    await oldItem.update({
                        status: 'New',
                        qty: Number(match.qty),
                        item_remark: match.item_remark || '',
                        modifier_details: match.modifier_details || []
                    }, { transaction: t });
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
                    
                    const oldQty = Number(oldItem.qty);
                    const newQty = Number(match.qty);
                    const isQtyIncreased = newQty > oldQty;

                    await oldItem.update({
                        qty: newQty,
                        status: isQtyIncreased ? 'New' : oldItem.status,
                        item_remark: match.item_remark || '',
                        modifier_details: match.modifier_details || []
                    }, { transaction: t });
                }
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
        res.json({ success: true, message: 'KOT modified successfully', revision: nextRevision, changes, kot_no: kot.kot_no });
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
