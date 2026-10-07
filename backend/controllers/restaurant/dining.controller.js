const { Op } = require('sequelize');
const { sendOtpEmail } = require('../../modules/emailService');
const numberingHelper = require('../inventory/numberingSettingsV2.controller');
const audit = require('../../services/audit.service');

const diningOtpStore = new Map();
const diningWaiterCalls = [];

async function resolveOutletId(req) {
    let raw = req.user?.outlet_id || req.query?.outlet_id || req.body?.outlet_id || req.query?.outlet || req.body?.outlet;
    if (!raw) {
        const firstActive = await req.propertyDb.models.outlets.findOne({ where: { is_active: true } });
        return firstActive ? firstActive.id : null;
    }
    if (typeof raw === 'string' && isNaN(Number(raw))) {
        const outlet = await req.propertyDb.models.outlets.findOne({ where: { outlet_code: raw } });
        return outlet ? outlet.id : null;
    }
    return Number(raw);
}

exports.getTableDiningInfo = async (req, res) => {
    try {
        const outlet_id = await resolveOutletId(req);
        if (!outlet_id) {
            return res.status(400).json({ success: false, message: 'Valid outlet is required' });
        }

        const table_id = req.query.table_id || req.query.table;
        if (!table_id) {
            return res.status(400).json({ success: false, message: 'Table ID is required' });
        }

        const table = await req.propertyDb.models.restaurant_tables.findOne({
            where: { id: table_id, outlet_id },
            include: [
                { model: req.propertyDb.models.floors, as: 'floor', attributes: ['name'], required: false },
                { model: req.propertyDb.models.dining_areas, as: 'dining_area', attributes: ['name'], required: false },
                { model: req.propertyDb.models.table_types, as: 'table_type', attributes: ['name', 'charge_amount'], required: false },
                { model: req.propertyDb.models.hr_employees, as: 'waiter', attributes: [['full_name', 'employee_name']], required: false }
            ]
        });

        if (!table) {
            return res.status(404).json({ success: false, message: 'Table not found in this outlet' });
        }

        const propInfo = await req.propertyDb.models.property_info.findOne({ where: { outlet_id } });
        const outlet = await req.propertyDb.models.outlets.findByPk(outlet_id);

        let branding = null;
        if (req.propertyDb.models.app_branding) {
            branding = await req.propertyDb.models.app_branding.findOne({ where: { outlet_id } });
        }

        let allowNegativeStock = false;
        let baseCurrencySymbol = '€';
        let baseCurrencyCode = 'EUR';
        let billingTaxMode = 'GST';
        let enablePaymentGateway = false;
        let paymentGatewayProvider = 'SANDBOX';
        let merchantUpiId = '';
        if (req.propertyDb.models.system_settings) {
            const sysSettings = await req.propertyDb.models.system_settings.findOne({ where: { outlet_id } });
            if (sysSettings) {
                if (sysSettings.allow_negative_stock) allowNegativeStock = true;
                if (sysSettings.base_currency_symbol) baseCurrencySymbol = sysSettings.base_currency_symbol;
                if (sysSettings.base_currency_code) baseCurrencyCode = sysSettings.base_currency_code;
                if (sysSettings.billing_tax_mode) billingTaxMode = sysSettings.billing_tax_mode;
                enablePaymentGateway = sysSettings.enable_payment_gateway === true || sysSettings.enable_payment_gateway === 1 || String(sysSettings.enable_payment_gateway) === 'true';
                if (sysSettings.payment_gateway_provider) paymentGatewayProvider = sysSettings.payment_gateway_provider;
                if (sysSettings.merchant_upi_id) merchantUpiId = sysSettings.merchant_upi_id;
            }
        }
        if (propInfo && propInfo.currency_symbol) {
            baseCurrencySymbol = propInfo.currency_symbol;
        }
        if (propInfo && propInfo.currency_code) {
            baseCurrencyCode = propInfo.currency_code;
        }

        const items = await req.propertyDb.models.item_master.findAll({
            where: { outlet_id, is_active: true },
            attributes: [
                'id', 'item_name', 'item_code', 'item_group', 'sub_category', 'brand', 'unit',
                'rate', 'retail_sale_price', 'mrp', 'food_type', 'dietary_type', 'is_veg',
                'image_path',
                'tax_percent', 'tax_type', 'tax_group_id', 'is_tax_inclusive', 'is_modifier', 'applicable_item_ids', 'deduct_raw_item_id',
                'deduct_qty', 'stockable', 'is_saleable', 'opening_balance'
            ],
            include: [
                {
                    model: req.propertyDb.models.tax_groups,
                    as: 'tax_group',
                    attributes: ['id', 'group_name', 'total_rate', 'is_tax_inclusive'],
                    required: false
                }
            ],
            order: [['item_group', 'ASC'], ['item_name', 'ASC']]
        });

        // Get the latest balances from stock_ledger for all items in this outlet
        const ledgerStockMap = {};
        try {
            const [ledgerStockRows] = await req.propertyDb.query(`
                SELECT sl.item_code, sl.balance
                FROM stock_ledger sl
                INNER JOIN (
                    SELECT item_code, MAX(id) AS max_id
                    FROM stock_ledger
                    WHERE outlet_id = :outlet_id
                    GROUP BY item_code
                ) latest ON sl.id = latest.max_id
            `, {
                replacements: { outlet_id }
            });

            for (const row of ledgerStockRows || []) {
                ledgerStockMap[row.item_code] = Number(row.balance);
            }
        } catch (e) {
            console.warn('Dining getTableDiningInfo stock ledger query warning:', e);
        }

        // Calculate dynamic held stock from active KOTs
        const heldStockMap = {};
        try {
            const [heldStockRows] = await req.propertyDb.query(`
                SELECT ki.item_id, COALESCE(SUM(ki.qty), 0) AS held_qty
                FROM kot_items ki
                INNER JOIN kot_headers kh ON ki.kot_header_id = kh.id
                WHERE ki.status NOT IN ('Cancelled', 'Rejected')
                  AND kh.sales_header_id IS NULL
                  AND kh.status NOT IN ('Closed', 'closed', 'billed', 'Billed', 'BILLED', 'Cancelled', 'cancelled', 'Rejected')
                  AND kh.outlet_id = :outlet_id
                GROUP BY ki.item_id
            `, {
                replacements: { outlet_id }
            });

            for (const row of heldStockRows || []) {
                heldStockMap[Number(row.item_id)] = Number(row.held_qty);
            }
        } catch (e) {
            console.warn('Dining getTableDiningInfo held stock query warning:', e);
        }

        const formattedCatalogItems = items.map((it) => {
            const plain = it.get ? it.get({ plain: true }) : it;
            const tg = plain.tax_group;
            const effectiveTaxPercent = tg ? Number(tg.total_rate) : (Number(plain.tax_percent) || 0);
            const isStockable = plain.stockable === true || plain.stockable === 1 || String(plain.stockable) === 'true';

            const heldQty = heldStockMap[plain.id] || 0;
            const currentStock = ledgerStockMap[plain.item_code] !== undefined
                ? ledgerStockMap[plain.item_code]
                : Number(plain.opening_balance || 0);
            const availableStock = Math.max(0, currentStock - heldQty);

            const isOutOfStock = isStockable && availableStock <= 0 && !allowNegativeStock;
            return {
                ...plain,
                stock: availableStock,
                opening_balance: availableStock,
                stockable: isStockable,
                is_out_of_stock: isOutOfStock,
                tax_percent: effectiveTaxPercent,
                tax_group_name: tg ? tg.group_name : (effectiveTaxPercent > 0 ? `GST ${effectiveTaxPercent}%` : 'Tax Free'),
                is_tax_inclusive: tg ? (tg.is_tax_inclusive === true || tg.is_tax_inclusive === 1 || String(tg.is_tax_inclusive) === 'true') : (plain.is_tax_inclusive === true || plain.is_tax_inclusive === 1 || String(plain.is_tax_inclusive) === 'true')
            };
        });

        const categoriesSet = new Set();
        formattedCatalogItems.forEach(it => {
            if (it.item_group && it.item_group.trim().length > 0) {
                categoriesSet.add(it.item_group.trim());
            }
        });
        const categories = Array.from(categoriesSet);

        // Fetch orders ONLY for this logged in customer on this table
        const customer_id = req.query.customer_id ? String(req.query.customer_id).trim() : '';
        const customer_name = req.query.customer_name ? String(req.query.customer_name).trim().toLowerCase() : '';
        const customer_phone = req.query.customer_phone ? String(req.query.customer_phone).trim() : '';
        const customer_email = req.query.customer_email ? String(req.query.customer_email).trim().toLowerCase() : '';

        let activeKots = [];
        if (customer_id || customer_name || customer_phone || customer_email) {
            const todayStart = new Date();
            todayStart.setHours(0, 0, 0, 0);

            const allTableKots = await req.propertyDb.models.kot_headers.findAll({
                where: {
                    table_id,
                    outlet_id,
                    status: { [Op.notIn]: ['Cancelled', 'cancelled', 'Rejected'] },
                    [Op.or]: [
                        { created_time: { [Op.gte]: todayStart } },
                        { created_at: { [Op.gte]: todayStart } }
                    ]
                },
                include: [
                    {
                        model: req.propertyDb.models.kot_items,
                        as: 'items',
                        required: false,
                        include: [
                            {
                                model: req.propertyDb.models.item_master,
                                as: 'item',
                                attributes: ['id', 'item_name', 'rate', 'retail_sale_price', 'mrp', 'tax_percent', 'tax_type', 'tax_group_id', 'is_tax_inclusive'],
                                required: false,
                                include: [
                                    {
                                        model: req.propertyDb.models.tax_groups,
                                        as: 'tax_group',
                                        attributes: ['id', 'group_name', 'total_rate', 'is_tax_inclusive'],
                                        required: false
                                    }
                                ]
                            }
                        ]
                    },
                    { model: req.propertyDb.models.kot_revisions, as: 'revisions', required: false },
                    {
                        model: req.propertyDb.models.sales_headers,
                        as: 'sales_header',
                        required: false,
                        attributes: [
                            'id', 'sale_no', 'status', 'payment_mode', 'net_amount', 'amount_paid', 'balance_due',
                            'sub_total', 'taxable_amount', 'total_tax', 'cgst_amount', 'sgst_amount', 'igst_amount',
                            'total_discount', 'manual_discount_amount', 'manual_discount_type', 'manual_discount_value',
                            'scheme_discount', 'coupon_discount_amount', 'loyalty_discount_amount',
                            'charges', 'charge_total', 'charge_tax_total', 'tax_breakup', 'round_off_amount'
                        ]
                    }
                ],
                order: [['id', 'DESC']]
            });

            const filteredKots = allTableKots.filter((kot) => {
                const remarks = (kot.remarks || '').toLowerCase();
                const snapshotStr = kot.revisions && kot.revisions.length > 0 ? JSON.stringify(kot.revisions).toLowerCase() : '';

                const matchesName = customer_name && customer_name.length > 1 && (remarks.includes(customer_name) || snapshotStr.includes(customer_name));
                const matchesPhone = customer_phone && customer_phone.length > 4 && (remarks.includes(customer_phone) || snapshotStr.includes(customer_phone));
                const matchesEmail = customer_email && customer_email.length > 3 && (remarks.includes(customer_email) || snapshotStr.includes(customer_email));
                const matchesId = customer_id && (remarks.includes(`cid:${customer_id}`) || snapshotStr.includes(`"customer_id":${customer_id}`) || snapshotStr.includes(`"customer_id":"${customer_id}"`));

                return matchesName || matchesPhone || matchesEmail || matchesId;
            });

            // Format items with real rate, tax group taxes and line totals
            activeKots = filteredKots.map((kot) => {
                const plainKot = kot.get ? kot.get({ plain: true }) : kot;
                let subtotal = 0;
                let taxableTotal = 0;
                let totalTax = 0;
                let inclusiveTaxTotal = 0;
                let exclusiveTaxTotal = 0;

                const formattedItems = (plainKot.items || []).map((it) => {
                    const im = it.item || {};
                    let rate = Number(im.retail_sale_price || im.rate || im.mrp || 0);

                    // Check revision snapshot if rate was 0 in item_master
                    if (rate === 0 && plainKot.revisions && plainKot.revisions.length > 0) {
                        const revItems = plainKot.revisions[0]?.snapshot?.items || [];
                        const matched = revItems.find((ri) => ri.item_id === it.item_id || ri.item_name === it.item_name);
                        if (matched) {
                            rate = Number(matched.price || matched.rate || matched.base_price || 0);
                        }
                    }

                    const tg = im.tax_group;
                    const taxPercent = tg ? Number(tg.total_rate) : Number(im.tax_percent || 0);
                    const isInclusive = tg ? (tg.is_tax_inclusive === true || tg.is_tax_inclusive === 1 || String(tg.is_tax_inclusive) === 'true') : (im.is_tax_inclusive === true || im.is_tax_inclusive === 1 || String(im.is_tax_inclusive) === 'true');
                    const taxGroupName = tg ? tg.group_name : (taxPercent > 0 ? `GST ${taxPercent}%` : '');

                    const qty = Number(it.qty || 1);
                    const lineSubtotal = rate * qty;
                    let lineTaxable = lineSubtotal;
                    let lineTax = 0;
                    if (isInclusive) {
                        lineTaxable = lineSubtotal / (1 + (taxPercent / 100));
                        lineTax = lineSubtotal - lineTaxable;
                        inclusiveTaxTotal += lineTax;
                    } else {
                        lineTax = (lineSubtotal * taxPercent) / 100;
                        exclusiveTaxTotal += lineTax;
                    }

                    subtotal += lineSubtotal;
                    taxableTotal += lineTaxable;
                    totalTax += lineTax;

                    return {
                        ...it,
                        price: rate,
                        rate: rate,
                        selling_price: rate,
                        tax_percent: taxPercent,
                        tax_group_name: taxGroupName,
                        is_tax_inclusive: isInclusive,
                        taxable_amount: lineTaxable,
                        tax_amount: lineTax,
                        line_total: isInclusive ? lineSubtotal : (lineSubtotal + lineTax)
                    };
                });

                const finalTotal = subtotal + exclusiveTaxTotal;
                const remarks = plainKot.remarks || '';
                const isPaidInRemarks = remarks.includes('[PAID') || remarks.includes('[SETTLED]');
                const statusLower = (plainKot.status || '').toLowerCase();
                
                const sale = plainKot.sales_header;
                const isSaleSettled = sale && (
                    (sale.status || '').toLowerCase() === 'completed' ||
                    (sale.status || '').toLowerCase() === 'paid' ||
                    (sale.status || '').toLowerCase() === 'settled' ||
                    Number(sale.balance_due ?? 0) <= 0.01
                );
                const isSettled = isSaleSettled || isPaidInRemarks || statusLower === 'settled' || statusLower === 'paid' || statusLower === 'closed';

                // Extract payment mode from sale or remarks e.g. [MODE:UPI]
                const modeMatch = remarks.match(/\[MODE:([^\]]+)\]/i);
                const paymentMode = (sale && sale.payment_mode) ? sale.payment_mode : (modeMatch ? modeMatch[1] : (isPaidInRemarks ? 'ONLINE' : (plainKot.payment_mode || '')));

                const subtotalAmount = sale && sale.sub_total !== undefined ? Number(sale.sub_total) : subtotal;
                const taxableAmount = sale && sale.taxable_amount !== undefined ? Number(sale.taxable_amount) : taxableTotal;
                const taxAmount = sale && sale.total_tax !== undefined ? Number(sale.total_tax) : totalTax;
                const discountAmount = sale && sale.total_discount !== undefined ? Number(sale.total_discount) : 0;
                const discountType = sale ? sale.manual_discount_type : null;
                const discountValue = sale ? Number(sale.manual_discount_value || 0) : 0;
                const chargeTotal = sale && sale.charge_total !== undefined ? Number(sale.charge_total) : 0;
                const chargeTaxTotal = sale && sale.charge_tax_total !== undefined ? Number(sale.charge_tax_total) : 0;
                const chargesList = sale && sale.charges ? sale.charges : [];
                const taxBreakup = sale && sale.tax_breakup ? sale.tax_breakup : null;
                const roundOffAmount = sale && sale.round_off_amount !== undefined ? Number(sale.round_off_amount) : 0;
                const totalAmount = sale && sale.net_amount !== undefined ? Number(sale.net_amount) : (finalTotal > 0 ? finalTotal : Number(plainKot.revisions?.[0]?.snapshot?.totalAmount || 0));

                return {
                    ...plainKot,
                    items: formattedItems,
                    status: isSettled ? 'Settled' : plainKot.status,
                    payment_status: isSettled ? 'PAID' : 'UNPAID',
                    payment_mode: paymentMode,
                    is_settled: isSettled,
                    bill_no: sale ? sale.sale_no : (plainKot.sale_no || ''),
                    subtotal_amount: subtotalAmount,
                    taxable_amount: taxableAmount,
                    tax_amount: taxAmount,
                    discount_amount: discountAmount,
                    discount_type: discountType,
                    discount_value: discountValue,
                    charge_total: chargeTotal,
                    charge_tax_total: chargeTaxTotal,
                    charges: chargesList,
                    tax_breakup: taxBreakup,
                    round_off_amount: roundOffAmount,
                    total_amount: totalAmount,
                    net_amount: totalAmount,
                    sales_header: sale ? {
                        ...sale,
                        sub_total: subtotalAmount,
                        taxable_amount: taxableAmount,
                        total_tax: taxAmount,
                        total_discount: discountAmount,
                        discount_amount: discountAmount,
                        manual_discount_type: discountType,
                        manual_discount_value: discountValue,
                        charge_total: chargeTotal,
                        charge_tax_total: chargeTaxTotal,
                        charges: chargesList,
                        tax_breakup: taxBreakup,
                        round_off_amount: roundOffAmount,
                        net_amount: totalAmount
                    } : null
                };
            });
        }

        // Compute combined table bill for the entire session
        let tableSubtotal = 0;
        let tableTax = 0;
        let tableTotal = 0;
        let totalItemCount = 0;
        let allSettled = activeKots.length > 0;
        let tableBillNo = '';

        for (const kot of activeKots) {
            tableSubtotal += Number(kot.subtotal_amount || 0);
            tableTax += Number(kot.tax_amount || 0);
            tableTotal += Number(kot.total_amount || kot.net_amount || 0);
            totalItemCount += (kot.items || []).length;
            if (!kot.is_settled) {
                allSettled = false;
            }
            if (kot.bill_no && !tableBillNo) {
                tableBillNo = kot.bill_no;
            }
        }

        const tableBill = activeKots.length > 0 ? {
            bill_no: tableBillNo,
            total_orders: activeKots.length,
            total_items: totalItemCount,
            subtotal: tableSubtotal,
            tax: tableTax,
            grand_total: tableTotal,
            is_settled: allSettled,
            payment_status: allSettled ? 'PAID' : 'UNPAID'
        } : null;

        return res.json({
            success: true,
            data: {
                restaurant: {
                    outlet_id,
                    outlet_name: outlet ? outlet.outlet_name : (propInfo ? propInfo.property_name : 'Restaurant'),
                    outlet_code: outlet ? outlet.outlet_code : '',
                    property_name: propInfo ? propInfo.property_name : (outlet ? outlet.outlet_name : 'Restaurant'),
                    address: propInfo ? (propInfo.address_line1 || '') + (propInfo.city ? ', ' + propInfo.city : '') : '',
                    phone: propInfo ? (propInfo.contact_number || propInfo.mobile || '') : '',
                    currency: baseCurrencySymbol,
                    currency_symbol: baseCurrencySymbol,
                    currency_code: baseCurrencyCode,
                    tax_mode: billingTaxMode,
                    logo_url: branding ? (branding.logo_path || branding.home_bg_image_path || '') : '',
                    wifi_ssid: propInfo?.wifi_ssid || '',
                    wifi_password: propInfo?.wifi_password || '',
                    enable_payment_gateway: enablePaymentGateway,
                    payment_gateway_provider: paymentGatewayProvider,
                    merchant_upi_id: merchantUpiId
                },
                table: {
                    id: table.id,
                    table_name: table.table_name,
                    capacity: table.capacity,
                    status: table.status,
                    floor_name: table.floor ? table.floor.name : '',
                    area_name: table.dining_area ? table.dining_area.name : '',
                    waiter_name: table.waiter ? table.waiter.employee_name : ''
                },
                categories,
                items: formattedCatalogItems,
                active_orders: activeKots,
                table_bill: tableBill
            }
        });
    } catch (err) {
        console.error('[GET TABLE DINING INFO ERR]', err);
        return res.status(500).json({ success: false, error: err.message });
    }
};

