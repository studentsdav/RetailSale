import { Request, Response, NextFunction } from 'express';
const { contextStorage } = require('../utils/context');

export const contextMiddleware = (req: Request, res: Response, next: NextFunction): void => {
  contextStorage.run(new Map<string, any>(), () => {
    next();
  });
};

module.exports = {
  contextMiddleware
};
