const express = require('express');
const cors = require('cors');
const path = require('path');
const fs = require('fs');
const { apiLimiter } = require('./middlewares/rateLimit.middleware');
const { contextMiddleware } = require('./middlewares/context.middleware');
const app = express();
app.use(contextMiddleware);

const loadConfig = require("./utils/decryptConfig");
require('pg');
const waitForPostgres = require('./utils/waitForPostgres');
const { Sequelize } = require('sequelize');
const propertyDb = require('./db/models');
const rootDir = process.pkg ? path.dirname(process.execPath) : process.cwd();
const { startBackupJob } = require("./jobs/backupJob");
const { startLoyaltyExpiryJob } = require("./jobs/loyaltyExpiryJob");
const { startAnalyticsRefreshJob } = require("./jobs/analyticsRefreshJob");
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
            console.log(dbError)
            return res.json({ success: false, action: 'FULL_RECOVERY', message: "Database connection failed." });
        }

        if (!fs.existsSync(sysConfigPath)) {
            return res.json({ success: false, action: 'AUTO_REINSTALL', message: "System files missing." });
        }


        res.json({ success: true, action: 'OK', status: 'RUNNING', time: new Date() });

    } catch (error) {
        res.status(500).json({ success: false, action: 'ERROR', message: "Fatal health check error." });
    }
});

app.use(dbMiddleware);
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

        if (!fs.existsSync(configPath)) {
            console.log('⚠️ [SYSTEM] config.enc is missing. Skipping database boot.');
            console.log('🛡️ [SYSTEM] Server entering Recovery Mode.');
            return;
        }

        const config = loadConfig();
        console.log('✅ Database connected', config.db_password);
        await waitForPostgres(config);

        await ensureDatabase(config);
        await propertyDb.authenticate();
        console.log('✅ Database connected');
        await runMigrations(propertyDb);

        console.log('✅ Database migrations complete');
        await propertyDb.sync({ alter: false });
        console.log('✅ Models synced');

        initializeAllBackups();
        startLoyaltyExpiryJob(propertyDb);
        startAnalyticsRefreshJob(propertyDb);
        
        // Start background WhatsApp message queue worker
        const { startWhatsappQueueJob } = require('./jobs/whatsappQueueJob');
        startWhatsappQueueJob(propertyDb);

    } catch (err) {
        console.error('❌ Database connection failed', err);
        process.exit(1);
    }
})();


// routes

app.use('/api/auth', require('./routes/auth.routes'));
app.use('/api/public', require('./routes/public.routes'));
app.use('/api/inventory', require('./routes/inventory.routes'));
app.use('/api/purchase-orders', require('./routes/purchase.routes'));
app.use('/api/receiving', require('./routes/receiving.routes'));
app.use('/api/suppliers', require('./routes/supplier.routes'));
app.use('/api/sales', require('./routes/sales.routes'));
app.use('/api/analytics', require('./routes/analytics.routes'));
app.use('/api/users', require('./routes/user.routes'));
app.use('/api/reports', require('./routes/reports.routes'));
app.use('/api/finance', require('./routes/finance.routes'));
app.use('/api/notifications', require('./routes/notification.routes'));
app.use('/api/delivery', require('./routes/delivery.routes'));
app.use('/api/audit', require('./routes/audit.routes'));
app.use('/webhooks/whatsapp', require('./routes/whatsappWebhook.routes'));
app.use('/api/whatsapp', require('./routes/whatsapp.routes'));

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
// Trigger restart: 2026-06-22-1