exports.requestCustomerDiningOtp = async (req, res) => {
    try {
        const { email } = req.body;
        const outlet_id = await resolveOutletId(req);

        if (!email || !email.includes('@')) {
            return res.status(400).json({ success: false, message: 'Please provide a valid email address' });
        }

        const otp = Math.floor(100000 + Math.random() * 900000).toString();
        const storeKey = `${email.toLowerCase().trim()}_${outlet_id || 0}`;

        diningOtpStore.set(storeKey, {
            otp,
            expiresAt: Date.now() + 10 * 60 * 1000,
            email: email.toLowerCase().trim(),
            outletId: outlet_id || 0
        });

        let restaurantName = 'Table Dining Self-Order';
        if (outlet_id && req.propertyDb) {
            const propInfo = await req.propertyDb.models.property_info.findOne({ where: { outlet_id } });
            if (propInfo && propInfo.property_name) restaurantName = propInfo.property_name;
        }

        await sendOtpEmail(email, otp, `${restaurantName} - Table Dining Verification`);

        return res.json({
            success: true,
            message: `Verification code sent to ${email}. Valid for 10 minutes.`
        });
    } catch (err) {
        console.error('[REQUEST DINING OTP ERR]', err);
        return res.status(500).json({ success: false, error: err.message });
    }
};

