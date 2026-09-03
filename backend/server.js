// Patch TextDecoder to support 'ascii' encoding under packaged Node environments (like pkg target node18)
try {
    new TextDecoder('ascii');
} catch (e) {
    const OriginalTextDecoder = globalThis.TextDecoder || (typeof global !== 'undefined' ? global.TextDecoder : null);
    if (OriginalTextDecoder) {
        const PatchedTextDecoder = class TextDecoder extends OriginalTextDecoder {
            constructor(encoding, options) {
                if (typeof encoding === 'string' && (encoding.toLowerCase() === 'ascii' || encoding.toLowerCase() === 'us-ascii')) {
                    super('utf-8', options);
                } else {
                    super(encoding, options);
                }
            }
        };
        if (typeof globalThis !== 'undefined') {
            globalThis.TextDecoder = PatchedTextDecoder;
        }
        if (typeof global !== 'undefined') {
            global.TextDecoder = PatchedTextDecoder;
        }
        try {
            const util = require('util');
            if (util && util.TextDecoder) {
                util.TextDecoder = PatchedTextDecoder;
            }
        } catch (utilErr) {
            // Ignore if util cannot be loaded or patched
        }
    }
}

const express = require('express');
const cors = require('cors');
const path = require('path');
const fs = require('fs');
const { apiLimiter } = require('./middlewares/rateLimit.middleware');
const { contextMiddleware } = require('./middlewares/context.middleware');
const app = express();
app.set('trust proxy', 1);
app.use(contextMiddleware);
app.use((req, res, next) => {
    res.setHeader('X-Powered-By', 'Famalth Business Solutions - FAMALTH LYNX');
    res.setHeader('X-Platform-Vendor', 'Famalth Ecosystem');
    console.log(`[REQUEST] ${req.method} ${req.originalUrl || req.url}`);
    next();
});

const loadConfig = require("./utils/decryptConfig");
require('pg');
const waitForPostgres = require('./utils/waitForPostgres');
const { Sequelize } = require('sequelize');
const propertyDb = require('./db/models');
const rootDir = process.pkg ? path.dirname(process.execPath) : process.cwd();
const { startBackupJob } = require("./jobs/backupJob");
const { startLoyaltyExpiryJob } = require("./jobs/loyaltyExpiryJob");
const { startAnalyticsRefreshJob } = require("./jobs/analyticsRefreshJob");
const { startSubscriptionDeliveryJob } = require("./jobs/subscriptionDeliveryJob");
const { startLuckyDrawJob } = require("./jobs/luckyDrawJob");
const CLIENT_FILE = path.join(rootDir, "client.json");
// body limits
app.use(express.json({
    limit: '100mb',
    verify: (req, res, buf) => {
        req.rawBody = buf;
    }
}));
app.use(express.urlencoded({ extended: true, limit: '100mb' }));
const dbMiddleware = require('./middlewares/db.middleware');
const ensureDatabase = require("./utils/ensureDatabase");
const runMigrations = require('./utils/migrationRunner');
const { getBackupStatus } = require("./utils/backupTracker");


require('dotenv').config({
    path: require('path').join(rootDir, '.env')
});
// cors (local + optional online)
// app.use(cors({
//     origin: ['http://localhost', 'http://127.0.0.1'],
//     credentials: true
// }));

app.use(cors({
    origin: function (origin, callback) {
        // Allow requests with no origin (like mobile apps or curl requests)
        if (!origin) return callback(null, true);
        callback(null, true);
    },
    credentials: true
}));

app.use('/uploads', express.static(path.join(rootDir, 'uploads')));

