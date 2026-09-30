export interface AuditLogPayload {
  db: any;
  user_id?: number | string | null;
  action: string;
  table: string;
  record_id?: number | string | null;
  meta?: Record<string, any>;
}

export const logAudit = async ({
  db,
  user_id,
  action,
  table,
  record_id,
  meta = {}
}: AuditLogPayload): Promise<void> => {
  if (db && db.models && db.models.audit_logs) {
    await db.models.audit_logs.create({
      user_id,
      action,
      table_name: table,
      record_id,
      meta: JSON.stringify(meta)
    });
  }
};

module.exports = {
  logAudit
};
