"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.ensureDeveloperTables = ensureDeveloperTables;
exports.getEcosystemInfo = getEcosystemInfo;
exports.getWebhooks = getWebhooks;
exports.registerWebhook = registerWebhook;
exports.deleteWebhook = deleteWebhook;
exports.testWebhook = testWebhook;
exports.getApiKeys = getApiKeys;
exports.generateApiKey = generateApiKey;
exports.deleteApiKey = deleteApiKey;
exports.issueOAuthToken = issueOAuthToken;
exports.refreshOAuthToken = refreshOAuthToken;
const crypto_1 = __importDefault(require("crypto"));
const jsonwebtoken_1 = __importDefault(require("jsonwebtoken"));
const http_1 = __importDefault(require("http"));
const https_1 = __importDefault(require("https"));
const url_1 = require("url");
// Memory fallback store if DB is temporarily offline
let memoryWebhooks = [];
let memoryApiKeys = [];
let tablesEnsured = false;
async function ensureDeveloperTables(propertyDb) {
    if (tablesEnsured || !propertyDb)
        return;
    try {
        await propertyDb.query(`
            CREATE TABLE IF NOT EXISTS developer_api_keys (
                id VARCHAR(100) PRIMARY KEY,
                outlet_id INT NOT NULL DEFAULT 0,
                key_name VARCHAR(150) NOT NULL,
                api_key VARCHAR(100) UNIQUE NOT NULL,
                client_id VARCHAR(100) UNIQUE NOT NULL,
                client_secret VARCHAR(100) NOT NULL,
                scopes JSONB DEFAULT '["orders:read", "billing:read", "reports:read"]'::jsonb,
                is_active BOOLEAN DEFAULT TRUE,
                last_used_at TIMESTAMP,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
            CREATE INDEX IF NOT EXISTS idx_dev_api_keys_outlet ON developer_api_keys(outlet_id);
            CREATE INDEX IF NOT EXISTS idx_dev_api_keys_api_key ON developer_api_keys(api_key);
            CREATE INDEX IF NOT EXISTS idx_dev_api_keys_client_id ON developer_api_keys(client_id);

            CREATE TABLE IF NOT EXISTS developer_webhooks (
                id VARCHAR(100) PRIMARY KEY,
                outlet_id INT NOT NULL DEFAULT 0,
                topic VARCHAR(100) NOT NULL,
                target_url TEXT NOT NULL,
                secret VARCHAR(100) NOT NULL,
                is_active BOOLEAN DEFAULT TRUE,
                failure_count INT DEFAULT 0,
                last_triggered_at TIMESTAMP,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
            CREATE INDEX IF NOT EXISTS idx_dev_webhooks_outlet ON developer_webhooks(outlet_id);
        `);
        tablesEnsured = true;
    }
    catch (err) {
        console.warn('[DEVELOPER ECOSYSTEM DB WARNING]:', err.message);
    }
}
async function getEcosystemInfo() {
    return {
        ecosystemName: 'FAMALTH LYNX Open Business Ecosystem',
        version: 'v2.0.0-ENTERPRISE',
        brand: 'FAMALTH LYNX',
        company: 'Famalth Business Solutions',
        supportedTopics: [
            'order.created',
            'order.completed',
            'bill.generated',
            'stock.low',
            'customer.created',
            'refund.processed'
        ],
        availableScopes: [
            { scope: 'orders:read', description: 'Read live store and dine-in/takeaway orders' },
            { scope: 'orders:write', description: 'Inject external e-commerce and delivery orders into POS' },
            { scope: 'billing:read', description: 'Read invoice summaries, payments, and tax records' },
            { scope: 'reports:read', description: 'Access daily/monthly revenue, analytics, and sales summaries' },
            { scope: 'inventory:read', description: 'Access live product catalog, SKUs, and stock levels' }
        ],
        authMethods: [
            { method: 'API_KEY', header: 'X-API-Key: lynx_live_sk_...' },
            { method: 'OAUTH2_CLIENT_CREDENTIALS', tokenEndpoint: '/api/v1/developer/oauth/token', header: 'Authorization: Bearer <token>' }
        ],
        documentationUrl: 'https://docs.famalthlynx.io/api/v1'
    };
}
async function getWebhooks(propertyDb, outletId = 0) {
    await ensureDeveloperTables(propertyDb);
    if (propertyDb) {
        try {
            const rows = await propertyDb.query(`SELECT id, outlet_id, topic, target_url, secret, is_active, failure_count, last_triggered_at, created_at
                 FROM developer_webhooks
                 WHERE outlet_id = $1 OR outlet_id = 0
                 ORDER BY created_at DESC`, { bind: [outletId] });
            if (rows[0]) {
                return rows[0].map((r) => ({
                    id: r.id,
                    outletId: r.outlet_id,
                    topic: r.topic,
                    targetUrl: r.target_url,
                    secret: r.secret,
                    isActive: Boolean(r.is_active),
                    failureCount: Number(r.failure_count || 0),
                    lastTriggeredAt: r.last_triggered_at ? new Date(r.last_triggered_at).toISOString() : null,
                    createdAt: r.created_at ? new Date(r.created_at).toISOString() : new Date().toISOString()
                }));
            }
        }
        catch (_) { }
    }
    return memoryWebhooks.filter(w => w.outletId === outletId || w.outletId === 0);
}
async function registerWebhook(propertyDb, outletId = 0, topic, targetUrl) {
    if (!topic || !targetUrl) {
        throw new Error('Topic and targetUrl are required.');
    }
    await ensureDeveloperTables(propertyDb);
    const id = `WH_${Date.now()}_${crypto_1.default.randomBytes(4).toString('hex')}`;
    const secret = `whsec_${crypto_1.default.randomBytes(24).toString('hex')}`;
    const createdAt = new Date().toISOString();
    if (propertyDb) {
        try {
            await propertyDb.query(`INSERT INTO developer_webhooks (id, outlet_id, topic, target_url, secret, is_active, failure_count, created_at)
                 VALUES ($1, $2, $3, $4, $5, TRUE, 0, CURRENT_TIMESTAMP)`, { bind: [id, outletId, topic.trim(), targetUrl.trim(), secret] });
        }
        catch (err) {
            console.error('[REGISTER WEBHOOK DB ERROR]:', err.message);
        }
    }
    const entry = {
        id,
        outletId,
        topic: topic.trim(),
        targetUrl: targetUrl.trim(),
        secret,
        isActive: true,
        failureCount: 0,
        createdAt
    };
    memoryWebhooks.unshift(entry);
    return entry;
}
async function deleteWebhook(propertyDb, outletId = 0, webhookId) {
    await ensureDeveloperTables(propertyDb);
    if (propertyDb) {
        try {
            await propertyDb.query(`DELETE FROM developer_webhooks WHERE id = $1 AND (outlet_id = $2 OR outlet_id = 0)`, { bind: [webhookId, outletId] });
        }
        catch (_) { }
    }
    memoryWebhooks = memoryWebhooks.filter(w => w.id !== webhookId);
    return true;
}
async function testWebhook(propertyDb, outletId = 0, webhookId) {
    const webhooks = await getWebhooks(propertyDb, outletId);
    const target = webhooks.find(w => w.id === webhookId);
    if (!target) {
        throw new Error('Webhook not found.');
    }
    const testPayload = {
        event: target.topic,
        timestamp: new Date().toISOString(),
        outletId: target.outletId || outletId,
        testMode: true,
        data: {
            sampleId: `TEST_${Date.now()}`,
            message: 'Lynx Developer Ecosystem Test Webhook Ping'
        }
    };
    const signature = crypto_1.default
        .createHmac('sha256', target.secret)
        .update(JSON.stringify(testPayload))
        .digest('hex');
    const startTime = Date.now();
    try {
        const parsed = new url_1.URL(target.targetUrl);
        const isHttps = parsed.protocol === 'https:';
        const client = isHttps ? https_1.default : http_1.default;
        const postData = JSON.stringify(testPayload);
        return await new Promise((resolve) => {
            const req = client.request({
                method: 'POST',
                hostname: parsed.hostname,
                port: parsed.port || (isHttps ? 443 : 80),
                path: `${parsed.pathname}${parsed.search}`,
                headers: {
                    'Content-Type': 'application/json',
                    'Content-Length': Buffer.byteLength(postData),
                    'X-Lynx-Event': target.topic,
                    'X-Lynx-Signature': `sha256=${signature}`
                },
                timeout: 6000
            }, (res) => {
                const responseTimeMs = Date.now() - startTime;
                if (propertyDb) {
                    propertyDb.query(`UPDATE developer_webhooks SET last_triggered_at = CURRENT_TIMESTAMP WHERE id = $1`, { bind: [webhookId] }).catch(() => { });
                }
                resolve({
                    success: (res.statusCode ?? 500) >= 200 && (res.statusCode ?? 500) < 300,
                    statusCode: res.statusCode,
                    responseTimeMs,
                    targetUrl: target.targetUrl
                });
            });
            req.on('error', (err) => {
                resolve({
                    success: false,
                    error: err.message,
                    responseTimeMs: Date.now() - startTime,
                    targetUrl: target.targetUrl
                });
            });
            req.on('timeout', () => {
                req.destroy();
                resolve({
                    success: false,
                    error: 'Request timed out after 6000ms',
                    responseTimeMs: Date.now() - startTime,
                    targetUrl: target.targetUrl
                });
            });
            req.write(postData);
            req.end();
        });
    }
    catch (err) {
        return {
            success: false,
            error: err.message,
            targetUrl: target.targetUrl
        };
    }
}
async function getApiKeys(propertyDb, outletId = 0) {
    await ensureDeveloperTables(propertyDb);
    if (propertyDb) {
        try {
            const rows = await propertyDb.query(`SELECT id, outlet_id, key_name, api_key, client_id, client_secret, scopes, is_active, last_used_at, created_at
                 FROM developer_api_keys
                 WHERE outlet_id = $1 OR outlet_id = 0
                 ORDER BY created_at DESC`, { bind: [outletId] });
            if (rows[0] && rows[0].length > 0) {
                return rows[0].map((r) => ({
                    id: r.id,
                    outletId: r.outlet_id,
                    keyName: r.key_name,
                    apiKey: r.api_key,
                    clientId: r.client_id,
                    clientSecret: r.client_secret,
                    scopes: Array.isArray(r.scopes) ? r.scopes : (typeof r.scopes === 'string' ? JSON.parse(r.scopes) : ['orders:read', 'billing:read', 'reports:read']),
                    isActive: Boolean(r.is_active),
                    lastUsedAt: r.last_used_at ? new Date(r.last_used_at).toISOString() : null,
                    createdAt: r.created_at ? new Date(r.created_at).toISOString() : new Date().toISOString()
                }));
            }
        }
        catch (_) { }
    }
    return memoryApiKeys.filter(k => k.outletId === outletId || k.outletId === 0);
}
async function generateApiKey(propertyDb, outletId = 0, keyName, scopes) {
    await ensureDeveloperTables(propertyDb);
    const id = `KEY_${Date.now()}_${crypto_1.default.randomBytes(4).toString('hex')}`;
    const apiKey = `lynx_live_sk_${crypto_1.default.randomBytes(18).toString('hex')}`;
    const clientId = `lynx_client_${crypto_1.default.randomBytes(10).toString('hex')}`;
    const clientSecret = `lynx_secret_${crypto_1.default.randomBytes(24).toString('hex')}`;
    const effectiveScopes = (scopes && scopes.length > 0)
        ? scopes
        : ['orders:read', 'orders:write', 'billing:read', 'reports:read', 'inventory:read'];
    const createdAt = new Date().toISOString();
    if (propertyDb) {
        try {
            await propertyDb.query(`INSERT INTO developer_api_keys (id, outlet_id, key_name, api_key, client_id, client_secret, scopes, is_active, created_at)
                 VALUES ($1, $2, $3, $4, $5, $6, $7, TRUE, CURRENT_TIMESTAMP)`, {
                bind: [
                    id,
                    outletId,
                    keyName ? keyName.trim() : 'External Partner Integration',
                    apiKey,
                    clientId,
                    clientSecret,
                    JSON.stringify(effectiveScopes)
                ]
            });
        }
        catch (err) {
            console.error('[GENERATE API KEY DB ERROR]:', err.message);
        }
    }
    const newKeyEntry = {
        id,
        outletId,
        keyName: keyName ? keyName.trim() : 'External Partner Integration',
        apiKey,
        clientId,
        clientSecret,
        scopes: effectiveScopes,
        isActive: true,
        createdAt
    };
    memoryApiKeys.unshift(newKeyEntry);
    return newKeyEntry;
}
async function deleteApiKey(propertyDb, outletId = 0, keyId) {
    await ensureDeveloperTables(propertyDb);
    if (propertyDb) {
        try {
            await propertyDb.query(`DELETE FROM developer_api_keys WHERE id = $1 AND (outlet_id = $2 OR outlet_id = 0)`, { bind: [keyId, outletId] });
        }
        catch (_) { }
    }
    memoryApiKeys = memoryApiKeys.filter(k => k.id !== keyId);
    return true;
}
/**
 * OAuth 2.0 RFC 6749 Client Credentials Token Exchange
 */
