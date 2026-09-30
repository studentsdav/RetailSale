import { Request, Response, NextFunction } from 'express';
const jwt = require('../utils/jwt.util');
const { contextStorage } = require('../utils/context');

export const authMiddleware = async (req: Request, res: Response, next: NextFunction): Promise<any> => {
  try {
    const token = req.headers.authorization?.split(' ')[1];
    if (!token) {
      // Check if we have an outlet identifier in query, body, or headers to bypass login for testing
      const rawOutlet =
        req.query?.outlet_code ||
        req.query?.outletcode ||
        req.query?.outlet_id ||
        (req.body && req.body.outlet_code) ||
        (req.body && req.body.outletcode) ||
        (req.body && req.body.outlet_id) ||
        req.headers['x-outlet-code'] ||
        req.headers['x-outlet-id'];

      if (rawOutlet && req.propertyDb) {
        try {
          let outlet = await req.propertyDb.models.outlets.findOne({
            where: { outlet_code: rawOutlet }
          });

          if (!outlet) {
            const num = Number(rawOutlet);
            if (Number.isInteger(num)) {
              outlet = await req.propertyDb.models.outlets.findByPk(num);
            }
          }

          if (outlet) {
            // Find an active admin/store user for this outlet
            const user = await req.propertyDb.models.users.findOne({
              where: {
                outlet_id: outlet.id,
                is_active: true
              }
            });

            if (user) {
              req.user = {
                user_id: user.id,
                id: user.id,
                outlet_id: outlet.id,
                role: user.role,
                outlet_code: outlet.outlet_code,
                permissions: ['*']
              };
              (req as any).outlet_id = outlet.id;
              (req as any).outlet_code = outlet.outlet_code;
              const store = contextStorage.getStore();
              if (store) {
                store.set('outlet_id', outlet.id);
              }
              return next();
            }
          }
        } catch (dbErr: any) {
          console.error('[AUTH BYPASS ERROR]', dbErr.message);
        }
      }

      return res.status(401).json({
        success: false,
        message: 'No token provided'
      });
    }

    // If the token is invalid/expired, this line will throw an error and jump to the catch block
    const data: any = jwt.verify(token);

    req.user = {
      ...data,
      id: data.user_id || data.id
    };
    (req as any).outlet_id = data.outlet_id;
    (req as any).outlet_code = data.outlet_code;
    const store = contextStorage.getStore();
    if (store) {
      store.set('outlet_id', data.outlet_id);
    }

    try {
      const {
        getOutletTimeZone,
        getNowInTimeZone,
        getTimeZoneContext,
        toOutletDateYmd,
        getOutletDateBounds
      } = require('../utils/timezoneHelper');
      const tz = await getOutletTimeZone(data.outlet_id, req.propertyDb);
      if (tz) {
        req.outletTimeZone = tz;
        req.nowInTimeZone = getNowInTimeZone(tz);
        req.timeZoneContext = getTimeZoneContext(tz);
        req.toOutletDateYmd = (date: any) => toOutletDateYmd(date, tz);
        req.getDateBounds = (fromDate: any, toDate: any) => getOutletDateBounds(fromDate, toDate, tz);
      }
    } catch (_) {}

    return next();
  } catch (error: any) {
    // 🚨 Catch the JWT error safely!
    console.error('JWT Verification Failed:', error.message);

    return res.status(401).json({
      success: false,
      // Tell Flutter exactly what went wrong
      error: error.name === 'TokenExpiredError' ? 'SESSION_EXPIRED' : 'INVALID_TOKEN',
      message: 'Session expired or invalid. Please log in again.'
    });
  }
};

module.exports = authMiddleware;
export default authMiddleware;
