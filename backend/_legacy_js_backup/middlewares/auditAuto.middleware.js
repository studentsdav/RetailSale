module.exports = (moduleName, tableName) => {
    return async (req, res, next) => {
        res.on('finish', async () => {
            if (![200, 201].includes(res.statusCode)) return;

            const action =
                req.method === 'POST' ? 'CREATE' :
                    req.method === 'PUT' ? 'UPDATE' :
                        req.method === 'DELETE' ? 'DELETE' :
                            'READ';

            await req.propertyDb.models.audit_logs.create({
                outlet_id: req.outlet_id,
                user_id: req.user?.user_id,
                module: moduleName,
                action,
                table_name: tableName,
                ip_address: req.ip,
                user_agent: req.headers['user-agent']
            });
        });

        next();
    };
};
