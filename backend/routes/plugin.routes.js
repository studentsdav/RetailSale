"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const router = express_1.default.Router();
const pluginController = require('../controllers/plugin.controller');
// GET /api/v1/plugins/marketplace
router.get('/marketplace', pluginController.getMarketplaceCatalog);
// GET /api/v1/plugins/community/search - Search public community plugins (TradingView style, max 20)
router.get('/community/search', pluginController.searchCommunityPlugins);
// GET /api/v1/plugins/installed
router.get('/installed', pluginController.getInstalledPlugins);
// POST /api/v1/plugins/install
router.post('/install', pluginController.installPlugin);
// POST /api/v1/plugins/uninstall
router.post('/uninstall', pluginController.uninstallPlugin);
router.post('/:id/uninstall', pluginController.uninstallPlugin);
// DELETE /api/v1/plugins/:id - Permanently delete a developer plugin
router.delete('/:id', pluginController.deleteDeveloperPlugin);
// POST /api/v1/plugins/:id/toggle
router.post('/:id/toggle', pluginController.togglePlugin);
// POST /api/v1/plugins/:id/config - Save credentials & settings
router.post('/:id/config', pluginController.savePluginConfig);
// POST /api/v1/plugins/:id/hook/:hook - Test / execute a hook
router.post('/:id/hook/:hook', pluginController.executePluginHook);
// GET /api/v1/plugins/:id/logs - Fetch execution logs
router.get('/:id/logs', pluginController.getPluginLogs);
// GET /api/v1/plugins/reports/third-party-orders - Fetch external orders report
router.get('/reports/third-party-orders', pluginController.getThirdPartyOrders);
// DELETE /api/v1/plugins/reports/third-party-orders - Delete external orders
router.delete('/reports/third-party-orders', pluginController.deleteThirdPartyOrders);
// POST /api/v1/plugins/developer/deploy - Deploy a custom JS/TS plugin
router.post('/developer/deploy', pluginController.deployDeveloperPlugin);
module.exports = router;
exports.default = router;
