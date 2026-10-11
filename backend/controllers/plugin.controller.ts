const pluginService = require('../services/plugin_manager.service');
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

export const getMarketplaceCatalog = async (req: any, res: any) => {
    try {
        const outletId = resolveOutletId(req);
        const data = await pluginService.getMarketplaceCatalog(getDb(req), outletId);
        return res.json({
            success: true,
            data
        });
    } catch (error: any) {
        console.error('[PLUGIN MARKETPLACE CONTROLLER ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: 'Failed to fetch plugin marketplace'
        });
    }
};

export const getInstalledPlugins = async (req: any, res: any) => {
    try {
        const outletId = resolveOutletId(req);
        const data = await pluginService.getInstalledPlugins(getDb(req), outletId);
        return res.json({
            success: true,
            data
        });
    } catch (error: any) {
        console.error('[INSTALLED PLUGINS CONTROLLER ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: 'Failed to fetch installed plugins'
        });
    }
};

export const installPlugin = async (req: any, res: any) => {
    try {
        const outletId = resolveOutletId(req);
        const { pluginId } = req.body;
        const data = await pluginService.installPlugin(getDb(req), outletId, pluginId);
        return res.json({
            success: true,
            data
        });
    } catch (error: any) {
        console.error('[INSTALL PLUGIN ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: error.message || 'Failed to install plugin'
        });
    }
};

export const uninstallPlugin = async (req: any, res: any) => {
    try {
        const outletId = resolveOutletId(req);
        const pluginId = req.params.id || req.body?.pluginId;
        await pluginService.uninstallPlugin(getDb(req), outletId, pluginId);
        return res.json({
            success: true,
            message: 'Plugin uninstalled successfully'
        });
    } catch (error: any) {
        console.error('[UNINSTALL PLUGIN ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: error.message || 'Failed to uninstall plugin'
        });
    }
};

export const deleteDeveloperPlugin = async (req: any, res: any) => {
    try {
        const outletId = resolveOutletId(req);
        const pluginId = req.params.id || req.body?.pluginId;
        await pluginService.deleteDeveloperPlugin(getDb(req), outletId, pluginId);
        return res.json({
            success: true,
            deleted: true,
            message: `Plugin "${pluginId}" permanently deleted from catalog.`
        });
    } catch (error: any) {
        console.error('[DELETE DEVELOPER PLUGIN ERROR]:', error.message);
        return res.status(error.message?.includes('Permission') ? 403 : 400).json({
            success: false,
            message: error.message || 'Failed to delete plugin'
        });
    }
};

export const togglePlugin = async (req: any, res: any) => {
    try {
        const outletId = resolveOutletId(req);
        const { id } = req.params;
        const { isActive } = req.body;
        const data = await pluginService.togglePlugin(getDb(req), outletId, id, isActive);
        return res.json({
            success: true,
            data
        });
    } catch (error: any) {
        console.error('[TOGGLE PLUGIN ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: error.message || 'Failed to toggle plugin'
        });
    }
};

export const savePluginConfig = async (req: any, res: any) => {
    try {
        const outletId = resolveOutletId(req);
        const { id } = req.params;
        const { config } = req.body;
        const data = await pluginService.savePluginConfig(getDb(req), outletId, id, config);
        return res.json({
            success: true,
            data
        });
    } catch (error: any) {
        console.error('[SAVE PLUGIN CONFIG ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: error.message || 'Failed to save plugin configuration'
        });
    }
};

export const deployDeveloperPlugin = async (req: any, res: any) => {
    try {
        const outletId = resolveOutletId(req);
        const data = await pluginService.deployDeveloperPlugin(getDb(req), outletId, req.body);
        return res.json({
            success: true,
            ...data
        });
    } catch (error: any) {
        console.error('[DEPLOY PLUGIN ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: error.message || 'Failed to deploy developer plugin'
        });
    }
};

export const executePluginHook = async (req: any, res: any) => {
    try {
        const outletId = resolveOutletId(req);
        const { id, hook } = req.params;
        const payload = req.body || {};
        const data = await pluginService.executePluginHook(getDb(req), outletId, id, hook, payload);
        return res.json({
            success: true,
            data
        });
    } catch (error: any) {
        console.error('[EXECUTE PLUGIN HOOK ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: error.message || 'Failed to execute plugin hook'
        });
    }
};

export const getPluginLogs = async (req: any, res: any) => {
    try {
        const outletId = resolveOutletId(req);
        const { id } = req.params;
        const data = await pluginService.getPluginExecutionLogs(getDb(req), outletId, id);
        return res.json({
            success: true,
            data
        });
    } catch (error: any) {
        console.error('[PLUGIN LOGS ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: error.message || 'Failed to fetch plugin logs'
        });
    }
};

export const getThirdPartyOrders = async (req: any, res: any) => {
    try {
        const outletId = resolveOutletId(req);
        const { sourceTag, limit, offset, search } = req.query;
        const data = await pluginService.getThirdPartyOrders(getDb(req), outletId, {
            sourceTag: sourceTag ? String(sourceTag) : undefined,
            limit: limit ? Number(limit) : 100,
            offset: offset ? Number(offset) : 0,
            search: search ? String(search) : undefined
        });
        return res.json({
            success: true,
            data
        });
    } catch (error: any) {
        console.error('[GET THIRD PARTY ORDERS CONTROLLER ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: error.message || 'Failed to fetch third-party orders'
        });
    }
};

export const deleteThirdPartyOrders = async (req: any, res: any) => {
    try {
        const outletId = resolveOutletId(req);
        const sourceTag = req.query.sourceTag || req.body?.sourceTag;
        const data = await pluginService.deleteThirdPartyOrders(getDb(req), outletId, {
            sourceTag: sourceTag ? String(sourceTag) : undefined
        });
        return res.json({
            success: true,
            data
        });
    } catch (error: any) {
        console.error('[DELETE THIRD PARTY ORDERS CONTROLLER ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: error.message || 'Failed to delete third-party orders'
        });
    }
};

export const searchCommunityPlugins = async (req: any, res: any) => {
    try {
        const outletId = resolveOutletId(req);
        const { q, search, limit, offset } = req.query;
        const searchQuery = String(q || search || '');
        const data = await pluginService.searchCommunityPlugins(
            getDb(req),
            outletId,
            searchQuery,
            Number(limit || 20),
            Number(offset || 0)
        );
        return res.json({
            success: true,
            data
        });
    } catch (error: any) {
        console.error('[COMMUNITY SEARCH CONTROLLER ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: 'Failed to search community plugins'
        });
    }
};

module.exports = {
    getMarketplaceCatalog,
    getInstalledPlugins,
    installPlugin,
    uninstallPlugin,
    togglePlugin,
    savePluginConfig,
    deployDeveloperPlugin,
    executePluginHook,
    getPluginLogs,
    getThirdPartyOrders,
    deleteThirdPartyOrders,
    searchCommunityPlugins,
    deleteDeveloperPlugin
};
export default module.exports;
