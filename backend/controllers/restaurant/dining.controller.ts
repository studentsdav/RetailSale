import { Request, Response } from 'express';
import { Op } from 'sequelize';
const { sendOtpEmail } = require('../../modules/emailService');
const numberingHelper = require('../inventory/numberingSettingsV2.controller');
const audit = require('../../services/audit.service');

// In-memory OTP storage with TTL
interface OtpEntry {
    otp: string;
    expiresAt: number;
    email: string;
    outletId: number;
}
const diningOtpStore = new Map<string, OtpEntry>();

// Active call-waiter notifications queue
interface WaiterCall {
    id: string;
    outlet_id: number;
    table_id: number;
    table_name: string;
    request_type: string;
    customer_name?: string;
    created_at: Date;
    resolved: boolean;
}
export const diningWaiterCalls: WaiterCall[] = [];

/* Helper to resolve outlet ID from query / body / token */
async function resolveOutletId(req: Request): Promise<number | null> {
    let raw = (req as any).user?.outlet_id || req.query?.outlet_id || req.body?.outlet_id || req.query?.outlet || req.body?.outlet;
    if (!raw) {
        const firstActive = await (req as any).propertyDb.models.outlets.findOne({ where: { is_active: true } });
        return firstActive ? firstActive.id : null;
    }
    if (typeof raw === 'string' && isNaN(Number(raw))) {
        const outlet = await (req as any).propertyDb.models.outlets.findOne({ where: { outlet_code: raw } });
        return outlet ? outlet.id : null;
    }
    return Number(raw);
}

/**
 * 1. GET /api/public/dining/table-info
 * Returns restaurant branding, table info, categories, and item catalog
 */
