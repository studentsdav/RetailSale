const developerService = require('../services/developer.service');
const defaultDb = require('../db/models');

function getDb(req: any) {
    return req.propertyDb || defaultDb;
}

function resolveOutletId(req: any) {
    const fromUser = Number(req?.user?.outlet_id || req?.user?.outletId);
    if (fromUser) return fromUser;

    const fromHeader = Number(req?.headers?.['x-outlet-id'] || req?.headers?.['outlet_id']);
    if (fromHeader) return fromHeader;

    const fromQueryOrBody = Number(req?.query?.outletId || req?.query?.outlet_id || req?.body?.outletId || req?.body?.outlet_id);
    if (fromQueryOrBody) return fromQueryOrBody;

    // Decode token if req.user was not populated by upstream middleware
    try {
        const token = req?.headers?.authorization?.split(' ')[1];
        if (token) {
            const jwt = require('../utils/jwt.util');
            const data: any = jwt.verify(token);
            if (data?.outlet_id || data?.outletId) return Number(data.outlet_id || data.outletId);
        }
    } catch (_) {}

    return 0;
}

export const getEcosystemInfo = async (req: any, res: any) => {
    try {
        const data = await developerService.getEcosystemInfo();
        return res.json({
            success: true,
            data
        });
    } catch (error: any) {
        console.error('[DEVELOPER ECOSYSTEM CONTROLLER ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: 'Failed to fetch ecosystem information'
        });
    }
};

export const getWebhooks = async (req: any, res: any) => {
    try {
        const outletId = resolveOutletId(req);
        const data = await developerService.getWebhooks(getDb(req), outletId);
        return res.json({
            success: true,
            data
        });
    } catch (error: any) {
        console.error('[DEVELOPER WEBHOOKS CONTROLLER ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: 'Failed to fetch webhooks'
        });
    }
};

export const registerWebhook = async (req: any, res: any) => {
    try {
        const outletId = resolveOutletId(req);
        const { topic, targetUrl } = req.body;
        const data = await developerService.registerWebhook(getDb(req), outletId, topic, targetUrl);
        return res.json({
            success: true,
            data,
            message: 'Webhook registered successfully'
        });
    } catch (error: any) {
        console.error('[DEVELOPER REGISTER WEBHOOK ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: error.message || 'Failed to register webhook'
        });
    }
};

export const deleteWebhook = async (req: any, res: any) => {
    try {
        const outletId = resolveOutletId(req);
        const { id } = req.params;
        await developerService.deleteWebhook(getDb(req), outletId, id);
        return res.json({
            success: true,
            message: 'Webhook deleted successfully'
        });
    } catch (error: any) {
        console.error('[DEVELOPER DELETE WEBHOOK ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: error.message || 'Failed to delete webhook'
        });
    }
};

export const testWebhook = async (req: any, res: any) => {
    try {
        const outletId = resolveOutletId(req);
        const { id } = req.params;
        const data = await developerService.testWebhook(getDb(req), outletId, id);
        return res.json({
            success: true,
            data
        });
    } catch (error: any) {
        console.error('[DEVELOPER TEST WEBHOOK ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: error.message || 'Failed to test webhook'
        });
    }
};

export const getApiKeys = async (req: any, res: any) => {
    try {
        const outletId = resolveOutletId(req);
        const data = await developerService.getApiKeys(getDb(req), outletId);
        return res.json({
            success: true,
            data
        });
    } catch (error: any) {
        console.error('[DEVELOPER API KEYS CONTROLLER ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: 'Failed to fetch API keys'
        });
    }
};

export const generateApiKey = async (req: any, res: any) => {
    try {
        const outletId = resolveOutletId(req);
        const { keyName, scopes } = req.body;
        const data = await developerService.generateApiKey(getDb(req), outletId, keyName, scopes);
        return res.json({
            success: true,
            data,
            message: 'API Key & OAuth credentials generated successfully'
        });
    } catch (error: any) {
        console.error('[DEVELOPER GENERATE API KEY ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: error.message || 'Failed to generate API key'
        });
    }
};

export const deleteApiKey = async (req: any, res: any) => {
    try {
        const outletId = resolveOutletId(req);
        const { id } = req.params;
        await developerService.deleteApiKey(getDb(req), outletId, id);
        return res.json({
            success: true,
            message: 'API Key revoked successfully'
        });
    } catch (error: any) {
        console.error('[DEVELOPER DELETE API KEY ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: error.message || 'Failed to revoke API key'
        });
    }
};

export const issueOAuthToken = async (req: any, res: any) => {
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
    } catch (error: any) {
        console.error('[DEVELOPER OAUTH TOKEN ERROR]:', error.message);
        return res.status(401).json({
            error: 'invalid_grant',
            error_description: error.message || 'Authentication failed'
        });
    }
};

module.exports = {
    getEcosystemInfo,
    getWebhooks,
    registerWebhook,
    deleteWebhook,
    testWebhook,
    getApiKeys,
    generateApiKey,
    deleteApiKey,
    issueOAuthToken
};

export default module.exports;
