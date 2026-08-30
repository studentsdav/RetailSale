
const bcrypt = require("bcryptjs");
const jwt = require('../../utils/jwt.util');
const audit = require('../../services/audit.service');
const { verifyLicenseOnline } = require('../public/licenseManager');
const { touchClient } = require("../../modules/sheetService");
const { internalCheckOutlet } = require("../public/outlet.controller");
const { sendOtpEmail } = require('../../modules/emailService');

exports.login = async (req, res, next) => {
    try {
        let licenseState = 'VALID';
        let daysRemaining = 999;

        const { username, password, role, outlet_code } = req.body;
        const db = req.propertyDb;


        if (!outlet_code) {
            return res.status(400).json({ success: false, message: 'Outlet code is required for login.' });
        }

        // if (fs.existsSync(CLIENT_FILE)) {
        //     const existingfile = JSON.parse(fs.readFileSync(CLIENT_FILE));
        //     if (existingfile.outlet_code !== outlet_code) {
        //         return res.status(403).json({ success: false, message: 'Terminal mismatch. This device is not registered to this outlet.' });
        //     }
        // }

        const currentOutlet = await db.models.outlets.findOne({
            where: {
                outlet_code: outlet_code,
                is_active: true
            }
        });

        if (!currentOutlet) {
            return res.status(401).json({ success: false, message: 'Invalid or inactive outlet code.' });
        }

        const user = await db.models.users.findOne({
            where: {
                username: username,
                outlet_id: currentOutlet.id
            }
        });

        if (!user || !user.is_active) {
            return res.status(401).json({ success: false, message: 'Invalid user for this outlet.' });
        }

        if (user.role !== role) {
            return res.status(401).json({ success: false, message: 'Invalid role selected.' });
        }

        const ok = await bcrypt.compare(password, user.password_hash);
        if (!ok) {
            return res.status(401).json({ success: false, message: 'Wrong password.' });
        }

        try {
            const licenseData = await verifyLicenseOnline(outlet_code);
            daysRemaining = licenseData.days_remaining;
            licenseState = licenseData.license_status;

            if (licenseState === 'EXPIRED') {
                return res.status(403).json({
                    success: false,
                    license_status: 'EXPIRED',
                    message: 'System license expired. Please renew to continue.'
                });
            }

        } catch (err) {
            console.warn(`[AUTH] Cloud license check bypassed: ${err.message}`);
        }

        const ROLE_PERMISSIONS = {
            ADMIN: ['*'],
            STORE: [
                'ITEM_REQUEST', 'PURCHASE_ORDER', 'STOCK_IN', 'STOCK_OUT', 'RETURN', 'DAMAGE',
                'ITEM_MASTER', 'SUPPLIER_MASTER', 'STOCK_LOCATION',
                'STOCK_BALANCE', 'DAMAGE_SUMMARY', 'STOCK_IN_REPORT', 'STOCK_OUT_REPORT',
                'DAMAGE_REPORT', 'REQUEST_REPORT', 'PURCHASE_REPORT', 'RETURN_REPORT',
                'STOCK_TRANSFER', 'PRODUCT_ASSEMBLY', 'RETURN_ISSUE', 'SUPPLIER_RETURN',
                'STOCK_TRANSFER_REPORT', 'SUBMISSIONS_STATUS'
            ],
            RETAIL: [
                'RETAIL_SALES', 'REPRINT_SALES_BILL', 'RETAIL_SALES_REPORT', 'CLOSING_REPORT',
                'CUSTOMER_APP', 'RETAILER_CONSOLE', 'RIDER_PORTAL'
            ],
            ACCOUNTS: [
                'SUPPLIER_PAYMENT', 'REPORTS', 'STOCK_BALANCE', 'DAMAGE_SUMMARY', 'STOCK_IN_REPORT',
                'STOCK_OUT_REPORT', 'RETAIL_SALES_REPORT', 'CLOSING_REPORT', 'PURCHASE_REPORT',
                'RETURN_REPORT', 'REQUEST_REPORT', 'DAMAGE_REPORT',
                'SUPPLIER_RETURN_REFUND', 'PENDING_REFUNDS', 'CASH_LEDGER', 'STOCK_LEDGER_REPORT',
                'VENDOR_PAYMENT_REPORT', 'SUBSCRIPTION_REPORT', 'SCHEME_REPORT', 'SCHEME_ANALYSIS',
                'LOYALTY_REPORT', 'STORE_ANALYSIS', 'BRAND_ANALYSIS', 'SOURCE_ANALYSIS',
                'COMMISSION_REPORT', 'PAYMENT_ANALYSIS', 'AI_QUERY_ANALYTICS'
            ],
            HR: [
                'HR_EMPLOYEES', 'HR_ATTENDANCE', 'HR_PAYROLL', 'HR_MASTERS'
            ]
        };

        let permissions = [];
        if (user.role === 'ADMIN') {
            permissions = ['*'];
        } else {
            const perms = await db.models.user_permissions.findAll({
                where: { user_id: user.id }
            });
            permissions = perms.map(p => p.perm_key);

            if (permissions.length === 0) {
                const defaultPerms = ROLE_PERMISSIONS[user.role] || [];
                if (defaultPerms.length > 0) {
                    await db.models.user_permissions.bulkCreate(
                        defaultPerms.map(p => ({ user_id: user.id, perm_key: p }))
                    );
                    permissions = defaultPerms;
                }
            }
        }

        const token = jwt.sign({
            user_id: user.id,
            outlet_id: currentOutlet.id,
            role: user.role,
            outlet_code: currentOutlet.outlet_code,
            permissions
        });

        await audit.log({
            req,
            module: 'AUTH',
            action: 'LOGIN',
            table: 'users',
            recordId: user.id,
            newData: { username: user.username },
            outlet_id: currentOutlet.id,
            user_id: user.id
        });

        await user.update({ last_login: new Date() });

        const property = await db.models.property_info.findOne({
            where: { outlet_id: currentOutlet.id },
            attributes: ['property_name']
        });

        const outletCheck = await internalCheckOutlet(outlet_code, req.propertyDb);

        if (!outletCheck.success) {
            return res.status(404).json({
                success: false,
                message: outletCheck.message
            });
        }

        await touchClient(outlet_code);

        const ROLE_MAX_DISCOUNTS = {
            ADMIN: 100.0,
            MANAGER: 50.0,
            STORE: 20.0,
            RETAIL: 15.0,
            CASHIER: 10.0,
            ACCOUNTS: 25.0,
            HR: 10.0,
            WAITER: 5.0,
            CAPTAIN: 15.0,
            KDS: 0.0,
            MARKETING: 25.0
        };

        const resolvedMaxDiscount = (user.max_discount_percent !== null && user.max_discount_percent !== undefined)
            ? parseFloat(user.max_discount_percent)
            : (ROLE_MAX_DISCOUNTS[user.role] || 10.0);

        res.json({
            success: true,
            license_status: licenseState,
            days_remaining: daysRemaining,
            token,
            user: {
                username: user.username,
                name: user.full_name,
                role: user.role,
                mobile: user.mobile,
                max_discount_percent: resolvedMaxDiscount,
                outlet_id: currentOutlet.id,
                outlet_code: currentOutlet.outlet_code,
                property_name: property?.property_name || '',
                outlet_type: currentOutlet.outlet_type || '',
                business_module: currentOutlet.business_module || 'ALL',
                permissions
            }
        });

    } catch (error) {
        console.error('[AUTH ERROR]', error);
        res.status(500).json({ success: false, message: 'Internal server error during login' });
    }
};

