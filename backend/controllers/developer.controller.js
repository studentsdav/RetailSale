const developerService = require('../services/developer.service');

function resolveOutletId(req) {
    return Number(req?.user?.outlet_id) || 0;
}

exports.getEcosystemInfo = async (req, res) => {
    try {
        const data = await developerService.getEcosystemInfo();
        return res.json({
            success: true,
            data
        });
    } catch (error) {
        console.error('[DEVELOPER ECOSYSTEM CONTROLLER ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: 'Failed to fetch ecosystem information'
        });
    }
};

exports.getWebhooks = async (req, res) => {
    try {
        const outletId = resolveOutletId(req);
        const data = await developerService.getWebhooks(req.propertyDb, outletId);
        return res.json({
            success: true,
            data
        });
    } catch (error) {
        console.error('[DEVELOPER WEBHOOKS CONTROLLER ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: 'Failed to fetch webhooks'
        });
    }
};

exports.registerWebhook = async (req, res) => {
    try {
        const outletId = resolveOutletId(req);
        const { topic, targetUrl } = req.body;
        const data = await developerService.registerWebhook(req.propertyDb, outletId, topic, targetUrl);
        return res.json({
            success: true,
            data
        });
    } catch (error) {
        console.error('[DEVELOPER REGISTER WEBHOOK ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: error.message || 'Failed to register webhook'
        });
    }
};

exports.getApiKeys = async (req, res) => {
    try {
        const outletId = resolveOutletId(req);
        const data = await developerService.getApiKeys(req.propertyDb, outletId);
        return res.json({
            success: true,
            data
        });
    } catch (error) {
        console.error('[DEVELOPER API KEYS CONTROLLER ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: 'Failed to fetch API keys'
        });
    }
};

exports.generateApiKey = async (req, res) => {
    try {
        const outletId = resolveOutletId(req);
        const { keyName } = req.body;
        const data = await developerService.generateApiKey(req.propertyDb, outletId, keyName);
        return res.json({
            success: true,
            data
        });
    } catch (error) {
        console.error('[DEVELOPER GENERATE API KEY ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: error.message || 'Failed to generate API key'
        });
    }
};
