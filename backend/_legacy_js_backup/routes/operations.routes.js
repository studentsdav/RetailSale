const express = require('express');
const router = express.Router();
const operationsController = require('../controllers/operations.controller');

// GET /api/v1/operations/health-snapshot
router.get('/health-snapshot', operationsController.getHealthSnapshot);

// GET /api/v1/operations/reorder-alerts
router.get('/reorder-alerts', operationsController.getReorderAlerts);

// GET /api/v1/operations/expiry-alerts?days=60
router.get('/expiry-alerts', operationsController.getExpiryAlerts);

module.exports = router;
