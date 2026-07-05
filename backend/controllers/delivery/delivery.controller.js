const { Op } = require('sequelize');
const bcrypt = require('bcryptjs');
const numberingHelper = require('../inventory/numberingSettingsV2.controller');
const { insertLedger } = require('../../services/stockLedger.service');

// helper to format numbers
const toAmount = (val) => {
    const num = Number(val);
    return Number.isFinite(num) ? num : 0;
};

// Helper to safely extract and resolve outlet_id (string outlet code or integer ID)
const resolveOutletId = async (req) => {
    const rawId = req.user?.outlet_code || req.user?.outlet_id || 
                  req.body?.outlet_code || req.body?.outletcode || req.body?.outlet_id || 
                  req.query?.outlet_code || req.query?.outletcode || req.query?.outlet_id;
    if (!rawId) return null;

    let resolvedId = null;
    if (typeof rawId === 'string' && isNaN(Number(rawId))) {
        const outlet = await req.propertyDb.models.outlets.findOne({
            where: { outlet_code: rawId }
        });
        if (outlet) resolvedId = outlet.id;
    } else {
        const num = Number(rawId);
        if (Number.isInteger(num)) resolvedId = num;
    }

    if (resolvedId) {
        if (!req.user) req.user = {};
        req.user.outlet_id = resolvedId;
    }
    return resolvedId;
};

