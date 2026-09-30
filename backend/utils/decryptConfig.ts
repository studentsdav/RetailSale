import crypto from 'crypto';
import fs from 'fs';

const SECRET = 'INTERNAL_SECRET';

export interface AppConfig {
  db_host: string;
  db_port: number | string;
  db_database: string;
  db_user: string;
  db_password?: string;
  JWT_SECRET: string;
  DATABASE_URL?: string;
  [key: string]: any;
}

export function loadConfig(): AppConfig {
  // 1. Check if running in Docker/Render/Cloud with environment variables
  if (process.env.DATABASE_URL || process.env.DB_HOST || process.env.DB_DATABASE) {
    return {
      db_host: process.env.DB_HOST || '127.0.0.1',
      db_port: process.env.DB_PORT || 5432,
      db_database: process.env.DB_DATABASE || process.env.DB_NAME || 'postgres',
      db_user: process.env.DB_USER || 'postgres',
      db_password: process.env.DB_PASSWORD || '',
      JWT_SECRET: process.env.JWT_SECRET || 'default_jwt_secret',
      DATABASE_URL: process.env.DATABASE_URL
    };
  }

  // 2. Try loading encrypted config.enc if present
  if (fs.existsSync('config.enc')) {
    try {
      const encrypted = fs.readFileSync('config.enc');
      const key = crypto.createHash('sha256').update(SECRET).digest();
      const iv = Buffer.alloc(16, 0);

      const decipher = crypto.createDecipheriv('aes-256-cbc', key, iv);
      let decrypted = decipher.update(encrypted);
      decrypted = Buffer.concat([decrypted, decipher.final()]);

      return JSON.parse(decrypted.toString());
    } catch (err: any) {
      console.warn('⚠️ Failed to decrypt config.enc:', err.message);
    }
  }

  // 3. Fallback default config object
  return {
    db_host: process.env.DB_HOST || '127.0.0.1',
    db_port: process.env.DB_PORT || 5432,
    db_database: process.env.DB_DATABASE || process.env.DB_NAME || 'postgres',
    db_user: process.env.DB_USER || 'postgres',
    db_password: process.env.DB_PASSWORD || '',
    JWT_SECRET: process.env.JWT_SECRET || 'default_jwt_secret',
    DATABASE_URL: process.env.DATABASE_URL
  };
}

module.exports = loadConfig;
export default loadConfig;
