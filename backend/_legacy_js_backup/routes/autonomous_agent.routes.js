const express = require('express');
const router = express.Router();
const agentController = require('../controllers/autonomous_agent.controller');

// GET /api/v1/agent/proposals
router.get('/proposals', agentController.getProposals);

// POST /api/v1/agent/proposals/:id/approve
router.post('/proposals/:id/approve', agentController.approveProposal);

// POST /api/v1/agent/proposals/:id/reject
router.post('/proposals/:id/reject', agentController.rejectProposal);

// GET /api/v1/agent/audit-logs
router.get('/audit-logs', agentController.getAuditLogs);

module.exports = router;
