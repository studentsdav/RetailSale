import crypto from 'crypto';
import jwt from 'jsonwebtoken';
import http from 'http';
import https from 'https';
import { URL } from 'url';

/**
 * FAMALTH LYNX ECOSYSTEM - Enterprise Developer APIs, OAuth 2.0 & Webhooks Service
 * Enables third-party software, ERP, delivery partners, and developer integrations.
 */

export interface WebhookEntry {
    id: string;
    outletId: number;
    topic: string;
    targetUrl: string;
    secret: string;
    isActive: boolean;
    failureCount: number;
    lastTriggeredAt?: string | null;
    createdAt: string;
}

export interface ApiKeyEntry {
    id: string;
    outletId: number;
    keyName: string;
    apiKey: string;
    clientId: string;
    clientSecret: string;
    scopes: string[];
    isActive: boolean;
    lastUsedAt?: string | null;
    createdAt: string;
}

// Memory fallback store if DB is temporarily offline
let memoryWebhooks: WebhookEntry[] = [];
let memoryApiKeys: ApiKeyEntry[] = [];

let tablesEnsured = false;
export async function ensureDeveloperTables(propertyDb: any) {
    if (tablesEnsured || !propertyDb) return;
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
    } catch (err: any) {
        console.warn('[DEVELOPER ECOSYSTEM DB WARNING]:', err.message);
    }
}

