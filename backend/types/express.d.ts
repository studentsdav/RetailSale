import { Request, Response, NextFunction } from 'express';

declare global {
  namespace Express {
    interface Request {
      user?: any;
      propertyDb?: any;
      tenantId?: string | number;
      branchId?: string | number;
      outletId?: string | number;
      outlet_id?: string | number;
      outlet_code?: string;
      outlet?: any;
      license?: any;
      rawBody?: Buffer;
      dbName?: string;
      outletTimeZone?: string;
      nowInTimeZone?: any;
      timeZoneContext?: any;
      toOutletDateYmd?: (date: any) => string;
      getDateBounds?: (fromDate: any, toDate: any) => { from: any; to: any };
    }
  }
}

export {};
