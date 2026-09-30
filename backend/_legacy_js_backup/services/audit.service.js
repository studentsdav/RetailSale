exports.log = async ({
    req,
    module,
    action,
    table,
    recordId = null,
    oldData = null,
    newData = null,
    outlet_id = null,
    user_id = null
}) => {
    try {
        await req.propertyDb.models.audit_logs.create({
            outlet_id: outlet_id ?? req.user?.outlet_id ?? req.outlet_id,
            user_id: user_id ?? req.user?.id ?? req.user?.user_id,
            module,
            action,
            table_name: table,
            record_id: recordId,
            old_data: oldData,
            new_data: newData,
            ip_address: req.ip,
            user_agent: req.headers['user-agent']
        });
    } catch (err) {
        console.error('Audit log failed:', err.message);
    }
};
