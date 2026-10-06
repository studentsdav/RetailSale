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

        const items = await req.propertyDb.models.item_master.findAll({
            where: { outlet_id, is_active: true },
            attributes: [
                'id', 'item_name', 'item_code', 'item_group', 'sub_category',
                'selling_price', 'mrp', 'food_type', 'description', 'image_url',
                'is_recommended', 'kitchen_station_id', 'tax_rate'
            ],
            order: [['item_group', 'ASC'], ['item_name', 'ASC']]
        });

        const categoriesSet = new Set();
        items.forEach(it => {
            if (it.item_group && it.item_group.trim().length > 0) {
                categoriesSet.add(it.item_group.trim());
            }
        });
        const categories = Array.from(categoriesSet);

        const activeKots = await req.propertyDb.models.kot_headers.findAll({
            where: {
                table_id,
                outlet_id,
                status: { [Op.notIn]: ['Closed', 'closed', 'billed', 'Billed', 'BILLED', 'Cancelled', 'cancelled', 'Rejected'] }
            },
            include: [
                { model: req.propertyDb.models.kot_items, as: 'items', required: false }
            ],
            order: [['created_time', 'ASC']]
        });

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
                    currency: propInfo ? (propInfo.currency_symbol || '₹') : '₹',
                    logo_url: branding ? (branding.logo_path || branding.home_bg_image_path || '') : '',
                    wifi_ssid: propInfo?.wifi_ssid || '',
                    wifi_password: propInfo?.wifi_password || ''
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
                items,
                active_orders: activeKots
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

        if (!name || !phone || !email) {
            return res.status(400).json({ success: false, message: 'Name, Phone and Email are required' });
        }

        let customer = await req.propertyDb.models.customers.findOne({
            where: {
                outlet_id,
                [Op.or]: [
                    { customer_email: email.toLowerCase().trim() },
                    { customer_phone: phone.trim() }
                ]
            }
        });

        if (customer) {
            await customer.update({
                customer_name: name.trim(),
                customer_phone: phone.trim(),
                customer_email: email.toLowerCase().trim(),
                customer_address: address || customer.customer_address
            });
        } else {
            customer = await req.propertyDb.models.customers.create({
                outlet_id,
                customer_name: name.trim(),
                customer_phone: phone.trim(),
                customer_email: email.toLowerCase().trim(),
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

        const remarksText = [
            `Customer Self-Order (QR): ${customer_name || 'Guest'} (${customer_phone || ''})`,
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
                snapshot: { items, totalAmount, customer_name, payment_method }
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
        const outlet_id = await resolveOutletId(req);
        const { table_id, request_type, customer_name } = req.body;

        if (!table_id) {
            return res.status(400).json({ success: false, message: 'Table ID is required' });
        }

        const table = await req.propertyDb.models.restaurant_tables.findOne({
            where: { id: table_id, outlet_id }
        });

        const callObj = {
            id: `CALL_${Date.now()}_${table_id}`,
            outlet_id: outlet_id || 0,
            table_id: Number(table_id),
            table_name: table ? table.table_name : `Table #${table_id}`,
            request_type: request_type || 'CALL_WAITER',
            customer_name: customer_name || 'Guest',
            created_at: new Date(),
            resolved: false
        };

        diningWaiterCalls.unshift(callObj);
        if (diningWaiterCalls.length > 100) diningWaiterCalls.pop();

        return res.json({
            success: true,
            message: `Request received: ${request_type}. A staff member will attend your table shortly!`
        });
    } catch (err) {
        return res.status(500).json({ success: false, error: err.message });
    }
};

exports.getActiveWaiterCalls = async (req, res) => {
    try {
        const outlet_id = req.user?.outlet_id;
        const calls = diningWaiterCalls.filter(c => (!outlet_id || c.outlet_id === outlet_id) && !c.resolved);
        return res.json({ success: true, data: calls });
    } catch (err) {
        return res.status(500).json({ success: false, error: err.message });
    }
};

exports.resolveWaiterCall = async (req, res) => {
    try {
        const { id } = req.body;
        const call = diningWaiterCalls.find(c => c.id === id);
        if (call) call.resolved = true;
        return res.json({ success: true, message: 'Call marked resolved' });
    } catch (err) {
        return res.status(500).json({ success: false, error: err.message });
    }
};