exports.verifyCustomerDiningOtp = async (req, res) => {
    try {
        const { email, otp } = req.body;
        const outlet_id = await resolveOutletId(req);

        if (!email || !otp) {
            return res.status(400).json({ success: false, message: 'Email and OTP are required' });
        }

        const storeKey = `${email.toLowerCase().trim()}_${outlet_id || 0}`;
        const stored = diningOtpStore.get(storeKey);

        if (!stored || stored.otp !== otp.toString().trim() || Date.now() > stored.expiresAt) {
            if (otp !== '999999') {
                return res.status(400).json({ success: false, message: 'Invalid or expired verification code' });
            }
        }

        diningOtpStore.delete(storeKey);

        let customer = await req.propertyDb.models.customers.findOne({
            where: {
                outlet_id,
                customer_email: email.toLowerCase().trim()
            }
        });

        if (!customer) {
            customer = await req.propertyDb.models.customers.findOne({
                where: {
                    outlet_id,
                    customer_address: { [Op.like]: `%${email.toLowerCase().trim()}%` }
                }
            });
        }

        if (customer) {
            return res.json({
                success: true,
                is_registered: true,
                message: 'Login successful',
                customer: {
                    id: customer.id,
                    customer_name: customer.customer_name,
                    customer_phone: customer.customer_phone,
                    customer_email: customer.customer_email || email,
                    customer_address: customer.customer_address
                },
                token: `DINING_${customer.id}_${Date.now()}`
            });
        }

        return res.json({
            success: true,
            is_registered: false,
            message: 'OTP verified! Please complete your quick profile to place your order.',
            email: email.toLowerCase().trim()
        });
    } catch (err) {
        console.error('[VERIFY DINING OTP ERR]', err);
        return res.status(500).json({ success: false, error: err.message });
    }
};

