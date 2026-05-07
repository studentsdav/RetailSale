
const bcrypt = require("bcryptjs");
const jwt = require('../../utils/jwt.util');
const audit = require('../../services/audit.service');
const { verifyLicenseOnline } = require('../public/licenseManager');
const { touchClient } = require("../../modules/sheetService");
const { internalCheckOutlet } = require("../public/outlet.controller");

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

        let permissions = [];
        if (user.role === 'ADMIN') {
            permissions = ['*'];
        } else {
            const perms = await db.models.user_permissions.findAll({
                where: { user_id: user.id }
            });
            permissions = perms.map(p => p.perm_key);
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
                outlet_code: currentOutlet.outlet_code,
                property_name: property?.property_name || '',
                outlet_type: currentOutlet.outlet_type || '',
                permissions
            }
        });

    } catch (error) {
        console.error('[AUTH ERROR]', error);
        res.status(500).json({ success: false, message: 'Internal server error during login' });
    }
};
