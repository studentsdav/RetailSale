"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.issueOAuthToken = exports.deleteApiKey = exports.generateApiKey = exports.getApiKeys = exports.testWebhook = exports.deleteWebhook = exports.registerWebhook = exports.getWebhooks = exports.getEcosystemInfo = void 0;
const developerService = require('../services/developer.service');
const defaultDb = require('../db/models');
function getDb(req) {
    return req.propertyDb || defaultDb;
}
function resolveOutletId(req) {
    return Number(req?.user?.outlet_id) || Number(req?.query?.outletId) || Number(req?.body?.outletId) || 0;
}
const getEcosystemInfo = async (req, res) => {
    try {
        const data = await developerService.getEcosystemInfo();
        return res.json({
            success: true,
            data
        });
    }
    catch (error) {
        console.error('[DEVELOPER ECOSYSTEM CONTROLLER ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: 'Failed to fetch ecosystem information'
        });
    }
};
exports.getEcosystemInfo = getEcosystemInfo;
const getWebhooks = async (req, res) => {
    try {
        const outletId = resolveOutletId(req);
        const data = await developerService.getWebhooks(getDb(req), outletId);
        return res.json({
            success: true,
            data
        });
    }
    catch (error) {
        console.error('[DEVELOPER WEBHOOKS CONTROLLER ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: 'Failed to fetch webhooks'
        });
    }
};
exports.getWebhooks = getWebhooks;
const registerWebhook = async (req, res) => {
    try {
        const outletId = resolveOutletId(req);
        const { topic, targetUrl } = req.body;
        const data = await developerService.registerWebhook(getDb(req), outletId, topic, targetUrl);
        return res.json({
            success: true,
            data,
            message: 'Webhook registered successfully'
        });
    }
    catch (error) {
        console.error('[DEVELOPER REGISTER WEBHOOK ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: error.message || 'Failed to register webhook'
        });
    }
};
exports.registerWebhook = registerWebhook;
const deleteWebhook = async (req, res) => {
    try {
        const outletId = resolveOutletId(req);
        const { id } = req.params;
        await developerService.deleteWebhook(getDb(req), outletId, id);
        return res.json({
            success: true,
            message: 'Webhook deleted successfully'
        });
    }
    catch (error) {
        console.error('[DEVELOPER DELETE WEBHOOK ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: error.message || 'Failed to delete webhook'
        });
    }
};
exports.deleteWebhook = deleteWebhook;
const testWebhook = async (req, res) => {
    try {
        const outletId = resolveOutletId(req);
        const { id } = req.params;
        const data = await developerService.testWebhook(getDb(req), outletId, id);
        return res.json({
            success: true,
            data
        });
    }
    catch (error) {
        console.error('[DEVELOPER TEST WEBHOOK ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: error.message || 'Failed to test webhook'
        });
    }
};
exports.testWebhook = testWebhook;
const getApiKeys = async (req, res) => {
    try {
        const outletId = resolveOutletId(req);
        const data = await developerService.getApiKeys(getDb(req), outletId);
        return res.json({
            success: true,
            data
        });
    }
    catch (error) {
        console.error('[DEVELOPER API KEYS CONTROLLER ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: 'Failed to fetch API keys'
        });
    }
};
exports.getApiKeys = getApiKeys;
const generateApiKey = async (req, res) => {
    try {
        const outletId = resolveOutletId(req);
        const { keyName, scopes } = req.body;
        const data = await developerService.generateApiKey(getDb(req), outletId, keyName, scopes);
        return res.json({
            success: true,
            data,
            message: 'API Key & OAuth credentials generated successfully'
        });
    }
    catch (error) {
        console.error('[DEVELOPER GENERATE API KEY ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: error.message || 'Failed to generate API key'
        });
    }
};
exports.generateApiKey = generateApiKey;
const deleteApiKey = async (req, res) => {
    try {
        const outletId = resolveOutletId(req);
        const { id } = req.params;
        await developerService.deleteApiKey(getDb(req), outletId, id);
        return res.json({
            success: true,
            message: 'API Key revoked successfully'
        });
    }
    catch (error) {
        console.error('[DEVELOPER DELETE API KEY ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: error.message || 'Failed to revoke API key'
        });
    }
};
exports.deleteApiKey = deleteApiKey;
const issueOAuthToken = async (req, res) => {
    try {
        const clientId = req.body?.client_id || req.body?.clientId;
        const clientSecret = req.body?.client_secret || req.body?.clientSecret;
        const grantType = req.body?.grant_type || req.body?.grantType || 'client_credentials';
        if (grantType === 'refresh_token') {
            const refreshToken = req.body?.refresh_token || req.body?.refreshToken;
            if (!refreshToken) {
                return res.status(400).json({
                    error: 'invalid_request',
                    error_description: 'refresh_token parameter is required for grant_type=refresh_token.'
                });
            }
            const data = await developerService.refreshOAuthToken(getDb(req), refreshToken);
            return res.json(data);
        }
        if (grantType !== 'client_credentials') {
            return res.status(400).json({
                error: 'unsupported_grant_type',
                error_description: 'Supported grant_type values: client_credentials, refresh_token.'
            });
        }
        const data = await developerService.issueOAuthToken(getDb(req), clientId, clientSecret);
        return res.json(data);
    }
    catch (error) {
        console.error('[DEVELOPER OAUTH TOKEN ERROR]:', error.message);
        return res.status(401).json({
            error: 'invalid_grant',
            error_description: error.message || 'Authentication failed'
        });
    }
};
exports.issueOAuthToken = issueOAuthToken;
module.exports = {
    getEcosystemInfo: exports.getEcosystemInfo,
    getWebhooks: exports.getWebhooks,
    registerWebhook: exports.registerWebhook,
    deleteWebhook: exports.deleteWebhook,
    testWebhook: exports.testWebhook,
    getApiKeys: exports.getApiKeys,
    generateApiKey: exports.generateApiKey,
    deleteApiKey: exports.deleteApiKey,
    issueOAuthToken: exports.issueOAuthToken
};
exports.default = module.exports;