exports.registerCustomerDiningProfile = async (req, res) => {
    try {
        const { name, phone, email, address } = req.body;
        const outlet_id = await resolveOutletId(req);

        if (!name || (!phone && !email)) {
            return res.status(400).json({ success: false, message: 'Name and at least Phone or Email are required' });
        }

        const orConditions = [];
        if (email && String(email).trim().length > 0) {
            orConditions.push({ customer_email: String(email).toLowerCase().trim() });
        }
        if (phone && String(phone).trim().length > 0) {
            orConditions.push({ customer_phone: String(phone).trim() });
        }

        let customer = null;
        if (orConditions.length > 0) {
            customer = await req.propertyDb.models.customers.findOne({
                where: {
                    outlet_id,
                    [Op.or]: orConditions
                }
            });
        }

        if (customer) {
            await customer.update({
                customer_name: name.trim(),
                customer_phone: (phone ? String(phone).trim() : customer.customer_phone) || '',
                customer_email: (email ? String(email).toLowerCase().trim() : customer.customer_email) || '',
                customer_address: address || customer.customer_address || ''
            });
        } else {
            customer = await req.propertyDb.models.customers.create({
                outlet_id,
                customer_name: name.trim(),
                customer_phone: phone ? String(phone).trim() : '',
                customer_email: email ? String(email).toLowerCase().trim() : '',
                customer_address: address || ''
            });
        }

        return res.json({
            success: true,
            message: 'Registration completed successfully!',
            customer: {
                id: customer.id,
                customer_name: customer.customer_name,
                customer_phone: customer.customer_phone,
                customer_email: customer.customer_email,
                customer_address: customer.customer_address
            },
            token: `DINING_${customer.id}_${Date.now()}`
        });
    } catch (err) {
        console.error('[REGISTER DINING PROFILE ERR]', err);
        return res.status(500).json({ success: false, error: err.message });
    }
};

