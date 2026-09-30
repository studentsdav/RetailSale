import { Request, Response, NextFunction } from 'express';

export const auditAutoMiddleware = (moduleName: string, tableName: string) => {
  return async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    res.on('finish', async () => {
      if (![200, 201].includes(res.statusCode)) return;

      const action =
        req.method === 'POST'
          ? 'CREATE'
          : req.method === 'PUT'
          ? 'UPDATE'
          : req.method === 'DELETE'
          ? 'DELETE'
          : 'READ';

      if (req.propertyDb && req.propertyDb.models && req.propertyDb.models.audit_logs) {
        try {
          await req.propertyDb.models.audit_logs.create({
            outlet_id: (req as any).outlet_id,
            user_id: req.user?.user_id,
            module: moduleName,
            action,
            table_name: tableName,
            ip_address: req.ip,
            user_agent: req.headers['user-agent']
          });
        } catch (err: any) {
          console.warn('[AUDIT_AUTO ERROR]', err.message);
        }
      }
    });

    next();
  };
};

module.exports = auditAutoMiddleware;
export default auditAutoMiddleware;