// health
app.get('/health', async (req, res) => {
    try {
        const licensePath = path.join(rootDir, 'license.key');
        if (!fs.existsSync(licensePath)) {
            return res.json({ success: false, action: 'LICENSE_ERROR', message: "License key is missing." });
        }
        try {
            const license = JSON.parse(fs.readFileSync(licensePath, 'utf8'));
            if (new Date() > new Date(license.valid_till)) {
                return res.json({ success: false, action: 'LICENSE_ERROR', message: "License has expired." });
            }
        } catch (e) {
            return res.json({ success: false, action: 'LICENSE_ERROR', message: "License file is corrupted." });
        }


        if (!process.env.DATABASE_URL && !process.env.DB_HOST) {
            const configPath = path.join(rootDir, 'config.enc');
            const sysConfigPath = path.join(rootDir, 'sysConfig.enc');

            if (!fs.existsSync(configPath)) {
                return res.json({ success: false, action: 'RECOVER_CONFIG', message: "Configuration missing." });
            }

            try {
                const config = loadConfig();
                const testDb = new Sequelize(config.db_database, config.db_user, config.db_password, {
                    host: config.db_host || "127.0.0.1",
                    port: Number(config.db_port || 5432),
                    dialect: "postgres",
                    logging: false
                });

                await testDb.authenticate();
                await testDb.close();
            } catch (dbError) {
                console.log(dbError);
                return res.json({ success: false, action: 'FULL_RECOVERY', message: "Database connection failed." });
            }

            if (!fs.existsSync(sysConfigPath)) {
                return res.json({ success: false, action: 'AUTO_REINSTALL', message: "System files missing." });
            }
        } else {
            try {
                await propertyDb.authenticate();
            } catch (dbError) {
                return res.json({ success: false, action: 'FULL_RECOVERY', message: "Cloud database connection failed." });
            }
        }

        res.json({ success: true, action: 'OK', status: 'RUNNING', time: new Date() });

    } catch (error) {
        res.status(500).json({ success: false, action: 'ERROR', message: "Fatal health check error." });
    }
});

app.use(dbMiddleware);
const timezoneMiddleware = require('./middlewares/timezone.middleware');
app.use(timezoneMiddleware);
app.use('/api', apiLimiter);


const licensePath = path.join(rootDir, 'license.key');
let license = { allowed_mode: 'OFFLINE' };

if (!fs.existsSync(licensePath)) {
    console.error('⚠️ [SYSTEM] LICENSE FILE MISSING. Booting in limited Recovery Mode.');
} else {
    try {
        const parsedLicense = JSON.parse(fs.readFileSync(licensePath, 'utf8'));
        if (new Date() > new Date(parsedLicense.valid_till)) {
            console.error('⚠️ [SYSTEM] LICENSE EXPIRED. Booting in limited Recovery Mode.');
        } else {
            license = parsedLicense;
        }
    } catch (e) {
        console.error('⚠️ [SYSTEM] INVALID LICENSE FILE FORMAT. Booting in limited Recovery Mode.');
    }
}

