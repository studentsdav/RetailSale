const audit = require('../../services/audit.service');
const bcrypt = require("bcryptjs");

const ROLE_PERMISSIONS = {
    ADMIN: ['*'],
    MANAGER: [
        'ITEM_REQUEST', 'PURCHASE_ORDER', 'STOCK_IN', 'STOCK_OUT', 'RETURN', 'DAMAGE',
        'ITEM_MASTER', 'SUPPLIER_MASTER', 'STOCK_LOCATION', 'STOCK_BALANCE', 'DAMAGE_SUMMARY',
        'STOCK_IN_REPORT', 'STOCK_OUT_REPORT', 'DAMAGE_REPORT', 'REQUEST_REPORT', 'PURCHASE_REPORT',
        'RETURN_REPORT', 'STOCK_TRANSFER', 'PRODUCT_ASSEMBLY', 'RETURN_ISSUE', 'SUPPLIER_RETURN',
        'STOCK_TRANSFER_REPORT', 'SUBMISSIONS_STATUS', 'RETAIL_SALES', 'REPRINT_SALES_BILL',
        'MODIFY_SALES_BILL', 'MODIFY_SALES_PAYMENT', 'RETAIL_SALES_REPORT', 'CLOSING_REPORT',
        'CUSTOMER_APP', 'RETAILER_CONSOLE', 'RIDER_PORTAL', 'CASH_LEDGER'
    ],
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
    ],
    WAITER: [
        'RETAIL_SALES'
    ],
    CAPTAIN: [
        'RETAIL_SALES'
    ]
};

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

exports.listUsers = async (req, res) => {
    const outlet_id = req.user.outlet_id;
    const users = await req.propertyDb.models.users.findAll({
        where: { outlet_id },
        attributes: { exclude: ['password_hash'] }
    });
    res.json({ success: true, data: users });
};

exports.checkUsernameAvailability = async (req, res) => {
    try {
        const { username } = req.body;
        const outlet_id = req.user.outlet_id;

        if (!username || !username.trim()) {
            return res.status(400).json({ success: false, message: 'Username is required' });
        }

        const cleanUsername = username.trim();
        const existing = await req.propertyDb.models.users.findOne({
            where: { outlet_id, username: cleanUsername }
        });

        if (existing) {
            return res.json({
                success: true,
                available: false,
                message: `Username '${cleanUsername}' is already in use in your store.`
            });
        }

        return res.json({
            success: true,
            available: true,
            message: `Username '${cleanUsername}' is available.`
        });
    } catch (err) {
        return res.status(500).json({ success: false, message: err.message });
    }
};

exports.createUser = async (req, res) => {
    const { username, full_name, mobile, role, permissions, password, contact_email, max_discount_percent } = req.body;

    const outlet_id = req.user.outlet_id;

    if (!username || !username.trim()) {
        return res.status(400).json({
            success: false,
            message: 'Username is required'
        });
    }

    const cleanUsername = username.trim();

    // Check if username is already taken within this outlet
    const existing = await req.propertyDb.models.users.findOne({
        where: { outlet_id, username: cleanUsername }
    });

    if (existing) {
        return res.status(400).json({
            success: false,
            message: `Username '${cleanUsername}' is already registered in your store. Please choose a different username.`
        });
    }

    if (!password || password.length < 4) {
        return res.status(400).json({
            success: false,
            message: 'Password must be at least 4 characters'
        });
    }

    const hash = await bcrypt.hash(password, 10);

    const defaultRoleDisc = ROLE_MAX_DISCOUNTS[role] ?? 10.0;
    const finalMaxDiscount = (max_discount_percent !== undefined && max_discount_percent !== null)
        ? max_discount_percent
        : defaultRoleDisc;

    const user = await req.propertyDb.models.users.create({
        outlet_id,
        username: cleanUsername,
        full_name,
        mobile,
        contact_email,
        role,
        max_discount_percent: finalMaxDiscount,
        password_hash: hash,
        is_active: true
    });

    let permsToAssign = permissions;
    if (!permsToAssign || permsToAssign.length === 0) {
        permsToAssign = ROLE_PERMISSIONS[role] || [];
    }

    if (permsToAssign?.length) {
        await req.propertyDb.models.user_permissions.bulkCreate(
            permsToAssign.map(p => ({
                user_id: user.id,
                perm_key: p
            }))
        );
    }

    res.json({
        success: true,
        message: 'User created successfully'
    });
};


exports.changePassword = async (req, res) => {
    const { username } = req.params;
    const { oldPassword, newPassword } = req.body;

    try {
        if (!oldPassword || !newPassword) {
            return res.status(400).json({ success: false, message: "Old and new passwords are required." });
        }
        const user = await req.propertyDb.models.users.findOne({
            where: { username: username, is_active: true }
        });

        if (!user) {
            return res.status(404).json({ success: false, message: "User not found." });
        }

        const isMatch = await bcrypt.compare(oldPassword, user.password_hash);
        if (!isMatch) {
            return res.status(401).json({ success: false, message: "Incorrect current password." });
        }

        const newHash = await bcrypt.hash(newPassword, 10);
        await user.update({ password_hash: newHash });

        res.json({ success: true, message: "Password updated successfully." });

    } catch (error) {
        console.error(`[AUTH] Change Password Error: ${error.message}`);
        res.status(500).json({ success: false, message: "An error occurred while changing the password." });
    }
};

