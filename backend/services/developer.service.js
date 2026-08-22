/**
 * FAMALTH LYNX ECOSYSTEM - Open Developer APIs & Webhooks Service
 * Enables third-party software, hardware peripherals, and developer integrations.
 */

let webhooksStore = [
    {
        id: 'WH_001',
        topic: 'sale.completed',
        targetUrl: 'https://api.myerp.com/webhooks/pos-sales',
        status: 'ACTIVE',
        createdAt: new Date().toISOString()
    },
    {
        id: 'WH_002',
        topic: 'stock.low',
        targetUrl: 'https://warehouse.supplychain.io/alerts/stock',
        status: 'ACTIVE',
        createdAt: new Date().toISOString()
    }
];

let apiKeysStore = [
    {
        id: 'KEY_001',
        keyName: 'Main Store E-Commerce Integration',
        apiKey: 'lynx_live_sk_98f412a8bc94017d23a',
        createdAt: new Date().toISOString(),
        permissions: ['read_catalog', 'write_sales', 'read_inventory']
    }
];

async function getEcosystemInfo() {
    return {
        ecosystemName: 'FAMALTH LYNX Open Business Ecosystem',
        version: 'v1.0.0-FAMALTH-LYNX',
        brand: 'FAMALTH LYNX',
        company: 'Famalth Business Solutions',
        supportedTopics: [
            'sale.completed',
            'stock.low',
            'customer.created',
            'purchase.received',
            'attendance.clock_in'
        ],
        hardwareIntegrations: [
            'Esc/Pos Thermal Printers (USB/Bluetooth/Network)',
            'Barcode Scanners (HID/COM/Serial)',
            'Electronic Weighing Scale Peripherals',
            'Merchant UPI & Android POS Smart Cards'
        ],
        documentationUrl: 'https://docs.famalthlynx.io/api/v1'
    };
}

async function getWebhooks(propertyDb, outletId = 0) {
    return webhooksStore;
}

async function registerWebhook(propertyDb, outletId = 0, topic, targetUrl) {
    if (!topic || !targetUrl) {
        throw new Error('Topic and targetUrl are required');
    }

    const newWebhook = {
        id: `WH_${Date.now()}`,
        topic,
        targetUrl,
        status: 'ACTIVE',
        createdAt: new Date().toISOString()
    };

    webhooksStore.push(newWebhook);
    return newWebhook;
}

async function getApiKeys(propertyDb, outletId = 0) {
    return apiKeysStore;
}

async function generateApiKey(propertyDb, outletId = 0, keyName) {
    const key = `lynx_live_sk_${Math.random().toString(36).substring(2, 15)}${Math.random().toString(36).substring(2, 15)}`;
    const newKeyEntry = {
        id: `KEY_${Date.now()}`,
        keyName: keyName || 'Developer Key',
        apiKey: key,
        createdAt: new Date().toISOString(),
        permissions: ['read_catalog', 'write_sales', 'read_inventory']
    };

    apiKeysStore.push(newKeyEntry);
    return newKeyEntry;
}

module.exports = {
    getEcosystemInfo,
    getWebhooks,
    registerWebhook,
    getApiKeys,
    generateApiKey
};
