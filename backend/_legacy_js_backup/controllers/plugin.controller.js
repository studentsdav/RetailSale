const pluginService = require('../services/plugin_manager.service');

function resolveOutletId(req) {
    return Number(req?.user?.outlet_id) || 0;
}

exports.getMarketplaceCatalog = async (req, res) => {
    try {
        const data = await pluginService.getMarketplaceCatalog();
        return res.json({
            success: true,
            data
        });
    } catch (error) {
        console.error('[PLUGIN MARKETPLACE CONTROLLER ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: 'Failed to fetch plugin marketplace'
        });
    }
};

exports.getInstalledPlugins = async (req, res) => {
    try {
        const outletId = resolveOutletId(req);
        const data = await pluginService.getInstalledPlugins(req.propertyDb, outletId);
        return res.json({
            success: true,
            data
        });
    } catch (error) {
        console.error('[INSTALLED PLUGINS CONTROLLER ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: 'Failed to fetch installed plugins'
        });
    }
};

exports.installPlugin = async (req, res) => {
    try {
        const outletId = resolveOutletId(req);
        const { pluginId } = req.body;
        const data = await pluginService.installPlugin(req.propertyDb, outletId, pluginId);
        return res.json({
            success: true,
            data
        });
    } catch (error) {
        console.error('[INSTALL PLUGIN ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: error.message || 'Failed to install plugin'
        });
    }
};

exports.togglePlugin = async (req, res) => {
    try {
        const outletId = resolveOutletId(req);
        const { id } = req.params;
        const { isActive } = req.body;
        const data = await pluginService.togglePlugin(req.propertyDb, outletId, id, isActive);
        return res.json({
            success: true,
            data
        });
    } catch (error) {
        console.error('[TOGGLE PLUGIN ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: error.message || 'Failed to toggle plugin'
        });
    }
};