export async function getEcosystemInfo() {
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

export async function getWebhooks(propertyDb?: any, outletId: number = 0): Promise<WebhookEntry[]> {
    await ensureDeveloperTables(propertyDb);
    if (propertyDb) {
        try {
            const querySql = outletId > 0
                ? `SELECT id, outlet_id, topic, target_url, secret, is_active, failure_count, last_triggered_at, created_at
                   FROM developer_webhooks
                   WHERE outlet_id = $1
                   ORDER BY created_at DESC`
                : `SELECT id, outlet_id, topic, target_url, secret, is_active, failure_count, last_triggered_at, created_at
                   FROM developer_webhooks
                   ORDER BY created_at DESC`;
            const bindParams = outletId > 0 ? [outletId] : [];
            const rows = await propertyDb.query(querySql, { bind: bindParams });
            if (rows[0]) {
                return rows[0].map((r: any) => ({
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
        } catch (_) {}
    }
    return memoryWebhooks.filter(w => outletId > 0 ? w.outletId === outletId : true);
}

export async function registerWebhook(
    propertyDb: any,
    outletId: number = 0,
    topic?: string,
    targetUrl?: string
): Promise<WebhookEntry> {
    if (!topic || !targetUrl) {
        throw new Error('Topic and targetUrl are required.');
    }

    await ensureDeveloperTables(propertyDb);
    const id = `WH_${Date.now()}_${crypto.randomBytes(4).toString('hex')}`;
    const secret = `whsec_${crypto.randomBytes(24).toString('hex')}`;
    const createdAt = new Date().toISOString();

    if (propertyDb) {
        try {
            await propertyDb.query(
                `INSERT INTO developer_webhooks (id, outlet_id, topic, target_url, secret, is_active, failure_count, created_at)
                 VALUES ($1, $2, $3, $4, $5, TRUE, 0, CURRENT_TIMESTAMP)`,
                { bind: [id, outletId, topic.trim(), targetUrl.trim(), secret] }
            );
        } catch (err: any) {
            console.error('[REGISTER WEBHOOK DB ERROR]:', err.message);
        }
    }

    const entry: WebhookEntry = {
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

export async function deleteWebhook(propertyDb: any, outletId: number = 0, webhookId: string): Promise<boolean> {
    await ensureDeveloperTables(propertyDb);
    if (propertyDb) {
        try {
            const deleteSql = outletId > 0
                ? `DELETE FROM developer_webhooks WHERE id = $1 AND outlet_id = $2`
                : `DELETE FROM developer_webhooks WHERE id = $1`;
            const bindParams = outletId > 0 ? [webhookId, outletId] : [webhookId];
            await propertyDb.query(deleteSql, { bind: bindParams });
        } catch (_) {}
    }
    memoryWebhooks = memoryWebhooks.filter(w => w.id !== webhookId);
    return true;
}

export async function testWebhook(propertyDb: any, outletId: number = 0, webhookId: string): Promise<any> {
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

    const signature = crypto
        .createHmac('sha256', target.secret)
        .update(JSON.stringify(testPayload))
        .digest('hex');

    const startTime = Date.now();
    try {
        const parsed = new URL(target.targetUrl);
        const isHttps = parsed.protocol === 'https:';
        const client = isHttps ? https : http;
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
                    propertyDb.query(
                        `UPDATE developer_webhooks SET last_triggered_at = CURRENT_TIMESTAMP WHERE id = $1`,
                        { bind: [webhookId] }
                    ).catch(() => {});
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
    } catch (err: any) {
        return {
            success: false,
            error: err.message,
            targetUrl: target.targetUrl
        };
    }
}

export async function getApiKeys(propertyDb?: any, outletId: number = 0): Promise<ApiKeyEntry[]> {
    await ensureDeveloperTables(propertyDb);
    if (propertyDb) {
        try {
            const querySql = outletId > 0
                ? `SELECT id, outlet_id, key_name, api_key, client_id, client_secret, scopes, is_active, last_used_at, created_at
                   FROM developer_api_keys
                   WHERE outlet_id = $1
                   ORDER BY created_at DESC`
                : `SELECT id, outlet_id, key_name, api_key, client_id, client_secret, scopes, is_active, last_used_at, created_at
                   FROM developer_api_keys
                   ORDER BY created_at DESC`;
            const bindParams = outletId > 0 ? [outletId] : [];
            const rows = await propertyDb.query(querySql, { bind: bindParams });
            if (rows[0] && rows[0].length > 0) {
                return rows[0].map((r: any) => ({
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
        } catch (_) {}
    }
    return memoryApiKeys.filter(k => outletId > 0 ? k.outletId === outletId : true);
}

export async function generateApiKey(
    propertyDb: any,
    outletId: number = 0,
    keyName?: string,
    scopes?: string[]
): Promise<ApiKeyEntry> {
    await ensureDeveloperTables(propertyDb);
    const id = `KEY_${Date.now()}_${crypto.randomBytes(4).toString('hex')}`;
    const apiKey = `lynx_live_sk_${crypto.randomBytes(18).toString('hex')}`;
    const clientId = `lynx_client_${crypto.randomBytes(10).toString('hex')}`;
    const clientSecret = `lynx_secret_${crypto.randomBytes(24).toString('hex')}`;
    const effectiveScopes = (scopes && scopes.length > 0)
        ? scopes
        : ['orders:read', 'orders:write', 'billing:read', 'reports:read', 'inventory:read'];
    const createdAt = new Date().toISOString();

    if (propertyDb) {
        try {
            await propertyDb.query(
                `INSERT INTO developer_api_keys (id, outlet_id, key_name, api_key, client_id, client_secret, scopes, is_active, created_at)
                 VALUES ($1, $2, $3, $4, $5, $6, $7, TRUE, CURRENT_TIMESTAMP)`,
                {
                    bind: [
                        id,
                        outletId,
                        keyName ? keyName.trim() : 'External Partner Integration',
                        apiKey,
                        clientId,
                        clientSecret,
                        JSON.stringify(effectiveScopes)
                    ]
                }
            );
        } catch (err: any) {
            console.error('[GENERATE API KEY DB ERROR]:', err.message);
        }
    }

    const newKeyEntry: ApiKeyEntry = {
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

export async function deleteApiKey(propertyDb: any, outletId: number = 0, keyId: string): Promise<boolean> {
    await ensureDeveloperTables(propertyDb);
    if (propertyDb) {
        try {
            const deleteSql = outletId > 0
                ? `DELETE FROM developer_api_keys WHERE id = $1 AND outlet_id = $2`
                : `DELETE FROM developer_api_keys WHERE id = $1`;
            const bindParams = outletId > 0 ? [keyId, outletId] : [keyId];
            await propertyDb.query(deleteSql, { bind: bindParams });
        } catch (_) {}
    }
    memoryApiKeys = memoryApiKeys.filter(k => k.id !== keyId);
    return true;
}

/**
 * OAuth 2.0 RFC 6749 Client Credentials Token Exchange
 */
export async function issueOAuthToken(propertyDb: any, clientId: string, clientSecret: string) {
    if (!clientId || !clientSecret) {
        throw new Error('client_id and client_secret are required.');
    }

    let keyRecord: ApiKeyEntry | undefined;
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
        propertyDb.query(
            `UPDATE developer_api_keys SET last_used_at = CURRENT_TIMESTAMP WHERE id = $1`,
            { bind: [keyRecord.id] }
        ).catch(() => {});
    }

    const jwtSecret = process.env.JWT_SECRET || 'lynx_enterprise_dev_secret_2026';
    const expiresInSeconds = 86400; // 24 Hours

    const token = jwt.sign(
        {
            sub: keyRecord.clientId,
            outlet_id: keyRecord.outletId,
            scopes: keyRecord.scopes,
            key_name: keyRecord.keyName,
            type: 'client_credentials'
        },
        jwtSecret,
        { expiresIn: expiresInSeconds }
    );

    // Long-lived Refresh Token (30 Days) - identical to Google/Gmail OAuth
    const refreshToken = jwt.sign(
        {
            sub: keyRecord.clientId,
            client_secret_hash: crypto.createHash('sha256').update(keyRecord.clientSecret).digest('hex'),
            outlet_id: keyRecord.outletId,
            type: 'refresh_token'
        },
        jwtSecret,
        { expiresIn: '30d' }
    );

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
export async function refreshOAuthToken(propertyDb: any, refreshToken: string) {
    if (!refreshToken) {
        throw new Error('refresh_token is required.');
    }

    const jwtSecret = process.env.JWT_SECRET || 'lynx_enterprise_dev_secret_2026';
    let decoded: any;
    try {
        decoded = jwt.verify(refreshToken, jwtSecret);
    } catch (err: any) {
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

    const secretHash = crypto.createHash('sha256').update(keyRecord.clientSecret).digest('hex');
    if (decoded.client_secret_hash !== secretHash) {
        throw new Error('Client secret has changed since this refresh token was issued.');
    }

    // Issue brand new 24h access token and new rolling refresh token
    const expiresInSeconds = 86400;
    const newAccessToken = jwt.sign(
        {
            sub: keyRecord.clientId,
            outlet_id: keyRecord.outletId,
            scopes: keyRecord.scopes,
            key_name: keyRecord.keyName,
            type: 'client_credentials'
        },
        jwtSecret,
        { expiresIn: expiresInSeconds }
    );

    const newRefreshToken = jwt.sign(
        {
            sub: keyRecord.clientId,
            client_secret_hash: secretHash,
            outlet_id: keyRecord.outletId,
            type: 'refresh_token'
        },
        jwtSecret,
        { expiresIn: '30d' }
    );

    return {
        access_token: newAccessToken,
        refresh_token: newRefreshToken,
        token_type: 'Bearer',
        expires_in: expiresInSeconds,
        scope: keyRecord.scopes.join(' '),
        outlet_id: keyRecord.outletId
    };
}

export default {
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
