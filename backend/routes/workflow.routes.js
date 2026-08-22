const express = require('express');
const router = express.Router();
const workflowController = require('../controllers/workflow.controller');

// GET /api/v1/workflows/rules
router.get('/rules', workflowController.getWorkflowRules);

// POST /api/v1/workflows/rules/:id/toggle
router.post('/rules/:id/toggle', workflowController.toggleWorkflowRule);

// POST /api/v1/workflows/trigger
router.post('/trigger', workflowController.triggerWorkflow);

module.exports = router;