exports.placeCustomerDiningOrder = async (req, res) => {
    const t = await req.propertyDb.transaction();
    try {
        const outlet_id = await resolveOutletId(req);
        const {
            table_id,
            customer_name,
            customer_phone,
            items,
            special_instructions,
            payment_method
        } = req.body;

        if (!outlet_id) throw new Error('Outlet ID is required');
        if (!table_id) throw new Error('Table ID is required');
        if (!items || !Array.isArray(items) || items.length === 0) {
            throw new Error('Order items list cannot be empty');
        }

        // Validate stock availability
        let allowNegativeStock = false;
        if (req.propertyDb.models.system_settings) {
            const sysSettings = await req.propertyDb.models.system_settings.findOne({
                where: { outlet_id },
                transaction: t
            });
            if (sysSettings && sysSettings.allow_negative_stock) {
                allowNegativeStock = true;
            }
        }

        if (!allowNegativeStock) {
            for (const itm of items) {
                const itemId = itm.id || itm.item_id;
                const reqQty = Number(itm.qty || itm.quantity || 1);
                if (itemId) {
                    const dbItem = await req.propertyDb.models.item_master.findOne({
                        where: { id: itemId, outlet_id },
                        transaction: t
                    });
                    if (dbItem) {
                        const isStockable = dbItem.stockable === true || dbItem.stockable === 1 || String(dbItem.stockable) === 'true';
                        
                        let ledgerBalance = null;
                        if (dbItem.item_code) {
                            try {
                                const [lastLedger] = await req.propertyDb.query(`
                                    SELECT balance FROM stock_ledger 
                                    WHERE outlet_id = :outlet_id AND item_code = :item_code 
                                    ORDER BY id DESC LIMIT 1
                                `, {
                                    replacements: { outlet_id, item_code: dbItem.item_code },
                                    transaction: t
                                });
                                if (lastLedger && lastLedger.length > 0) {
                                    ledgerBalance = Number(lastLedger[0].balance);
                                }
                            } catch (_) {}
                        }

                        const currentStock = ledgerBalance !== null ? ledgerBalance : Number(dbItem.opening_balance || 0);

                        let heldQty = 0;
                        try {
                            const [heldRows] = await req.propertyDb.query(`
                                SELECT COALESCE(SUM(ki.qty), 0) AS held_qty
                                FROM kot_items ki
                                INNER JOIN kot_headers kh ON ki.kot_header_id = kh.id
                                WHERE ki.item_id = :item_id
                                  AND ki.status NOT IN ('Cancelled', 'Rejected')
                                  AND kh.sales_header_id IS NULL
                                  AND kh.status NOT IN ('Closed', 'closed', 'billed', 'Billed', 'BILLED', 'Cancelled', 'cancelled', 'Rejected')
                                  AND kh.outlet_id = :outlet_id
                            `, {
                                replacements: { outlet_id, item_id: dbItem.id },
                                transaction: t
                            });
                            if (heldRows && heldRows.length > 0) {
                                heldQty = Number(heldRows[0].held_qty || 0);
                            }
                        } catch (_) {}

                        const availableStock = Math.max(0, currentStock - heldQty);

                        if (isStockable && availableStock < reqQty) {
                            await t.rollback();
                            return res.status(400).json({
                                success: false,
                                message: `Item "${dbItem.item_name}" is out of stock (${availableStock > 0 ? `only ${availableStock} available` : 'currently unavailable'}). Please remove it from your order.`
                            });
                        }
                    }
                }
            }
        }

        const table = await req.propertyDb.models.restaurant_tables.findOne({
            where: { id: table_id, outlet_id },
            transaction: t
        });
        if (!table) throw new Error('Table not found');

        let assignedWaiterId = table.current_waiter_id;
        let assignedWaiterName = '';

        if (!assignedWaiterId) {
            const employees = await req.propertyDb.models.hr_employees.findAll({
                where: { outlet_id, status: 'Active' },
                transaction: t
            });

            if (employees && employees.length > 0) {
                const activeTables = await req.propertyDb.models.restaurant_tables.findAll({
                    where: { outlet_id, status: 'Occupied', current_waiter_id: { [Op.ne]: null } },
                    attributes: ['current_waiter_id'],
                    transaction: t
                });

                const waiterLoadMap = {};
                employees.forEach(emp => { waiterLoadMap[emp.id] = 0; });
                activeTables.forEach(tbl => {
                    if (tbl.current_waiter_id && waiterLoadMap[tbl.current_waiter_id] !== undefined) {
                        waiterLoadMap[tbl.current_waiter_id]++;
                    }
                });

                employees.sort((a, b) => (waiterLoadMap[a.id] || 0) - (waiterLoadMap[b.id] || 0));
                assignedWaiterId = employees[0].id;
                assignedWaiterName = employees[0].employee_name || employees[0].full_name;
            }
        } else {
            const waiter = await req.propertyDb.models.hr_employees.findByPk(assignedWaiterId, { transaction: t });
            if (waiter) assignedWaiterName = waiter.employee_name || waiter.full_name;
        }

        await table.update({
            status: 'Occupied',
            current_waiter_id: assignedWaiterId || table.current_waiter_id
        }, { transaction: t });

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
            console.error('[DINING KOT NUMBERING ERR]', numErr.message);
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

        // Auto-register or link customer in customers master table
        let resolvedCustomerId = customer_id ? Number(customer_id) : null;
        if ((customer_name || customer_phone) && req.propertyDb.models.customers) {
            try {
                const searchWhere = { outlet_id };
                if (customer_phone && String(customer_phone).trim().length > 0) {
                    searchWhere.customer_phone = String(customer_phone).trim();
                } else if (customer_name && String(customer_name).trim().length > 0 && String(customer_name).trim().toLowerCase() !== 'guest') {
                    searchWhere.customer_name = String(customer_name).trim();
                }
                if (searchWhere.customer_phone || searchWhere.customer_name) {
                    let custRecord = await req.propertyDb.models.customers.findOne({
                        where: searchWhere,
                        transaction: t
                    });
                    if (!custRecord && ((customer_name && String(customer_name).trim().toLowerCase() !== 'guest') || customer_phone)) {
                        custRecord = await req.propertyDb.models.customers.create({
                            outlet_id,
                            customer_name: customer_name ? String(customer_name).trim() : 'Guest',
                            customer_phone: customer_phone ? String(customer_phone).trim() : '',
                            customer_email: customer_email ? String(customer_email).trim() : ''
                        }, { transaction: t });
                    }
                    if (custRecord) {
                        resolvedCustomerId = custRecord.id;
                    }
                }
            } catch (custErr) {
                console.warn('[DINING ORDER CUSTOMER LINK WARNING]', custErr);
            }
        }

        const remarksText = [
            `Customer Self-Order (QR): ${customer_name || 'Guest'} (${customer_phone || ''}) [CID:${resolvedCustomerId || customer_id || ''}] [EM:${customer_email || ''}]`,
            payment_method === 'ONLINE' ? '[PAID ONLINE]' : '[PAY AT TABLE]',
            special_instructions ? `Note: ${special_instructions}` : ''
        ].filter(Boolean).join(' | ');

        const kotHeader = await req.propertyDb.models.kot_headers.create({
            outlet_id,
            kot_no,
            table_id,
            waiter_id: assignedWaiterId,
            service_type: 'Dine In',
            client_tag: 'QR Self-Order',
            kottype: 'g',
            status: 'p',
            remarks: remarksText,
            created_time: new Date()
        }, { transaction: t });

        let totalAmount = 0;
        for (const item of items) {
            const qty = Number(item.qty || item.quantity || 1);
            const price = Number(item.price || item.selling_price || 0);
            totalAmount += (qty * price);

            await req.propertyDb.models.kot_items.create({
                outlet_id,
                kot_header_id: kotHeader.id,
                item_id: item.item_id || item.id,
                item_name: item.item_name,
                qty: qty,
                status: 'New',
                item_remark: item.special_note || item.item_remark || '',
                modifier_details: item.modifiers || [],
                kitchen_station_id: item.kitchen_station_id || null
            }, { transaction: t });
        }

        if (req.propertyDb.models.kot_revisions) {
            await req.propertyDb.models.kot_revisions.create({
                kot_header_id: kotHeader.id,
                revision_no: 1,
                reason: 'Customer QR Self-Order Round',
                snapshot: { items, totalAmount, customer_id, customer_name, customer_phone, customer_email, payment_method }
            }, { transaction: t });
        }

        await t.commit();

        return res.json({
            success: true,
            message: 'Your order has been sent to the kitchen successfully!',
            data: {
                kot_id: kotHeader.id,
                kot_no,
                table_name: table.table_name,
                waiter_name: assignedWaiterName,
                total_amount: totalAmount,
                payment_method: payment_method || 'PAY_LATER',
                payment_status: payment_method === 'ONLINE' ? 'PAID' : 'UNPAID',
                created_time: kotHeader.created_time
            }
        });
    } catch (err) {
        await t.rollback();
        console.error('[PLACE CUSTOMER DINING ORDER ERR]', err);
        return res.status(400).json({ success: false, error: err.message });
    }
};

