const audit = require('../../services/audit.service');
const bcrypt = require("bcryptjs");

exports.listUsers = async (req, res) => {
    const outlet_id = req.user.outlet_id;
    const users = await req.propertyDb.models.users.findAll({
        where: { outlet_id },
        attributes: { exclude: ['password_hash'] }
    });
    res.json({ success: true, data: users });
};

exports.createUser = async (req, res) => {
    const { username, full_name, mobile, role, permissions, password, contact_email } = req.body;

    const outlet_id = req.user.outlet_id;

    if (!password || password.length < 4) {
        return res.status(400).json({
            success: false,
            message: 'Password must be at least 4 characters'
        });
    }

    const hash = await bcrypt.hash(password, 10);

    const user = await req.propertyDb.models.users.create({
        outlet_id,
        username,
        full_name,
        mobile,
        contact_email,
        role,
        password_hash: hash,
        is_active: true
    });

    if (permissions?.length) {
        await req.propertyDb.models.user_permissions.bulkCreate(
            permissions.map(p => ({
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
    const { full_name, mobile, role, contact_email } = req.body;

    const user = await req.propertyDb.models.users.findByPk(req.params.id);
    if (!user) {
        return res.status(404).json({ success: false });
    }

    const oldData = user.toJSON();

    await user.update({ full_name, mobile, role, contact_email });

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

