"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.deleteThirdPartyOrders = exports.getThirdPartyOrders = exports.getPluginLogs = exports.executePluginHook = exports.deployDeveloperPlugin = exports.savePluginConfig = exports.togglePlugin = exports.uninstallPlugin = exports.installPlugin = exports.getInstalledPlugins = exports.getMarketplaceCatalog = void 0;
const pluginService = require('../services/plugin_manager.service');
const defaultDb = require('../db/models');
function getDb(req) {
    return req.propertyDb || defaultDb;
}
function resolveOutletId(req) {
    return Number(req?.user?.outlet_id) || Number(req?.query?.outletId) || Number(req?.body?.outletId) || 0;
}
const getMarketplaceCatalog = async (req, res) => {
    try {
        const outletId = resolveOutletId(req);
        const data = await pluginService.getMarketplaceCatalog(getDb(req), outletId);
        return res.json({
            success: true,
            data
        });
    }
    catch (error) {
        console.error('[PLUGIN MARKETPLACE CONTROLLER ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: 'Failed to fetch plugin marketplace'
        });
    }
};
exports.getMarketplaceCatalog = getMarketplaceCatalog;
const getInstalledPlugins = async (req, res) => {
    try {
        const outletId = resolveOutletId(req);
        const data = await pluginService.getInstalledPlugins(getDb(req), outletId);
        return res.json({
            success: true,
            data
        });
    }
    catch (error) {
        console.error('[INSTALLED PLUGINS CONTROLLER ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: 'Failed to fetch installed plugins'
        });
    }
};
exports.getInstalledPlugins = getInstalledPlugins;
const installPlugin = async (req, res) => {
    try {
        const outletId = resolveOutletId(req);
        const { pluginId } = req.body;
        const data = await pluginService.installPlugin(getDb(req), outletId, pluginId);
        return res.json({
            success: true,
            data
        });
    }
    catch (error) {
        console.error('[INSTALL PLUGIN ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: error.message || 'Failed to install plugin'
        });
    }
};
exports.installPlugin = installPlugin;
const uninstallPlugin = async (req, res) => {
    try {
        const outletId = resolveOutletId(req);
        const pluginId = req.params.id || req.body?.pluginId;
        await pluginService.uninstallPlugin(getDb(req), outletId, pluginId);
        return res.json({
            success: true,
            message: 'Plugin uninstalled successfully'
        });
    }
    catch (error) {
        console.error('[UNINSTALL PLUGIN ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: error.message || 'Failed to uninstall plugin'
        });
    }
};
exports.uninstallPlugin = uninstallPlugin;
const deleteDeveloperPlugin = async (req, res) => {
    try {
        const outletId = resolveOutletId(req);
        const pluginId = req.params.id || req.body?.pluginId;
        await pluginService.deleteDeveloperPlugin(getDb(req), outletId, pluginId);
        return res.json({
            success: true,
            deleted: true,
            message: `Plugin "${pluginId}" permanently deleted from catalog.`
        });
    }
    catch (error) {
        console.error('[DELETE DEVELOPER PLUGIN ERROR]:', error.message);
        return res.status(error.message?.includes('Permission') ? 403 : 400).json({
            success: false,
            message: error.message || 'Failed to delete plugin'
        });
    }
};
exports.deleteDeveloperPlugin = deleteDeveloperPlugin;
const togglePlugin = async (req, res) => {
    try {
        const outletId = resolveOutletId(req);
        const { id } = req.params;
        const { isActive } = req.body;
        const data = await pluginService.togglePlugin(getDb(req), outletId, id, isActive);
        return res.json({
            success: true,
            data
        });
    }
    catch (error) {
        console.error('[TOGGLE PLUGIN ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: error.message || 'Failed to toggle plugin'
        });
    }
};
exports.togglePlugin = togglePlugin;
const savePluginConfig = async (req, res) => {
    try {
        const outletId = resolveOutletId(req);
        const { id } = req.params;
        const { config } = req.body;
        const data = await pluginService.savePluginConfig(getDb(req), outletId, id, config);
        return res.json({
            success: true,
            data
        });
    }
    catch (error) {
        console.error('[SAVE PLUGIN CONFIG ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: error.message || 'Failed to save plugin configuration'
        });
    }
};
exports.savePluginConfig = savePluginConfig;
const deployDeveloperPlugin = async (req, res) => {
    try {
        const outletId = resolveOutletId(req);
        const data = await pluginService.deployDeveloperPlugin(getDb(req), outletId, req.body);
        return res.json({
            success: true,
            ...data
        });
    }
    catch (error) {
        console.error('[DEPLOY PLUGIN ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: error.message || 'Failed to deploy developer plugin'
        });
    }
};
exports.deployDeveloperPlugin = deployDeveloperPlugin;
const executePluginHook = async (req, res) => {
    try {
        const outletId = resolveOutletId(req);
        const { id, hook } = req.params;
        const payload = req.body || {};
        const data = await pluginService.executePluginHook(getDb(req), outletId, id, hook, payload);
        return res.json({
            success: true,
            data
        });
    }
    catch (error) {
        console.error('[EXECUTE PLUGIN HOOK ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: error.message || 'Failed to execute plugin hook'
        });
    }
};
exports.executePluginHook = executePluginHook;
const getPluginLogs = async (req, res) => {
    try {
        const outletId = resolveOutletId(req);
        const { id } = req.params;
        const data = await pluginService.getPluginExecutionLogs(getDb(req), outletId, id);
        return res.json({
            success: true,
            data
        });
    }
    catch (error) {
        console.error('[PLUGIN LOGS ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: error.message || 'Failed to fetch plugin logs'
        });
    }
};
exports.getPluginLogs = getPluginLogs;
const getThirdPartyOrders = async (req, res) => {
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
    }
    catch (error) {
        console.error('[GET THIRD PARTY ORDERS CONTROLLER ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: error.message || 'Failed to fetch third-party orders'
        });
    }
};
exports.getThirdPartyOrders = getThirdPartyOrders;
const deleteThirdPartyOrders = async (req, res) => {
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
    }
    catch (error) {
        console.error('[DELETE THIRD PARTY ORDERS CONTROLLER ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: error.message || 'Failed to delete third-party orders'
        });
    }
};
exports.deleteThirdPartyOrders = deleteThirdPartyOrders;
const searchCommunityPlugins = async (req, res) => {
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
    }
    catch (error) {
        console.error('[COMMUNITY SEARCH CONTROLLER ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: 'Failed to search community plugins'
        });
    }
};
exports.searchCommunityPlugins = searchCommunityPlugins;
module.exports = {
    getMarketplaceCatalog: exports.getMarketplaceCatalog,
    getInstalledPlugins: exports.getInstalledPlugins,
    installPlugin: exports.installPlugin,
    uninstallPlugin: exports.uninstallPlugin,
    deleteDeveloperPlugin: exports.deleteDeveloperPlugin,
    togglePlugin: exports.togglePlugin,
    savePluginConfig: exports.savePluginConfig,
    deployDeveloperPlugin: exports.deployDeveloperPlugin,
    executePluginHook: exports.executePluginHook,
    getPluginLogs: exports.getPluginLogs,
    getThirdPartyOrders: exports.getThirdPartyOrders,
    deleteThirdPartyOrders: exports.deleteThirdPartyOrders,
    searchCommunityPlugins: exports.searchCommunityPlugins
};
exports.default = module.exports;
