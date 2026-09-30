module.exports.logAudit = async ({
    db,
    user_id,
    action,
    table,
    record_id,
    meta = {}
}) => {
    await db.models.audit_logs.create({
        user_id,
        action,
        table_name: table,
        record_id,
        meta: JSON.stringify(meta),
    });
};