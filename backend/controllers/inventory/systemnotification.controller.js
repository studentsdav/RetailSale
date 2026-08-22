exports.getNotifications = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;

        const rows = await req.propertyDb.models.system_notifications.findAll({
            where: { outlet_id },
            order: [['created_at', 'DESC']],
            limit: 30
        });

        res.json({ success: true, data: rows });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.createNotification = async (req, res) => {
    try {
        const outlet_id = req.user?.outlet_id || 0;
        const { title, message, module = 'STICKY_NOTES', type = 'INFO', entity_id = null } = req.body;

        const created = await req.propertyDb.models.system_notifications.create({
            outlet_id,
            module,
            title: title || 'Sticky Note Reminder',
            message: message || '',
            type,
            entity_id,
            is_read: false,
            created_at: new Date()
        });

        res.status(201).json({ success: true, data: created });
    } catch (err) {
        console.error('[CREATE NOTIFICATION ERROR]:', err);
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.markNotificationRead = async (req, res) => {
    try {
        const id = req.params.id;
        const outlet_id = req.user.outlet_id;

        const notification =
            await req.propertyDb.models.system_notifications.findOne({
                where: { id, outlet_id }
            });

        if (!notification) {
            return res.status(404).json({
                success: false,
                message: "Notification not found"
            });
        }

        await notification.update({
            is_read: true
        });

        res.json({
            success: true
        });

    } catch (err) {
        res.status(500).json({
            success: false,
            error: err.message
        });
    }
};