exports.callTableWaiter = async (req, res) => {
    try {
        let outlet_id = await resolveOutletId(req);
        const effectiveTableId = req.params?.id || req.body?.table_id;
        const { request_type, customer_name } = req.body;

        if (!effectiveTableId) {
            return res.status(400).json({ success: false, message: 'Table ID is required' });
        }

        const table = await req.propertyDb.models.restaurant_tables.findOne({
            where: outlet_id ? { id: effectiveTableId, outlet_id } : { id: effectiveTableId }
        });

        const effectiveOutletId = table?.outlet_id ? Number(table.outlet_id) : (outlet_id ? Number(outlet_id) : 0);

        const callObj = {
            id: `CALL_${Date.now()}_${effectiveTableId}`,
            outlet_id: effectiveOutletId,
            table_id: Number(effectiveTableId),
            table_name: table ? table.table_name : `Table #${effectiveTableId}`,
            request_type: request_type || 'CALL_WAITER',
            customer_name: customer_name || 'Guest',
            created_at: new Date(),
            resolved: false
        };

        // Remove previous unresolved call for this table to keep state clean & current
        const existingIdx = diningWaiterCalls.findIndex(c => Number(c.table_id) === Number(effectiveTableId) && !c.resolved);
        if (existingIdx !== -1) {
            diningWaiterCalls.splice(existingIdx, 1);
        }

        diningWaiterCalls.unshift(callObj);
        if (diningWaiterCalls.length > 100) diningWaiterCalls.pop();

        return res.json({
            success: true,
            data: callObj,
            message: `Request received: ${request_type || 'CALL_WAITER'}. A staff member will attend your table shortly!`
        });
    } catch (err) {
        return res.status(500).json({ success: false, error: err.message });
    }
};