(async () => {
    try {
        const configPath = path.join(rootDir, 'config.enc');

        if (!process.env.DATABASE_URL && !process.env.DB_HOST && !fs.existsSync(configPath)) {
            console.log('⚠️ [SYSTEM] config.enc is missing and cloud DB not set. Skipping database boot.');
            console.log('🛡️ [SYSTEM] Server entering Recovery Mode.');
            return;
        }

        const config = loadConfig();

        if (!process.env.DATABASE_URL) {
            await waitForPostgres(config);
            await ensureDatabase(config);
        }

        await propertyDb.authenticate();
        console.log('✅ Database connected successfully');
        
        // Dynamically add merchant_upi_id and subscription delivery charge columns if missing to prevent DB query crashes
        try {
            await propertyDb.query(`
                ALTER TABLE system_settings 
                ADD COLUMN IF NOT EXISTS time_zone VARCHAR(100) DEFAULT 'Asia/Kolkata',
                ADD COLUMN IF NOT EXISTS merchant_upi_id VARCHAR(255) DEFAULT '',
                ADD COLUMN IF NOT EXISTS sub_delivery_charge_enabled BOOLEAN DEFAULT FALSE,
                ADD COLUMN IF NOT EXISTS sub_delivery_charge_name VARCHAR(255) DEFAULT 'Subscription Delivery',
                ADD COLUMN IF NOT EXISTS sub_delivery_charge_amount NUMERIC(12,2) DEFAULT 0.0,
                ADD COLUMN IF NOT EXISTS sub_delivery_charge_type VARCHAR(50) DEFAULT 'FLAT',
                ADD COLUMN IF NOT EXISTS sub_delivery_charge_gst_percent NUMERIC(12,2) DEFAULT 0.0,
                ADD COLUMN IF NOT EXISTS sub_delivery_free_above NUMERIC(12,2) DEFAULT 0.0;
            `);
            console.log('✅ Verified/added merchant_upi_id and subscription delivery charge columns in system_settings table');
        } catch (colErr) {
            console.warn('⚠️ Failed to dynamically alter table system_settings:', colErr.message);
        }

        try {
            await propertyDb.query(`
                ALTER TABLE milk_subscriptions 
                ADD COLUMN IF NOT EXISTS delivery_charge_amount NUMERIC(12,2) DEFAULT 0.0,
                ADD COLUMN IF NOT EXISTS delivery_charge_gst_percent NUMERIC(12,2) DEFAULT 0.0,
                ADD COLUMN IF NOT EXISTS delivery_charge_tax_amount NUMERIC(12,2) DEFAULT 0.0;
            `);
            console.log('✅ Verified/added delivery charge columns in milk_subscriptions table');
        } catch (colErr) {
            console.warn('⚠️ Failed to dynamically alter table milk_subscriptions:', colErr.message);
        }

        try {
            await propertyDb.query(`
                ALTER TABLE delivery_customers 
                ADD COLUMN IF NOT EXISTS email VARCHAR(255) DEFAULT '',
                ADD COLUMN IF NOT EXISTS otp_code VARCHAR(10) DEFAULT '',
                ADD COLUMN IF NOT EXISTS otp_expires_at TIMESTAMP DEFAULT NULL;
            `);
            console.log('✅ Verified/added email and otp columns in delivery_customers table');
        } catch (colErr) {
            console.warn('⚠️ Failed to dynamically alter table delivery_customers:', colErr.message);
        }

        try {
            await propertyDb.query(`
                ALTER TABLE property_info 
                ADD COLUMN IF NOT EXISTS terms_and_conditions TEXT DEFAULT '',
                ADD COLUMN IF NOT EXISTS bank_name VARCHAR(150) DEFAULT '',
                ADD COLUMN IF NOT EXISTS bank_acc_no VARCHAR(50) DEFAULT '',
                ADD COLUMN IF NOT EXISTS bank_ifsc VARCHAR(30) DEFAULT '',
                ADD COLUMN IF NOT EXISTS upi_id VARCHAR(100) DEFAULT '',
                ADD COLUMN IF NOT EXISTS upi_payee_name VARCHAR(150) DEFAULT '',
                ADD COLUMN IF NOT EXISTS print_bank_details BOOLEAN DEFAULT false,
                ADD COLUMN IF NOT EXISTS print_upi_qr BOOLEAN DEFAULT false,
                ADD COLUMN IF NOT EXISTS print_digital_signature BOOLEAN DEFAULT false;
            `);
            console.log('✅ Verified/added custom columns in property_info table');
        } catch (colErr) {
            console.warn('⚠️ Failed to dynamically alter table property_info:', colErr.message);
        }

        try {
            await propertyDb.query(`
                CREATE TABLE IF NOT EXISTS user_notes (
                    id SERIAL PRIMARY KEY,
                    outlet_id INTEGER NOT NULL DEFAULT 0,
                    user_id INTEGER DEFAULT 1,
                    title VARCHAR(255) NOT NULL,
                    content TEXT DEFAULT '',
                    color_hex VARCHAR(20) DEFAULT '#FEF08A',
                    is_pinned BOOLEAN DEFAULT FALSE,
                    is_completed BOOLEAN DEFAULT FALSE,
                    is_archived BOOLEAN DEFAULT FALSE,
                    is_trashed BOOLEAN DEFAULT FALSE,
                    deleted_at TIMESTAMP WITH TIME ZONE DEFAULT NULL,
                    reminder_type VARCHAR(50) DEFAULT 'NONE',
                    reminder_date TIMESTAMP WITH TIME ZONE DEFAULT NULL,
                    reminder_time VARCHAR(30) DEFAULT NULL,
                    "createdAt" TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                    "updatedAt" TIMESTAMP WITH TIME ZONE DEFAULT NOW()
                );
                ALTER TABLE user_notes
                ADD COLUMN IF NOT EXISTS is_archived BOOLEAN DEFAULT FALSE,
                ADD COLUMN IF NOT EXISTS is_trashed BOOLEAN DEFAULT FALSE,
                ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE DEFAULT NULL;
            `);
            // Auto purge notes in trash older than 30 days
            await propertyDb.query(`
                DELETE FROM user_notes 
                WHERE is_trashed = true 
                  AND deleted_at IS NOT NULL 
                  AND deleted_at < NOW() - INTERVAL '30 days';
            `);
            console.log('✅ Verified user_notes table columns and purged notes in Trash older than 30 days');
        } catch (noteErr) {
            console.warn('⚠️ Failed to verify user_notes table:', noteErr.message);
        }

        try {
            await propertyDb.query(`
                ALTER TABLE recurring_expenses
                ADD COLUMN IF NOT EXISTS remind_days_before INTEGER DEFAULT 7;
            `);
            console.log('✅ Verified/added remind_days_before column in recurring_expenses table');
        } catch (recErr) {
            console.warn('⚠️ Failed to dynamically alter table recurring_expenses:', recErr.message);
        }

        try {
            await propertyDb.query(`
                CREATE TABLE IF NOT EXISTS bank_accounts (
                    id SERIAL PRIMARY KEY,
                    outlet_id INTEGER NOT NULL,
                    bank_name VARCHAR(150) NOT NULL,
                    account_name VARCHAR(150) NOT NULL,
                    account_number VARCHAR(50) NOT NULL,
                    ifsc_code VARCHAR(20),
                    branch_name VARCHAR(100),
                    account_type VARCHAR(30) DEFAULT 'CURRENT',
                    opening_balance NUMERIC(12,2) DEFAULT 0.00,
                    current_balance NUMERIC(12,2) DEFAULT 0.00,
                    is_active BOOLEAN DEFAULT TRUE,
                    is_primary BOOLEAN DEFAULT FALSE,
                    created_by INTEGER,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );
                ALTER TABLE bank_accounts ADD COLUMN IF NOT EXISTS is_primary BOOLEAN DEFAULT FALSE;
                CREATE TABLE IF NOT EXISTS chart_of_accounts (
                    id SERIAL PRIMARY KEY,
                    outlet_id INTEGER NOT NULL,
                    account_code VARCHAR(30),
                    account_name VARCHAR(150) NOT NULL,
                    group_name VARCHAR(100) NOT NULL,
                    nature VARCHAR(30) NOT NULL,
                    opening_debit NUMERIC(12,2) DEFAULT 0.00,
                    opening_credit NUMERIC(12,2) DEFAULT 0.00,
                    current_balance NUMERIC(12,2) DEFAULT 0.00,
                    is_system BOOLEAN DEFAULT FALSE,
                    is_active BOOLEAN DEFAULT TRUE,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );
                CREATE TABLE IF NOT EXISTS accounting_vouchers (
                    id SERIAL PRIMARY KEY,
                    outlet_id INTEGER NOT NULL,
                    voucher_no VARCHAR(50) NOT NULL,
                    voucher_type VARCHAR(30) NOT NULL,
                    voucher_date DATE NOT NULL,
                    payment_mode VARCHAR(30) DEFAULT 'CASH',
                    bank_account_id INTEGER,
                    reference_no VARCHAR(100),
                    narration TEXT,
                    total_debit NUMERIC(12,2) DEFAULT 0.00,
                    total_credit NUMERIC(12,2) DEFAULT 0.00,
                    status VARCHAR(20) DEFAULT 'POSTED',
                    created_by INTEGER NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );
                CREATE TABLE IF NOT EXISTS voucher_lines (
                    id SERIAL PRIMARY KEY,
                    voucher_id INTEGER NOT NULL,
                    line_type VARCHAR(20) NOT NULL,
                    account_id INTEGER,
                    account_name VARCHAR(150) NOT NULL,
                    account_type VARCHAR(50) DEFAULT 'GENERAL',
                    debit_amount NUMERIC(12,2) DEFAULT 0.00,
                    credit_amount NUMERIC(12,2) DEFAULT 0.00,
                    particulars VARCHAR(255)
                );
                CREATE TABLE IF NOT EXISTS business_loans (
                    id SERIAL PRIMARY KEY,
                    outlet_id INTEGER NOT NULL,
                    loan_name VARCHAR(150) NOT NULL,
                    lender_name VARCHAR(150),
                    principal_amount NUMERIC(12,2) DEFAULT 0.00,
                    interest_rate NUMERIC(5,2) DEFAULT 0.00,
                    tenure_months INTEGER DEFAULT 12,
                    monthly_emi NUMERIC(12,2) DEFAULT 0.00,
                    remaining_principal NUMERIC(12,2) DEFAULT 0.00,
                    status VARCHAR(30) DEFAULT 'ACTIVE',
                    notes TEXT,
                    created_by INTEGER,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );
                CREATE TABLE IF NOT EXISTS capital_assets (
                    id SERIAL PRIMARY KEY,
                    outlet_id INTEGER NOT NULL,
                    asset_name VARCHAR(150) NOT NULL,
                    asset_category VARCHAR(50) DEFAULT 'FIXED_ASSET',
                    purchase_date DATE DEFAULT CURRENT_DATE,
                    purchase_cost NUMERIC(12,2) DEFAULT 0.00,
                    current_value NUMERIC(12,2) DEFAULT 0.00,
                    notes TEXT,
                    created_by INTEGER,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );
            `);
            console.log('✅ Verified/created accounting database tables (bank_accounts, chart_of_accounts, accounting_vouchers, voucher_lines)');
        } catch (accErr) {
            console.warn('⚠️ Failed to verify accounting tables:', accErr.message);
        }

        await runMigrations(propertyDb);

        console.log('✅ Database migrations complete');
        // Note: Model sync disabled to prevent duplicate PostgreSQL constraint index generation. Database migrations manage table schema.
        // await propertyDb.sync({ alter: false });

        initializeAllBackups();
        startLoyaltyExpiryJob(propertyDb);
        startAnalyticsRefreshJob(propertyDb);
        startSubscriptionDeliveryJob(propertyDb);
        startLuckyDrawJob(propertyDb);
        
        // Start background WhatsApp message queue worker
        const { startWhatsappQueueJob } = require('./jobs/whatsappQueueJob');
        startWhatsappQueueJob(propertyDb);

        // Start background recurring expenses worker
        const { startRecurringExpensesJob } = require('./jobs/recurringExpensesJob');
        startRecurringExpensesJob(propertyDb);

        // Start background Night Audit worker
        const { startNightAuditJob } = require('./jobs/nightAuditJob');
        startNightAuditJob(propertyDb);

        // Start background Notes Reminder worker
        const { startNotesReminderJob } = require('./jobs/notesReminderJob');
        startNotesReminderJob(propertyDb);

    } catch (err) {
        console.error('❌ Database connection failed', err);
        process.exit(1);
    }
})();


