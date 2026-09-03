exports.auditReport = async (req, res) => {
    const timeZone = req.outletTimeZone || 'Asia/Kolkata';
    const logs = await req.propertyDb.models.audit_logs.findAll({
        order: [['created_at', 'DESC']],
        limit: 500
    });

    const formattedLogs = logs.map(log => {
        const item = log.toJSON ? log.toJSON() : { ...log };
        if (item.created_at) {
            try {
                item.created_at_formatted = new Date(item.created_at).toLocaleString('en-US', { timeZone });
            } catch (_) {
                item.created_at_formatted = item.created_at;
            }
        }
        return item;
    });

    res.json({ success: true, timeZone, data: formattedLogs });
};