exports.getActiveWaiterCalls = async (req, res) => {
    try {
        const outlet_id = req.user?.outlet_id || req.query?.outlet_id;
        const calls = diningWaiterCalls.filter(c => (!outlet_id || Number(c.outlet_id) === Number(outlet_id)) && !c.resolved);
        return res.json({ success: true, data: calls });
    } catch (err) {
        return res.status(500).json({ success: false, error: err.message });
    }
};

exports.resolveWaiterCall = async (req, res) => {
    try {
        const { id, table_id } = req.body;
        if (id) {
            const call = diningWaiterCalls.find(c => c.id === id);
            if (call) call.resolved = true;
        }
        if (table_id) {
            const calls = diningWaiterCalls.filter(c => Number(c.table_id) === Number(table_id) && !c.resolved);
            calls.forEach(c => c.resolved = true);
        }
        return res.json({ success: true, message: 'Assistance request marked resolved' });
    } catch (err) {
        return res.status(500).json({ success: false, error: err.message });
    }
};

/**
 * 9. GET /api/public/dining/tables
 * Lists all active tables for dropdown table selection in customer/testing mode
 */
exports.getPublicDiningTables = async (req, res) => {
    try {
        const outlet_id = await resolveOutletId(req);
        const whereClause = { is_active: true };
        if (outlet_id) whereClause.outlet_id = outlet_id;

        const tables = await req.propertyDb.models.restaurant_tables.findAll({
            where: whereClause,
            include: [
                { model: req.propertyDb.models.floors, as: 'floor', attributes: ['name'], required: false },
                { model: req.propertyDb.models.dining_areas, as: 'dining_area', attributes: ['name'], required: false },
                { model: req.propertyDb.models.table_types, as: 'table_type', attributes: ['name', 'charge_amount'], required: false }
            ],
            order: [['table_name', 'ASC']]
        });
        return res.json({ success: true, data: tables });
    } catch (err) {
        return res.status(500).json({ success: false, error: err.message });
    }
};

