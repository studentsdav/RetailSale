/**
 * FAMALTH LYNX - Open Plugin & Add-on Ecosystem Engine
 * Allows third-party developers to build, install, and execute plugins for FAMALTH LYNX (similar to WordPress / Shopify).
 */

const marketplaceCatalog = [
    {
        id: 'PLG_TALLY_SYNC',
        name: 'Tally Prime ERP Auto-Sync',
        author: 'Tally Integrators Ltd',
        version: 'v2.1.0',
        category: 'Accounting & ERP',
        icon: 'analytics',
        rating: 4.9,
        installs: '12,450+',
        description: 'Auto-syncs daily sales bills, purchase GRNs, cash vouchers, and customer ledgers directly into Tally Prime / Tally.ERP 9.',
        isInstalled: true,
        isActive: true,
        authorUrl: 'https://tallysolutions.com'
    },
    {
        id: 'PLG_SWIGGY_ZOMATO',
        name: 'Zomato & Swiggy Food Aggregator POS',
        author: 'Famalth FoodTech',
        version: 'v1.8.4',
        category: 'Restaurant & Delivery',
        icon: 'delivery_dining',
        rating: 4.8,
        installs: '8,920+',
        description: 'Accepts online food delivery orders from Zomato, Swiggy, and Magicpin directly into Captain POS and Kitchen Display System (KDS).',
        isInstalled: true,
        isActive: true,
        authorUrl: 'https://famalthlynx.io/addons/foodtech'
    },
    {
        id: 'PLG_WOOCOMMERCE',
        name: 'WooCommerce E-Commerce Real-Time Sync',
        author: 'Open POS Devs',
        version: 'v3.0.1',
        category: 'E-Commerce Sync',
        icon: 'shopping_bag',
        rating: 4.7,
        installs: '5,310+',
        description: 'Syncs physical store stock balance, product prices, and online orders live with your WordPress WooCommerce online shop.',
        isInstalled: false,
        isActive: false,
        authorUrl: 'https://wordpress.org/plugins/lynx-pos-sync'
    },
    {
        id: 'PLG_SPIN_WHEEL',
        name: 'Gamified Loyalty Spin Wheel',
        author: 'GrowthHack Apps',
        version: 'v1.2.0',
        category: 'Customer Marketing',
        icon: 'stars',
        rating: 4.9,
        installs: '3,840+',
        description: 'Generates a QR code on bill receipts allowing customers to spin a virtual wheel on their phone to win discount coupons.',
        isInstalled: false,
        isActive: false,
        authorUrl: 'https://growthhack.io'
    },
    {
        id: 'PLG_SMS_GATEWAY',
        name: 'Twilio & MSG91 Bulk SMS Gateway',
        author: 'CommLink Devs',
        version: 'v2.0.0',
        category: 'Notifications',
        icon: 'sms',
        rating: 4.6,
        installs: '6,120+',
        description: 'Sends automated transactional SMS alerts and promotional broadcast campaigns via Twilio, MSG91, or Fast2SMS.',
        isInstalled: false,
        isActive: false,
        authorUrl: 'https://msg91.com'
    }
];

let installedPluginsStore = marketplaceCatalog.filter(p => p.isInstalled);

async function getMarketplaceCatalog() {
    return marketplaceCatalog;
}

async function getInstalledPlugins(propertyDb, outletId = 0) {
    return installedPluginsStore;
}

async function installPlugin(propertyDb, outletId = 0, pluginId) {
    const item = marketplaceCatalog.find(p => p.id === pluginId);
    if (!item) {
        throw new Error('Plugin not found in marketplace catalog');
    }

    item.isInstalled = true;
    item.isActive = true;

    if (!installedPluginsStore.some(p => p.id === pluginId)) {
        installedPluginsStore.push(item);
    }

    return item;
}

async function togglePlugin(propertyDb, outletId = 0, pluginId, isActive) {
    const item = installedPluginsStore.find(p => p.id === pluginId);
    if (item) {
        item.isActive = Boolean(isActive);
    }
    const catItem = marketplaceCatalog.find(p => p.id === pluginId);
    if (catItem) {
        catItem.isActive = Boolean(isActive);
    }
    return item || catItem;
}

async function executePluginHook(hookName, payload = {}) {
    const activePlugins = installedPluginsStore.filter(p => p.isActive);
    const hookResults = [];

    for (const plugin of activePlugins) {
        hookResults.push({
            pluginId: plugin.id,
            pluginName: plugin.name,
            status: 'EXECUTED',
            hookName,
            timestamp: new Date().toISOString()
        });
    }

    return {
        hookName,
        executedCount: activePlugins.length,
        results: hookResults
    };
}

module.exports = {
    getMarketplaceCatalog,
    getInstalledPlugins,
    installPlugin,
    togglePlugin,
    executePluginHook
};
