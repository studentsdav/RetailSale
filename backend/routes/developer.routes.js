const express = require('express');
const router = express.Router();
const developerController = require('../controllers/developer.controller');

// GET /api/v1/developer/ecosystem/info
router.get('/ecosystem/info', developerController.getEcosystemInfo);

// GET /api/v1/developer/webhooks
router.get('/webhooks', developerController.getWebhooks);

// POST /api/v1/developer/webhooks
router.post('/webhooks', developerController.registerWebhook);

// GET /api/v1/developer/api-keys
router.get('/api-keys', developerController.getApiKeys);

// POST /api/v1/developer/api-keys
router.post('/api-keys', developerController.generateApiKey);

module.exports = router;
