"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const router = express_1.default.Router();
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
exports.default = router;
