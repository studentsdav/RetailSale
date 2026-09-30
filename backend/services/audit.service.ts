export interface AuditLogOptions {
  req: any;
  module: string;
  action: string;
  table: string;
  recordId?: number | string | null;
  oldData?: any;
  newData?: any;
  outlet_id?: number | string | null;
  user_id?: number | string | null;
}

export const log = async ({
  req,
  module,
  action,
  table,
  recordId = null,
  oldData = null,
  newData = null,
  outlet_id = null,
  user_id = null
}: AuditLogOptions): Promise<void> => {
  try {
    if (req?.propertyDb?.models?.audit_logs) {
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
        user_agent: req.headers ? req.headers['user-agent'] : null
      });
    }
  } catch (err: any) {
    console.error('Audit log failed:', err.message);
  }
};

module.exports = {
  log
};
