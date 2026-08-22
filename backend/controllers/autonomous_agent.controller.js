const agentService = require('../services/autonomous_agent.service');

function resolveOutletId(req) {
    return Number(req?.user?.outlet_id) || 0;
}

exports.getProposals = async (req, res) => {
    try {
        const outletId = resolveOutletId(req);
        const data = await agentService.getProposals(req.propertyDb, outletId);
        return res.json({
            success: true,
            data
        });
    } catch (error) {
        console.error('[AUTONOMOUS AGENT CONTROLLER ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: 'Failed to fetch agent proposals'
        });
    }
};

exports.approveProposal = async (req, res) => {
    try {
        const outletId = resolveOutletId(req);
        const { id } = req.params;
        const data = await agentService.approveProposal(req.propertyDb, outletId, id);
        return res.json({
            success: true,
            data
        });
    } catch (error) {
        console.error('[AUTONOMOUS AGENT APPROVE ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: error.message || 'Failed to approve proposal'
        });
    }
};

exports.rejectProposal = async (req, res) => {
    try {
        const outletId = resolveOutletId(req);
        const { id } = req.params;
        const data = await agentService.rejectProposal(req.propertyDb, outletId, id);
        return res.json({
            success: true,
            data
        });
    } catch (error) {
        console.error('[AUTONOMOUS AGENT REJECT ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: error.message || 'Failed to reject proposal'
        });
    }
};

exports.getAuditLogs = async (req, res) => {
    try {
        const outletId = resolveOutletId(req);
        const data = await agentService.getAuditLogs(req.propertyDb, outletId);
        return res.json({
            success: true,
            data
        });
    } catch (error) {
        console.error('[AUTONOMOUS AGENT AUDIT LOG ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: 'Failed to fetch audit logs'
        });
    }
};
