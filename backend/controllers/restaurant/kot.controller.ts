import { Request, Response } from 'express';
import { Op } from 'sequelize';
const { getOutletDateBounds } = require('../../utils/timezoneHelper');
const audit = require('../../services/audit.service');
const { insertLedger } = require('../../services/stockLedger.service');
const numberingHelper = require('../inventory/numberingSettingsV2.controller');

export const getNextKotNo = async (req: Request, res: Response) => {
    try {
        const outlet_id = (req as any).user?.outlet_id;
        let nextNo: string | undefined;

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
        } catch (numErr: any) {
            console.error('[NEXT KOT NO HELPER ERR]', numErr.message);
        }

        if (!nextNo) {
            const today = new Date();
            const dateStr = `${today.getFullYear()}${String(today.getMonth() + 1).padStart(2, '0')}${String(today.getDate()).padStart(2, '0')}`;
            const count = await (req as any).propertyDb.models.kot_headers.count({
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
    } catch (err: any) {
        res.status(500).json({ success: false, error: err.message });
    }
};

export const listKots = async (req: Request, res: Response) => {
    try {
        const outlet_id = (req as any).user?.outlet_id;
        const { status, table_id, active_only, from_date, to_date } = req.query as any;

        const whereClause: any = { outlet_id };
        if (status) {
            whereClause.status = status;
        }
        if (table_id) whereClause.table_id = table_id;
        if (active_only === 'true') {
            whereClause.sales_header_id = null;
            whereClause.status = { [Op.notIn]: ['Closed', 'closed', 'billed', 'Billed', 'BILLED', 'NC Cleared', 'nc_cleared', 'NC_CLEARED', 'cancelled', 'Cancelled', 'Rejected'] };
            if (!table_id && req.query.kds_only === 'true') {
                whereClause.kds_dismissed = { [Op.ne]: true };
            }
        }
        if (from_date && to_date) {
            const outletTz = (req as any).outletTimeZone || 'Asia/Kolkata';
            const { startDate, endDate } = (req as any).getDateBounds ? (req as any).getDateBounds(from_date, to_date) : getOutletDateBounds(from_date, to_date, outletTz);
            if (startDate && endDate) {
                whereClause.created_time = {
                    [Op.between]: [startDate, endDate]
                };
            }
        }

        const kots = await (req as any).propertyDb.models.kot_headers.findAll({
            where: whereClause,
            distinct: true,
            logging: console.log,
            include: [
                { model: (req as any).propertyDb.models.restaurant_tables, as: 'table', attributes: ['table_name', 'status', 'current_guest_count', 'capacity'], required: false },
                { model: (req as any).propertyDb.models.hr_employees, as: 'waiter', attributes: [['full_name', 'employee_name']], required: false },
                { model: (req as any).propertyDb.models.hr_employees, as: 'captain', attributes: [['full_name', 'employee_name']], required: false },
                { model: (req as any).propertyDb.models.kot_revisions, as: 'revisions', required: false },
                {
                    model: (req as any).propertyDb.models.sales_headers,
                    as: 'sales_header',
                    required: false,
                    attributes: [
                        'id', 'sale_no', 'status', 'payment_mode', 'net_amount', 'amount_paid', 'balance_due',
                        'sub_total', 'taxable_amount', 'total_tax', 'cgst_amount', 'sgst_amount', 'igst_amount',
                        'total_discount', 'manual_discount_amount', 'manual_discount_type', 'manual_discount_value',
                        'scheme_discount', 'coupon_discount_amount', 'loyalty_discount_amount',
                        'charges', 'charge_total', 'charge_tax_total', 'tax_breakup', 'round_off_amount'
                    ]
                },
                {
                    model: (req as any).propertyDb.models.kot_items,
                    as: 'items',
                    required: false,
                    include: [
                        { model: (req as any).propertyDb.models.kitchen_stations, as: 'station', attributes: ['station_name'], required: false },
                        {
                            model: (req as any).propertyDb.models.item_master,
                            as: 'item',
                            attributes: ['id', 'item_code', 'item_name', 'hsn_sac_code', 'barcode', 'unit', 'rate', 'retail_sale_price', 'mrp', 'tax_percent', 'tax_type', 'tax_group_id', 'brand', 'location', 'item_group', 'sub_category', 'is_tax_inclusive'],
                            required: false,
                            include: [
                                {
                                    model: (req as any).propertyDb.models.tax_groups,
                                    as: 'tax_group',
                                    attributes: ['id', 'group_name', 'group_code', 'total_rate', 'is_tax_inclusive'],
                                    required: false,
                                    include: [
                                        {
                                            model: (req as any).propertyDb.models.tax_group_components,
                                            as: 'components',
                                            required: false
                                        }
                                    ]
                                }
                            ]
                        }
                    ]
                }
            ],
            order: [['created_time', 'DESC']]
        });

        const seenKotIds = new Set();
        let resultData: any[] = [];
        for (const kot of kots) {
            const plain = kot.get({ plain: true });
            if (plain.id && seenKotIds.has(plain.id)) continue;
            if (plain.id) seenKotIds.add(plain.id);

            // Format captain name to 'N/A' if null/empty/dummy
            if (!plain.captain || !plain.captain.employee_name || plain.captain.employee_name.toString().toLowerCase().includes('dummy')) {
                plain.captain = { employee_name: 'N/A' };
            }

            if (plain.sales_header) {
                plain.bill_no = plain.sales_header.sale_no;
                plain.total_amount = Number(plain.sales_header.net_amount);
                plain.net_amount = Number(plain.sales_header.net_amount);
                plain.subtotal_amount = Number(plain.sales_header.sub_total);
                plain.taxable_amount = Number(plain.sales_header.taxable_amount);
                plain.tax_amount = Number(plain.sales_header.total_tax);
                plain.discount_amount = Number(plain.sales_header.total_discount || 0);
                plain.discount_type = plain.sales_header.manual_discount_type;
                plain.discount_value = Number(plain.sales_header.manual_discount_value || 0);
                plain.charge_total = Number(plain.sales_header.charge_total || 0);
                plain.charge_tax_total = Number(plain.sales_header.charge_tax_total || 0);
                plain.charges = plain.sales_header.charges || [];
                plain.tax_breakup = plain.sales_header.tax_breakup || null;
                plain.round_off_amount = Number(plain.sales_header.round_off_amount || 0);
                plain.payment_mode = plain.sales_header.payment_mode || plain.payment_mode;
                if (plain.sales_header.status === 'COMPLETED' || plain.sales_header.status === 'PAID' || Number(plain.sales_header.balance_due ?? 0) <= 0.01) {
                    plain.is_settled = true;
                    plain.payment_status = 'PAID';
                    plain.status = 'Closed';
                }
            }

            // Extract customer info from remarks or revisions if plain.customer_name is missing
            if (!plain.customer_name && plain.remarks) {
                const rem = String(plain.remarks);
                const qrIdx = rem.indexOf('Customer Self-Order (QR):');
                if (qrIdx !== -1) {
                    let qrPart = rem.substring(qrIdx + 'Customer Self-Order (QR):'.length);
                    const pipeIdx = qrPart.indexOf('|');
                    if (pipeIdx !== -1) qrPart = qrPart.substring(0, pipeIdx);

                    const cidMatch = qrPart.match(/\[CID:\s*([^\]]*)\]/i);
                    const emMatch = qrPart.match(/\[EM:\s*([^\]]*)\]/i);
                    const phoneMatch = qrPart.match(/\(([^)]*)\)/);

                    let parsedName = qrPart
                        .replace(/\[CID:[^\]]*\]/ig, '')
                        .replace(/\[EM:[^\]]*\]/ig, '')
                        .replace(/\([^)]*\)/g, '')
                        .trim();

                    const parsedPhone = phoneMatch ? phoneMatch[1].trim() : '';
                    const parsedCid = cidMatch ? cidMatch[1].trim() : '';
                    const parsedEm = emMatch ? emMatch[1].trim() : '';

                    if (parsedName && parsedName.toLowerCase() !== 'guest') plain.customer_name = parsedName;
                    if (parsedPhone) plain.customer_phone = parsedPhone;
                    if (parsedCid) plain.customer_id = parsedCid;
                    if (parsedEm) plain.customer_email = parsedEm;
                }
            }

            resultData.push(plain);
        }

        if (active_only === 'true') {
            resultData = resultData.filter(kot => {
                if (kot.sales_header_id != null) return false;
                const s = (kot.status || '').toLowerCase();
                if (s === 'billed' || s === 'closed' || s === 'cancelled' || s === 'rejected' || s === 'nc cleared' || s === 'nc_cleared') return false;
                return true;
            });
        }

        res.json({ success: true, data: resultData });
    } catch (err: any) {
        res.status(500).json({ success: false, error: err.message });
    }
};