async function issueOAuthToken(propertyDb, clientId, clientSecret) {
    if (!clientId || !clientSecret) {
        throw new Error('client_id and client_secret are required.');
    }
    let keyRecord;
    const allKeys = await getApiKeys(propertyDb, 0);
    keyRecord = allKeys.find(k => k.clientId === clientId && k.clientSecret === clientSecret);
    if (!keyRecord) {
        throw new Error('Invalid client credentials.');
    }
    if (!keyRecord.isActive) {
        throw new Error('Client credentials have been revoked or disabled.');
    }
    // Update last_used_at
    if (propertyDb) {
        propertyDb.query(`UPDATE developer_api_keys SET last_used_at = CURRENT_TIMESTAMP WHERE id = $1`, { bind: [keyRecord.id] }).catch(() => { });
    }
    const jwtSecret = process.env.JWT_SECRET || 'lynx_enterprise_dev_secret_2026';
    const expiresInSeconds = 86400; // 24 Hours
    const token = jsonwebtoken_1.default.sign({
        sub: keyRecord.clientId,
        outlet_id: keyRecord.outletId,
        scopes: keyRecord.scopes,
        key_name: keyRecord.keyName,
        type: 'client_credentials'
    }, jwtSecret, { expiresIn: expiresInSeconds });
    // Long-lived Refresh Token (30 Days) - identical to Google/Gmail OAuth
    const refreshToken = jsonwebtoken_1.default.sign({
        sub: keyRecord.clientId,
        client_secret_hash: crypto_1.default.createHash('sha256').update(keyRecord.clientSecret).digest('hex'),
        outlet_id: keyRecord.outletId,
        type: 'refresh_token'
    }, jwtSecret, { expiresIn: '30d' });
    return {
        access_token: token,
        refresh_token: refreshToken,
        token_type: 'Bearer',
        expires_in: expiresInSeconds,
        scope: keyRecord.scopes.join(' '),
        outlet_id: keyRecord.outletId
    };
}
/**
 * Exchange a Refresh Token for a fresh Access Token automatically
 */
