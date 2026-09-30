const express = require('express');
const router = express.Router();
const pluginController = require('../controllers/plugin.controller');

// GET /api/v1/plugins/marketplace
router.get('/marketplace', pluginController.getMarketplaceCatalog);

// GET /api/v1/plugins/installed
router.get('/installed', pluginController.getInstalledPlugins);

// POST /api/v1/plugins/install
router.post('/install', pluginController.installPlugin);

// POST /api/v1/plugins/:id/toggle
router.post('/:id/toggle', pluginController.togglePlugin);

module.exports = router;