// In-memory store for supplier OTPs: "outletCode_email" -> { otp, expiresAt }
const supplierOtpStore = new Map();

exports.requestSupplierOtp = async (req, res) => {
    try {
        const { outlet_code, email } = req.body;
        const db = req.propertyDb;

        if (!outlet_code || !email) {
            return res.status(400).json({ success: false, message: 'Outlet code and email are required.' });
        }

        const currentOutlet = await db.models.outlets.findOne({
            where: {
                outlet_code: outlet_code,
                is_active: true
            }
        });

        if (!currentOutlet) {
            return res.status(404).json({ success: false, message: 'Invalid or inactive outlet code.' });
        }

        if (!currentOutlet.contact_email || currentOutlet.contact_email.trim().toLowerCase() !== email.trim().toLowerCase()) {
            return res.status(400).json({ success: false, message: 'The entered email does not match the registered outlet email.' });
        }

        // Generate 6-digit OTP
        const otpCode = Math.floor(100000 + Math.random() * 900000).toString();

        // Store OTP in memory (valid for 10 minutes)
        const storeKey = `${outlet_code}_${email.trim().toLowerCase()}`;
        supplierOtpStore.set(storeKey, {
            otp: otpCode,
            expiresAt: Date.now() + 600000 // 10 minutes
        });

        // Send OTP email
        await sendOtpEmail(email.trim().toLowerCase(), otpCode, "Supplier Login Verification");

        res.json({
            success: true,
            message: 'Verification OTP has been sent to your registered email address.'
        });
    } catch (error) {
        console.error('[OTP REQUEST ERROR]', error);
        res.status(500).json({ success: false, message: 'Internal server error during OTP request.' });
    }
};