export const getKotDetails = async (req: Request, res: Response) => {
    try {
        const outlet_id = (req as any).user?.outlet_id;
        const { id } = req.params;

        const kot = await (req as any).propertyDb.models.kot_headers.findOne({
            where: { id, outlet_id },
            include: [
                { model: (req as any).propertyDb.models.restaurant_tables, as: 'table', attributes: ['table_name', 'status', 'current_guest_count', 'capacity'], required: false },
                { model: (req as any).propertyDb.models.hr_employees, as: 'waiter', attributes: [['full_name', 'employee_name']], required: false },
                { model: (req as any).propertyDb.models.hr_employees, as: 'captain', attributes: [['full_name', 'employee_name']], required: false },
                {
                    model: (req as any).propertyDb.models.sales_headers,
                    as: 'sales_header',
                    required: false,
                    attributes: ['id', 'sale_no', 'status', 'payment_mode', 'net_amount', 'amount_paid', 'balance_due', 'sub_total', 'total_tax', 'charge_total', 'charge_tax_total']
                },
                {
                    model: (req as any).propertyDb.models.kot_items,
                    as: 'items',
                    required: false,
                    include: [
                        { model: (req as any).propertyDb.models.kitchen_stations, as: 'station', attributes: ['station_name'], required: false },
                        {
                            model: (req as any).propertyDb.models.item_master,
                            as: 'item',
                            attributes: ['id', 'item_code', 'item_name', 'hsn_sac_code', 'barcode', 'unit', 'rate', 'retail_sale_price', 'mrp', 'tax_percent', 'tax_type', 'tax_group_id', 'brand', 'location', 'item_group', 'sub_category', 'is_tax_inclusive'],
                            required: false,
                            include: [
                                {
                                    model: (req as any).propertyDb.models.tax_groups,
                                    as: 'tax_group',
                                    attributes: ['id', 'group_name', 'group_code', 'total_rate', 'is_tax_inclusive'],
                                    required: false,
                                    include: [
                                        {
                                            model: (req as any).propertyDb.models.tax_group_components,
                                            as: 'components',
                                            required: false
                                        }
                                    ]
                                }
                            ]
                        }
                    ]
                },
                { model: (req as any).propertyDb.models.kot_revisions, as: 'revisions' }
            ]
        });

        if (!kot) return res.status(404).json({ success: false, message: 'KOT not found' });
        const plain = kot.get ? kot.get({ plain: true }) : kot;

        if (plain.sales_header) {
            plain.bill_no = plain.sales_header.sale_no;
            plain.total_amount = Number(plain.sales_header.net_amount);
            plain.net_amount = Number(plain.sales_header.net_amount);
            plain.subtotal_amount = Number(plain.sales_header.sub_total);
            plain.tax_amount = Number(plain.sales_header.total_tax);
            plain.payment_mode = plain.sales_header.payment_mode || plain.payment_mode;
            if (plain.sales_header.status === 'COMPLETED' || plain.sales_header.status === 'PAID' || Number(plain.sales_header.balance_due ?? 0) <= 0.01) {
                plain.is_settled = true;
                plain.payment_status = 'PAID';
                plain.status = 'Closed';
            }
        }

        if (!plain.customer_name && plain.remarks) {
            const rem = String(plain.remarks);
            const qrIdx = rem.indexOf('Customer Self-Order (QR):');
            if (qrIdx !== -1) {
                let qrPart = rem.substring(qrIdx + 'Customer Self-Order (QR):'.length);
                const pipeIdx = qrPart.indexOf('|');
                if (pipeIdx !== -1) qrPart = qrPart.substring(0, pipeIdx);

                const cidMatch = qrPart.match(/\[CID:\s*([^\]]*)\]/i);
                const emMatch = qrPart.match(/\[EM:\s*([^\]]*)\]/i);
                const phoneMatch = qrPart.match(/\(([^)]*)\)/);

                let parsedName = qrPart
                    .replace(/\[CID:[^\]]*\]/ig, '')
                    .replace(/\[EM:[^\]]*\]/ig, '')
                    .replace(/\([^)]*\)/g, '')
                    .trim();

                const parsedPhone = phoneMatch ? phoneMatch[1].trim() : '';
                const parsedCid = cidMatch ? cidMatch[1].trim() : '';
                const parsedEm = emMatch ? emMatch[1].trim() : '';

                if (parsedName && parsedName.toLowerCase() !== 'guest') plain.customer_name = parsedName;
                if (parsedPhone) plain.customer_phone = parsedPhone;
                if (parsedCid) plain.customer_id = parsedCid;
                if (parsedEm) plain.customer_email = parsedEm;
            }
        }
        res.json({ success: true, data: plain });
    } catch (err: any) {
        res.status(500).json({ success: false, error: err.message });
    }
};