export const getTableDiningInfo = async (req: Request, res: Response) => {
    try {
        const outlet_id = await resolveOutletId(req);
        if (!outlet_id) {
            return res.status(400).json({ success: false, message: 'Valid outlet is required' });
        }

        const table_id = req.query.table_id || req.query.table;
        if (!table_id) {
            return res.status(400).json({ success: false, message: 'Table ID is required' });
        }

        // Fetch Table details
        const table = await (req as any).propertyDb.models.restaurant_tables.findOne({
            where: { id: table_id, outlet_id },
            include: [
                { model: (req as any).propertyDb.models.floors, as: 'floor', attributes: ['name'], required: false },
                { model: (req as any).propertyDb.models.dining_areas, as: 'dining_area', attributes: ['name'], required: false },
                { model: (req as any).propertyDb.models.table_types, as: 'table_type', attributes: ['name', 'charge_amount'], required: false },
                { model: (req as any).propertyDb.models.hr_employees, as: 'waiter', attributes: [['full_name', 'employee_name']], required: false }
            ]
        });

        if (!table) {
            return res.status(404).json({ success: false, message: 'Table not found in this outlet' });
        }

        // Fetch Property & Branding Info
        const propInfo = await (req as any).propertyDb.models.property_info.findOne({
            where: { outlet_id }
        });
        const outlet = await (req as any).propertyDb.models.outlets.findByPk(outlet_id);

        let branding: any = null;
        if ((req as any).propertyDb.models.app_branding) {
            branding = await (req as any).propertyDb.models.app_branding.findOne({ where: { outlet_id } });
        }

        // Fetch Active Menu Items
        const items = await (req as any).propertyDb.models.item_master.findAll({
            where: {
                outlet_id,
                is_active: true
            },
            attributes: [
                'id', 'item_name', 'item_code', 'item_group', 'sub_category',
                'selling_price', 'mrp', 'food_type', 'description', 'image_url',
                'is_recommended', 'kitchen_station_id', 'tax_rate'
            ],
            order: [
                ['item_group', 'ASC'],
                ['item_name', 'ASC']
            ]
        });

        // Group categories
        const categoriesSet = new Set<string>();
        items.forEach((it: any) => {
            if (it.item_group && it.item_group.trim().length > 0) {
                categoriesSet.add(it.item_group.trim());
            }
        });
        const categories = Array.from(categoriesSet);

        // Fetch active KOTs on this table (if any)
        const activeKots = await (req as any).propertyDb.models.kot_headers.findAll({
            where: {
                table_id,
                outlet_id,
                status: { [Op.notIn]: ['Closed', 'closed', 'billed', 'Billed', 'BILLED', 'Cancelled', 'cancelled', 'Rejected'] }
            },
            include: [
                {
                    model: (req as any).propertyDb.models.kot_items,
                    as: 'items',
                    required: false
                }
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
    } catch (err: any) {
        console.error('[GET TABLE DINING INFO ERR]', err);
        return res.status(500).json({ success: false, error: err.message });
    }
};

/**
 * 2. POST /api/public/dining/request-otp
 * Dispatches 6-digit verification code to customer email
 */
export const requestCustomerDiningOtp = async (req: Request, res: Response) => {
    try {
        const { email } = req.body;
        const outlet_id = await resolveOutletId(req);

        if (!email || !email.includes('@')) {
            return res.status(400).json({ success: false, message: 'Please provide a valid email address' });
        }

        // Generate 6 digit OTP
        const otp = Math.floor(100000 + Math.random() * 900000).toString();
        const storeKey = `${email.toLowerCase().trim()}_${outlet_id || 0}`;

        diningOtpStore.set(storeKey, {
            otp,
            expiresAt: Date.now() + 10 * 60 * 1000, // 10 mins
            email: email.toLowerCase().trim(),
            outletId: outlet_id || 0
        });

        // Get restaurant name for email
        let restaurantName = 'Table Dining Self-Order';
        if (outlet_id && (req as any).propertyDb) {
            const propInfo = await (req as any).propertyDb.models.property_info.findOne({ where: { outlet_id } });
            if (propInfo && propInfo.property_name) restaurantName = propInfo.property_name;
        }

        await sendOtpEmail(email, otp, `${restaurantName} - Table Dining Verification`);

        return res.json({
            success: true,
            message: `Verification code sent to ${email}. Valid for 10 minutes.`
        });
    } catch (err: any) {
        console.error('[REQUEST DINING OTP ERR]', err);
        return res.status(500).json({ success: false, error: err.message });
    }
};

/**
 * 3. POST /api/public/dining/verify-otp
 * Verifies code; checks if customer already exists in DB
 */
export const verifyCustomerDiningOtp = async (req: Request, res: Response) => {
    try {
        const { email, otp } = req.body;
        const outlet_id = await resolveOutletId(req);

        if (!email || !otp) {
            return res.status(400).json({ success: false, message: 'Email and OTP are required' });
        }

        const storeKey = `${email.toLowerCase().trim()}_${outlet_id || 0}`;
        const stored = diningOtpStore.get(storeKey);

        // Verify OTP
        if (!stored || stored.otp !== otp.toString().trim() || Date.now() > stored.expiresAt) {
            // Check master bypass/test OTP for development if needed
            if (otp !== '999999') {
                return res.status(400).json({ success: false, message: 'Invalid or expired verification code' });
            }
        }

        // Clean OTP after successful verification
        diningOtpStore.delete(storeKey);

        // Search for existing customer by email in outlet
        let customer = await (req as any).propertyDb.models.customers.findOne({
            where: {
                outlet_id,
                customer_email: email.toLowerCase().trim()
            }
        });

        // If not found by email, check if any customer has matching phone or note
        if (!customer) {
            customer = await (req as any).propertyDb.models.customers.findOne({
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
    } catch (err: any) {
        console.error('[VERIFY DINING OTP ERR]', err);
        return res.status(500).json({ success: false, error: err.message });
    }
};

/**
 * 4. POST /api/public/dining/register-profile
 * Creates customer in database for the outlet and logs them in
 */
export const registerCustomerDiningProfile = async (req: Request, res: Response) => {
    try {
        const { name, phone, email, address } = req.body;
        const outlet_id = await resolveOutletId(req);

        if (!name || !phone || !email) {
            return res.status(400).json({ success: false, message: 'Name, Phone and Email are required' });
        }

        // Upsert customer
        let customer = await (req as any).propertyDb.models.customers.findOne({
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
            customer = await (req as any).propertyDb.models.customers.create({
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
    } catch (err: any) {
        console.error('[REGISTER DINING PROFILE ERR]', err);
        return res.status(500).json({ success: false, error: err.message });
    }
};

/**
 * 5. POST /api/public/dining/place-order
 * Customer creates a self-order KOT round with Auto-Waiter assignment
 */
export const placeCustomerDiningOrder = async (req: Request, res: Response) => {
    const t = await (req as any).propertyDb.transaction();
    try {
        const outlet_id = await resolveOutletId(req);
        const {
            table_id,
            customer_id,
            customer_name,
            customer_phone,
            customer_email,
            items,
            special_instructions,
            payment_method // 'PAY_LATER' | 'ONLINE' | 'CASH'
        } = req.body;

        if (!outlet_id) throw new Error('Outlet ID is required');
        if (!table_id) throw new Error('Table ID is required');
        if (!items || !Array.isArray(items) || items.length === 0) {
            throw new Error('Order items list cannot be empty');
        }

        // 1. Fetch Table
        const table = await (req as any).propertyDb.models.restaurant_tables.findOne({
            where: { id: table_id, outlet_id },
            transaction: t
        });
        if (!table) throw new Error('Table not found');

        // 2. Auto-Assign Waiter if not already assigned
        let assignedWaiterId = table.current_waiter_id;
        let assignedWaiterName = '';

        if (!assignedWaiterId) {
            // Find all active employees with waiter/captain/service roles
            const employees = await (req as any).propertyDb.models.hr_employees.findAll({
                where: {
                    outlet_id,
                    status: 'Active'
                },
                transaction: t
            });

            if (employees && employees.length > 0) {
                // Find waiter with minimum active table load
                const activeTables = await (req as any).propertyDb.models.restaurant_tables.findAll({
                    where: {
                        outlet_id,
                        status: 'Occupied',
                        current_waiter_id: { [Op.ne]: null }
                    },
                    attributes: ['current_waiter_id'],
                    transaction: t
                });

                const waiterLoadMap: Record<number, number> = {};
                employees.forEach((emp: any) => { waiterLoadMap[emp.id] = 0; });
                activeTables.forEach((tbl: any) => {
                    if (tbl.current_waiter_id && waiterLoadMap[tbl.current_waiter_id] !== undefined) {
                        waiterLoadMap[tbl.current_waiter_id]++;
                    }
                });

                // Sort employees by lowest workload
                employees.sort((a: any, b: any) => (waiterLoadMap[a.id] || 0) - (waiterLoadMap[b.id] || 0));
                assignedWaiterId = employees[0].id;
                assignedWaiterName = employees[0].employee_name || employees[0].full_name;
            }
        } else {
            const waiter = await (req as any).propertyDb.models.hr_employees.findByPk(assignedWaiterId, { transaction: t });
            if (waiter) assignedWaiterName = waiter.employee_name || waiter.full_name;
        }

        // Update table status to Occupied & assign waiter
        await table.update({
            status: 'Occupied',
            current_waiter_id: assignedWaiterId || table.current_waiter_id
        }, { transaction: t });

        // 3. Resolve Sequential KOT Number
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
            console.error('[DINING KOT NUMBERING ERR]', numErr.message);
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

        // 4. Create KOT Header
        const remarksText = [
            `Customer Self-Order (QR): ${customer_name || 'Guest'} (${customer_phone || ''})`,
            payment_method === 'ONLINE' ? '[PAID ONLINE]' : '[PAY AT TABLE]',
            special_instructions ? `Note: ${special_instructions}` : ''
        ].filter(Boolean).join(' | ');

        const kotHeader = await (req as any).propertyDb.models.kot_headers.create({
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

        // 5. Create KOT Items
        let totalAmount = 0;
        for (const item of items) {
            const qty = Number(item.qty || item.quantity || 1);
            const price = Number(item.price || item.selling_price || 0);
            totalAmount += (qty * price);

            await (req as any).propertyDb.models.kot_items.create({
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

        // 6. Create KOT Revision log
        if ((req as any).propertyDb.models.kot_revisions) {
            await (req as any).propertyDb.models.kot_revisions.create({
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
    } catch (err: any) {
        await t.rollback();
        console.error('[PLACE CUSTOMER DINING ORDER ERR]', err);
        return res.status(400).json({ success: false, error: err.message });
    }
};

/**
 * 6. POST /api/public/dining/call-waiter
 * Instant notification trigger for waitstaff
 */
export const callTableWaiter = async (req: Request, res: Response) => {
    try {
        const outlet_id = await resolveOutletId(req);
        const { table_id, request_type, customer_name } = req.body;

        if (!table_id) {
            return res.status(400).json({ success: false, message: 'Table ID is required' });
        }

        const table = await (req as any).propertyDb.models.restaurant_tables.findOne({
            where: { id: table_id, outlet_id }
        });

        const callObj: WaiterCall = {
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
        // Keep in-memory calls list bounded
        if (diningWaiterCalls.length > 100) diningWaiterCalls.pop();

        return res.json({
            success: true,
            message: `Request received: ${request_type}. A staff member will attend your table shortly!`
        });
    } catch (err: any) {
        return res.status(500).json({ success: false, error: err.message });
    }
};

/**
 * 7. GET /api/restaurant/dining/waiter-calls (POS/Captain Dashboard)
 */
export const getActiveWaiterCalls = async (req: Request, res: Response) => {
    try {
        const outlet_id = (req as any).user?.outlet_id;
        const calls = diningWaiterCalls.filter(c => (!outlet_id || c.outlet_id === outlet_id) && !c.resolved);
        return res.json({ success: true, data: calls });
    } catch (err: any) {
        return res.status(500).json({ success: false, error: err.message });
    }
};

/**
 * 8. POST /api/restaurant/dining/resolve-waiter-call
 */
export const resolveWaiterCall = async (req: Request, res: Response) => {
    try {
        const { id } = req.body;
        const call = diningWaiterCalls.find(c => c.id === id);
        if (call) call.resolved = true;
        return res.json({ success: true, message: 'Call marked resolved' });
    } catch (err: any) {
        return res.status(500).json({ success: false, error: err.message });
    }
};