exports.verifySupplierOtp = async (req, res) => {
    try {
        const { outlet_code, email, otp } = req.body;
        const db = req.propertyDb;

        if (!outlet_code || !email || !otp) {
            return res.status(400).json({ success: false, message: 'Outlet code, email, and OTP are required.' });
        }

        const storeKey = `${outlet_code}_${email.trim().toLowerCase()}`;
        const record = supplierOtpStore.get(storeKey);

        if (!record || record.otp !== otp.toString().trim() || Date.now() > record.expiresAt) {
            return res.status(400).json({ success: false, message: 'Invalid or expired OTP.' });
        }

        // Clear OTP after successful verification
        supplierOtpStore.delete(storeKey);

        // Fetch the outlet
        const currentOutlet = await db.models.outlets.findOne({
            where: {
                outlet_code: outlet_code,
                is_active: true
            }
        });

        if (!currentOutlet) {
            return res.status(404).json({ success: false, message: 'Outlet no longer exists or is inactive.' });
        }

        // Find the primary/first active admin or store user for this outlet
        const user = await db.models.users.findOne({
            where: {
                outlet_id: currentOutlet.id,
                is_active: true,
                role: ['ADMIN', 'STORE']
            }
        });

        if (!user) {
            return res.status(404).json({ success: false, message: 'No active manager/admin user found for this outlet.' });
        }

        // Generate login token
        const token = jwt.sign({
            user_id: user.id,
            outlet_id: currentOutlet.id,
            role: user.role,
            outlet_code: currentOutlet.outlet_code,
            permissions: ['*'] // Admin permissions
        });

        await user.update({ last_login: new Date() });

        const property = await db.models.property_info.findOne({
            where: { outlet_id: currentOutlet.id },
            attributes: ['property_name']
        });

        const outletCheck = await internalCheckOutlet(outlet_code, db);

        if (!outletCheck.success) {
            return res.status(404).json({
                success: false,
                message: outletCheck.message
            });
        }

        await touchClient(outlet_code);

        res.json({
            success: true,
            license_status: 'VALID',
            days_remaining: 999,
            token,
            user: {
                username: user.username,
                name: user.full_name,
                role: user.role,
                mobile: user.mobile,
                outlet_id: currentOutlet.id,
                outlet_code: currentOutlet.outlet_code,
                property_name: property?.property_name || '',
                outlet_type: currentOutlet.outlet_type || '',
                business_module: currentOutlet.business_module || 'ALL',
                permissions: ['*']
            }
        });
    } catch (error) {
        console.error('[OTP VERIFY ERROR]', error);
        res.status(500).json({ success: false, message: 'Internal server error during OTP verification.' });
    }
};