export const createKot = async (req: Request, res: Response) => {
    const t = await (req as any).propertyDb.transaction();
    try {
        const outlet_id = (req as any).user?.outlet_id;
        const user_id = (req as any).user?.user_id || (req as any).user?.id;
        const { table_id: rawTableId, service_type, kottype, waiter_id, captain_id, remarks, items, client_tag, sub_table } = req.body;

        if (!items || items.length === 0) throw new Error('Cannot create KOT without items');

        let validTableId: number | null = null;
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

        let table: any = null;
        if (validTableId) {
            table = await (req as any).propertyDb.models.restaurant_tables.findOne({
                where: { id: validTableId, outlet_id },
                transaction: t
            });
            if (!table) throw new Error('Table not found');
            await table.update({ status: 'Occupied' }, { transaction: t });

            // Auto-seat ONLY the single reservation closest to current time within the slot window
            try {
                const now = new Date();
                const windowStart = new Date(now.getTime() - 60 * 60 * 1000);
                const windowEnd = new Date(now.getTime() + 60 * 60 * 1000);

                const activeResvs = await (req as any).propertyDb.models.table_reservations.findAll({
                    where: {
                        table_id: validTableId,
                        outlet_id,
                        status: { [Op.in]: ['Pending', 'Confirmed', 'Reserved'] },
                        reservation_time: {
                            [Op.between]: [windowStart, windowEnd]
                        }
                    },
                    transaction: t
                });

                if (activeResvs && activeResvs.length > 0) {
                    activeResvs.sort((a: any, b: any) => {
                        const diffA = Math.abs(new Date(a.reservation_time).getTime() - now.getTime());
                        const diffB = Math.abs(new Date(b.reservation_time).getTime() - now.getTime());
                        return diffA - diffB;
                    });

                    const closest = activeResvs[0];
                    await closest.update({ status: 'Seated' }, { transaction: t });
                    console.log(`[AUTO SEAT RESERVATION] Marked reservation #${closest.id} for table #${validTableId} as Seated`);
                }
            } catch (resvErr: any) {
                console.error('[AUTO SEAT RESERVATION FAIL]', resvErr.message);
            }
        }

        // Generate KOT number using Document Sequence Settings
        let kot_no: string | undefined;
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
        } catch (numErr: any) {
            console.error('[CREATE KOT NUMBERING HELPER ERR]', numErr.message);
        }

        if (!kot_no) {
            const today = new Date();
            const dateStr = `${today.getFullYear()}${String(today.getMonth() + 1).padStart(2, '0')}${String(today.getDate()).padStart(2, '0')}`;
            const count = await (req as any).propertyDb.models.kot_headers.count({
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
        let validWaiterId: any = null;
        if (waiter_id && waiter_id !== 'null' && waiter_id !== 'undefined' && Number(waiter_id) > 0) {
            const waiterExists = await (req as any).propertyDb.models.hr_employees.findOne({
                where: { id: waiter_id, outlet_id },
                transaction: t
            });
            if (waiterExists) validWaiterId = waiter_id;
        }

        let validCaptainId: any = null;
        if (captain_id && captain_id !== 'null' && captain_id !== 'undefined' && Number(captain_id) > 0) {
            const captainExists = await (req as any).propertyDb.models.hr_employees.findOne({
                where: { id: captain_id, outlet_id },
                transaction: t
            });
            if (captainExists) validCaptainId = captain_id;
        }

        const gCount = Number(req.body.guest_count) || Number(req.body.guests) || (table ? (Number(table.current_guest_count) || Number(table.capacity) || 2) : 2);

        // Create KOT Header with status = 'p' (pending) and kottype ('g', 'nc', 'packing')
        const header = await (req as any).propertyDb.models.kot_headers.create({
            outlet_id,
            kot_no,
            table_id: validTableId,
            service_type: service_type || 'Dine In',
            client_tag: client_tag ? String(client_tag).trim() : 'Bill 1',
            sub_table: sub_table ? String(sub_table).trim() : null,
            kottype: determinedKotType,
            status: req.body.status || 'p',
            waiter_id: validWaiterId,
            captain_id: validCaptainId,
            guest_count: gCount,
            remarks,
            revision_no: 1,
            created_time: new Date()
        }, { transaction: t });

        if (table && gCount > 0) {
            await table.update({ current_guest_count: gCount }, { transaction: t });
        }

        // Save Items and assign stations automatically based on item_master location
        const itemsToCreate: any[] = [];
        for (const element of items) {
            const itemDef = await (req as any).propertyDb.models.item_master.findOne({
                where: { id: element.item_id, outlet_id },
                transaction: t
            });

            if (!itemDef) throw new Error(`Item ${element.item_name} not found`);

            let stationId = itemDef.kitchen_station_id;
            if (!stationId) {
                const itemLoc = (itemDef.location || element.location || 'Kitchen').trim();
                const stationMatch = await (req as any).propertyDb.models.kitchen_stations.findOne({
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

        const createdItems = await (req as any).propertyDb.models.kot_items.bulkCreate(itemsToCreate, { transaction: t });

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
    } catch (err: any) {
        await t.rollback();
        res.status(400).json({ success: false, error: err.message });
    }
};

function getItemLocationHelper(item: any) {
    if (!item) return '';
    let loc = (item.station?.station_name ||
        item.item?.location ||
        item.item?.item_location ||
        item.item?.kitchen_location ||
        item.location ||
        '').toString().trim();

    if (!loc) {
        loc = (item.item?.item_group ||
            item.item?.category ||
            item.item_group ||
            item.category ||
            '').toString().trim();
    }
    return loc ? loc.toLowerCase() : 'main kitchen';
}

async function releaseTableIfNoActiveKots(db: any, tableId: number | null, outlet_id: number, transaction?: any) {
    if (!tableId || Number(tableId) <= 0) return;
    try {
        const activeKots = await db.models.kot_headers.findAll({
            where: {
                table_id: tableId,
                outlet_id,
                status: {
                    [Op.notIn]: ['Cancelled', 'cancelled', 'Rejected', 'rejected', 'Billed', 'billed', 'Closed', 'closed', 'NC Cleared', 'nc_cleared', 'NC_CLEARED', 'Settled', 'settled']
                }
            },
            include: [
                {
                    model: db.models.kot_items,
                    as: 'items',
                    required: false
                }
            ],
            transaction
        });

        let hasActiveItems = false;
        for (const k of activeKots) {
            const items = k.items || [];
            const activeItems = items.filter((it: any) => {
                const s = (it.status || '').toLowerCase();
                return s !== 'cancelled' && s !== 'rejected';
            });
            if (activeItems.length > 0) {
                hasActiveItems = true;
                break;
            }
        }

        if (!hasActiveItems) {
            await db.models.restaurant_tables.update(
                {
                    status: 'Available',
                    current_guest_count: 0
                },
                {
                    where: { id: tableId, outlet_id },
                    transaction
                }
            );
            console.log(`[TABLE AUTO-RELEASED] Table #${tableId} marked as Available (0 active orders/KOTs remaining).`);
        }
    } catch (e: any) {
        console.error(`[RELEASE TABLE ERROR] Failed to check/release table #${tableId}:`, e.message);
    }
}

export const updateKotStatus = async (req: Request, res: Response) => {
    try {
        const outlet_id = (req as any).user?.outlet_id;
        const { id } = req.params;
        const { status, kds_dismissed, remarks, location, station_name } = req.body;

        const kot = await (req as any).propertyDb.models.kot_headers.findOne({
            where: { id, outlet_id },
            include: [
                {
                    model: (req as any).propertyDb.models.kot_items,
                    as: 'items',
                    required: false,
                    include: [
                        { model: (req as any).propertyDb.models.kitchen_stations, as: 'station', attributes: ['station_name'], required: false },
                        { model: (req as any).propertyDb.models.item_master, as: 'item', attributes: ['location', 'item_group', 'sub_category', 'brand'], required: false }
                    ]
                }
            ]
        });
        if (!kot) return res.status(404).json({ success: false, message: 'KOT not found' });

        const targetLocation = (location || station_name || '').toString().trim().toLowerCase();

        if (targetLocation && targetLocation !== 'all' && targetLocation !== 'all stations') {
            for (const item of (kot.items || [])) {
                const itemLoc = getItemLocationHelper(item).toLowerCase();
                const matchesLoc = itemLoc === targetLocation ||
                    (itemLoc && targetLocation && (itemLoc.includes(targetLocation) || targetLocation.includes(itemLoc)));
                if (matchesLoc) {
                    await item.update({ status: status });
                }
            }

            const allItems = await (req as any).propertyDb.models.kot_items.findAll({ where: { kot_header_id: id, outlet_id } });
            const activeItems = allItems.filter((it: any) => it.status !== 'Cancelled' && it.status !== 'Rejected' && it.status !== 'cancelled');

            const allServed = activeItems.length > 0 && activeItems.every((it: any) => (it.status || '').toLowerCase() === 'served');
            const allReadyOrServed = activeItems.length > 0 && activeItems.every((it: any) => {
                const s = (it.status || '').toLowerCase();
                return s === 'served' || s === 'ready';
            });
            const anyPreparingOrReady = activeItems.some((it: any) => {
                const s = (it.status || '').toLowerCase();
                return s === 'preparing' || s === 'ready' || s === 'served';
            });

            let newHeaderStatus = kot.status;
            if (activeItems.length === 0) {
                newHeaderStatus = 'Cancelled';
                await kot.update({ status: 'Cancelled' });
                if (kot.table_id) {
                    await releaseTableIfNoActiveKots((req as any).propertyDb, kot.table_id, outlet_id);
                }
            } else if (allServed) {
                newHeaderStatus = 'Served';
                await kot.update({ status: 'Served', served_time: new Date() });
            } else if (allReadyOrServed) {
                newHeaderStatus = 'Ready';
                await kot.update({ status: 'Ready', ready_time: new Date() });
            } else if (anyPreparingOrReady) {
                newHeaderStatus = 'Preparing';
                await kot.update({ status: 'Preparing' });
            } else {
                newHeaderStatus = 'New';
                await kot.update({ status: 'New' });
            }

            return res.json({ success: true, data: { header_status: newHeaderStatus } });
        }

        const updateData: any = { status };
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
            await (req as any).propertyDb.models.kot_items.update(
                { status: 'Preparing' },
                { where: { kot_header_id: id, status: { [Op.in]: ['New', 'new', 'p', 'Pending', 'pending'] }, outlet_id } }
            );
        }
        else if (status === 'Ready') {
            updateData.ready_time = now;
            await (req as any).propertyDb.models.kot_items.update(
                { status: 'Ready' },
                { where: { kot_header_id: id, status: { [Op.in]: ['New', 'new', 'p', 'Pending', 'pending', 'Preparing', 'preparing'] }, outlet_id } }
            );
        }
        else if (status === 'Served') {
            updateData.served_time = now;
            await (req as any).propertyDb.models.kot_items.update(
                { status: 'Served' },
                { where: { kot_header_id: id, status: { [Op.in]: ['New', 'new', 'p', 'Pending', 'pending', 'Preparing', 'preparing', 'Ready', 'ready'] }, outlet_id } }
            );
        }
        else if (status === 'Closed') {
            updateData.closed_time = now;
            updateData.kds_dismissed = true;
            await (req as any).propertyDb.models.kot_items.update(
                { status: 'Served' },
                { where: { kot_header_id: id, status: { [Op.in]: ['New', 'new', 'p', 'Pending', 'pending', 'Preparing', 'preparing', 'Ready', 'ready', 'Served', 'served'] }, outlet_id } }
            );
        }
        else if (status === 'Cancelled' || status === 'cancelled' || status === 'Rejected') {
            await (req as any).propertyDb.models.kot_items.update(
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

        await kot.update(updateData);

        // Auto-release table if KOT is cancelled, rejected, billed, closed or cleared
        if (kot.table_id) {
            await releaseTableIfNoActiveKots((req as any).propertyDb, kot.table_id, outlet_id);
        }

        // Handle House KOT stock deduction upon clearance (status becomes Served or Closed)
        if ((status === 'Served' || status === 'Closed') && kot.service_type === 'House KOT') {
            // Check if stock ledger entry already exists for this KOT to prevent double deduction
            const alreadyDeducted = await (req as any).propertyDb.models.stock_ledger.findOne({
                where: {
                    outlet_id,
                    ref_no: kot.kot_no,
                    txn_type: 'KOT Consumption'
                }
            });

            if (!alreadyDeducted) {
                const kotItems = await (req as any).propertyDb.models.kot_items.findAll({
                    where: {
                        kot_header_id: id,
                        status: { [Op.notIn]: ['Cancelled', 'Rejected'] },
                        outlet_id
                    },
                    include: [
                        {
                            model: (req as any).propertyDb.models.item_master,
                            as: 'item'
                        }
                    ]
                });

                for (const item of kotItems) {
                    if (item.item) {
                        await insertLedger({
                            db: (req as any).propertyDb,
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

        res.json({ success: true, data: kot });
    } catch (err: any) {
        res.status(400).json({ success: false, error: err.message });
    }
};

export const updateKotItemStatus = async (req: Request, res: Response) => {
    const t = await (req as any).propertyDb.transaction();
    try {
        const outlet_id = (req as any).user?.outlet_id;
        const { itemId } = req.params;
        const { status, cancel_reason, qty } = req.body;

        const item = await (req as any).propertyDb.models.kot_items.findOne({
            where: { id: itemId, outlet_id },
            include: [{ model: (req as any).propertyDb.models.kot_headers, as: 'header' }],
            transaction: t
        });

        if (!item) return res.status(404).json({ success: false, message: 'KOT item not found' });

        const updateData: any = {};
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

        // Re-evaluate parent KOT header status based on remaining items
        if (item.kot_header_id) {
            const allItems = await (req as any).propertyDb.models.kot_items.findAll({
                where: { kot_header_id: item.kot_header_id, outlet_id },
                transaction: t
            });
            const activeItems = allItems.filter((it: any) => it.status !== 'Cancelled' && it.status !== 'Rejected' && it.status !== 'cancelled');

            const allServed = activeItems.length > 0 && activeItems.every((it: any) => it.status === 'Served' || it.status === 'served');
            const allReadyOrServed = activeItems.length > 0 && activeItems.every((it: any) => it.status === 'Served' || it.status === 'served' || it.status === 'Ready' || it.status === 'ready');

            if (activeItems.length === 0) {
                await (req as any).propertyDb.models.kot_headers.update(
                    { status: 'Cancelled' },
                    { where: { id: item.kot_header_id, outlet_id }, transaction: t }
                );
                const parentKot = item.header || await (req as any).propertyDb.models.kot_headers.findByPk(item.kot_header_id, { transaction: t });
                if (parentKot && parentKot.table_id) {
                    await releaseTableIfNoActiveKots((req as any).propertyDb, parentKot.table_id, outlet_id, t);
                }
            } else if (allServed) {
                await (req as any).propertyDb.models.kot_headers.update(
                    { status: 'Served', served_time: new Date() },
                    { where: { id: item.kot_header_id, outlet_id }, transaction: t }
                );
            } else if (allReadyOrServed) {
                await (req as any).propertyDb.models.kot_headers.update(
                    { status: 'Ready', ready_time: new Date() },
                    { where: { id: item.kot_header_id, outlet_id }, transaction: t }
                );
            } else {
                await (req as any).propertyDb.models.kot_headers.update(
                    { status: 'Preparing' },
                    { where: { id: item.kot_header_id, outlet_id }, transaction: t }
                );
            }
        }

        // If cancelled/rejected or reduced, write audit log
        if (updateData.status === 'Cancelled' || updateData.status === 'Rejected' || qty !== undefined) {
            const isFullyCancelled = updateData.status === 'Cancelled' || updateData.status === 'Rejected';
            const desc = isFullyCancelled
                ? `Cancelled/Rejected item "${item.item_name}" from KOT ${item.header ? item.header.kot_no : item.kot_header_id}. Reason: ${cancel_reason || 'No reason'}`
                : `Reduced item "${item.item_name}" qty from ${oldQty} to ${qty} in KOT ${item.header ? item.header.kot_no : item.kot_header_id}. Reason: ${cancel_reason || 'No reason'}`;

            await (req as any).propertyDb.models.restaurant_audit_trail.create({
                outlet_id,
                user_id: (req as any).user?.id,
                action_type: isFullyCancelled ? 'ITEM_CANCEL' : 'ITEM_QTY_REDUCE',
                description: desc
            }, { transaction: t });
        }

        await t.commit();
        res.json({ success: true, data: item });
    } catch (err: any) {
        await t.rollback();
        res.status(400).json({ success: false, error: err.message });
    }
};

export const modifyKot = async (req: Request, res: Response) => {
    const t = await (req as any).propertyDb.transaction();
    try {
        const outlet_id = (req as any).user?.outlet_id;
        const { id } = req.params;
        const { items, modification_reason } = req.body; // Full updated list of items

        if (!items || items.length === 0) throw new Error('Modified KOT must contain items');

        const kot = await (req as any).propertyDb.models.kot_headers.findOne({
            where: { id, outlet_id },
            transaction: t
        });
        if (!kot) throw new Error('KOT not found');

        const oldItems = await (req as any).propertyDb.models.kot_items.findAll({
            where: { kot_header_id: id, outlet_id },
            transaction: t
        });

        const nextRevision = Number(kot.revision_no) + 1;
        const changes: { added: any[]; removed: any[]; updated: any[] } = { added: [], removed: [], updated: [] };

        // Process differences to calculate revision details
        for (const oldItem of oldItems) {
            const match = items.find((i: any) => i.item_id === oldItem.item_id);
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
            const exists = oldItems.find((i: any) => i.item_id === newItem.item_id);
            if (!exists) {
                // New item added
                const itemDef = await (req as any).propertyDb.models.item_master.findOne({
                    where: { id: newItem.item_id, outlet_id },
                    transaction: t
                });
                if (!itemDef) throw new Error(`Item ${newItem.item_name} not found`);

                changes.added.push({ item_id: newItem.item_id, item_name: itemDef.item_name, qty: newItem.qty });

                await (req as any).propertyDb.models.kot_items.create({
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
        await (req as any).propertyDb.models.kot_revisions.create({
            kot_header_id: id,
            revision_no: nextRevision,
            change_details: changes,
            modified_by: (req as any).user?.id,
            modification_reason: modification_reason || 'Order update'
        }, { transaction: t });

        // Update Header revision index
        await kot.update({ revision_no: nextRevision, status: 'New' }, { transaction: t });

        await t.commit();
        res.json({ success: true, message: 'KOT modified successfully', revision: nextRevision, changes, kot_no: kot.kot_no });
    } catch (err: any) {
        await t.rollback();
        res.status(400).json({ success: false, error: err.message });
    }
};

export const reprintKot = async (req: Request, res: Response) => {
    try {
        const outlet_id = (req as any).user?.outlet_id;
        const { id } = req.params;

        const kot = await (req as any).propertyDb.models.kot_headers.findOne({
            where: { id, outlet_id }
        });
        if (!kot) return res.status(404).json({ success: false, message: 'KOT not found' });

        // Record audit
        await (req as any).propertyDb.models.restaurant_audit_trail.create({
            outlet_id,
            user_id: (req as any).user?.id,
            action_type: 'KOT_REPRINT',
            description: `Reprinted KOT ${kot.kot_no}`
        });

        res.json({ success: true, message: 'Reprint logged successfully' });
    } catch (err: any) {
        res.status(400).json({ success: false, error: err.message });
    }
};

export default {
    getNextKotNo,
    listKots,
    getKotDetails,
    createKot,
    updateKotStatus,
    updateKotItemStatus,
    modifyKot,
    reprintKot
};

module.exports = {
    getNextKotNo,
    listKots,
    getKotDetails,
    createKot,
    updateKotStatus,
    updateKotItemStatus,
    modifyKot,
    reprintKot
};
