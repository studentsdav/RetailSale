import jwt from 'jsonwebtoken';
const loadConfig = require('./decryptConfig');

let jwtSecret = 'default_jwt_secret';

try {
  const config = loadConfig();
  if (config && config.JWT_SECRET) {
    jwtSecret = config.JWT_SECRET;
  }
} catch (error) {
  console.log('⚠️ [JWT] config.enc missing. Running with safe dummy keys for UI recovery.');
}

export const sign = (payload: string | object | Buffer, options: jwt.SignOptions = { expiresIn: '1d' }): string => {
  return jwt.sign(payload, jwtSecret, options);
};

export const verify = <T = any>(token: string): T => {
  return jwt.verify(token, jwtSecret) as T;
};

module.exports = {
  sign,
  verify
};