const resolveOrderBillNo = async (req, order, outlet_id) => {
    if (!order) return null;
    const sale = await req.propertyDb.models.sales_headers.findOne({
        where: {
            outlet_id,
            notes: `Auto-generated from delivery order #${order.id}`,
            is_latest: true
        }
    });
    if (sale) {
        return sale.sale_no;
    }

    if (order.payment_mode === 'EXCHANGE' || (order.notes && order.notes.includes('Exchange order for return'))) {
        const match = order.notes ? order.notes.match(/against bill #([^\s|]+)/) : null;
        if (match && match[1]) {
            return match[1];
        }

        const returnOrderMatch = order.notes ? order.notes.match(/Exchange order for return #(\d+)/) : null;
        if (returnOrderMatch && returnOrderMatch[1]) {
            const originalOrderId = parseInt(returnOrderMatch[1]);
            const origSale = await req.propertyDb.models.sales_headers.findOne({
                where: {
                    outlet_id,
                    notes: `Auto-generated from delivery order #${originalOrderId}`,
                    is_latest: true
                }
            });
            if (origSale) {
                return origSale.sale_no;
            }
        }
    }
    return null;
};

exports.listCatalogProducts = async (req, res) => {
    try {
        const outletId = await resolveOutletId(req);
        if (!outletId) {
            return res.status(400).json({ success: false, message: 'outlet_id is required' });
        }

        const search = req.query.search || '';
        const category = req.query.category || '';
        const page = parseInt(req.query.page) || 1;
        const limit = parseInt(req.query.limit) || 10;
        const offset = (page - 1) * limit;

        // Fetch distinct categories for filters
        const distinctGroups = await req.propertyDb.models.item_master.findAll({
            attributes: [[req.propertyDb.fn('DISTINCT', req.propertyDb.col('item_group')), 'item_group']],
            where: {
                outlet_id: outletId,
                is_active: true,
                is_saleable: true
            },
            raw: true
        });
        const categories = distinctGroups.map(dg => dg.item_group).filter(Boolean);

        // Build conditions
        let queryConditions = `im.outlet_id = :outletId AND im.is_active = true AND im.is_saleable = true`;
        const replacements = { outletId, limit, offset };

        if (search) {
            queryConditions += ` AND (im.item_name ILIKE :search OR im.brand ILIKE :search)`;
            replacements.search = `%${search}%`;
        }

        if (category) {
            queryConditions += ` AND im.item_group = :category`;
            replacements.category = category;
        }

        // Fetch paginated items with latest stock from stock_ledger
        const items = await req.propertyDb.query(`
            SELECT 
                im.*,
                COALESCE(
                    (SELECT sl.balance FROM stock_ledger sl 
                     WHERE sl.outlet_id = im.outlet_id AND sl.item_code = im.item_code 
                     ORDER BY sl.id DESC LIMIT 1),
                    im.opening_balance
                ) AS current_stock
            FROM item_master im
            WHERE ${queryConditions}
            ORDER BY im.item_name ASC
            LIMIT :limit OFFSET :offset
        `, {
            replacements,
            type: req.propertyDb.QueryTypes.SELECT
        });

        // Get total count for pagination calculations
        const totalCountResult = await req.propertyDb.query(`
            SELECT COUNT(*) as count
            FROM item_master im
            WHERE ${queryConditions}
        `, {
            replacements,
            type: req.propertyDb.QueryTypes.SELECT
        });
        const totalCount = parseInt(totalCountResult[0].count);
        const totalPages = Math.ceil(totalCount / limit);

        const hasGstin = !!(req.query.gstin);
        const processedItems = [];
        for (const item of items) {
            const dbItem = await req.propertyDb.models.item_master.findByPk(item.id, {
                include: [
                    {
                        model: req.propertyDb.models.attribute_values,
                        as: 'attribute_values',
                        required: false,
                        include: [
                            {
                                model: req.propertyDb.models.attributes,
                                as: 'attribute',
                                required: false
                            }
                        ]
                    }
                ]
            });
            const itemJson = dbItem ? dbItem.toJSON() : {};
            const mergedItem = {
                ...itemJson,
                current_stock: item.current_stock
            };

            if (hasGstin && Number(mergedItem.b2b_rate) > 0) {
                mergedItem.rate = mergedItem.b2b_rate;
                mergedItem.retail_sale_price = mergedItem.b2b_rate;
            }
            processedItems.push(mergedItem);
        }

        res.json({
            success: true,
            data: processedItems,
            pagination: {
                totalCount,
                totalPages,
                currentPage: page,
                limit
            },
            categories
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.placeOrder = async (req, res) => {
    const t = await req.propertyDb.transaction();
    try {
        const {
            outlet_id,
            customer_name,
            customer_phone,
            customer_address,
            items,
            sub_total,
            tax_amount,
            delivery_charge,
            net_amount,
            payment_status, // PAID (online) or UNPAID (CoD)
            gstin,
            charges,
            coupon_code,
            payment_gateway_details
        } = req.body;

        if (!outlet_id || !customer_name || !customer_phone || !customer_address || !items || items.length === 0) {
            await t.rollback();
            return res.status(400).json({ success: false, message: 'Missing required order fields' });
        }

        // Validate B2B bulk buying restriction: if no GSTIN, max quantity of any item is 5
        if (!gstin) {
            for (const item of items) {
                if (Number(item.qty) > 5) {
                    await t.rollback();
                    return res.status(400).json({ 
                        success: false, 
                        message: `Bulk ordering (> 5 units) is restricted to B2B customers. Please provide a GSTIN to order more than 5 units of ${item.item_name}.` 
                    });
                }
            }
        }

        let actualOutletId;
        if (typeof outlet_id === 'string' && outlet_id.startsWith('OUTLET')) {
            const outlet = await req.propertyDb.models.outlets.findOne({
                where: { outlet_code: outlet_id },
                transaction: t
            });
            if (!outlet) {
                await t.rollback();
                return res.status(400).json({ success: false, message: `Outlet not found for code: ${outlet_id}` });
            }
            actualOutletId = outlet.id;
        } else {
            actualOutletId = Number(outlet_id);
        }

        const systemSettings = await req.propertyDb.models.system_settings.findOne({
            where: { outlet_id: actualOutletId },
            transaction: t
        });
        const allowNegativeStock = systemSettings?.allow_negative_stock ?? false;

        if (!allowNegativeStock) {
            // Aggregate required quantities by item_code
            const requiredQuantities = {};
            
            for (const item of items) {
                const qty = Number(item.qty) || 0;
                requiredQuantities[item.item_code] = (requiredQuantities[item.item_code] || 0) + qty;
                
                // Fetch BOM components for composite items
                const bomComponents = await req.propertyDb.models.item_boms.findAll({
                    where: { outlet_id: actualOutletId, parent_item_id: item.item_id },
                    include: [
                        {
                            model: req.propertyDb.models.item_master,
                            as: 'component_item',
                            where: { is_active: true }
                        }
                    ],
                    transaction: t
                });
                
                if (bomComponents && bomComponents.length > 0) {
                    for (const bomComp of bomComponents) {
                        const compItem = bomComp.component_item;
                        if (!compItem) continue;
                        const qtyRequiredPerUnit = Number(bomComp.quantity) || 0;
                        const totalQtyNeeded = qtyRequiredPerUnit * qty;
                        requiredQuantities[compItem.item_code] = (requiredQuantities[compItem.item_code] || 0) + totalQtyNeeded;
                    }
                }
            }

            // Verify stock for all required item_codes
            for (const itemCode of Object.keys(requiredQuantities)) {
                const needed = requiredQuantities[itemCode];
                if (needed <= 0) continue;

                // Find the item details first
                const itemMaster = await req.propertyDb.models.item_master.findOne({
                    where: { outlet_id: actualOutletId, item_code: itemCode },
                    attributes: ['item_name', 'stockable', 'opening_balance'],
                    transaction: t
                });

                // Skip stock check if the item is not stockable
                if (itemMaster && itemMaster.stockable === false) {
                    continue;
                }

                const lastLedger = await req.propertyDb.models.stock_ledger.findOne({
                    where: { outlet_id: actualOutletId, item_code: itemCode },
                    order: [['id', 'DESC']],
                    transaction: t
                });

                let lastBalance = 0;
                if (lastLedger && lastLedger.balance !== null) {
                    lastBalance = Number(lastLedger.balance);
                } else if (itemMaster && itemMaster.opening_balance !== null) {
                    lastBalance = Number(itemMaster.opening_balance);
                }

                if (needed > lastBalance) {
                    const displayName = itemMaster?.item_name || itemCode;
                    await t.rollback();
                    return res.status(400).json({
                        success: false,
                        message: `Insufficient stock for item ${displayName}. Available: ${lastBalance}`
                    });
                }
            }
        }

        // Fetch settings for commission formula calculation
        const outletSettings = await req.propertyDb.models.outlet_settings.findOne({
            where: { outlet_id: actualOutletId },
            transaction: t
        });
        const meta = outletSettings?.meta_data || {};

        if (coupon_code) {
            const coupons = meta.coupons || [];
            const couponIndex = coupons.findIndex(c => String(c.code).trim().toUpperCase() === String(coupon_code).trim().toUpperCase());
            if (couponIndex !== -1) {
                const coupon = coupons[couponIndex];
                if (coupon.is_active === false) {
                    await t.rollback();
                    return res.status(400).json({ success: false, message: `Coupon code '${coupon_code}' is inactive.` });
                }
                if (coupon.max_uses !== undefined && coupon.max_uses !== null) {
                    const maxUses = parseInt(coupon.max_uses);
                    const usedCount = parseInt(coupon.used_count || 0);
                    if (maxUses > 0 && usedCount >= maxUses) {
                        await t.rollback();
                        return res.status(400).json({ success: false, message: `Coupon code '${coupon_code}' has expired or reached its maximum usage limit.` });
                    }
                }
                coupon.used_count = (parseInt(coupon.used_count || 0)) + 1;
                coupons[couponIndex] = coupon;
                meta.coupons = coupons;
                if (outletSettings) {
                    outletSettings.meta_data = meta;
                    outletSettings.changed('meta_data', true);
                    await outletSettings.save({ transaction: t });
                }
            } else {
                await t.rollback();
                return res.status(400).json({ success: false, message: `Coupon code '${coupon_code}' is invalid.` });
            }
        }
        const commissionType = meta.commission_type || 'FLAT';
        const commissionVal = parseFloat(meta.commission_value ?? 20.00);

        let calculatedCommission = commissionVal;
        if (commissionType === 'PERCENTAGE') {
            calculatedCommission = (toAmount(net_amount) * commissionVal) / 100.0;
        }

        const finalPaymentMode = String(req.body.payment_mode || (payment_status === 'PAID' ? 'UPI' : 'CASH')).trim().toUpperCase();

        let subscriptionAllocationPreview = null;
        try {
            const salesController = require('../sales/sales.controller');
            subscriptionAllocationPreview = await salesController.allocateMilkSubscriptionCoverage({
                req: {
                    ...req,
                    user: {
                        ...(req.user || {}),
                        outlet_id: actualOutletId
                    }
                },
                header: {
                    customer_name,
                    customer_phone,
                    customer_gstin: gstin,
                    sale_date: new Date()
                },
                items: items.map((item) => ({
                    item_id: item.item_id,
                    item_code: item.item_code,
                    item_name: item.item_name,
                    qty: Number(item.qty),
                    rate: Number(item.rate),
                    tax_percent: Number(item.tax_percent || 0),
                    unit: item.unit
                }))
            });
            if (!subscriptionAllocationPreview?.totalCoveredAmount) {
                subscriptionAllocationPreview = null;
            }
        } catch (allocErr) {
            console.warn('[DELIVERY] Subscription allocation preview failed:', allocErr.message);
        }

        const order = await req.propertyDb.models.customer_orders.create({
            outlet_id: actualOutletId,
            customer_name,
            customer_phone,
            customer_address,
            items,
            sub_total: toAmount(sub_total),
            tax_amount: toAmount(tax_amount),
            delivery_charge: toAmount(delivery_charge),
            net_amount: toAmount(net_amount),
            payment_status: payment_status || 'UNPAID',
            payment_mode: finalPaymentMode,
            is_prepaid: (payment_status || '').toUpperCase() === 'PAID',
            status: 'PENDING',
            commission_amount: toAmount(calculatedCommission),
            commission_status: 'UNPAID',
            gstin: gstin || null,
            charges: charges || null,
            subscription_allocation: subscriptionAllocationPreview,
            payment_gateway_details: payment_gateway_details || null
        }, { transaction: t });

        // Retailer notification: new order received
        await req.propertyDb.models.system_notifications.create({
            outlet_id: actualOutletId,
            module: 'DELIVERY',
            title: 'New Customer Order',
            message: `New order #${order.id} received from ${customer_name} (Rs. ${toAmount(net_amount).toFixed(2)})`,
            type: 'SUCCESS',
            entity_id: order.id
        }, { transaction: t });

        // Customer notification: order confirmed
        await req.propertyDb.models.system_notifications.create({
            outlet_id: actualOutletId,
            module: 'CUSTOMER',
            title: 'Order Placed! 🎉',
            message: `Your order #${order.id} (Rs. ${toAmount(net_amount).toFixed(2)}) has been placed and is awaiting confirmation.`,
            type: 'SUCCESS',
            entity_id: order.id
        }, { transaction: t });

        // Record prepaid payment in cash ledger immediately so it shows as income
        if ((payment_status || '').toUpperCase() === 'PAID') {
            const { createLedgerEntry } = require('../../services/cashLedger.service');
            await createLedgerEntry({
                db: req.propertyDb,
                outlet_id: actualOutletId,
                txn_date: new Date(),
                transaction_type: 'SALE_CASH',
                reference_type: 'DELIVERY_ORDER',
                reference_id: order.id,
                reference_no: `ORD-${order.id}`,
                party_name: customer_name,
                payment_method: finalPaymentMode,
                amount_in: toAmount(net_amount),
                notes: `Prepaid online order #${order.id} from ${customer_name}`,
                created_by: null,
                transaction: t
            });
        }

        await t.commit();
        res.status(201).json({ success: true, data: order });
    } catch (error) {
        await t.rollback();
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.trackOrder = async (req, res) => {
    try {
        const order = await req.propertyDb.models.customer_orders.findByPk(req.params.id, {
            include: [{
                model: req.propertyDb.models.delivery_partners,
                as: 'partner',
                attributes: ['id', 'name', 'phone', 'status'],
                bypassOutletFilter: true
            }]
        });

        if (!order) {
            return res.status(404).json({ success: false, message: 'Order not found' });
        }

        const sale = await req.propertyDb.models.sales_headers.findOne({
            where: {
                outlet_id: order.outlet_id,
                notes: `Auto-generated from delivery order #${order.id}`,
                is_deleted: false,
                is_latest: true
            }
        });

        const json = order.toJSON();
        json.sale_id = sale ? sale.id : null;
        json.sale_no = sale ? sale.sale_no : null;
        if (!json.sale_no) {
            json.sale_no = await resolveOrderBillNo(req, json, order.outlet_id);
        }

        res.json({ success: true, data: json });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.listOrders = async (req, res) => {
    try {
        const outlet_id = await resolveOutletId(req);
        if (!outlet_id) {
            return res.status(400).json({ success: false, message: 'outlet_id is required' });
        }
        const { search, fromDate, toDate, today, includePendingReturns } = req.query;

        const dateWhereClause = { outlet_id };

        // 1. Handle "Today Only" or Date Range
        const parseDateLocal = (val) => {
            if (!val) return null;
            const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(val.trim());
            if (match) {
                return new Date(Number(match[1]), Number(match[2]) - 1, Number(match[3]));
            }
            return new Date(val);
        };

        let start, end;
        if (today === 'true') {
            const refDate = fromDate ? parseDateLocal(fromDate) : new Date();
            start = new Date(refDate);
            start.setHours(0, 0, 0, 0);
            end = new Date(refDate);
            end.setHours(23, 59, 59, 999);
        } else {
            if (fromDate) {
                start = parseDateLocal(fromDate);
                start.setHours(0, 0, 0, 0);
            }
            if (toDate) {
                end = parseDateLocal(toDate);
                end.setHours(23, 59, 59, 999);
            }
        }

        if (start || end) {
            const dateFilter = {};
            if (start) dateFilter[Op.gte] = start;
            if (end) dateFilter[Op.lte] = end;
            dateWhereClause[Op.or] = [
                { created_at: dateFilter },
                { status: { [Op.in]: ['PENDING', 'ACCEPTED', 'ASSIGNED', 'OUT_FOR_DELIVERY'] } }
            ];
        }

        // 2. Handle Search (by customer_name, customer_phone, or order ID)
        if (search) {
            const searchOr = [
                { customer_name: { [Op.iLike]: `%${search}%` } },
                { customer_phone: { [Op.iLike]: `%${search}%` } }
            ];
            if (!isNaN(search)) {
                searchOr.push({ id: parseInt(search) });
            }

            if (dateWhereClause[Op.or]) {
                dateWhereClause[Op.and] = [
                    { [Op.or]: dateWhereClause[Op.or] },
                    { [Op.or]: searchOr }
                ];
                delete dateWhereClause[Op.or];
            } else {
                dateWhereClause[Op.or] = searchOr;
            }
        }

        const activeExchangeExclusion = {
            [Op.or]: [
                { payment_mode: { [Op.ne]: 'EXCHANGE' } },
                { status: { [Op.in]: ['DELIVERED', 'CANCELLED'] } }
            ]
        };

        // 3. Build final where: if includePendingReturns=true, merge with OR for pending returns/refunds
        // Exclude replacement exchange orders from active lists as they are processed via the return order workflow
        let whereClause;
        if (includePendingReturns === 'true') {
            whereClause = {
                [Op.or]: [
                    {
                        ...dateWhereClause,
                        ...activeExchangeExclusion
                    },
                    { outlet_id, return_status: 'PENDING' },
                    { outlet_id, refund_status: 'PENDING' }
                ]
            };
        } else {
            whereClause = {
                ...dateWhereClause,
                ...activeExchangeExclusion
            };
        }


        const orders = await req.propertyDb.models.customer_orders.findAll({
            where: whereClause,
            include: [{
                model: req.propertyDb.models.delivery_partners,
                as: 'partner',
                attributes: ['id', 'name', 'phone', 'status'],
                bypassOutletFilter: true
            }],
            order: [['created_at', 'DESC']]
        });

        const orderIds = orders.map(o => o.id);
        const sales = orderIds.length > 0 ? await req.propertyDb.models.sales_headers.findAll({
            where: {
                outlet_id,
                notes: {
                    [Op.or]: orderIds.map(id => `Auto-generated from delivery order #${id}`)
                },
                is_latest: true
            }
        }) : [];

        const saleMap = {};
        for (const sale of sales) {
            const match = String(sale.notes || '').match(/#(\d+)$/);
            if (match) {
                const orderId = parseInt(match[1]);
                saleMap[orderId] = { id: sale.id, sale_no: sale.sale_no };
            }
        }

        const saleIds = sales.map(s => s.id);
        const refunds = saleIds.length > 0 ? await req.propertyDb.models.sales_refunds.findAll({
            where: {
                outlet_id,
                sale_id: saleIds
            }
        }) : [];

        const orderRefundsMap = {};
        for (const refund of refunds) {
            const sale = sales.find(s => s.id === refund.sale_id);
            if (sale) {
                const match = String(sale.notes || '').match(/#(\d+)$/);
                if (match) {
                    const orderId = parseInt(match[1]);
                    orderRefundsMap[orderId] = {
                        payment_mode: refund.payment_mode || 'N/A',
                        amount_paid: parseFloat(refund.amount_paid ?? 0.0),
                        amount_pending: parseFloat(refund.amount_pending ?? 0.0),
                        status: refund.status || 'PENDING',
                        notes: refund.notes || '',
                        refund_date: refund.refund_date
                    };
                }
            }
        }



        const data = await Promise.all(orders.map(async o => {
            const json = o.toJSON();
            const saleInfo = saleMap[o.id];
            json.sale_id = saleInfo ? saleInfo.id : null;
            json.sale_no = saleInfo ? saleInfo.sale_no : null;
            if (!json.sale_no) {
                json.sale_no = await resolveOrderBillNo(req, json, outlet_id);
            }
            json.refund_details = orderRefundsMap[o.id] || null;

            // Check if a subscription discount was actually applied to the order (amount < 0)
            const charges = json.charges || [];
            const hasSubscriptionDiscount = charges.some(c => 
                (c.code === 'SUBSCRIPTION_DISCOUNT' || String(c.name || '').toLowerCase().includes('subscription discount')) &&
                parseFloat(c.amount || 0) < 0
            );

            json.contains_subscription_item = hasSubscriptionDiscount;

            return json;
        }));

        res.json({ success: true, data });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.listRiders = async (req, res) => {
    try {
        const outlet_id = await resolveOutletId(req);
        if (!outlet_id) {
            return res.status(400).json({ success: false, message: 'outlet_id is required' });
        }
        const riders = await req.propertyDb.models.delivery_partners.findAll({
            where: {
                outlet_id,
                status: {
                    [Op.ne]: 'INACTIVE'
                }
            },
            order: [['name', 'ASC']]
        });
        res.json({ success: true, data: riders });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.deleteRider = async (req, res) => {
    try {
        const outlet_id = await resolveOutletId(req);
        if (!outlet_id) {
            return res.status(400).json({ success: false, message: 'outlet_id is required' });
        }
        const { id } = req.params;

        const rider = await req.propertyDb.models.delivery_partners.findOne({
            where: { id, outlet_id }
        });

        if (!rider) {
            return res.status(404).json({ success: false, message: 'Rider not found' });
        }

        const ordersCount = await req.propertyDb.models.customer_orders.count({
            where: { assigned_partner_id: id }
        });

        if (ordersCount > 0) {
            rider.status = 'INACTIVE';
            await rider.save();
            return res.json({ 
                success: true, 
                message: 'Rider has order history, so they have been marked as INACTIVE.',
                action: 'INACTIVATED'
            });
        } else {
            await rider.destroy();
            return res.json({ 
                success: true, 
                message: 'Rider deleted successfully.',
                action: 'DELETED'
            });
        }
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.registerRider = async (req, res) => {
    try {
        const outlet_id = await resolveOutletId(req);
        if (!outlet_id) {
            return res.status(400).json({ success: false, message: 'outlet_id is required' });
        }
        const { name, phone, password } = req.body;
        if (!name || !phone || !password) {
            return res.status(400).json({ success: false, message: 'Name, phone, and password are required' });
        }

        if (password.trim().length < 4) {
            return res.status(400).json({ success: false, message: 'Password must be at least 4 characters' });
        }

        // Check for duplicate phone
        const existing = await req.propertyDb.models.delivery_partners.findOne({
            where: { outlet_id, phone }
        });
        if (existing) {
            return res.status(400).json({ success: false, message: 'A rider with this phone number is already registered.' });
        }

        const createData = {
            outlet_id,
            name,
            phone,
            status: 'AVAILABLE',
            password_hash: bcrypt.hashSync(password.trim(), 10)
        };

        const rider = await req.propertyDb.models.delivery_partners.create(createData);

        // Trigger assignment of pending orders if any
        setTimeout(() => processPendingOrders(req, outlet_id), 100);

        res.status(201).json({ success: true, data: {
            id: rider.id, name: rider.name, phone: rider.phone, status: rider.status
        }});
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.acceptOrder = async (req, res) => {
    const t = await req.propertyDb.transaction();
    try {
        const { id } = req.params;
        const { rider_id, for_edit } = req.body;
        const outlet_id = await resolveOutletId(req);
        if (!outlet_id) {
            await t.rollback();
            return res.status(400).json({ success: false, message: 'outlet_id is required' });
        }
        const userId = req.user?.id || 1;

        const order = await req.propertyDb.models.customer_orders.findOne({
            where: { id, outlet_id },
            transaction: t
        });

        if (!order) {
            await t.rollback();
            return res.status(404).json({ success: false, message: 'Customer order not found' });
        }

        if (order.status !== 'PENDING') {
            await t.rollback();
            return res.status(400).json({ success: false, message: `Order already accepted or processed. Current status: ${order.status}` });
        }

        if (for_edit === true) {
            const charges = order.charges || [];
            const hasSubscriptionDiscount = charges.some(c => 
                (c.code === 'SUBSCRIPTION_DISCOUNT' || String(c.name || '').toLowerCase().includes('subscription discount')) &&
                parseFloat(c.amount || 0) < 0
            );

            if (hasSubscriptionDiscount) {
                await t.rollback();
                return res.status(400).json({ success: false, message: 'Subscription item included' });
            }
        }

        // 1. Resolve official sale invoice number
        const resolved = await numberingHelper.resolveNextNumber({
            req,
            module: 'SALES',
            date: new Date(),
            outlet_id
        });

        if (!resolved || !resolved.number) {
            await t.rollback();
            return res.status(400).json({
                success: false,
                message: 'Sales billing sequence numbering is not configured'
            });
        }

        const saleNo = resolved.number;

        const salesController = require('../sales/sales.controller');
        const normalizeSubscriptionAllocation = (value) => {
            if (!value || typeof value !== 'object') return null;
            const items = Array.isArray(value.items) ? value.items : [];
            const consumptions = Array.isArray(value.consumptions) ? value.consumptions : [];
            const coverages = Array.isArray(value.subscriptionCoverages) ? value.subscriptionCoverages : [];
            const totalCoveredAmount = Number(value.totalCoveredAmount ?? 0) || 0;
            const totalCoveredQty = Number(value.totalCoveredQty ?? 0) || 0;
            return {
                items,
                consumptions,
                totalCoveredAmount,
                totalCoveredQty,
                subscriptionId: Number(value.subscriptionId ?? 0) || 0,
                subscriptionItemId: Number(value.subscriptionItemId ?? 0) || 0,
                subscriptionCoverages: coverages
                    .map((coverage) => ({
                        subscriptionId: Number(coverage?.subscriptionId ?? 0) || 0,
                        subscriptionItemId: Number(coverage?.subscriptionItemId ?? 0) || 0,
                        itemId: Number(coverage?.itemId ?? 0) || 0,
                        totalCoveredQty: Number(coverage?.totalCoveredQty ?? 0) || 0,
                        totalCoveredAmount: Number(coverage?.totalCoveredAmount ?? 0) || 0
                    }))
                    .filter((coverage) => coverage.subscriptionId > 0 || coverage.itemId > 0)
            };
        };

        const storedSubscriptionAllocation = normalizeSubscriptionAllocation(order.subscription_allocation);
        const subscriptionAllocation = storedSubscriptionAllocation && storedSubscriptionAllocation.consumptions.length > 0
            ? storedSubscriptionAllocation
            : await salesController.allocateMilkSubscriptionCoverage({
                req,
                header: {
                    customer_name: order.customer_name,
                    customer_phone: order.customer_phone,
                    customer_gstin: order.gstin,
                    sale_date: new Date()
                },
                items: order.items.map(item => ({
                    item_id: item.item_id,
                    item_code: item.item_code,
                    item_name: item.item_name,
                    qty: Number(item.qty),
                    rate: Number(item.rate),
                    tax_percent: Number(item.tax_percent || 0),
                    unit: item.unit
                })),
                transaction: t,
                pendingOrderContext: {
                    excludeOrderId: order.id,
                    beforeCreatedAt: order.created_at || order.createdAt || new Date()
                }
            });

        const finalItems = subscriptionAllocation.items;
        const derivedSubTotal = finalItems.reduce((sum, item) => sum + (toAmount(item.qty) * toAmount(item.rate)), 0);

        // 3. Local tax calculation helpers
        const taxSummary = new Map();
        const addTaxBreakup = (breakupList) => {
            for (const tax of breakupList) {
                const key = `${tax.code}_${tax.rate}`;
                if (!taxSummary.has(key)) {
                    taxSummary.set(key, {
                        code: tax.code,
                        label: tax.label,
                        taxType: tax.taxType,
                        tax_type: tax.tax_type,
                        rate: tax.rate,
                        taxableAmount: 0,
                        taxable_amount: 0,
                        taxAmount: 0,
                        tax_amount: 0
                    });
                }
                const summary = taxSummary.get(key);
                summary.taxableAmount += tax.taxableAmount;
                summary.taxable_amount += tax.taxable_amount;
                summary.taxAmount += tax.taxAmount;
                summary.tax_amount += tax.tax_amount;
            }
        };

        const calculateTaxesForAmountLocal = (taxMode, taxType, taxPercent, taxableAmount) => {
            if (taxMode === 'NONE' || taxPercent <= 0 || taxableAmount <= 0) {
                return [];
            }
            const taxAmount = taxableAmount * taxPercent / 100;
            const halfRate = taxPercent / 2;
            const halfAmount = taxAmount / 2;
            return [
                {
                    code: 'CGST',
                    label: `CGST ${halfRate % 1 === 0 ? halfRate.toFixed(0) : halfRate.toFixed(2)}%`,
                    taxType: 'GST',
                    tax_type: 'GST',
                    rate: halfRate,
                    taxableAmount,
                    taxable_amount: taxableAmount,
                    taxAmount: halfAmount,
                    tax_amount: halfAmount
                },
                {
                    code: 'SGST',
                    label: `SGST ${halfRate % 1 === 0 ? halfRate.toFixed(0) : halfRate.toFixed(2)}%`,
                    taxType: 'GST',
                    tax_type: 'GST',
                    rate: halfRate,
                    taxableAmount,
                    taxable_amount: taxableAmount,
                    taxAmount: halfAmount,
                    tax_amount: halfAmount
                }
            ];
        };

        // Process charges
        let chargeTaxTotal = 0.0;
        let chargeSubtotal = 0.0;
        if (order.charges && Array.isArray(order.charges)) {
            for (const ch of order.charges) {
                const chTaxPercent = parseFloat(ch.tax_percent || 0.0);
                const chTaxableAmount = parseFloat(ch.taxable_amount || ch.amount || 0.0);
                const chTaxAmount = parseFloat(ch.tax_amount || 0.0);
                chargeSubtotal += chTaxableAmount;
                chargeTaxTotal += chTaxAmount;

                const chBreakup = calculateTaxesForAmountLocal('CGST_SGST', 'GST', chTaxPercent, chTaxableAmount);
                addTaxBreakup(chBreakup);
            }
        }

        // Process items tax breakup
        let itemsTaxTotal = 0.0;
        for (const item of finalItems) {
            const itemQty = toAmount(item.qty);
            const itemRate = toAmount(item.rate);
            const itemAmount = itemQty * itemRate;
            const itemTaxPercent = item._subscription_free ? 0.0 : parseFloat(item.tax_percent || 0.0);
            const itemTaxableAmount = item._subscription_free ? 0.0 : parseFloat(item.taxable_amount || itemAmount || 0.0);
            const itemTaxAmount = item._subscription_free ? 0.0 : parseFloat(item.tax_amount || (itemTaxableAmount * itemTaxPercent / 100) || 0.0);

            itemsTaxTotal += itemTaxAmount;

            const itemBreakup = calculateTaxesForAmountLocal('CGST_SGST', 'GST', itemTaxPercent, itemTaxableAmount);
            addTaxBreakup(itemBreakup);
        }

        const derivedTaxBreakup = Array.from(taxSummary.values())
            .sort((a, b) => a.label.localeCompare(b.label));

        const derivedCgstAmount = derivedTaxBreakup
            .filter((tax) => tax.code === 'CGST')
            .reduce((sum, tax) => sum + tax.taxAmount, 0);

        const derivedSgstAmount = derivedTaxBreakup
            .filter((tax) => tax.code === 'SGST')
            .reduce((sum, tax) => sum + tax.taxAmount, 0);

        const derivedIgstAmount = derivedTaxBreakup
            .filter((tax) => tax.code === 'IGST')
            .reduce((sum, tax) => sum + tax.taxAmount, 0);

        const finalTaxAmount = itemsTaxTotal + chargeTaxTotal;
        const derivedNetAmount = toAmount(derivedSubTotal) + toAmount(finalTaxAmount) + toAmount(chargeSubtotal);

        // 2. Prepare POS Sale parameters
        const isPrepaid = order.payment_status === 'PAID';
        const isCredit = order.payment_mode === 'CREDIT';
        const amountPaid = isPrepaid ? derivedNetAmount : 0;
        const balanceDue = isPrepaid ? 0 : derivedNetAmount;
        const paymentMode = isPrepaid ? 'UPI' : (isCredit ? 'CREDIT' : 'CASH');

        // 3. Create POS sales_headers entry
        const saleHeader = await req.propertyDb.models.sales_headers.create({
            outlet_id,
            sale_no: saleNo,
            sale_date: new Date(),
            customer_name: order.customer_name,
            customer_phone: order.customer_phone,
            customer_address: order.customer_address,
            payment_mode: paymentMode,
            initial_amount_paid: amountPaid,
            amount_paid: amountPaid,
            change_amount: 0,
            balance_due: balanceDue,
            order_type: 'DELIVERY',
            billing_country: 'India',
            billing_tax_mode: 'CGST_SGST',
            bill_format: 'A4',
            tax_percent: 0,
            total_qty: finalItems.reduce((sum, item) => sum + toAmount(item.qty), 0),
            sub_total: derivedSubTotal,
            taxable_amount: toAmount(derivedSubTotal) + toAmount(chargeSubtotal),
            cgst_amount: derivedCgstAmount,
            sgst_amount: derivedSgstAmount,
            igst_amount: derivedIgstAmount,
            tax_breakup: derivedTaxBreakup,
            total_tax: finalTaxAmount,
            charges: order.charges || [],
            charge_total: toAmount(chargeSubtotal),
            charge_tax_total: toAmount(chargeTaxTotal),
            total_discount: subscriptionAllocation.totalCoveredAmount,
            round_off_amount: 0,
            net_amount: derivedNetAmount,
            status: 'COMPLETED',
            created_by: userId,
            is_latest: true,
            is_deleted: false,
            version_no: 1,
            notes: `Auto-generated from delivery order #${order.id}`
        }, { transaction: t });

        // 4. Create POS sales_items entries and deduct stock
        for (const item of finalItems) {
            const itemQty = toAmount(item.qty);
            const itemRate = toAmount(item.rate);
            const itemAmount = itemQty * itemRate;
            const itemTaxPercent = item._subscription_free ? 0.0 : parseFloat(item.tax_percent || 0.0);
            const itemTaxableAmount = item._subscription_free ? 0.0 : parseFloat(item.taxable_amount || itemAmount || 0.0);
            const itemTaxAmount = item._subscription_free ? 0.0 : parseFloat(item.tax_amount || (itemTaxableAmount * itemTaxPercent / 100) || 0.0);
            const itemLineTotal = itemTaxableAmount + itemTaxAmount;
            const itemBreakup = calculateTaxesForAmountLocal('CGST_SGST', 'GST', itemTaxPercent, itemTaxableAmount);

            // Fetch unit from item master if it is not sent in the order items payload
            let resolvedUnit = item.unit;
            if (!resolvedUnit) {
                const itemMaster = await req.propertyDb.models.item_master.findByPk(item.item_id, { transaction: t });
                resolvedUnit = itemMaster?.unit || '';
            }

            await req.propertyDb.models.sales_items.create({
                sale_id: saleHeader.id,
                item_id: item.item_id,
                item_code: item.item_code,
                item_name: item.item_name,
                unit: resolvedUnit || '',
                qty: itemQty,
                rate: itemRate,
                line_discount: 0,
                amount: itemAmount,
                taxable_amount: itemTaxableAmount,
                tax_type: 'GST',
                tax_percent: itemTaxPercent,
                tax_amount: itemTaxAmount,
                line_total: itemLineTotal,
                tax_breakup: itemBreakup,
                net_amount: itemLineTotal
            }, { transaction: t });


            // Deduct the parent item stock
            await insertLedger({
                db: req.propertyDb,
                outlet_id,
                item_code: item.item_code,
                txn_date: new Date(),
                txn_type: 'SALE',
                ref_no: saleNo,
                qty_out: toAmount(item.qty),
                transaction: t,
                allow_negative: !!for_edit
            });

            // If it is a composite item, also deduct components
            const bomComponents = await req.propertyDb.models.item_boms.findAll({
                where: { outlet_id, parent_item_id: item.item_id },
                include: [
                    {
                        model: req.propertyDb.models.item_master,
                        as: 'component_item',
                        where: { is_active: true }
                    }
                ],
                transaction: t
            });

            if (bomComponents && bomComponents.length > 0) {
                for (const bomComp of bomComponents) {
                    const compItem = bomComp.component_item;
                    if (!compItem) continue;
                    const qtyRequiredPerUnit = Number(bomComp.quantity);
                    const totalQtyNeeded = qtyRequiredPerUnit * toAmount(item.qty);

                    await insertLedger({
                        db: req.propertyDb,
                        outlet_id,
                        item_code: compItem.item_code,
                        txn_date: new Date(),
                        txn_type: 'SALE',
                        ref_no: saleNo,
                        qty_out: totalQtyNeeded,
                        transaction: t,
                        allow_negative: !!for_edit
                    });
                }
            }
        }

        // 4.5 Persist milk subscription consumptions if any subscription coverage occurred
        if (subscriptionAllocation.consumptions.length > 0) {
            await salesController.persistMilkSubscriptionConsumptions({
                req,
                transaction: t,
                sale: saleHeader,
                consumptions: subscriptionAllocation.consumptions
            });

            if (subscriptionAllocation.totalCoveredAmount > 0) {
                const coverages = Array.isArray(subscriptionAllocation.subscriptionCoverages)
                    ? subscriptionAllocation.subscriptionCoverages
                    : [{
                        subscriptionId: subscriptionAllocation.subscriptionId,
                        subscriptionItemId: subscriptionAllocation.subscriptionItemId,
                        itemId: null,
                        totalCoveredQty: subscriptionAllocation.totalCoveredQty,
                        totalCoveredAmount: subscriptionAllocation.totalCoveredAmount
                    }];

                for (const coverage of coverages) {
                    const coverageAdvance = await salesController.findSubscriptionItemAdvance(
                        req,
                        coverage.subscriptionId,
                        coverage.itemId || subscriptionAllocation.subscriptionItemId,
                        t
                    );
                    if (coverageAdvance) {
                        await salesController.consumeSubscriptionItemAdvance(
                            req,
                            coverage.subscriptionId,
                            coverage.itemId || subscriptionAllocation.subscriptionItemId,
                            coverage.totalCoveredQty,
                            t
                        );
                    }

                    const subscriptionCashAdvance = await salesController.findSubscriptionCustomerAdvance(
                        req,
                        coverage.subscriptionId,
                        t
                    );
                    let appliedCashAdvanceAmount = 0;
                    if (subscriptionCashAdvance) {
                        appliedCashAdvanceAmount = Math.min(
                            toAmount(subscriptionCashAdvance.available_amount),
                            toAmount(coverage.totalCoveredAmount)
                        );
                        await salesController.consumeSubscriptionCustomerAdvance(
                            req,
                            coverage.subscriptionId,
                            appliedCashAdvanceAmount,
                            t
                        );
                    }

                    if (appliedCashAdvanceAmount > 0) {
                        const { createLedgerEntry } = require('../../services/cashLedger.service');
                        await createLedgerEntry({
                            db: req.propertyDb,
                            outlet_id,
                            txn_date: saleHeader.sale_date || new Date(),
                            transaction_type: 'ADVANCE_APPLY',
                            reference_type: 'SUBSCRIPTION',
                            reference_id: coverage.subscriptionId,
                            reference_no: saleHeader.sale_no,
                            party_name: order.customer_name || order.customer_phone || 'Subscription Customer',
                            payment_method: 'SUBSCRIPTION',
                            amount_out: appliedCashAdvanceAmount,
                            notes: `Advance adjusted for subscription item consumption in delivery order #${order.id}`,
                            created_by: userId,
                            transaction: t
                        });
                    }
                }
            }
        }

        // 5. Try to assign delivery partner automatically or manually
        let assigned = false;
        if (rider_id && rider_id !== 'AUTO' && rider_id !== '') {
            const DeliveryPartner = req.propertyDb.models.delivery_partners;
            const partner = await DeliveryPartner.findOne({
                where: {
                    id: Number(rider_id),
                    outlet_id
                },
                transaction: t
            });
            if (partner) {
                order.assigned_partner_id = partner.id;
                order.status = 'ASSIGNED';
                order.assigned_at = new Date();
                await order.save({ transaction: t });

                partner.status = 'BUSY';
                await partner.save({ transaction: t });

                // Retailer notification
                await req.propertyDb.models.system_notifications.create({
                    outlet_id,
                    module: 'DELIVERY',
                    title: 'Order Assigned',
                    message: `Order #${order.id} for ${order.customer_name} assigned to rider ${partner.name}.`,
                    type: 'INFO',
                    entity_id: order.id
                }, { transaction: t });

                // Rider notification
                await req.propertyDb.models.system_notifications.create({
                    outlet_id,
                    module: 'RIDER',
                    title: 'New Delivery Assigned 🛵',
                    message: `Order #${order.id} for ${order.customer_name} at ${order.delivery_address || 'customer address'} has been assigned to you.`,
                    type: 'INFO',
                    entity_id: partner.id
                }, { transaction: t });

                // Customer notification
                await req.propertyDb.models.system_notifications.create({
                    outlet_id,
                    module: 'CUSTOMER',
                    title: 'Order Confirmed & Rider Assigned ✅',
                    message: `Your order #${order.id} is confirmed. Rider ${partner.name} will deliver it to you.`,
                    type: 'SUCCESS',
                    entity_id: order.id
                }, { transaction: t });

                assigned = true;
            } else {
                await t.rollback();
                return res.status(404).json({ success: false, message: 'Selected rider not found' });
            }
        } else {
            assigned = await autoAssignOrder(req, order, t);
        }

        // Create a cash ledger entry for POS sale only if prepaid
        if (isPrepaid) {
            // Delete the temporary order-placement ledger entry to prevent double-crediting
            await req.propertyDb.models.cash_ledger.destroy({
                where: {
                    outlet_id,
                    reference_type: 'DELIVERY_ORDER',
                    reference_id: order.id
                },
                transaction: t
            });

            const { createLedgerEntry } = require('../../services/cashLedger.service');
            await createLedgerEntry({
                db: req.propertyDb,
                outlet_id,
                txn_date: new Date(),
                transaction_type: 'SALE_CASH',
                reference_type: 'SALE',
                reference_id: saleHeader.id,
                reference_no: saleHeader.sale_no,
                party_name: saleHeader.customer_name || saleHeader.customer_phone || 'Walk-in Customer',
                payment_method: paymentMode,
                amount_in: derivedNetAmount,
                notes: `Prepaid delivery order #${order.id} checkout`,
                created_by: userId,
                transaction: t
            });
        }

        await t.commit();

        res.json({
            success: true,
            message: 'Order accepted, POS sale created, receipt printed, and delivery rider assigned.',
            data: {
                order_id: order.id,
                order_status: order.status,
                assigned_rider_id: order.assigned_partner_id,
                is_assigned: assigned,
                sale_no: saleNo,
                sale_id: saleHeader.id
            }
        });
    } catch (error) {
        await t.rollback();
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.updateOrderDeliveryStatus = async (req, res) => {
    const t = await req.propertyDb.transaction();
    try {
        const { id } = req.params;
        const { status } = req.body; // OUT_FOR_DELIVERY or DELIVERED

        const order = await req.propertyDb.models.customer_orders.findByPk(id, { transaction: t });
        if (!order) {
            await t.rollback();
            return res.status(404).json({ success: false, message: 'Order not found' });
        }

        if (status === 'OUT_FOR_DELIVERY') {
            order.status = 'OUT_FOR_DELIVERY';
            order.picked_up_at = new Date();
            await order.save({ transaction: t });
        } else if (status === 'DELIVERED') {
            order.status = 'DELIVERED';
            order.delivered_at = new Date();

            const paymentModeInput = String(req.body.payment_mode || req.body.paymentMode || order.payment_mode || 'CASH')
                .trim()
                .toUpperCase();
            
            const allowedModes = new Set(['CASH', 'CARD', 'UPI', 'BANK', 'CREDIT']);
            const finalPaymentMode = allowedModes.has(paymentModeInput) ? paymentModeInput : 'CASH';
            order.payment_mode = finalPaymentMode;

            if (finalPaymentMode === 'CREDIT') {
                order.payment_status = 'UNPAID'; // Keep unpaid since it's CREDIT outstanding
            } else {
                order.payment_status = 'PAID'; // Collected payment on delivery (CASH, UPI, etc.)
            }

            await order.save({ transaction: t });

            // Free the rider
            if (order.assigned_partner_id) {
                const rider = await req.propertyDb.models.delivery_partners.findByPk(order.assigned_partner_id, { transaction: t });
                if (rider) {
                    rider.status = 'AVAILABLE';
                    await rider.save({ transaction: t });
                }
            }

            // Find the associated POS sales header
            const sale = await req.propertyDb.models.sales_headers.findOne({
                where: {
                    outlet_id: order.outlet_id,
                    notes: `Auto-generated from delivery order #${order.id}`,
                    is_deleted: false,
                    is_latest: true
                },
                transaction: t
            });

            if (sale) {
                // Update POS sale header
                if (finalPaymentMode === 'CREDIT') {
                    await sale.update({
                        payment_mode: 'CREDIT',
                        amount_paid: 0,
                        balance_due: toAmount(order.net_amount),
                        change_amount: 0
                    }, { transaction: t });
                } else {
                    await sale.update({
                        payment_mode: finalPaymentMode,
                        amount_paid: toAmount(order.net_amount),
                        balance_due: 0,
                        change_amount: 0
                    }, { transaction: t });
                }

                // Delete old ledger entries for all versions of this order's sales (to prevent duplicate entries from modifications)
                const allSales = await req.propertyDb.models.sales_headers.findAll({
                    where: {
                        outlet_id: order.outlet_id,
                        notes: `Auto-generated from delivery order #${order.id}`
                    },
                    transaction: t
                });
                const saleIds = allSales.map(s => s.id);

                if (saleIds.length > 0) {
                    await req.propertyDb.models.cash_ledger.destroy({
                        where: {
                            outlet_id: order.outlet_id,
                            reference_type: 'SALE',
                            reference_id: { [Op.in]: saleIds }
                        },
                        transaction: t
                    });
                }

                if (finalPaymentMode === 'CREDIT') {
                    // Create new SALE_CREDIT ledger entry to record credit sale in the ledger
                    const { createLedgerEntry } = require('../../services/cashLedger.service');
                    await createLedgerEntry({
                        db: req.propertyDb,
                        outlet_id: order.outlet_id,
                        txn_date: new Date(),
                        transaction_type: 'SALE_CREDIT',
                        reference_type: 'SALE',
                        reference_id: sale.id,
                        reference_no: sale.sale_no,
                        party_name: sale.customer_name || sale.customer_phone || 'Walk-in Customer',
                        payment_method: 'CREDIT',
                        amount_in: 0,
                        notes: `Delivery order #${order.id} delivered on Credit. Outstanding: ${toAmount(order.net_amount).toFixed(2)}`,
                        created_by: req.user?.id || 1,
                        transaction: t
                    });
                } else {
                    // Update/Re-create the cash ledger entries to reflect the payment
                    const { createLedgerEntry } = require('../../services/cashLedger.service');

                    // Create new SALE_CASH ledger entry
                    await createLedgerEntry({
                        db: req.propertyDb,
                        outlet_id: order.outlet_id,
                        txn_date: new Date(),
                        transaction_type: 'SALE_CASH',
                        reference_type: 'SALE',
                        reference_id: sale.id,
                        reference_no: sale.sale_no,
                        party_name: sale.customer_name || sale.customer_phone || 'Walk-in Customer',
                        payment_method: finalPaymentMode,
                        amount_in: toAmount(order.net_amount),
                        notes: `Delivery payment collected in ${finalPaymentMode} for order #${order.id}`,
                        created_by: req.user?.id || 1,
                        transaction: t
                    });
                }
            }
        } else {
            await t.rollback();
            return res.status(400).json({ success: false, message: 'Invalid status update. Must be OUT_FOR_DELIVERY or DELIVERED' });
        }

        // Notifications for customer and retailer
        if (status === 'OUT_FOR_DELIVERY') {
            await req.propertyDb.models.system_notifications.create({
                outlet_id: order.outlet_id,
                module: 'CUSTOMER',
                title: 'Your Order is On the Way! 🛵',
                message: `Your order #${order.id} is out for delivery and will arrive soon!`,
                type: 'INFO',
                entity_id: order.id
            }, { transaction: t });
            await req.propertyDb.models.system_notifications.create({
                outlet_id: order.outlet_id,
                module: 'DELIVERY',
                title: 'Order Out for Delivery',
                message: `Order #${order.id} for ${order.customer_name} is out for delivery.`,
                type: 'INFO',
                entity_id: order.id
            }, { transaction: t });
        } else if (status === 'DELIVERED') {
            await req.propertyDb.models.system_notifications.create({
                outlet_id: order.outlet_id,
                module: 'CUSTOMER',
                title: 'Order Delivered! ✅',
                message: `Your order #${order.id} has been delivered. Thank you for shopping with us!`,
                type: 'SUCCESS',
                entity_id: order.id
            }, { transaction: t });
            await req.propertyDb.models.system_notifications.create({
                outlet_id: order.outlet_id,
                module: 'DELIVERY',
                title: 'Order Delivered',
                message: `Order #${order.id} for ${order.customer_name} has been successfully delivered.`,
                type: 'SUCCESS',
                entity_id: order.id
            }, { transaction: t });
        }

        await t.commit();

        // Trigger processing of any other pending orders since rider became available
        if (status === 'DELIVERED') {
            setTimeout(() => processPendingOrders(req, order.outlet_id), 100);
        }

        res.json({ success: true, data: order });
    } catch (error) {
        await t.rollback();
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.updateRiderStatus = async (req, res) => {
    try {
        const { id } = req.body;
        const { status } = req.body; // AVAILABLE or OFFLINE
        if (!id || !status) {
            return res.status(400).json({ success: false, message: 'Rider ID and status are required' });
        }
        const rider = await req.propertyDb.models.delivery_partners.findByPk(id);
        if (!rider) {
            return res.status(404).json({ success: false, message: 'Rider not found' });
        }
        rider.status = status;
        await rider.save();

        if (status === 'AVAILABLE') {
            setTimeout(() => processPendingOrders(req, rider.outlet_id), 100);
        }

        res.json({ success: true, data: rider });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

// Helper: Auto assign order
async function autoAssignOrder(req, order, transaction) {
    const DeliveryPartner = req.propertyDb.models.delivery_partners;
    const partner = await DeliveryPartner.findOne({
        where: {
            outlet_id: order.outlet_id,
            status: 'AVAILABLE'
        },
        transaction
    });

    if (partner) {
        order.assigned_partner_id = partner.id;
        order.status = 'ASSIGNED';
        order.assigned_at = new Date();
        await order.save({ transaction });

        partner.status = 'BUSY';
        await partner.save({ transaction });

        // Retailer notification
        await req.propertyDb.models.system_notifications.create({
            outlet_id: order.outlet_id,
            module: 'DELIVERY',
            title: 'Order Auto-Assigned',
            message: `Order #${order.id} for ${order.customer_name} auto-assigned to rider ${partner.name}.`,
            type: 'INFO',
            entity_id: order.id
        }, { transaction });

        // Rider notification
        await req.propertyDb.models.system_notifications.create({
            outlet_id: order.outlet_id,
            module: 'RIDER',
            title: 'New Delivery Assigned 🛵',
            message: `Order #${order.id} for ${order.customer_name} has been assigned to you. Please pick it up.`,
            type: 'INFO',
            entity_id: partner.id
        }, { transaction });

        // Customer notification
        await req.propertyDb.models.system_notifications.create({
            outlet_id: order.outlet_id,
            module: 'CUSTOMER',
            title: 'Order Confirmed & Rider Assigned ✅',
            message: `Your order #${order.id} is confirmed. Rider ${partner.name} is on the way.`,
            type: 'SUCCESS',
            entity_id: order.id
        }, { transaction });

        return true;
    } else {
        order.status = 'ACCEPTED';
        await order.save({ transaction });
        return false;
    }
}

// Helper: Process pending orders list
async function processPendingOrders(req, outletId) {
    const CustomerOrder = req.propertyDb.models.customer_orders;
    const pendingOrders = await CustomerOrder.findAll({
        where: {
            outlet_id: outletId,
            status: { [Op.in]: ['PENDING', 'ACCEPTED'] }
        },
        order: [['created_at', 'ASC']]
    });

    for (const order of pendingOrders) {
        const t = await req.propertyDb.transaction();
        try {
            const orderLock = await CustomerOrder.findByPk(order.id, { transaction: t });
            if (orderLock.status === 'PENDING' || orderLock.status === 'ACCEPTED') {
                const assigned = await autoAssignOrder(req, orderLock, t);
                if (!assigned) {
                    await t.rollback();
                    break; // No riders available, stop checking subsequent orders
                }
            }
            await t.commit();
        } catch (err) {
            await t.rollback();
            console.error('Error in processPendingOrders transaction:', err);
        }
    }
}

exports.registerCustomer = async (req, res) => {
    const t = await req.propertyDb.transaction();
    try {
        const { outlet_id, name, phone, password, address } = req.body;
        if (!outlet_id || !name || !phone || !password) {
            await t.rollback();
            return res.status(400).json({ success: false, message: 'Missing required registration fields' });
        }

        // Resolve string outlet_id to integer and fetch outlet record for outlet_code
        let actualOutletId;
        let resolvedOutletCode = outlet_id;
        if (typeof outlet_id === 'string' && outlet_id.startsWith('OUTLET')) {
            const outlet = await req.propertyDb.models.outlets.findOne({
                where: { outlet_code: outlet_id },
                transaction: t
            });
            if (!outlet) {
                await t.rollback();
                return res.status(400).json({ success: false, message: `Outlet not found for code: ${outlet_id}` });
            }
            actualOutletId = outlet.id;
            resolvedOutletCode = outlet.outlet_code;
        } else {
            actualOutletId = Number(outlet_id);
            // Fetch outlet_code from integer id
            const outlet = await req.propertyDb.models.outlets.findByPk(actualOutletId, { transaction: t });
            if (outlet) resolvedOutletCode = outlet.outlet_code;
        }

        // Check if customer already exists
        const existing = await req.propertyDb.models.delivery_customers.findOne({
            where: { outlet_id: actualOutletId, phone },
            transaction: t
        });
        if (existing) {
            await t.rollback();
            return res.status(400).json({ success: false, message: 'A customer with this phone number is already registered.' });
        }

        const password_hash = bcrypt.hashSync(password, 10);

        const customer = await req.propertyDb.models.delivery_customers.create({
            outlet_id: actualOutletId,
            name,
            phone,
            password_hash,
            address: address || ''
        }, { transaction: t });

        // Sync customer to sales_headers
        const existingSalesCustomer = await req.propertyDb.models.sales_headers.findOne({
            where: {
                outlet_id: actualOutletId,
                customer_phone: phone,
                status: { [Op.in]: ['COMPLETED', 'CUSTOMER'] },
                is_latest: true,
                is_deleted: false
            },
            transaction: t
        });

        if (existingSalesCustomer) {
            await existingSalesCustomer.update({
                customer_name: name,
                customer_address: address || existingSalesCustomer.customer_address || '',
                status: 'CUSTOMER'
            }, { transaction: t });
        } else {
            await req.propertyDb.models.sales_headers.create({
                outlet_id: actualOutletId,
                sale_no: `CUST-${Date.now()}-${Math.floor(1000 + Math.random() * 9000)}`,
                sale_date: new Date(),
                customer_name: name,
                customer_phone: phone,
                customer_address: address || '',
                status: 'CUSTOMER',
                is_latest: true,
                is_deleted: false,
                payment_mode: 'CASH',
                initial_amount_paid: 0,
                amount_paid: 0,
                change_amount: 0,
                balance_due: 0,
                billing_country: 'India',
                billing_tax_mode: 'CGST_SGST',
                bill_format: 'A4',
                tax_percent: 0,
                total_qty: 0,
                sub_total: 0,
                taxable_amount: 0,
                cgst_amount: 0,
                sgst_amount: 0,
                igst_amount: 0,
                total_tax: 0,
                tax_breakup: [],
                charges: [],
                charge_total: 0,
                charge_tax_total: 0,
                total_discount: 0,
                net_amount: 0,
                version_no: 1
            }, { transaction: t });
        }

        await t.commit();
        res.status(201).json({
            success: true,
            data: {
                id: customer.id,
                name: customer.name,
                phone: customer.phone,
                address: customer.address,
                // Return outlet_id (outlet code string) so the customer app
                // can correctly associate future orders with this outlet
                outlet_id: resolvedOutletCode
            }
        });
    } catch (error) {
        await t.rollback();
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.loginCustomer = async (req, res) => {
    try {
        const { outlet_id, phone, password } = req.body;
        if (!outlet_id || !phone || !password) {
            return res.status(400).json({ success: false, message: 'Phone and password are required' });
        }

        // Resolve string outlet_id to integer and fetch outlet_code
        let actualOutletId;
        let resolvedOutletCode = outlet_id;
        if (typeof outlet_id === 'string' && outlet_id.startsWith('OUTLET')) {
            const outlet = await req.propertyDb.models.outlets.findOne({
                where: { outlet_code: outlet_id }
            });
            if (!outlet) {
                return res.status(400).json({ success: false, message: `Outlet not found for code: ${outlet_id}` });
            }
            actualOutletId = outlet.id;
            resolvedOutletCode = outlet.outlet_code;
        } else {
            actualOutletId = Number(outlet_id);
            // Fetch outlet_code from integer id
            const outlet = await req.propertyDb.models.outlets.findByPk(actualOutletId);
            if (outlet) resolvedOutletCode = outlet.outlet_code;
        }

        const customer = await req.propertyDb.models.delivery_customers.findOne({
            where: { outlet_id: actualOutletId, phone }
        });

        if (!customer || !bcrypt.compareSync(password, customer.password_hash)) {
            return res.status(400).json({ success: false, message: 'Invalid phone number or password.' });
        }

        res.json({
            success: true,
            data: {
                id: customer.id,
                name: customer.name,
                phone: customer.phone,
                address: customer.address,
                // Return outlet_id (outlet code string) so the customer app
                // can correctly associate future orders with the right outlet
                outlet_id: resolvedOutletCode
            }
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.getCustomerHistory = async (req, res) => {
    try {
        const { phone } = req.query;
        if (!phone) {
            return res.status(400).json({ success: false, message: 'Phone query parameter is required' });
        }

        // 1. Fetch customer online orders
        const onlineOrders = await req.propertyDb.models.customer_orders.findAll({
            where: { customer_phone: phone },
            include: [{
                model: req.propertyDb.models.delivery_partners,
                as: 'partner',
                attributes: ['id', 'name', 'phone'],
                bypassOutletFilter: true
            }],
            order: [['created_at', 'DESC']]
        });

        // Fetch all outlet settings in parallel for return settings
        const outletIds = [...new Set(onlineOrders.map(o => o.outlet_id))];
        const outletSettingsList = outletIds.length > 0 ? await req.propertyDb.models.outlet_settings.findAll({
            where: { outlet_id: outletIds }
        }) : [];
        const outletSettingsMap = {};
        for (const os of outletSettingsList) {
            outletSettingsMap[os.outlet_id] = os.meta_data?.default_return_window_days ?? 7;
        }

        // Fetch all item return windows in parallel
        const allItemIds = [];
        for (const order of onlineOrders) {
            const items = order.items || [];
            for (const item of items) {
                if (item.item_id) {
                    allItemIds.push(item.item_id);
                }
            }
        }
        const uniqueItemIds = [...new Set(allItemIds)];
        const itemsList = uniqueItemIds.length > 0 ? await req.propertyDb.models.item_master.findAll({
            where: { id: uniqueItemIds },
            attributes: ['id', 'return_window_days', 'outlet_id']
        }) : [];

        const itemWindowMap = {}; // key: outlet_id + '_' + item_id
        for (const item of itemsList) {
            itemWindowMap[`${item.outlet_id}_${item.id}`] = item.return_window_days;
        }

        // Fetch associate refunds details in bulk
        const onlineOrderIds = onlineOrders.map(o => o.id);
        const associatedSales = onlineOrderIds.length > 0 ? await req.propertyDb.models.sales_headers.findAll({
            where: {
                outlet_id: outletIds,
                notes: {
                    [Op.in]: onlineOrderIds.map(id => `Auto-generated from delivery order #${id}`)
                },
                is_latest: true
            }
        }) : [];

        const orderIdToSaleNoMap = {};
        for (const sale of associatedSales) {
            const match = sale.notes.match(/#(\d+)/);
            if (match) {
                const orderId = parseInt(match[1]);
                orderIdToSaleNoMap[orderId] = sale.sale_no;
            }
        }

        const saleIdToOrderMap = {};
        for (const sale of associatedSales) {
            const match = sale.notes.match(/#(\d+)/);
            if (match) {
                const orderId = parseInt(match[1]);
                saleIdToOrderMap[sale.id] = orderId;
            }
        }

        const saleIds = associatedSales.map(s => s.id);
        const refunds = saleIds.length > 0 ? await req.propertyDb.models.sales_refunds.findAll({
            where: {
                outlet_id: outletIds,
                sale_id: saleIds
            }
        }) : [];

        const orderRefundsMap = {};
        for (const refund of refunds) {
            const orderId = saleIdToOrderMap[refund.sale_id];
            if (orderId) {
                orderRefundsMap[orderId] = {
                    payment_mode: refund.payment_mode || 'N/A',
                    amount_paid: parseFloat(refund.amount_paid ?? 0.0),
                    amount_pending: parseFloat(refund.amount_pending ?? 0.0),
                    status: refund.status || 'PENDING',
                    notes: refund.notes || '',
                    refund_date: refund.refund_date
                };
            }
        }

        // Now map onlineOrders to plain objects and append return eligibility info
        const enrichedOrders = onlineOrders.map(order => {
            const orderJson = order.toJSON();
            const outletId = order.outlet_id;
            const globalWindow = outletSettingsMap[outletId] ?? 7;

            // Find the minimum return window for items in this order
            let minWindow = globalWindow;
            const items = orderJson.items || [];
            for (const item of items) {
                if (item.item_id) {
                    const itemWindow = itemWindowMap[`${outletId}_${item.item_id}`];
                    const w = itemWindow != null ? itemWindow : globalWindow;
                    if (w < minWindow) {
                        minWindow = w;
                    }
                }
            }

            // Check if return window is expired
            let returnEligible = false;
            let daysRemaining = 0;
            const isExchangeOrder = order.payment_mode === 'EXCHANGE' || (order.notes && order.notes.includes('Exchange order for return'));
            if (order.status === 'DELIVERED' && !isExchangeOrder) {
                const deliveredAt = order.delivered_at || order.updated_at;
                if (deliveredAt) {
                    const msElapsed = Date.now() - new Date(deliveredAt).getTime();
                    const daysElapsed = msElapsed / (1000 * 60 * 60 * 24);
                    daysRemaining = minWindow - daysElapsed;
                    returnEligible = daysRemaining >= 0;
                }
            }

            orderJson.return_eligible = returnEligible;
            orderJson.return_window_days = minWindow;
            orderJson.return_days_remaining = daysRemaining;
            orderJson.refund_details = orderRefundsMap[orderJson.id] || null;
            orderJson.bill_no = orderIdToSaleNoMap[orderJson.id] || null;
            return orderJson;
        });

        // 2. Fetch customer in-store POS sales invoices
        const inStoreSales = await req.propertyDb.models.sales_headers.findAll({
            where: { customer_phone: phone, is_deleted: false, is_latest: true },
            include: [{
                model: req.propertyDb.models.sales_items,
                as: 'items'
            }],
            order: [['sale_date', 'DESC']]
        });

        const inStoreSaleIds = inStoreSales.map(s => s.id);
        const inStoreRefunds = inStoreSaleIds.length > 0 ? await req.propertyDb.models.sales_refunds.findAll({
            where: {
                sale_id: inStoreSaleIds
            }
        }) : [];

        const inStoreRefundsMap = {};
        for (const refund of inStoreRefunds) {
            if (!inStoreRefundsMap[refund.sale_id]) {
                inStoreRefundsMap[refund.sale_id] = [];
            }
            inStoreRefundsMap[refund.sale_id].push(refund);
        }

        const enrichedInStoreSales = inStoreSales.map(sale => {
            const saleJson = sale.toJSON();
            const refunds = inStoreRefundsMap[sale.id] || [];
            let totalRefundPaid = 0;
            let hasPending = false;
            let hasPaid = false;
            refunds.forEach(r => {
                totalRefundPaid += Number(r.amount_paid || 0);
                if (r.status === 'PAID') hasPaid = true;
                if (r.status === 'PENDING') hasPending = true;
            });

            if (refunds.length > 0) {
                saleJson.refund_amount = totalRefundPaid;
                if (hasPaid && hasPending) {
                    saleJson.refund_status = 'PARTIALLY_REFUNDED';
                } else if (hasPaid) {
                    saleJson.refund_status = 'REFUNDED';
                } else if (hasPending) {
                    saleJson.refund_status = 'PENDING';
                }
                const paidRefunds = refunds.filter(r => r.status === 'PAID');
                if (paidRefunds.length > 0) {
                    paidRefunds.sort((a, b) => new Date(b.updated_at || b.refund_date) - new Date(a.updated_at || a.refund_date));
                    saleJson.refund_payment_mode = paidRefunds[0].payment_mode;
                    saleJson.refund_paid_at = paidRefunds[0].updated_at || paidRefunds[0].refund_date;
                }
            }
            return saleJson;
        });

        res.json({
            success: true,
            data: {
                onlineOrders: enrichedOrders,
                inStoreSales: enrichedInStoreSales
            }
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.payRiderCommission = async (req, res) => {
    const t = await req.propertyDb.transaction();
    try {
        const { id } = req.params; // rider_id
        const outlet_id = await resolveOutletId(req);
        if (!outlet_id) {
            await t.rollback();
            return res.status(400).json({ success: false, message: 'outlet_id is required' });
        }
        const userId = req.user?.id || 1;

        // Find the rider
        const rider = await req.propertyDb.models.delivery_partners.findOne({
            where: { id, outlet_id },
            transaction: t
        });

        if (!rider) {
            await t.rollback();
            return res.status(404).json({ success: false, message: 'Rider not found' });
        }

        // Find all delivered orders assigned to this rider with unpaid commissions
        const orders = await req.propertyDb.models.customer_orders.findAll({
            where: {
                assigned_partner_id: id,
                outlet_id,
                status: 'DELIVERED',
                commission_status: 'UNPAID'
            },
            transaction: t
        });

        if (orders.length === 0) {
            await t.rollback();
            return res.status(400).json({ success: false, message: 'No unpaid commissions found for this rider.' });
        }

        const totalCommission = orders.reduce((sum, order) => sum + toAmount(order.commission_amount), 0);

        // Update all orders' commission status to PAID
        await req.propertyDb.models.customer_orders.update({
            commission_status: 'PAID'
        }, {
            where: {
                id: { [Op.in]: orders.map(o => o.id) }
            },
            transaction: t
        });

        const paymentMethodInput = String(req.body.payment_method || req.body.paymentMethod || 'CASH')
            .trim()
            .toUpperCase();
        
        const allowedMethods = new Set(['CASH', 'CARD', 'UPI', 'BANK']);
        const paymentMethod = allowedMethods.has(paymentMethodInput) ? paymentMethodInput : 'CASH';

        // Create a cash ledger debit entry for the retailer
        const { createLedgerEntry } = require('../../services/cashLedger.service');
        await createLedgerEntry({
            db: req.propertyDb,
            outlet_id,
            txn_date: new Date(),
            transaction_type: 'EXPENSE',
            reference_type: 'RIDER_COMMISSION',
            reference_id: rider.id,
            party_name: rider.name,
            payment_method: paymentMethod,
            amount_out: totalCommission,
            notes: `Commission paid to rider: ${rider.name} for ${orders.length} deliveries.`,
            created_by: userId,
            transaction: t
        });

        await t.commit();

        res.json({
            success: true,
            message: `Paid Rs. ${totalCommission.toFixed(2)} commission for ${orders.length} deliveries. Debited from ledger.`,
            data: {
                rider_id: rider.id,
                amount_paid: totalCommission,
                deliveries_paid: orders.length
            }
        });
    } catch (error) {
        await t.rollback();
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.cancelOrder = async (req, res) => {
    const t = await req.propertyDb.transaction();
    try {
        const { id } = req.params;
        const outlet_id = await resolveOutletId(req);
        if (!outlet_id) {
            await t.rollback();
            return res.status(400).json({ success: false, message: 'outlet_id is required' });
        }

        const order = await req.propertyDb.models.customer_orders.findOne({
            where: { id, outlet_id },
            transaction: t
        });

        if (!order) {
            await t.rollback();
            return res.status(404).json({ success: false, message: 'Order not found' });
        }

        if (order.status === 'CANCELLED' || order.status === 'DELIVERED') {
            await t.rollback();
            return res.status(400).json({ success: false, message: `Cannot cancel order in status: ${order.status}` });
        }

        const { reason, refund_now } = req.body;

        const isPrepaid = order.payment_status === 'PAID';
        const oldStatus = order.status;
        order.status = 'CANCELLED';
        order.cancellation_reason = reason || 'Retailer cancelled';

        let isGatewayRefunded = false;
        let gatewayTxnId = null;

        // Handle refund_status for prepaid orders
        if (isPrepaid) {
            if (order.payment_gateway_details) {
                try {
                    const details = typeof order.payment_gateway_details === 'string'
                        ? JSON.parse(order.payment_gateway_details)
                        : JSON.parse(JSON.stringify(order.payment_gateway_details || {}));
                    
                    // Accept both 'txn_id' (Flutter customer app key) and legacy 'transaction_id'
                    if (details && (details.txn_id || details.transaction_id)) {
                        gatewayTxnId = details.txn_id || details.transaction_id;
                        const refundTxnId = 'REF_' + Math.random().toString(36).substr(2, 9).toUpperCase();
                        
                        // Set top level values for UI queries
                        details.refund_txn_id = refundTxnId;
                        details.status = 'REFUNDED';
                        details.refunded_at = new Date().toISOString();
                        details.refund_reason = reason || 'Order cancelled by Retailer';
                        details.refund_amount = Number(order.net_amount);

                        details.refunds = details.refunds || [];
                        details.refunds.push({
                            refund_transaction_id: refundTxnId,
                            amount: Number(order.net_amount),
                            reason: reason || 'Order cancelled by Retailer',
                            refunded_at: new Date().toISOString(),
                            status: 'SUCCESS'
                        });
                        
                        order.payment_gateway_details = details;
                        order.changed('payment_gateway_details', true);
                        order.refund_status = 'REFUNDED';
                        order.refund_payment_mode = 'GATEWAY';
                        order.refund_paid_at = new Date();
                        isGatewayRefunded = true;
                    }
                } catch (err) {
                    console.error("Auto gateway refund failed during cancelOrder: ", err);
                }
            }
            
            if (!isGatewayRefunded) {
                if (refund_now === true) {
                    order.refund_status = 'REFUNDED';
                    order.refund_payment_mode = order.payment_mode || 'UPI';
                    order.refund_paid_at = new Date();
                } else {
                    order.refund_status = 'PENDING';
                }
            }
        }

        await order.save({ transaction: t });

        // Free the rider if assigned
        if (order.assigned_partner_id) {
            const rider = await req.propertyDb.models.delivery_partners.findByPk(order.assigned_partner_id, { transaction: t });
            if (rider) {
                rider.status = 'AVAILABLE';
                await rider.save({ transaction: t });
            }
        }

        // Find the associated POS sales header
        const sale = await req.propertyDb.models.sales_headers.findOne({
            where: {
                outlet_id,
                notes: `Auto-generated from delivery order #${order.id}`,
                is_deleted: false,
                is_latest: true
            },
            transaction: t
        });

        if (sale) {
            // Mark sale as deleted
            sale.is_deleted = true;
            await sale.save({ transaction: t });

            // Delete cash ledger SALE entries associated with all versions of this order's sales
            // Only delete if NOT prepaid, since for prepaid orders we want to keep the credit entry
            if (!isPrepaid) {
                const allSales = await req.propertyDb.models.sales_headers.findAll({
                    where: {
                        outlet_id,
                        notes: `Auto-generated from delivery order #${order.id}`
                    },
                    transaction: t
                });
                const saleIds = allSales.map(s => s.id);

                if (saleIds.length > 0) {
                    await req.propertyDb.models.cash_ledger.destroy({
                        where: {
                            outlet_id,
                            reference_type: 'SALE',
                            reference_id: { [Op.in]: saleIds }
                        },
                        transaction: t
                    });
                }
            }

            // Restore stock if the order had been accepted (which is when we deduct stock)
            if (oldStatus !== 'PENDING') {
                for (const item of order.items) {
                    // Re-add parent item stock
                    await insertLedger({
                        db: req.propertyDb,
                        outlet_id,
                        item_code: item.item_code,
                        txn_date: new Date(),
                        txn_type: 'SALE_RETURN',
                        ref_no: sale.sale_no,
                        qty_in: toAmount(item.qty),
                        transaction: t
                    });

                    // Restore composite components if any
                    const bomComponents = await req.propertyDb.models.item_boms.findAll({
                        where: { outlet_id, parent_item_id: item.item_id },
                        include: [
                            {
                                model: req.propertyDb.models.item_master,
                                as: 'component_item',
                                where: { is_active: true }
                            }
                        ],
                        transaction: t
                    });

                    if (bomComponents && bomComponents.length > 0) {
                        for (const bomComp of bomComponents) {
                            const compItem = bomComp.component_item;
                            if (!compItem) continue;
                            const qtyRequiredPerUnit = Number(bomComp.quantity);
                            const totalQtyNeeded = qtyRequiredPerUnit * toAmount(item.qty);

                            await insertLedger({
                                db: req.propertyDb,
                                outlet_id,
                                item_code: compItem.item_code,
                                txn_date: new Date(),
                                txn_type: 'SALE_RETURN',
                                ref_no: sale.sale_no,
                                qty_in: totalQtyNeeded,
                                transaction: t
                            });
                        }
                    }
                }
            }
        }

        // For prepaid orders cancelled by supplier: if refund_now=true or isGatewayRefunded, add a debit entry to record the refund payout
        if (isPrepaid && (refund_now === true || isGatewayRefunded)) {
            // Immediate refund: debit ledger to record money returned to customer
            const { createLedgerEntry } = require('../../services/cashLedger.service');
            await createLedgerEntry({
                db: req.propertyDb,
                outlet_id,
                txn_date: new Date(),
                transaction_type: 'REFUND',
                reference_type: 'DELIVERY_ORDER',
                reference_id: order.id,
                reference_no: `ORD-${order.id}`,
                party_name: order.customer_name,
                payment_method: isGatewayRefunded ? 'GATEWAY' : (order.payment_mode || 'UPI'),
                amount_out: toAmount(order.net_amount),
                notes: isGatewayRefunded
                    ? `Gateway Auto-Refund for cancelled prepaid order #${order.id} (Txn: ${gatewayTxnId})`
                    : `Refund for cancelled prepaid order #${order.id} to ${order.customer_name}`,
                created_by: req.user?.id || null,
                transaction: t
            });
        }

        await t.commit();
        
        // Trigger assignment of other pending orders since rider might have become available
        if (order.assigned_partner_id) {
            // We need to import the processPendingOrders if it is not in scope
            // Note: it is defined as a helper in this file
            setTimeout(() => {
                try {
                    processPendingOrders(req, outlet_id);
                } catch (e) {
                    console.error("Error processing pending orders on cancel:", e.message);
                }
            }, 100);
        }

        res.json({ success: true, message: 'Order successfully cancelled, rider released, sale voided and stock restored.' });
    } catch (error) {
        await t.rollback();
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.cancelOrderAsCustomer = async (req, res) => {
    const t = await req.propertyDb.transaction();
    try {
        const { id } = req.params;

        const order = await req.propertyDb.models.customer_orders.findOne({
            where: { id },
            transaction: t
        });

        if (!order) {
            await t.rollback();
            return res.status(404).json({ success: false, message: 'Order not found' });
        }

        if (order.status !== 'PENDING' && order.status !== 'ACCEPTED') {
            await t.rollback();
            return res.status(400).json({ success: false, message: `Cannot cancel order in status: ${order.status}` });
        }

        const { reason } = req.body;

        const outlet_id = order.outlet_id;
        const oldStatus = order.status;
        order.status = 'CANCELLED';
        order.cancellation_reason = reason || 'Customer cancelled';
        await order.save({ transaction: t });

        if (order.assigned_partner_id) {
            const rider = await req.propertyDb.models.delivery_partners.findByPk(order.assigned_partner_id, { transaction: t });
            if (rider) {
                rider.status = 'AVAILABLE';
                await rider.save({ transaction: t });
            }
        }

        const sale = await req.propertyDb.models.sales_headers.findOne({
            where: {
                outlet_id,
                notes: `Auto-generated from delivery order #${order.id}`,
                is_deleted: false,
                is_latest: true
            },
            transaction: t
        });

        if (sale) {
            sale.is_deleted = true;
            await sale.save({ transaction: t });

            // Delete cash ledger SALE entries associated with all versions of this order's sales
            // Only delete if NOT prepaid, since for prepaid orders we want to keep the credit entry
            if (order.payment_status !== 'PAID') {
                const allSales = await req.propertyDb.models.sales_headers.findAll({
                    where: {
                        outlet_id,
                        notes: `Auto-generated from delivery order #${order.id}`
                    },
                    transaction: t
                });
                const saleIds = allSales.map(s => s.id);

                if (saleIds.length > 0) {
                    await req.propertyDb.models.cash_ledger.destroy({
                        where: {
                            outlet_id,
                            reference_type: 'SALE',
                            reference_id: { [Op.in]: saleIds }
                        },
                        transaction: t
                    });
                }
            }

            if (oldStatus !== 'PENDING') {
                for (const item of order.items) {
                    await insertLedger({
                        db: req.propertyDb,
                        outlet_id,
                        item_code: item.item_code,
                        txn_date: new Date(),
                        txn_type: 'SALE_RETURN',
                        ref_no: sale.sale_no,
                        qty_in: toAmount(item.qty),
                        transaction: t
                    });

                    const bomComponents = await req.propertyDb.models.item_boms.findAll({
                        where: { outlet_id, parent_item_id: item.item_id },
                        include: [
                            {
                                model: req.propertyDb.models.item_master,
                                as: 'component_item',
                                where: { is_active: true }
                            }
                        ],
                        transaction: t
                    });

                    if (bomComponents && bomComponents.length > 0) {
                        for (const bomComp of bomComponents) {
                            const compItem = bomComp.component_item;
                            if (!compItem) continue;
                            const qtyRequiredPerUnit = Number(bomComp.quantity);
                            const totalQtyNeeded = qtyRequiredPerUnit * toAmount(item.qty);

                            await insertLedger({
                                db: req.propertyDb,
                                outlet_id,
                                item_code: compItem.item_code,
                                txn_date: new Date(),
                                txn_type: 'SALE_RETURN',
                                ref_no: sale.sale_no,
                                qty_in: totalQtyNeeded,
                                transaction: t
                            });
                        }
                    }
                }
            }
        }

        // For prepaid orders cancelled by customer: auto-add a refund debit entry (no retailer action needed)
        if (order.payment_status === 'PAID') {
            let isGatewayRefunded = false;
            let gatewayTxnId = null;

            if (order.payment_gateway_details) {
                try {
                    const details = typeof order.payment_gateway_details === 'string'
                        ? JSON.parse(order.payment_gateway_details)
                        : JSON.parse(JSON.stringify(order.payment_gateway_details || {}));
                    
                    // Accept both 'txn_id' (Flutter customer app key) and legacy 'transaction_id'
                    if (details && (details.txn_id || details.transaction_id)) {
                        gatewayTxnId = details.txn_id || details.transaction_id;
                        const refundTxnId = 'REF_' + Math.random().toString(36).substr(2, 9).toUpperCase();
                        
                        // Set top level values for UI queries
                        details.refund_txn_id = refundTxnId;
                        details.status = 'REFUNDED';
                        details.refunded_at = new Date().toISOString();
                        details.refund_reason = reason || 'Order cancelled by Customer';
                        details.refund_amount = Number(order.net_amount);

                        details.refunds = details.refunds || [];
                        details.refunds.push({
                            refund_transaction_id: refundTxnId,
                            amount: Number(order.net_amount),
                            reason: reason || 'Order cancelled by Customer',
                            refunded_at: new Date().toISOString(),
                            status: 'SUCCESS'
                        });
                        
                        order.payment_gateway_details = details;
                        order.changed('payment_gateway_details', true);
                        order.refund_status = 'REFUNDED';
                        order.refund_payment_mode = 'GATEWAY';
                        order.refund_paid_at = new Date();
                        isGatewayRefunded = true;
                    }
                } catch (err) {
                    console.error("Auto gateway refund failed during cancelOrderAsCustomer: ", err);
                }
            }

            if (!isGatewayRefunded) {
                order.refund_status = 'REFUNDED';
                order.refund_payment_mode = order.payment_mode || 'UPI';
                order.refund_paid_at = new Date();
            }
            await order.save({ transaction: t });

            // Record refund debit in ledger
            const { createLedgerEntry } = require('../../services/cashLedger.service');
            await createLedgerEntry({
                db: req.propertyDb,
                outlet_id,
                txn_date: new Date(),
                transaction_type: 'REFUND',
                reference_type: 'DELIVERY_ORDER',
                reference_id: order.id,
                reference_no: `ORD-${order.id}`,
                party_name: order.customer_name,
                payment_method: isGatewayRefunded ? 'GATEWAY' : (order.payment_mode || 'UPI'),
                amount_out: toAmount(order.net_amount),
                notes: isGatewayRefunded 
                    ? `Gateway Auto-Refund for customer-cancelled prepaid order #${order.id} (Txn: ${gatewayTxnId})`
                    : `Auto-refund for customer-cancelled prepaid order #${order.id} to ${order.customer_name}`,
                created_by: null,
                transaction: t
            });
        }

        await t.commit();

        if (order.assigned_partner_id) {
            setTimeout(() => {
                try {
                    processPendingOrders(req, outlet_id);
                } catch (e) {
                    console.error("Error processing pending orders on cancel:", e.message);
                }
            }, 100);
        }

        res.json({ success: true, message: 'Order successfully cancelled.' });
    } catch (error) {
        await t.rollback();
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.requestOrderReturn = async (req, res) => {
    try {
        const { id } = req.params;
        const { return_type, return_item_id, return_item_name, returned_items } = req.body; // 'REFUND' or 'EXCHANGE'
        let outlet_id = await resolveOutletId(req);

        let order;
        if (!outlet_id) {
            order = await req.propertyDb.models.customer_orders.findOne({
                where: { id }
            });
            if (order) {
                outlet_id = order.outlet_id;
            }
        } else {
            order = await req.propertyDb.models.customer_orders.findOne({
                where: { id, outlet_id }
            });
        }

        if (!outlet_id) {
            return res.status(400).json({ success: false, message: 'outlet_id is required' });
        }

        if (!order) {
            return res.status(404).json({ success: false, message: 'Order not found' });
        }

        if (order.return_status) {
            return res.status(400).json({ success: false, message: 'A return or exchange request has already been processed or submitted for this order.' });
        }

        if (order.payment_mode === 'EXCHANGE' || (order.notes && order.notes.includes('Exchange order for return'))) {
            return res.status(400).json({ success: false, message: 'This order was received as an exchange. Return or exchange is allowed only once.' });
        }

        if (order.status !== 'DELIVERED') {
            return res.status(400).json({ success: false, message: 'Only delivered orders can be returned' });
        }

        // --- Return window validation ---
        // Get per-item return_window_days; use lowest window among returned items
        const itemsToCheck = returned_items && Array.isArray(returned_items) && returned_items.length > 0
            ? returned_items
            : (return_item_id ? [{ item_id: return_item_id }] : order.items || []);

        // Fetch global default return window from outlet_settings
        const outletSettings = await req.propertyDb.models.outlet_settings.findOne({
            where: { outlet_id }
        }).catch(() => null);
        const globalWindow = outletSettings?.meta_data?.default_return_window_days ?? 7;

        // Find the minimum return window among all returned items
        let minReturnWindow = globalWindow;
        if (itemsToCheck.length > 0) {
            const itemIds = itemsToCheck.map(it => it.item_id).filter(Boolean);
            if (itemIds.length > 0) {
                const itemRecords = await req.propertyDb.models.item_master.findAll({
                    where: { id: itemIds, outlet_id },
                    attributes: ['id', 'return_window_days']
                });
                for (const rec of itemRecords) {
                    const w = rec.return_window_days != null ? rec.return_window_days : globalWindow;
                    if (w < minReturnWindow) minReturnWindow = w;
                }
            }
        }

        // Check if delivery was within the return window
        const deliveredAt = order.delivered_at || order.updated_at;
        if (deliveredAt) {
            const msElapsed = Date.now() - new Date(deliveredAt).getTime();
            const daysElapsed = msElapsed / (1000 * 60 * 60 * 24);
            if (daysElapsed > minReturnWindow) {
                return res.status(400).json({
                    success: false,
                    message: `Return window of ${minReturnWindow} day(s) has expired. Delivered ${Math.floor(daysElapsed)} day(s) ago.`
                });
            }
        }

        order.return_status = 'PENDING';
        order.return_type = return_type || 'REFUND';
        order.return_item_id = return_item_id || null;
        order.return_item_name = return_item_name || null;
        order.returned_items = returned_items || null;
        if (return_type === 'REFUND') {
            order.refund_status = 'PENDING';
        } else {
            order.refund_status = null;
        }

        await order.save();
        res.json({ success: true, message: 'Return request submitted successfully.', data: order });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.acceptOrderReturn = async (req, res) => {
    const t = await req.propertyDb.transaction();
    try {
        const { id } = req.params;
        const { action, rider_id, remark } = req.body; // action: 'ACCEPT' or 'REJECT'; rider_id: optional for return pickup; remark: optional reason why rejected
        const outlet_id = await resolveOutletId(req);

        if (!outlet_id) {
            await t.rollback();
            return res.status(400).json({ success: false, message: 'outlet_id is required' });
        }

        const order = await req.propertyDb.models.customer_orders.findOne({
            where: { id, outlet_id },
            transaction: t
        });

        if (!order) {
            await t.rollback();
            return res.status(404).json({ success: false, message: 'Order not found' });
        }

        if (order.return_status !== 'PENDING') {
            await t.rollback();
            return res.status(400).json({ success: false, message: 'No pending return request for this order' });
        }

        if (action === 'REJECT') {
            order.return_status = 'REJECTED';
            order.refund_status = null;
            order.return_rejection_reason = remark || 'Supplier rejected return request';
        } else {
            order.return_status = 'RETURN_ACCEPTED';
            if (rider_id) {
                order.assigned_partner_id = rider_id;
                order.assigned_at = new Date();
                order.status = 'ASSIGNED'; // Marks order back to ASSIGNED so rider gets notification
                const partner = await req.propertyDb.models.delivery_partners.findByPk(Number(rider_id), { transaction: t });
                if (partner) {
                    partner.status = 'BUSY';
                    await partner.save({ transaction: t });
                }
            }

            // Exchange auto replacement order creation
            if (order.return_type === 'EXCHANGE') {
                let replacementItems = [];
                if (order.returned_items && Array.isArray(order.returned_items) && order.returned_items.length > 0) {
                    replacementItems = order.returned_items;
                } else if (order.return_item_id) {
                    const matched = (order.items || []).find(it => it.item_id === order.return_item_id);
                    if (matched) {
                        replacementItems = [{ ...matched }];
                    } else {
                        replacementItems = [{
                            item_id: order.return_item_id,
                            item_name: order.return_item_name,
                            item_code: order.return_item_name,
                            qty: 1,
                            rate: 0,
                            taxable_amount: 0,
                            tax_amount: 0,
                            net_amount: 0
                        }];
                    }
                } else {
                    replacementItems = (order.items || []).map(it => ({ ...it }));
                }

                let repSubTotal = 0;
                let repTaxAmount = 0;
                let repNetAmount = 0;
                for (const item of replacementItems) {
                    const qty = toAmount(item.qty || 1);
                    const rate = toAmount(item.rate || 0);
                    const taxable = toAmount(item.taxable_amount || (qty * rate));
                    const tax = toAmount(item.tax_amount || 0);
                    const net = toAmount(item.net_amount || (taxable + tax));
                    repSubTotal += taxable;
                    repTaxAmount += tax;
                    repNetAmount += net;
                }

                // Find original sale to use its sale_no as the reference number in the stock ledger
                const sale = await req.propertyDb.models.sales_headers.findOne({
                    where: {
                        outlet_id: order.outlet_id,
                        notes: `Auto-generated from delivery order #${order.id}`,
                        is_deleted: false,
                        is_latest: true
                    },
                    transaction: t
                });
                const originalSaleNo = sale ? sale.sale_no : null;

                const replacementOrder = await req.propertyDb.models.customer_orders.create({
                    outlet_id: order.outlet_id,
                    customer_name: order.customer_name,
                    customer_phone: order.customer_phone,
                    customer_address: order.customer_address,
                    items: replacementItems,
                    sub_total: repSubTotal,
                    tax_amount: repTaxAmount,
                    delivery_charge: 0,
                    net_amount: repNetAmount,
                    payment_status: 'PAID',
                    payment_mode: 'EXCHANGE',
                    status: 'ACCEPTED',
                    commission_amount: 0,
                    commission_status: 'UNPAID',
                    gstin: order.gstin || null,
                    notes: `Exchange order for return #${order.id}${originalSaleNo ? ` against bill #${originalSaleNo}` : ''}`
                }, { transaction: t });
                const refNo = sale ? sale.sale_no : `ORDER-${order.id}`;

                // Deduct stock of replacement items under the original bill number (avoiding double GST / double bill)
                for (const item of replacementItems) {
                    const itemQty = toAmount(item.qty);

                    await insertLedger({
                        db: req.propertyDb,
                        outlet_id: order.outlet_id,
                        item_code: item.item_code,
                        txn_date: new Date(),
                        txn_type: 'SALE',
                        ref_no: refNo,
                        qty_out: itemQty,
                        transaction: t
                    });

                    // If it is a composite item, also deduct components
                    const bomComponents = await req.propertyDb.models.item_boms.findAll({
                        where: { outlet_id: order.outlet_id, parent_item_id: item.item_id },
                        include: [
                            {
                                model: req.propertyDb.models.item_master,
                                as: 'component_item',
                                where: { is_active: true }
                            }
                        ],
                        transaction: t
                    });

                    if (bomComponents && bomComponents.length > 0) {
                        for (const bomComp of bomComponents) {
                            const compItem = bomComp.component_item;
                            if (!compItem) continue;
                            const qtyRequiredPerUnit = Number(bomComp.quantity);
                            const totalQtyNeeded = qtyRequiredPerUnit * itemQty;

                            await insertLedger({
                                db: req.propertyDb,
                                outlet_id: order.outlet_id,
                                item_code: compItem.item_code,
                                txn_date: new Date(),
                                txn_type: 'SALE',
                                ref_no: refNo,
                                qty_out: totalQtyNeeded,
                                transaction: t
                            });
                        }
                    }
                }

                await req.propertyDb.models.system_notification.create({
                    outlet_id: order.outlet_id,
                    module: 'DELIVERY',
                    title: 'New Exchange Order',
                    message: `Exchange order #${replacementOrder.id} placed for customer ${order.customer_name} (Return #${order.id})`,
                    type: 'SUCCESS',
                    entity_id: replacementOrder.id
                }, { transaction: t });
            }
        }

        await order.save({ transaction: t });
        await t.commit();
        res.json({ success: true, message: 'Return request processed successfully.', data: order });
    } catch (error) {
        await t.rollback();
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.registerRiderFromApp = async (req, res) => {
    try {
        const { outlet_id, name, phone, password } = req.body;
        if (!outlet_id || !name || !phone || !password) {
            return res.status(400).json({ success: false, message: 'All fields are required' });
        }

        // Resolve string outlet_id to integer
        let actualOutletId;
        if (typeof outlet_id === 'string' && outlet_id.startsWith('OUTLET')) {
            const outlet = await req.propertyDb.models.outlets.findOne({
                where: { outlet_code: outlet_id }
            });
            if (!outlet) {
                return res.status(400).json({ success: false, message: `Outlet not found for code: ${outlet_id}` });
            }
            actualOutletId = outlet.id;
        } else {
            actualOutletId = Number(outlet_id);
        }

        // Check if delivery partner already exists
        const existing = await req.propertyDb.models.delivery_partners.findOne({
            where: { outlet_id: actualOutletId, phone }
        });
        if (existing) {
            return res.status(400).json({ success: false, message: 'A rider with this phone number is already registered.' });
        }

        const password_hash = bcrypt.hashSync(password, 10);

        const rider = await req.propertyDb.models.delivery_partners.create({
            outlet_id: actualOutletId,
            name,
            phone,
            password_hash,
            status: 'AVAILABLE'
        });

        res.status(201).json({
            success: true,
            data: {
                id: rider.id,
                name: rider.name,
                phone: rider.phone,
                status: rider.status
            }
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.loginRider = async (req, res) => {
    try {
        const { outlet_id, phone, password } = req.body;
        if (!outlet_id || !phone || !password) {
            return res.status(400).json({ success: false, message: 'Phone and password are required' });
        }

        // Resolve string outlet_id to integer
        let actualOutletId;
        if (typeof outlet_id === 'string' && outlet_id.startsWith('OUTLET')) {
            const outlet = await req.propertyDb.models.outlets.findOne({
                where: { outlet_code: outlet_id }
            });
            if (!outlet) {
                return res.status(400).json({ success: false, message: `Outlet not found for code: ${outlet_id}` });
            }
            actualOutletId = outlet.id;
        } else {
            actualOutletId = Number(outlet_id);
        }

        const rider = await req.propertyDb.models.delivery_partners.findOne({
            where: { outlet_id: actualOutletId, phone }
        });

        if (!rider) {
            return res.status(400).json({ success: false, message: 'Invalid phone number or password.' });
        }

        if (!rider.password_hash) {
            return res.status(400).json({ success: false, message: 'Please register your account with a password first.' });
        }

        if (!bcrypt.compareSync(password, rider.password_hash)) {
            return res.status(400).json({ success: false, message: 'Invalid phone number or password.' });
        }

        res.json({
            success: true,
            data: {
                id: rider.id,
                name: rider.name,
                phone: rider.phone,
                status: rider.status
            }
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.updateB2bRate = async (req, res) => {
    try {
        const { item_code } = req.params;
        const { b2b_rate } = req.body;
        const actualOutletId = await resolveOutletId(req);

        if (!actualOutletId) {
            return res.status(400).json({ success: false, message: 'outlet_id is required' });
        }

        const item = await req.propertyDb.models.item_master.findOne({
            where: { outlet_id: actualOutletId, item_code }
        });

        if (!item) {
            return res.status(404).json({ success: false, message: 'Item not found' });
        }

        item.b2b_rate = parseFloat(b2b_rate) || 0;
        await item.save();

        res.json({ success: true, message: 'B2B rate updated successfully', data: item });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.getReturnSettings = async (req, res) => {
    try {
        let actualOutletId = await resolveOutletId(req);

        // Fallback: if still null/undefined, find the first active outlet
        if (!actualOutletId) {
            const defaultOutlet = await req.propertyDb.models.outlets.findOne({
                where: { is_active: true }
            });
            if (defaultOutlet) {
                actualOutletId = defaultOutlet.id;
            }
        }

        const settings = await req.propertyDb.models.outlet_settings.findOne({
            where: { outlet_id: actualOutletId }
        });
        let sysSettings = null;
        try {
            sysSettings = await req.propertyDb.models.system_settings.findOne({
                where: { outlet_id: actualOutletId }
            });
        } catch (dbErr) {
            console.warn("⚠️ System settings query failed, trying fallback without merchant_upi_id:", dbErr.message);
            try {
                const attributes = Object.keys(req.propertyDb.models.system_settings.rawAttributes).filter(
                    attr => attr !== 'merchant_upi_id'
                );
                sysSettings = await req.propertyDb.models.system_settings.findOne({
                    where: { outlet_id: actualOutletId },
                    attributes: attributes
                });
            } catch (fallbackErr) {
                console.error("❌ Fallback system settings query failed:", fallbackErr.stack);
            }
        }
        const meta = settings?.meta_data || {};
        res.json({
            success: true,
            data: {
                default_return_window_days: meta.default_return_window_days ?? 7,
                min_delivery_order_value: parseFloat(meta.min_delivery_order_value ?? 0.0),
                delivery_charge: parseFloat(meta.delivery_charge ?? 0.0),
                delivery_gst_percent: parseFloat(meta.delivery_gst_percent ?? 18.0),
                platform_fee: parseFloat(meta.platform_fee ?? 10.0),
                platform_gst_percent: parseFloat(meta.platform_gst_percent ?? 18.0),
                other_charges: parseFloat(meta.other_charges ?? 0.0),
                other_charges_gst_percent: parseFloat(meta.other_charges_gst_percent ?? 18.0),
                commission_type: meta.commission_type ?? 'FLAT',
                commission_value: parseFloat(meta.commission_value ?? 20.0),
                custom_charges: meta.custom_charges || [],
                coupons: meta.coupons || [],
                is_exchange_available: meta.is_exchange_available ?? true,
                is_refund_available: meta.is_refund_available ?? true,
                enable_payment_gateway: sysSettings?.enable_payment_gateway ?? false,
                payment_gateway_provider: sysSettings?.payment_gateway_provider ?? 'SANDBOX',
                payment_gateway_api_key: sysSettings?.payment_gateway_api_key ?? '',
                merchant_upi_id: sysSettings?.merchant_upi_id ?? ''
            }
        });
    } catch (error) {
        console.error("GET RETURN SETTINGS ERROR STACK:", error.stack || error);
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.updateReturnSettings = async (req, res) => {
    try {
        const outlet_id = await resolveOutletId(req);
        if (!outlet_id) {
            return res.status(400).json({ success: false, message: 'outlet_id is required' });
        }
        const {
            default_return_window_days,
            min_delivery_order_value,
            delivery_charge,
            delivery_gst_percent,
            platform_fee,
            platform_gst_percent,
            other_charges,
            other_charges_gst_percent,
            commission_type,
            commission_value,
            custom_charges,
            coupons,
            is_exchange_available,
            is_refund_available
        } = req.body;

        let settings = await req.propertyDb.models.outlet_settings.findOne({ where: { outlet_id } });
        if (!settings) {
            settings = await req.propertyDb.models.outlet_settings.create({ outlet_id, meta_data: {} });
        }
        const meta = settings.meta_data || {};

        if (default_return_window_days !== undefined) {
            const days = parseInt(default_return_window_days);
            if (isNaN(days) || days < 0 || days > 365) {
                return res.status(400).json({ success: false, message: 'Invalid number of days (0–365)' });
            }
            meta.default_return_window_days = days;
        }

        if (min_delivery_order_value !== undefined) {
            const minVal = parseFloat(min_delivery_order_value);
            if (isNaN(minVal) || minVal < 0) {
                return res.status(400).json({ success: false, message: 'Invalid min_delivery_order_value' });
            }
            meta.min_delivery_order_value = minVal;
        }

        if (delivery_charge !== undefined) {
            const charge = parseFloat(delivery_charge);
            if (isNaN(charge) || charge < 0) {
                return res.status(400).json({ success: false, message: 'Invalid delivery_charge' });
            }
            meta.delivery_charge = charge;
        }

        if (delivery_gst_percent !== undefined) {
            const gst = parseFloat(delivery_gst_percent);
            if (isNaN(gst) || gst < 0 || gst > 100) {
                return res.status(400).json({ success: false, message: 'Invalid delivery_gst_percent' });
            }
            meta.delivery_gst_percent = gst;
        }

        if (platform_fee !== undefined) {
            const fee = parseFloat(platform_fee);
            if (isNaN(fee) || fee < 0) {
                return res.status(400).json({ success: false, message: 'Invalid platform_fee' });
            }
            meta.platform_fee = fee;
        }

        if (platform_gst_percent !== undefined) {
            const gst = parseFloat(platform_gst_percent);
            if (isNaN(gst) || gst < 0 || gst > 100) {
                return res.status(400).json({ success: false, message: 'Invalid platform_gst_percent' });
            }
            meta.platform_gst_percent = gst;
        }

        if (other_charges !== undefined) {
            const charge = parseFloat(other_charges);
            if (isNaN(charge) || charge < 0) {
                return res.status(400).json({ success: false, message: 'Invalid other_charges' });
            }
            meta.other_charges = charge;
        }

        if (other_charges_gst_percent !== undefined) {
            const gst = parseFloat(other_charges_gst_percent);
            if (isNaN(gst) || gst < 0 || gst > 100) {
                return res.status(400).json({ success: false, message: 'Invalid other_charges_gst_percent' });
            }
            meta.other_charges_gst_percent = gst;
        }

        if (commission_type !== undefined) {
            if (commission_type !== 'FLAT' && commission_type !== 'PERCENTAGE') {
                return res.status(400).json({ success: false, message: 'commission_type must be FLAT or PERCENTAGE' });
            }
            meta.commission_type = commission_type;
        }

        if (commission_value !== undefined) {
            const commVal = parseFloat(commission_value);
            if (isNaN(commVal) || commVal < 0) {
                return res.status(400).json({ success: false, message: 'Invalid commission_value' });
            }
            meta.commission_value = commVal;
        }

        if (custom_charges !== undefined) {
            if (!Array.isArray(custom_charges)) {
                return res.status(400).json({ success: false, message: 'custom_charges must be an array' });
            }
            meta.custom_charges = custom_charges;
        }

        if (coupons !== undefined) {
            if (!Array.isArray(coupons)) {
                return res.status(400).json({ success: false, message: 'coupons must be an array' });
            }
            meta.coupons = coupons;
        }

        if (is_exchange_available !== undefined) {
            meta.is_exchange_available = !!is_exchange_available;
        }

        if (is_refund_available !== undefined) {
            meta.is_refund_available = !!is_refund_available;
        }

        settings.meta_data = meta;
        settings.changed('meta_data', true);
        await settings.save();

        res.json({
            success: true,
            message: 'Settings updated successfully.',
            data: {
                default_return_window_days: meta.default_return_window_days ?? 7,
                min_delivery_order_value: parseFloat(meta.min_delivery_order_value ?? 0.0),
                delivery_charge: parseFloat(meta.delivery_charge ?? 0.0),
                delivery_gst_percent: parseFloat(meta.delivery_gst_percent ?? 18.0),
                platform_fee: parseFloat(meta.platform_fee ?? 10.0),
                platform_gst_percent: parseFloat(meta.platform_gst_percent ?? 18.0),
                other_charges: parseFloat(meta.other_charges ?? 0.0),
                other_charges_gst_percent: parseFloat(meta.other_charges_gst_percent ?? 18.0),
                commission_type: meta.commission_type ?? 'FLAT',
                commission_value: parseFloat(meta.commission_value ?? 20.0),
                custom_charges: meta.custom_charges || [],
                coupons: meta.coupons || [],
                is_exchange_available: meta.is_exchange_available ?? true,
                is_refund_available: meta.is_refund_available ?? true
            }
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.updateItemReturnWindow = async (req, res) => {
    try {
        const { item_code } = req.params;
        const { return_window_days } = req.body;
        const outlet_id = await resolveOutletId(req);
        if (!outlet_id) {
            return res.status(400).json({ success: false, message: 'outlet_id is required' });
        }
        const days = parseInt(return_window_days);
        if (isNaN(days) || days < 0) {
            return res.status(400).json({ success: false, message: 'Invalid return_window_days value' });
        }
        const item = await req.propertyDb.models.item_master.findOne({
            where: { outlet_id, item_code }
        });
        if (!item) {
            return res.status(404).json({ success: false, message: 'Item not found' });
        }
        item.return_window_days = days;
        await item.save();
        res.json({ success: true, message: `Return window for ${item.item_name} set to ${days} day(s).`, data: item });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.handoverReturn = async (req, res) => {
    const t = await req.propertyDb.transaction();
    try {
        const { id } = req.params;
        const { status } = req.body; // RETURN_PICKED_UP_FROM_STORE, RETURN_COLLECTED, RETURN_HANDED_OVER
        const outlet_id = await resolveOutletId(req);

        if (!outlet_id) {
            await t.rollback();
            return res.status(400).json({ success: false, message: 'outlet_id is required' });
        }

        const order = await req.propertyDb.models.customer_orders.findOne({
            where: { id, outlet_id },
            transaction: t
        });

        if (!order) {
            await t.rollback();
            return res.status(404).json({ success: false, message: 'Order not found' });
        }

        // Backward compatibility fallback
        const targetStatus = status || 'RETURN_HANDED_OVER';

        if (targetStatus === 'RETURN_PICKED_UP_FROM_STORE') {
            if (order.return_status !== 'RETURN_ACCEPTED') {
                await t.rollback();
                return res.status(400).json({ success: false, message: `Invalid status for store pickup: ${order.return_status}` });
            }
            order.return_status = 'RETURN_PICKED_UP_FROM_STORE';
        } else if (targetStatus === 'RETURN_COLLECTED') {
            if (order.return_status !== 'RETURN_PICKED_UP_FROM_STORE' && order.return_status !== 'RETURN_ACCEPTED') {
                await t.rollback();
                return res.status(400).json({ success: false, message: `Invalid status for doorstep collection: ${order.return_status}` });
            }
            order.return_status = 'RETURN_COLLECTED';

            // Find associated replacement order and auto mark as DELIVERED
            const replacementOrder = await req.propertyDb.models.customer_orders.findOne({
                where: {
                    outlet_id,
                    notes: {
                        [Op.like]: `Exchange order for return #${order.id}%`
                    }
                },
                transaction: t
            });
            if (replacementOrder) {
                replacementOrder.status = 'DELIVERED';
                replacementOrder.delivered_at = new Date();
                await replacementOrder.save({ transaction: t });

                // Update associated POS sale header
                const replSale = await req.propertyDb.models.sales_headers.findOne({
                    where: {
                        outlet_id,
                        notes: `Auto-generated from delivery order #${replacementOrder.id}`,
                        is_deleted: false,
                        is_latest: true
                    },
                    transaction: t
                });
                if (replSale) {
                    replSale.status = 'COMPLETED';
                    await replSale.save({ transaction: t });
                }
            }
        } else if (targetStatus === 'RETURN_HANDED_OVER') {
            order.return_status = 'RETURN_HANDED_OVER';

            // Free the rider
            if (order.assigned_partner_id) {
                const rider = await req.propertyDb.models.delivery_partners.findByPk(order.assigned_partner_id, { transaction: t });
                if (rider) {
                    rider.status = 'AVAILABLE';
                    await rider.save({ transaction: t });
                }
            }
        } else {
            await t.rollback();
            return res.status(400).json({ success: false, message: `Invalid target status: ${targetStatus}` });
        }

        await order.save({ transaction: t });
        await t.commit();

        res.json({ success: true, message: `Return status updated to ${order.return_status} successfully.`, data: order });
    } catch (error) {
        await t.rollback();
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.finalReceiveReturn = async (req, res) => {
    const t = await req.propertyDb.transaction();
    try {
        const { id } = req.params;
        const { add_to_stock, refund_action, replacement_rider_id, refund_payment_mode, action, remark } = req.body;
        const outlet_id = await resolveOutletId(req);

        if (!outlet_id) {
            await t.rollback();
            return res.status(400).json({ success: false, message: 'outlet_id is required' });
        }

        const order = await req.propertyDb.models.customer_orders.findOne({
            where: { id, outlet_id },
            transaction: t
        });

        if (!order) {
            await t.rollback();
            return res.status(404).json({ success: false, message: 'Order not found' });
        }

        const allowedStatuses = ['PENDING', 'RETURN_ACCEPTED', 'RETURN_HANDED_OVER'];
        if (!allowedStatuses.includes(order.return_status)) {
            await t.rollback();
            return res.status(400).json({ success: false, message: `Invalid return status for final receive: ${order.return_status}` });
        }

        // Rejection logic for exchange/return at final receive stage
        if (action === 'REJECT' || refund_action === 'REJECT') {
            order.return_status = 'REJECTED';
            order.refund_status = null;

            // Find the associated replacement order using notes
            const replacementOrder = await req.propertyDb.models.customer_orders.findOne({
                where: {
                    outlet_id,
                    notes: {
                        [Op.like]: `Exchange order for return #${order.id}%`
                    }
                },
                transaction: t
            });

            if (replacementOrder) {
                if (replacementOrder.status !== 'CANCELLED') {
                    const oldReplStatus = replacementOrder.status;
                    replacementOrder.status = 'CANCELLED';
                    await replacementOrder.save({ transaction: t });

                    // Free rider of replacement order if assigned
                    if (replacementOrder.assigned_partner_id) {
                        const rider = await req.propertyDb.models.delivery_partners.findByPk(replacementOrder.assigned_partner_id, { transaction: t });
                        if (rider) {
                            rider.status = 'AVAILABLE';
                            await rider.save({ transaction: t });
                        }
                    }

                    // Find associated POS sales header for replacement order
                    const replSale = await req.propertyDb.models.sales_headers.findOne({
                        where: {
                            outlet_id,
                            notes: `Auto-generated from delivery order #${replacementOrder.id}`,
                            is_deleted: false,
                            is_latest: true
                        },
                        transaction: t
                    });

                    if (replSale) {
                        replSale.is_deleted = true;
                        await replSale.save({ transaction: t });

                        // Delete cash ledger entries
                        await req.propertyDb.models.cash_ledger.destroy({
                            where: {
                                outlet_id,
                                reference_type: 'SALE',
                                reference_id: replSale.id
                            },
                            transaction: t
                        });
                    }

                    // Find original sale to use its sale_no as fallback reference number for the stock ledger
                    const originalSale = await req.propertyDb.models.sales_headers.findOne({
                        where: {
                            outlet_id,
                            notes: `Auto-generated from delivery order #${order.id}`,
                            is_deleted: false,
                            is_latest: true
                        },
                        transaction: t
                    });
                    const fallbackRef = replSale ? replSale.sale_no : (originalSale ? originalSale.sale_no : `ORDER-${replacementOrder.id}`);

                    // Restore stock of the replacement items (if they were accepted/processed)
                    if (oldReplStatus !== 'PENDING') {
                        for (const item of replacementOrder.items) {
                            await insertLedger({
                                db: req.propertyDb,
                                outlet_id,
                                item_code: item.item_code,
                                txn_date: new Date(),
                                txn_type: 'SALE_RETURN',
                                ref_no: fallbackRef,
                                qty_in: toAmount(item.qty),
                                transaction: t
                            });

                            // Restore composite components if any
                            const bomComponents = await req.propertyDb.models.item_boms.findAll({
                                where: { outlet_id, parent_item_id: item.item_id },
                                include: [
                                    {
                                        model: req.propertyDb.models.item_master,
                                        as: 'component_item',
                                        where: { is_active: true }
                                    }
                                ],
                                transaction: t
                            });

                            if (bomComponents && bomComponents.length > 0) {
                                for (const bomComp of bomComponents) {
                                    const compItem = bomComp.component_item;
                                    if (!compItem) continue;
                                    const qtyRequiredPerUnit = Number(bomComp.quantity);
                                    const totalQtyNeeded = qtyRequiredPerUnit * toAmount(item.qty);

                                    await insertLedger({
                                        db: req.propertyDb,
                                        outlet_id,
                                        item_code: compItem.item_code,
                                        txn_date: new Date(),
                                        txn_type: 'SALE_RETURN',
                                        ref_no: fallbackRef,
                                        qty_in: totalQtyNeeded,
                                        transaction: t
                                    });
                                }
                            }
                        }
                    }
                }
            }

            order.status = 'DELIVERED';
            await order.save({ transaction: t });
            await t.commit();
            return res.json({ success: true, message: 'Return request rejected. Replacement order cancelled and stock restored.', data: order });
        }

        const sale = await req.propertyDb.models.sales_headers.findOne({
            where: {
                outlet_id,
                notes: `Auto-generated from delivery order #${order.id}`,
                is_deleted: false,
                is_latest: true
            },
            include: [{ model: req.propertyDb.models.sales_items, as: 'items' }],
            transaction: t
        });

        const refNo = sale ? sale.sale_no : `ORDER-${order.id}`;

        let itemsToProcess = [];
        if (order.returned_items && Array.isArray(order.returned_items)) {
            itemsToProcess = order.returned_items;
        } else if (order.return_item_id) {
            const matched = (order.items || []).find(it => it.item_id === order.return_item_id);
            if (matched) {
                itemsToProcess = [matched];
            } else {
                itemsToProcess = [{
                    item_id: order.return_item_id,
                    item_name: order.return_item_name,
                    item_code: order.return_item_name,
                    qty: 1
                }];
            }
        }

        // 1. Optional Stock Restoration
        if (add_to_stock === true) {
            for (const item of itemsToProcess) {
                const itemQty = toAmount(item.qty);
                await insertLedger({
                    db: req.propertyDb,
                    outlet_id,
                    item_code: item.item_code,
                    txn_date: new Date(),
                    txn_type: 'SALE_RETURN',
                    ref_no: refNo,
                    qty_in: itemQty,
                    transaction: t
                });

                const bomComponents = await req.propertyDb.models.item_boms.findAll({
                    where: { outlet_id, parent_item_id: item.item_id },
                    include: [
                        {
                            model: req.propertyDb.models.item_master,
                            as: 'component_item',
                            where: { is_active: true }
                        }
                    ],
                    transaction: t
                });

                if (bomComponents && bomComponents.length > 0) {
                    for (const bomComp of bomComponents) {
                        const compItem = bomComp.component_item;
                        if (!compItem) continue;
                        const qtyRequiredPerUnit = Number(bomComp.quantity);
                        const totalQtyNeeded = qtyRequiredPerUnit * itemQty;

                        await insertLedger({
                            db: req.propertyDb,
                            outlet_id,
                            item_code: compItem.item_code,
                            txn_date: new Date(),
                            txn_type: 'SALE_RETURN',
                            ref_no: refNo,
                            qty_in: totalQtyNeeded,
                            transaction: t
                        });
                    }
                }
            }
        }

        // 2. Refund / Exchange Logic
        if (refund_action === 'REFUND') {
            order.return_status = 'RETURNED';
            if (order.payment_gateway_details) {
                // For gateway orders, the refund is pending until manually processed via gateway transactions tab
                order.refund_status = 'PENDING';
                order.refund_payment_mode = null;
                order.refund_paid_at = null;
            } else {
                order.refund_status = 'REFUNDED';
                order.refund_payment_mode = order.payment_mode || 'UPI';
                order.refund_paid_at = new Date();
            }

            if (sale) {
                const alreadyReturned = {};
                const existingCNs = await req.propertyDb.models.sales_credit_notes.findAll({
                    where: { sale_id: sale.id, outlet_id },
                    transaction: t
                });
                for (const cn of existingCNs) {
                    if (Array.isArray(cn.items)) {
                        for (const it of cn.items) {
                            alreadyReturned[it.item_id] = (alreadyReturned[it.item_id] || 0) + Number(it.qty);
                        }
                    }
                }

                const cnItems = [];
                let cnTotalQty = 0;
                let cnSubTotal = 0;
                let cnTaxableAmount = 0;
                let cnCgstAmount = 0;
                let cnSgstAmount = 0;
                let cnIgstAmount = 0;
                let cnTotalTax = 0;
                let cnNetAmount = 0;

                for (const retItem of itemsToProcess) {
                    const saleItem = sale.items.find(it => it.item_id === retItem.item_id);
                    if (!saleItem) continue;

                    const qtyToReturn = Number(retItem.qty || 1);
                    if (qtyToReturn <= 0) continue;

                    const prevReturned = alreadyReturned[saleItem.item_id] || 0;
                    const maxReturnable = Number(saleItem.qty) - prevReturned;
                    const finalReturnQty = qtyToReturn > maxReturnable ? maxReturnable : qtyToReturn;
                    if (finalReturnQty <= 0) continue;

                    const proportion = finalReturnQty / Number(saleItem.qty);
                    const taxable_val = toAmount(Number(saleItem.taxable_amount || saleItem.net_amount) * proportion);
                    const tax_val = toAmount(Number(saleItem.tax_amount || 0) * proportion);
                    const net_val = toAmount(Number(saleItem.net_amount) * proportion);
                    const rate = Number(saleItem.rate);

                    let cgst_amount = 0;
                    let sgst_amount = 0;
                    let igst_amount = 0;
                    let tax_breakup = [];

                    if (Array.isArray(saleItem.tax_breakup)) {
                        tax_breakup = saleItem.tax_breakup.map(tax => {
                            const taxAmt = toAmount(Number(tax.taxAmount) * proportion);
                            if (tax.code === 'CGST') cgst_amount += taxAmt;
                            if (tax.code === 'SGST') sgst_amount += taxAmt;
                            if (tax.code === 'IGST') igst_amount += taxAmt;
                            return { ...tax, taxAmount: taxAmt };
                        });
                    } else {
                        const taxPercent = Number(saleItem.tax_percent || 0);
                        if (taxPercent > 0) {
                            const calculatedTax = toAmount(taxable_val * taxPercent / 100);
                            cgst_amount = toAmount(calculatedTax / 2);
                            sgst_amount = toAmount(calculatedTax / 2);
                            tax_val = calculatedTax;
                        }
                    }

                    cnItems.push({
                        item_id: saleItem.item_id,
                        item_code: saleItem.item_code,
                        item_name: saleItem.item_name,
                        qty: finalReturnQty,
                        rate,
                        taxable_amount: taxable_val,
                        tax_amount: tax_val,
                        cgst_amount,
                        sgst_amount,
                        igst_amount,
                        net_amount: net_val,
                        tax_percent: saleItem.tax_percent || 0,
                        tax_breakup
                    });

                    cnTotalQty += finalReturnQty;
                    cnSubTotal += toAmount(rate * finalReturnQty);
                    cnTaxableAmount += taxable_val;
                    cnCgstAmount += cgst_amount;
                    cnSgstAmount += sgst_amount;
                    cnIgstAmount += igst_amount;
                    cnTotalTax += tax_val;
                    cnNetAmount += net_val;
                }

                if (cnItems.length > 0) {
                    const todayStr = new Date().toISOString().slice(0, 10).replace(/-/g, '');
                    const cnCount = await req.propertyDb.models.sales_credit_notes.count({
                        where: { outlet_id, credit_note_date: new Date() },
                        transaction: t
                    });
                    const seqCN = String(cnCount + 1).padStart(4, '0');
                    const credit_note_no = `CN-${todayStr}-${seqCN}`;

                    const customRefundAmount = req.body.refund_amount !== undefined && req.body.refund_amount !== null ? parseFloat(req.body.refund_amount) : null;
                    const finalCnNetAmount = customRefundAmount !== null ? customRefundAmount : cnNetAmount;

                    await req.propertyDb.models.sales_credit_notes.create({
                        outlet_id,
                        sale_id: sale.id,
                        credit_note_no,
                        credit_note_date: new Date(),
                        customer_name: sale.customer_name,
                        customer_phone: sale.customer_phone,
                        customer_gstin: sale.customer_gstin,
                        items: cnItems,
                        total_qty: cnTotalQty,
                        sub_total: cnSubTotal,
                        taxable_amount: cnTaxableAmount,
                        cgst_amount: cnCgstAmount,
                        sgst_amount: cnSgstAmount,
                        igst_amount: cnIgstAmount,
                        total_tax: cnTotalTax,
                        net_amount: finalCnNetAmount,
                        reason: 'Sales Return',
                        status: 'PENDING',
                        notes: `Credit Note issued for delivery sales return on order #${order.id}`,
                        created_by: req.user.id
                    }, { transaction: t });

                    const refundCount = await req.propertyDb.models.sales_refunds.count({
                        where: { outlet_id, refund_date: new Date() },
                        transaction: t
                    });
                    const seqRefund = String(refundCount + 1).padStart(4, '0');
                    const refund_no = `REF-${todayStr}-${seqRefund}`;

                    // If refund payment mode is chosen (instant refund)
                    const isPaid = !!refund_payment_mode;
                    const refundRecord = await req.propertyDb.models.sales_refunds.create({
                        outlet_id,
                        sale_id: sale.id,
                        refund_no,
                        refund_date: new Date(),
                        amount_pending: isPaid ? 0 : finalCnNetAmount,
                        amount_paid: isPaid ? finalCnNetAmount : 0,
                        status: isPaid ? 'PAID' : 'PENDING',
                        payment_mode: refund_payment_mode || null,
                        notes: isPaid 
                            ? `Refund paid in ${refund_payment_mode} for Credit Note ${credit_note_no} against delivery order #${order.id}`
                            : `Pending refund for Credit Note ${credit_note_no} against delivery order #${order.id}`,
                        created_by: req.user.id
                    }, { transaction: t });

                    if (isPaid) {
                        const { createLedgerEntry } = require('../../services/cashLedger.service');
                        await createLedgerEntry({
                            db: req.propertyDb,
                            outlet_id,
                            txn_date: new Date(),
                            transaction_type: 'SALE_REFUND',
                            reference_type: 'SALE_REFUND',
                            reference_id: refundRecord.id,
                            reference_no: refundRecord.refund_no,
                            party_name: sale?.customer_name || sale?.customer_phone || 'Walk-in Customer',
                            payment_method: refund_payment_mode,
                            amount_out: finalCnNetAmount,
                            notes: `Refund paid against bill ${sale?.sale_no || ''}`,
                            created_by: req.user.id,
                            transaction: t
                        });
                    }
                }
            }
        } else if (refund_action === 'ACCEPT_NO_REFUND') {
            order.return_status = 'RETURNED';
            order.refund_status = 'NO_REFUND';
        } else if (refund_action === 'EXCHANGE') {
            order.return_status = 'EXCHANGED';
            order.refund_status = 'EXCHANGED';

            if (replacement_rider_id) {
                order.assigned_partner_id = replacement_rider_id;
                order.assigned_at = new Date();
                order.status = 'ASSIGNED';
                const partner = await req.propertyDb.models.delivery_partners.findByPk(Number(replacement_rider_id), { transaction: t });
                if (partner) {
                    partner.status = 'BUSY';
                    await partner.save({ transaction: t });
                }
            }

            // Auto-mark replacement order as DELIVERED if it exists and is not already completed/cancelled
            const replacementOrder = await req.propertyDb.models.customer_orders.findOne({
                where: {
                    outlet_id,
                    notes: {
                        [Op.like]: `Exchange order for return #${order.id}%`
                    }
                },
                transaction: t
            });

            if (replacementOrder) {
                if (replacementOrder.status !== 'DELIVERED' && replacementOrder.status !== 'CANCELLED') {
                    replacementOrder.status = 'DELIVERED';
                    replacementOrder.delivered_at = new Date();
                    await replacementOrder.save({ transaction: t });

                    // Update associated POS sale header
                    const replSale = await req.propertyDb.models.sales_headers.findOne({
                        where: {
                            outlet_id,
                            notes: `Auto-generated from delivery order #${replacementOrder.id}`,
                            is_deleted: false,
                            is_latest: true
                        },
                        transaction: t
                    });
                    if (replSale) {
                        replSale.status = 'COMPLETED';
                        await replSale.save({ transaction: t });
                    }
                }
            }
        }

        // Reset original order status on return completion
        order.status = 'DELIVERED';

        if (remark) {
            order.notes = order.notes ? `${order.notes} | Remark: ${remark}` : remark;
        }

        await order.save({ transaction: t });
        await t.commit();
        res.json({ success: true, message: 'Return processed completely.', data: order });
    } catch (error) {
        await t.rollback();
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.markRefundPaid = async (req, res) => {
    const t = await req.propertyDb.transaction();
    try {
        const { id } = req.params;
        const { refund_method, notes } = req.body; // refund_method: 'CASH','UPI','BANK', notes: optional
        const outlet_id = await resolveOutletId(req);

        if (!outlet_id) {
            await t.rollback();
            return res.status(400).json({ success: false, message: 'outlet_id is required' });
        }

        const order = await req.propertyDb.models.customer_orders.findOne({
            where: { id, outlet_id },
            transaction: t
        });

        if (!order) {
            await t.rollback();
            return res.status(404).json({ success: false, message: 'Order not found' });
        }

        if (order.refund_status !== 'PENDING') {
            await t.rollback();
            return res.status(400).json({
                success: false,
                message: `Refund is not pending for this order (current status: ${order.refund_status ?? 'none'})`
            });
        }

        const method = String(refund_method || order.payment_mode || 'CASH').trim().toUpperCase();
        order.refund_status = 'REFUNDED';
        order.refund_payment_mode = method;
        order.refund_paid_at = new Date();
        if (notes) {
            order.notes = order.notes ? `${order.notes} | Refund: ${notes}` : `Refund: ${notes}`;
        }
        await order.save({ transaction: t });

        // Record the refund payout as a debit in the cash ledger
        const refundAmt = toAmount(order.net_amount);
        const { createLedgerEntry } = require('../../services/cashLedger.service');
        await createLedgerEntry({
            db: req.propertyDb,
            outlet_id,
            txn_date: new Date(),
            transaction_type: 'REFUND',
            reference_type: 'DELIVERY_ORDER',
            reference_id: order.id,
            reference_no: `ORD-${order.id}`,
            party_name: order.customer_name,
            payment_method: method,
            amount_out: refundAmt,
            notes: notes
                ? `Refund for order #${order.id} (${notes})`
                : `Refund paid for order #${order.id} to ${order.customer_name}`,
            created_by: req.user?.id || null,
            transaction: t
        });

        await t.commit();
        res.json({ success: true, message: 'Refund marked as paid successfully.', data: order });
    } catch (error) {
        if (t && !t.finished) await t.rollback();
        res.status(500).json({ success: false, error: error.message });
    }
};


exports.reassignOrder = async (req, res) => {
    const t = await req.propertyDb.transaction();
    try {
        const { id } = req.params;
        const { rider_id } = req.body;
        const outlet_id = await resolveOutletId(req);
        if (!outlet_id) {
            await t.rollback();
            return res.status(400).json({ success: false, message: 'outlet_id is required' });
        }

        const order = await req.propertyDb.models.customer_orders.findOne({
            where: { id, outlet_id },
            transaction: t
        });

        if (!order) {
            await t.rollback();
            return res.status(404).json({ success: false, message: 'Order not found' });
        }

        if (order.status !== 'ACCEPTED' && order.status !== 'ASSIGNED') {
            await t.rollback();
            return res.status(400).json({ success: false, message: `Cannot reassign rider for order with status: ${order.status}` });
        }

        // 1. Free the old rider if one was assigned
        if (order.assigned_partner_id) {
            const oldRider = await req.propertyDb.models.delivery_partners.findByPk(order.assigned_partner_id, { transaction: t });
            if (oldRider) {
                oldRider.status = 'AVAILABLE';
                await oldRider.save({ transaction: t });
            }
        }

        // 2. Perform new assignment
        let assigned = false;
        if (rider_id && rider_id !== 'AUTO' && rider_id !== 'NONE' && rider_id !== '') {
            const partner = await req.propertyDb.models.delivery_partners.findOne({
                where: { id: Number(rider_id), outlet_id },
                transaction: t
            });
            if (partner) {
                order.assigned_partner_id = partner.id;
                order.status = 'ASSIGNED';
                order.assigned_at = new Date();
                await order.save({ transaction: t });

                partner.status = 'BUSY';
                await partner.save({ transaction: t });

                await req.propertyDb.models.system_notification.create({
                    outlet_id,
                    module: 'DELIVERY',
                    title: 'Order Reassigned',
                    message: `Order #${order.id} for ${order.customer_name} reassigned to rider ${partner.name}.`,
                    type: 'INFO',
                    entity_id: order.id
                }, { transaction: t });

                assigned = true;
            } else {
                await t.rollback();
                return res.status(404).json({ success: false, message: 'Selected rider not found' });
            }
        } else if (rider_id === 'AUTO') {
            assigned = await autoAssignOrder(req, order, t);
        } else {
            // unassign / NONE
            order.assigned_partner_id = null;
            order.status = 'ACCEPTED';
            await order.save({ transaction: t });
        }

        await t.commit();
        res.json({
            success: true,
            message: 'Rider reassigned successfully.',
            data: {
                order_id: order.id,
                assigned_rider_id: order.assigned_partner_id,
                is_assigned: assigned,
                status: order.status
            }
        });
    } catch (error) {
        await t.rollback();
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.submitOrderFeedback = async (req, res) => {
    try {
        const { id } = req.params;
        const { rating, comment } = req.body;

        if (rating === undefined || rating === null) {
            return res.status(400).json({ success: false, message: 'Rating is required' });
        }

        const order = await req.propertyDb.models.customer_orders.findOne({
            where: { id }
        });

        if (!order) {
            return res.status(404).json({ success: false, message: 'Order not found' });
        }

        if (order.status !== 'DELIVERED') {
            return res.status(400).json({ success: false, message: 'Feedback can only be submitted for delivered orders' });
        }

        order.feedback = {
            rating: Number(rating),
            comment: comment || '',
            submitted_at: new Date().toISOString(),
            reply: null,
            replied_at: null
        };
        order.changed('feedback', true);
        await order.save();

        res.json({ success: true, message: 'Feedback submitted successfully', feedback: order.feedback });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.replyToOrderFeedback = async (req, res) => {
    try {
        const { id } = req.params;
        const { reply } = req.body;

        if (!reply) {
            return res.status(400).json({ success: false, message: 'Reply is required' });
        }

        const order = await req.propertyDb.models.customer_orders.findOne({
            where: { id }
        });

        if (!order) {
            return res.status(404).json({ success: false, message: 'Order not found' });
        }

        if (!order.feedback) {
            return res.status(400).json({ success: false, message: 'No customer feedback exists for this order' });
        }

        const feedback = { ...order.feedback };
        feedback.reply = reply;
        feedback.replied_at = new Date().toISOString();

        order.feedback = feedback;
        order.changed('feedback', true);
        await order.save();

        res.json({ success: true, message: 'Reply submitted successfully', feedback: order.feedback });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

/**
 * GET /api/delivery/customer/notifications?customer_phone=...&outlet_id=...
 * Returns unread CUSTOMER module notifications for the outlet.
 * The customer app polls this every minute to show local notifications.
 */
exports.getCustomerNotifications = async (req, res) => {
    try {
        const { outlet_id } = req.query;
        if (!outlet_id) return res.status(400).json({ success: false, message: 'outlet_id required' });

        let actualOutletId = outlet_id;
        if (typeof outlet_id === 'string' && outlet_id.startsWith('OUTLET')) {
            const outlet = await req.propertyDb.models.outlets.findOne({ where: { outlet_code: outlet_id } });
            if (outlet) actualOutletId = outlet.id;
        }

        const rows = await req.propertyDb.models.system_notifications.findAll({
            where: { outlet_id: actualOutletId, module: 'CUSTOMER', is_read: false },
            order: [['created_at', 'DESC']],
            limit: 20
        });

        res.json({ success: true, data: rows });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

/**
 * GET /api/delivery/rider/notifications?rider_id=...&outlet_id=...
 * Returns unread RIDER module notifications for the given rider.
 * entity_id in the notification stores the rider's ID.
 */
exports.getRiderNotifications = async (req, res) => {
    try {
        const { outlet_id, rider_id } = req.query;
        if (!outlet_id || !rider_id) return res.status(400).json({ success: false, message: 'outlet_id and rider_id required' });

        let actualOutletId = outlet_id;
        if (typeof outlet_id === 'string' && outlet_id.startsWith('OUTLET')) {
            const outlet = await req.propertyDb.models.outlets.findOne({ where: { outlet_code: outlet_id } });
            if (outlet) actualOutletId = outlet.id;
        }

        const rows = await req.propertyDb.models.system_notifications.findAll({
            where: { outlet_id: actualOutletId, module: 'RIDER', entity_id: Number(rider_id), is_read: false },
            order: [['created_at', 'DESC']],
            limit: 20
        });

        res.json({ success: true, data: rows });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.listTransactions = async (req, res) => {
    try {
        const outlet_id = await resolveOutletId(req);
        if (!outlet_id) {
            return res.status(400).json({ success: false, message: 'outlet_id is required' });
        }

        const { Sequelize } = req.propertyDb;
        const orders = await req.propertyDb.models.customer_orders.findAll({
            where: {
                outlet_id,
                payment_gateway_details: {
                    [Sequelize.Op.ne]: null
                }
            },
            order: [['id', 'DESC']]
        });

        const ordersJson = [];
        for (const order of orders) {
            const orderObj = order.toJSON();
            orderObj.has_pending_credit_notes = false;

            orderObj.bill_no = await resolveOrderBillNo(req, orderObj, outlet_id);

            const sale = await req.propertyDb.models.sales_headers.findOne({
                where: {
                    outlet_id,
                    notes: `Auto-generated from delivery order #${order.id}`,
                    is_deleted: false,
                    is_latest: true
                }
            });

            if (sale) {
                const refundsCount = await req.propertyDb.models.sales_refunds.count({
                    where: {
                        outlet_id,
                        sale_id: sale.id,
                        status: {
                            [Sequelize.Op.in]: ['PENDING', 'PARTIALLY_PAID']
                        }
                    }
                });
                orderObj.has_pending_credit_notes = refundsCount > 0;
            }
            ordersJson.push(orderObj);
        }

        res.json({ success: true, data: ordersJson });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.refundGatewayPayment = async (req, res) => {
    const t = await req.propertyDb.transaction();
    try {
        const { id } = req.params;
        const { refund_amount, reason } = req.body;
        const outlet_id = await resolveOutletId(req);

        if (!outlet_id) {
            await t.rollback();
            return res.status(400).json({ success: false, message: 'outlet_id is required' });
        }

        const order = await req.propertyDb.models.customer_orders.findOne({
            where: { id, outlet_id },
            transaction: t
        });

        if (!order) {
            await t.rollback();
            return res.status(404).json({ success: false, message: 'Order not found' });
        }

        if (!order.payment_gateway_details) {
            await t.rollback();
            return res.status(400).json({ success: false, message: 'This order was not paid using online payment gateway.' });
        }

        const details = JSON.parse(JSON.stringify(order.payment_gateway_details || {}));
        if (details.status === 'REFUNDED') {
            await t.rollback();
            return res.status(400).json({ success: false, message: 'This transaction is already fully refunded.' });
        }

        // Simulate Gateway Refund api call (Razorpay/Stripe/Paytm API)
        const gatewayProvider = details.provider || 'SANDBOX';
        const refundTxnId = 'ref_' + gatewayProvider.toLowerCase() + '_' + Math.random().toString(36).substring(2, 15);
        
        // Update payment_gateway_details
        details.refund_txn_id = refundTxnId;
        details.status = 'REFUNDED';
        details.refunded_at = new Date().toISOString();
        details.refund_reason = reason || 'Customer requested refund';
        details.refund_amount = refund_amount || order.net_amount;

        order.refund_status = 'REFUNDED';
        order.refund_payment_mode = order.payment_mode || 'GATEWAY';
        order.refund_paid_at = new Date();
        order.payment_gateway_details = details;
        order.changed('payment_gateway_details', true);
        
        await order.save({ transaction: t });

        // Record the refund in Cash Ledger
        const refundAmt = toAmount(refund_amount || order.net_amount);
        const { createLedgerEntry } = require('../../services/cashLedger.service');
        await createLedgerEntry({
            db: req.propertyDb,
            outlet_id,
            txn_date: new Date(),
            transaction_type: 'REFUND',
            reference_type: 'DELIVERY_ORDER',
            reference_id: order.id,
            reference_no: `ORD-${order.id}`,
            party_name: order.customer_name,
            payment_method: order.payment_mode || 'UPI',
            amount_out: refundAmt,
            notes: `Gateway Online Refund: ${gatewayProvider} TxID ${refundTxnId}. Reason: ${reason || 'Customer request'}`,
            created_by: req.user?.id || null,
            transaction: t
        });

        await t.commit();
        const orderJson = order.toJSON();
        orderJson.bill_no = await resolveOrderBillNo(req, orderJson, outlet_id);
        res.json({ success: true, message: `Gateway Refund via ${gatewayProvider} processed successfully.`, data: orderJson });
    } catch (error) {
        if (t && !t.finished) await t.rollback();
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.getOrderPendingRefunds = async (req, res) => {
    try {
        const { id } = req.params;
        const outlet_id = await resolveOutletId(req);
        if (!outlet_id) {
            return res.status(400).json({ success: false, message: 'outlet_id is required' });
        }

        const order = await req.propertyDb.models.customer_orders.findOne({
            where: { id, outlet_id }
        });

        if (!order) {
            return res.status(404).json({ success: false, message: 'Order not found' });
        }

        const sale = await req.propertyDb.models.sales_headers.findOne({
            where: {
                outlet_id,
                notes: `Auto-generated from delivery order #${order.id}`,
                is_deleted: false,
                is_latest: true
            }
        });

        if (!sale) {
            return res.json({ success: true, data: [] });
        }

        const refunds = await req.propertyDb.models.sales_refunds.findAll({
            where: {
                outlet_id,
                sale_id: sale.id,
                status: {
                    [req.propertyDb.Sequelize.Op.in]: ['PENDING', 'PARTIALLY_PAID']
                }
            },
            order: [['id', 'DESC']]
        });

        res.json({ success: true, data: refunds });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.refundGatewayViaCreditNote = async (req, res) => {
    const t = await req.propertyDb.transaction();
    try {
        const { id } = req.params;
        const { refund_id, reason } = req.body;
        const outlet_id = await resolveOutletId(req);

        if (!outlet_id) {
            await t.rollback();
            return res.status(400).json({ success: false, message: 'outlet_id is required' });
        }

        const order = await req.propertyDb.models.customer_orders.findOne({
            where: { id, outlet_id },
            transaction: t
        });

        if (!order) {
            await t.rollback();
            return res.status(404).json({ success: false, message: 'Order not found' });
        }

        if (!order.payment_gateway_details) {
            await t.rollback();
            return res.status(400).json({ success: false, message: 'This order was not paid using online payment gateway.' });
        }

        // Check if within 7 days
        const createdAt = new Date(order.created_at);
        const now = new Date();
        const differenceInDays = (now - createdAt) / (1000 * 60 * 60 * 24);
        if (differenceInDays > 7) {
            await t.rollback();
            return res.status(400).json({ success: false, message: 'Refund window is closed (7-day period expired).' });
        }

        const sale = await req.propertyDb.models.sales_headers.findOne({
            where: {
                outlet_id,
                notes: `Auto-generated from delivery order #${order.id}`,
                is_deleted: false,
                is_latest: true
            },
            transaction: t
        });

        if (!sale) {
            await t.rollback();
            return res.status(404).json({ success: false, message: 'Associated sale record not found.' });
        }

        const refund = await req.propertyDb.models.sales_refunds.findOne({
            where: { id: refund_id, sale_id: sale.id, outlet_id },
            transaction: t
        });

        if (!refund) {
            await t.rollback();
            return res.status(404).json({ success: false, message: 'Credit note not found.' });
        }

        if (refund.status === 'PAID') {
            await t.rollback();
            return res.status(400).json({ success: false, message: 'This credit note has already been fully paid.' });
        }

        const refundAmt = Number(refund.amount_pending) - Number(refund.amount_paid);
        if (refundAmt <= 0) {
            await t.rollback();
            return res.status(400).json({ success: false, message: 'Remaining refund amount is 0.' });
        }

        const details = JSON.parse(JSON.stringify(order.payment_gateway_details || {}));

        // Simulate Gateway Refund API call
        const gatewayProvider = details.provider || 'SANDBOX';
        const refundTxnId = 'ref_' + gatewayProvider.toLowerCase() + '_' + Math.random().toString(36).substring(2, 15);

        // Update sales_refunds (credit note)
        await refund.update({
            amount_paid: Number(refund.amount_paid) + refundAmt,
            status: 'PAID',
            payment_mode: 'GATEWAY',
            reference_no: refundTxnId,
            notes: reason || `Refunded via Gateway from credit note ${refund.refund_no}`,
            updated_by: req.user?.id || null
        }, { transaction: t });

        // Update payment_gateway_details of order
        details.refunds = details.refunds || [];
        details.refunds.push({
            refund_transaction_id: refundTxnId,
            amount: refundAmt,
            reason: reason || `Refunded via Credit Note ${refund.refund_no}`,
            refunded_at: new Date().toISOString(),
            credit_note_id: refund.id,
            credit_note_no: refund.refund_no,
            status: 'SUCCESS'
        });

        details.refund_txn_id = refundTxnId;
        details.refunded_at = new Date().toISOString();
        details.refund_reason = reason || `Refunded via Credit Note ${refund.refund_no}`;
        details.refund_amount = (Number(details.refund_amount) || 0) + refundAmt;

        const isFullyRefunded = Number(details.refund_amount) >= Number(order.net_amount);
        details.status = isFullyRefunded ? 'REFUNDED' : 'PARTIALLY_REFUNDED';

        order.refund_status = isFullyRefunded ? 'REFUNDED' : 'PARTIALLY_REFUNDED';
        order.refund_payment_mode = 'GATEWAY';
        order.refund_paid_at = new Date();
        order.payment_gateway_details = details;
        order.changed('payment_gateway_details', true);

        await order.save({ transaction: t });

        // Insert into Cash Ledger
        const { createLedgerEntry } = require('../../services/cashLedger.service');
        await createLedgerEntry({
            db: req.propertyDb,
            outlet_id,
            txn_date: new Date(),
            transaction_type: 'SALE_REFUND',
            reference_type: 'SALE_REFUND',
            reference_id: refund.id,
            reference_no: refund.refund_no,
            party_name: order.customer_name || 'Walk-in Customer',
            payment_method: 'GATEWAY',
            amount_out: refundAmt,
            notes: reason || `Refunded via Gateway against credit note ${refund.refund_no} for order #${order.id}`,
            created_by: req.user?.id || null,
            transaction: t
        });

        await t.commit();
        const orderJson = order.toJSON();
        orderJson.bill_no = await resolveOrderBillNo(req, orderJson, outlet_id);
        res.json({
            success: true,
            message: `Gateway refund of Rs. ${refundAmt.toFixed(2)} processed successfully.`,
            data: orderJson
        });
    } catch (error) {
        if (t && !t.finished) await t.rollback();
        res.status(500).json({ success: false, error: error.message });
    }
};