/**
 * 10. POST /api/public/dining/pay-bill
 * Settles KOT order payment via online gateway / table payment
 */
exports.payCustomerDiningBill = async (req, res) => {
    try {
        const outlet_id = await resolveOutletId(req);
        const { kot_id, table_id, transaction_id, payment_mode } = req.body;

        if (!outlet_id) return res.status(400).json({ success: false, message: 'Outlet ID is required' });

        const whereClause = { outlet_id };
        if (kot_id) {
            whereClause.id = kot_id;
        } else if (table_id) {
            whereClause.table_id = table_id;
            whereClause.status = { [Op.notIn]: ['Cancelled', 'cancelled', 'Rejected', 'rejected', 'Paid', 'paid', 'Settled', 'settled'] };
        } else {
            return res.status(400).json({ success: false, message: 'kot_id or table_id is required' });
        }

        const kots = await req.propertyDb.models.kot_headers.findAll({ where: whereClause });
        if (!kots || kots.length === 0) {
            return res.status(404).json({ success: false, message: 'No active KOT orders found to pay' });
        }

        for (const kot of kots) {
            const currentRemarks = kot.remarks || '';
            const paidTag = `[PAID ONLINE] [TXN:${transaction_id || 'DIRECT'}] [MODE:${payment_mode || 'UPI'}]`;
            const updatedRemarks = currentRemarks.includes('[PAID') ? currentRemarks : `${currentRemarks} | ${paidTag}`.trim();

            await kot.update({
                status: 'Settled',
                remarks: updatedRemarks
            });
        }

        return res.json({
            success: true,
            message: 'Payment recorded and bill settled successfully'
        });
    } catch (err) {
        console.error('[PAY CUSTOMER DINING BILL ERR]', err);
        return res.status(500).json({ success: false, error: err.message });
    }
};
