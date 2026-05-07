exports.getNotifications = async (req, res) => {
    const outlet_id = req.user.outlet_id;

    const rows = await req.propertyDb.models.system_notifications.findAll({
        where: { outlet_id },
        order: [['created_at', 'DESC']],
        limit: 20
    });

    res.json({ success: true, data: rows });
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