// routes

// No-auth: Flutter uses this at startup to anchor its internal clock against DB time
app.use('/api/system/server-time', require('./routes/systemTime.routes'));

app.use('/api/auth', require('./routes/auth.routes'));
app.use('/api/public', require('./routes/public.routes'));
app.use('/api/inventory', require('./routes/inventory.routes'));
app.use('/api/purchase-orders', require('./routes/purchase.routes'));
app.use('/api/inventory/purchase-orders', require('./routes/purchase.routes'));
app.use('/api/receiving', require('./routes/receiving.routes'));
app.use('/api/suppliers', require('./routes/supplier.routes'));
app.use('/api/sales', require('./routes/sales.routes'));
app.use('/api/lucky-draw', require('./routes/luckyDraw.routes'));
app.use('/api/analytics', require('./routes/analytics.routes'));
app.use('/api/users', require('./routes/user.routes'));
app.use('/api/reports', require('./routes/reports.routes'));
app.use('/api/finance', require('./routes/finance.routes'));
app.use('/api/accounting', require('./routes/accounting.routes'));
app.use('/api/notifications', require('./routes/notification.routes'));
app.use('/api/delivery', require('./routes/delivery.routes'));
app.use('/api/audit', require('./routes/audit.routes'));
app.use('/api/night-audit', require('./routes/nightAudit.routes'));
app.use('/webhooks/whatsapp', require('./routes/whatsappWebhook.routes'));
app.use('/api/whatsapp', require('./routes/whatsapp.routes'));
app.use('/api/hrms', require('./routes/hrms.routes'));
app.use('/api/restaurant', require('./routes/restaurant.routes'));
app.use('/api/settings/smtp', require('./routes/restaurant.routes'));
app.use('/api/v1/ai', require('./routes/ai_assist.routes'));
app.use('/api/v1/intelligence', require('./routes/intelligence.routes'));
app.use('/api/v1/operations', require('./routes/operations.routes'));
app.use('/api/v1/workflows', require('./routes/workflow.routes'));
app.use('/api/v1/agent', require('./routes/autonomous_agent.routes'));
app.use('/api/v1/developer', require('./routes/developer.routes'));
app.use('/api/v1/plugins', require('./routes/plugin.routes'));
app.use('/api/notes', require('./routes/userNote.routes'));

