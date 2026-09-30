import { Request, Response, NextFunction } from 'express';
const propertyDb = require('../db/models/index');

export const propertyContextMiddleware = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
  if (req.user) {
    (req as any).outlet_id = req.user.outlet_id;
  }
  req.propertyDb = propertyDb;
  next();
};

module.exports = propertyContextMiddleware;
export default propertyContextMiddleware;