exports.updateUser = async (req, res) => {
    const { full_name, mobile, role, contact_email, max_discount_percent } = req.body;

    const user = await req.propertyDb.models.users.findByPk(req.params.id);
    if (!user) {
        return res.status(404).json({ success: false });
    }

    const oldData = user.toJSON();
    const roleChanged = role && role !== oldData.role;

    const updatePayload = { full_name, mobile, role, contact_email };
    if (max_discount_percent !== undefined) {
        updatePayload.max_discount_percent = max_discount_percent;
    }

    await user.update(updatePayload);

    if (roleChanged) {
        // Destroy existing permissions for this user
        await req.propertyDb.models.user_permissions.destroy({
            where: { user_id: user.id }
        });

        // Add new permissions corresponding to the new role
        const defaultPerms = ROLE_PERMISSIONS[role] || [];
        if (defaultPerms.length > 0) {
            await req.propertyDb.models.user_permissions.bulkCreate(
                defaultPerms.map(p => ({ user_id: user.id, perm_key: p }))
            );
        }
    }

    await audit.log({
        req,
        module: 'USER',
        action: 'UPDATE',
        table: 'users',
        recordId: user.id,
        old_data: {},
        new_data: user.toJSON(),
        outlet_id: req.user.outlet_id,
        user_id: req.user.id
    });


    res.json({ success: true });
};

exports.toggleStatus = async (req, res) => {
    const user = await req.propertyDb.models.users.findByPk(req.params.id);
    if (!user) {
        return res.status(404).json({ success: false });
    }

    const oldStatus = user.is_active;

    await user.update({ is_active: !user.is_active });

    await audit.log({
        req,
        module: 'USER',
        action: user.is_active ? 'ACTIVATE' : 'DEACTIVATE',
        table: 'users',
        recordId: user.id,
        old_data: { is_active: oldStatus },
        new_data: { is_active: user.is_active },
        outlet_id: req.user.outlet_id,
        user_id: req.user.id
    });

    res.json({ success: true });
};

exports.resetPassword = async (req, res) => {

    const { password } = req.body;

    const user = await req.propertyDb.models.users.findByPk(req.params.id);

    if (!user) {
        return res.status(404).json({ success: false });
    }

    const hash = await bcrypt.hash(password, 10);

    await user.update({
        password_hash: hash
    });

    res.json({
        success: true,
        message: 'Password reset successfully'
    });
};


exports.updatePermissions = async (req, res) => {
    const t = await req.propertyDb.transaction();

    try {
        const outlet_id = req.user.outlet_id;
        const user_id = req.params.id;
        const { permissions } = req.body;

        if (!Array.isArray(permissions)) {
            await t.rollback();
            return res.status(400).json({ success: false, step: 'INVALID_PERMISSIONS' });
        }

        const user = await req.propertyDb.models.users.findOne({
            where: { id: user_id, outlet_id },
            transaction: t
        });

        if (!user) {
            await t.rollback();
            return res.status(404).json({ success: false, step: 'USER_NOT_FOUND' });
        }


        const oldPerms = await req.propertyDb.models.user_permissions.findAll({
            where: { user_id },
            transaction: t
        });


        await req.propertyDb.models.user_permissions.destroy({
            where: { user_id },
            transaction: t
        });


        if (permissions.length) {
            await req.propertyDb.models.user_permissions.bulkCreate(
                permissions.map(p => ({ user_id: user_id, perm_key: p })),
                { transaction: t }
            );
        }


        await audit.log({
            req,
            module: 'USER',
            action: 'UPDATE_PERMISSIONS',
            table: 'user_permissions',
            recordId: user_id,
            old_data: oldPerms.map(p => p.perm_key),
            new_data: permissions,
            outlet_id: req.user.outlet_id,
            user_id: req.user.id
        });

        await t.commit();

        return res.json({
            success: true,
            saved: true,
            permissions
        });

    } catch (err) {
        await t.rollback();

        console.error('UPDATE_PERMISSIONS FAILED AT:', err);

        return res.status(500).json({
            success: false,
            saved: false,
            error: err.message
        });
    }
};


exports.getPermissions = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const user_id = req.params.id;

        const user = await req.propertyDb.models.users.findOne({
            where: { id: user_id, outlet_id }
        });

        if (!user) {
            return res.status(404).json({ success: false });
        }

        const perms = await req.propertyDb.models.user_permissions.findAll({
            where: { user_id },
            attributes: ['perm_key']
        });

        res.json({
            success: true,
            data: perms.map(p => p.perm_key),
        });

    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};

