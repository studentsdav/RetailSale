exports.auditReport = async (req, res) => {
    const logs = await req.propertyDb.models.audit_logs.findAll({
        order: [['created_at', 'DESC']],
        limit: 500
    });

    res.json({ success: true, data: logs });
};
