const bcrypt = require("bcryptjs");
const crypto = require("crypto");
const loadConfig = require("../../utils/decryptConfig");
const { initClient } = require("../../modules/clientSetup");
const { verifyLicenseOnline } = require('./licenseManager'); // Uncomment if used
const fs = require("fs");
const path = require("path");
const rootDir = process.pkg ? path.dirname(process.execPath) : process.cwd();

exports.internalCheckOutlet = async (outlet_code, propertyDb) => {

    const sysConfigPath = path.join(rootDir, 'sysConfig.enc');
    const configPath = path.join(rootDir, 'config.enc');

    if (!fs.existsSync(sysConfigPath) || !fs.existsSync(configPath)) {
        return {
            success: false,
            message: "System files corrupted. Please reinstall the software."
        };
    }

    if (!outlet_code) {
        return { success: false, message: "Outlet code is required" };
    }

    const outlet = await propertyDb.models.outlets.findOne({
        where: { outlet_code: outlet_code, is_active: true }
    });

    if (!outlet) {
        return { success: false, exists: false, message: "Outlet not found" };
    }

    const config = loadConfig();

    await initClient(config, outlet);

    return { success: true, exists: true };
};


exports.checkOutlet = async (req, res) => {
    try {
        const { outlet_code } = req.body;

        if (!outlet_code) {
            return res.status(400).json({
                success: false,
                message: "Outlet code is required"
            });
        }

        const outlet = await req.propertyDb.models.outlets.findOne({
            where: { outlet_code: outlet_code, is_active: true }
        });

        if (!outlet) {
            return res.json({
                success: true,
                exists: false,
                data: { outlet_id: 0 }
            });
        }

        const safeOutlet = outlet.toJSON();
        delete safeOutlet.recovery_pin_hash;

        res.json({
            success: true,
            exists: true,
            data: safeOutlet
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: error.message
        });
    }
};

exports.createOutlet = async (req, res) => {
    try {
        const {
            outlet_code,
            outlet_name,
            outlet_type,
            contact_email,
            contact_phone,
            recovery_pin,
            tax_id
        } = req.body;


        if (!outlet_code || !outlet_name) {
            return res.status(400).json({
                success: false,
                message: "Outlet code and name are required"
            });
        }


        if (!recovery_pin || recovery_pin.toString().length < 4) {
            return res.status(400).json({
                success: false,
                message: "A recovery PIN (minimum 4 characters) is required for secure account recovery."
            });
        }

        const exists = await req.propertyDb.models.outlets.findOne({
            where: { outlet_code }
        });

        if (exists) {
            return res.status(400).json({
                success: false,
                message: "Outlet code already exists in the system."
            });
        }


        const pinHash = await bcrypt.hash(recovery_pin.toString(), 10);

        const outlet = await req.propertyDb.models.outlets.create({
            outlet_code,
            outlet_name,
            outlet_type,
            contact_email,
            contact_phone,
            recovery_pin_hash: pinHash,
            tax_id,
            is_active: true
        });

        const userCount = await req.propertyDb.models.users.count({
            where: { outlet_id: outlet.id }
        });

        let adminCredentials = null;

        if (userCount === 0) {
            const uniqueUsername = `admin_${outlet_code}`;
            const randomHex = crypto.randomBytes(4).toString('hex');
            const defaultPassword = `${randomHex}@A1`;
            const hash = await bcrypt.hash(defaultPassword, 10);

            await req.propertyDb.models.users.create({
                outlet_id: outlet.id,
                username: uniqueUsername,
                full_name: 'System Admin',
                role: 'ADMIN',
                password_hash: hash,
                contact_email: contact_email,
                mobile: contact_phone,
                is_active: true
            });

            adminCredentials = {
                username: uniqueUsername,
                password: defaultPassword
            };
        }

        const config = loadConfig();
        await initClient(config, outlet);

        res.json({
            success: true,
            message: "Outlet configured successfully. Ensure admin credentials are saved securely.",
            data: {
                outlet_id: outlet.id,
                outlet_code: outlet.outlet_code,
                admin_credentials: adminCredentials
            }
        });

    } catch (err) {
        res.status(500).json({
            success: false,
            message: err.message
        });
    }
};

exports.createAdmin = async (req, res) => {
    try {
        const { outlet_code, username, password, full_name } = req.body;

        if (!outlet_code || !username || !password) {
            return res.status(400).json({
                success: false,
                message: 'Outlet code, username, and password are required'
            });
        }

        const outlet = await req.propertyDb.models.outlets.findOne({
            where: { outlet_code: outlet_code, is_active: true }
        });

        if (!outlet) {
            return res.status(400).json({
                success: false,
                message: 'Invalid or inactive outlet code'
            });
        }

        const userCount = await req.propertyDb.models.users.count({
            where: { outlet_id: outlet.id }
        });

        if (userCount > 0) {
            return res.status(400).json({
                success: false,
                message: 'Admin already exists for this outlet'
            });
        }

        const hash = await bcrypt.hash(password, 10);

        await req.propertyDb.models.users.create({
            outlet_id: outlet.id,
            username: username,
            full_name: full_name || 'System Admin',
            role: 'ADMIN',
            password_hash: hash,
            is_active: true
        });

        res.json({
            success: true,
            message: 'Admin user created successfully'
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: error.message
        });
    }
};

exports.startupSystem = async (outletCode) => {
    try {
        const licenseData = await verifyLicenseOnline(outletCode);

        if (licenseData.license_status === 'EXPIRED') {
            return false;
        }

        return true;
    } catch (err) {
        if (err.message === "OFFLINE") {
            return true;
        }
        return false;
    }
};