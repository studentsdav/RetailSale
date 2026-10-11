import express from 'express';
const router = express.Router();
const developerController = require('../controllers/developer.controller');

// GET /api/v1/developer/ecosystem/info
router.get('/ecosystem/info', developerController.getEcosystemInfo);

// Webhook routes
router.get('/webhooks', developerController.getWebhooks);
router.post('/webhooks', developerController.registerWebhook);
router.delete('/webhooks/:id', developerController.deleteWebhook);
router.post('/webhooks/:id/test', developerController.testWebhook);

// API Keys routes (both /api-keys and /apikeys supported to prevent 404s)
router.get('/api-keys', developerController.getApiKeys);
router.post('/api-keys', developerController.generateApiKey);
router.delete('/api-keys/:id', developerController.deleteApiKey);

router.get('/apikeys', developerController.getApiKeys);
router.post('/apikeys', developerController.generateApiKey);
router.delete('/apikeys/:id', developerController.deleteApiKey);

// OAuth 2.0 RFC 6749 Client Credentials Token Endpoint
router.post('/oauth/token', developerController.issueOAuthToken);

module.exports = router;
export default router;