async function refreshOAuthToken(propertyDb, refreshToken) {
    if (!refreshToken) {
        throw new Error('refresh_token is required.');
    }
    const jwtSecret = process.env.JWT_SECRET || 'lynx_enterprise_dev_secret_2026';
    let decoded;
    try {
        decoded = jsonwebtoken_1.default.verify(refreshToken, jwtSecret);
    }
    catch (err) {
        throw new Error('Invalid or expired refresh token: ' + err.message);
    }
    if (decoded.type !== 'refresh_token') {
        throw new Error('Provided token is not a valid refresh token.');
    }
    const allKeys = await getApiKeys(propertyDb, 0);
    const keyRecord = allKeys.find(k => k.clientId === decoded.sub);
    if (!keyRecord || !keyRecord.isActive) {
        throw new Error('Client credentials corresponding to this refresh token are invalid or revoked.');
    }
    const secretHash = crypto_1.default.createHash('sha256').update(keyRecord.clientSecret).digest('hex');
    if (decoded.client_secret_hash !== secretHash) {
        throw new Error('Client secret has changed since this refresh token was issued.');
    }
    // Issue brand new 24h access token and new rolling refresh token
    const expiresInSeconds = 86400;
    const newAccessToken = jsonwebtoken_1.default.sign({
        sub: keyRecord.clientId,
        outlet_id: keyRecord.outletId,
        scopes: keyRecord.scopes,
        key_name: keyRecord.keyName,
        type: 'client_credentials'
    }, jwtSecret, { expiresIn: expiresInSeconds });
    const newRefreshToken = jsonwebtoken_1.default.sign({
        sub: keyRecord.clientId,
        client_secret_hash: secretHash,
        outlet_id: keyRecord.outletId,
        type: 'refresh_token'
    }, jwtSecret, { expiresIn: '30d' });
    return {
        access_token: newAccessToken,
        refresh_token: newRefreshToken,
        token_type: 'Bearer',
        expires_in: expiresInSeconds,
        scope: keyRecord.scopes.join(' '),
        outlet_id: keyRecord.outletId
    };
}
exports.default = {
    ensureDeveloperTables,
    getEcosystemInfo,
    getWebhooks,
    registerWebhook,
    deleteWebhook,
    testWebhook,
    getApiKeys,
    generateApiKey,
    deleteApiKey,
    issueOAuthToken,
    refreshOAuthToken
};