// Web SPA static file serving (Only active if public/ directory exists)
const webBuildPath = path.join(rootDir, 'public');
if (fs.existsSync(webBuildPath)) {
    app.use(express.static(webBuildPath));
    app.use((req, res, next) => {
        if (req.method === 'GET' && !req.path.startsWith('/api') && !req.path.startsWith('/health') && !req.path.startsWith('/uploads') && !req.path.startsWith('/webhooks')) {
            return res.sendFile(path.join(webBuildPath, 'index.html'));
        }
        next();
    });
}

// not found
app.use((req, res) => {
    res.status(404).json({ success: false, message: 'API not found' });
});

// error
app.use((err, req, res, next) => {
    console.error(err);
    res.status(500).json({ success: false, message: 'Server error' });
});

// server
const PORT = process.env.PORT || 3000;
const HOST = license.allowed_mode === 'ONLINE' ? '0.0.0.0' : '0.0.0.0';

app.listen(PORT, HOST, () => {
    console.log(`INV API running on http://${HOST}:${PORT}`);
});


function initializeAllBackups() {
    console.log("🔄 Initializing background backups for all registered outlets...");

    if (!fs.existsSync(CLIENT_FILE)) {
        console.log("⚠️ Client file not found. Bypassing backup initialization.");
        return;
    }

    const config = loadConfig();

    try {

        const fileData = fs.readFileSync(CLIENT_FILE, "utf8");
        let clients = JSON.parse(fileData);

        if (!Array.isArray(clients)) {
            clients = [clients];
        }

        if (clients.length === 0) {
            console.log("⚠️ No outlets found in client file. Bypassing backups.");
            return;
        }

        clients.forEach(client => {
            if (client && client.outlet_code) {
                const status = getBackupStatus(client.outlet_code);
                console.log(`▶️ Scheduling backups for outlet: [${client.outlet_code}] | Cloud Sync: ${status.isCloudEnabled ? 'ON' : 'OFF'}`);

                startBackupJob(client, config);
            }
        });

    } catch (error) {
        console.error(`❌ Failed to initialize backups: ${error.message}`);
    }
}
// Trigger restart: 2026-07-25-1
