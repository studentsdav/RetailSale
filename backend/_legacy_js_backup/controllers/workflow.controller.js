const workflowService = require('../services/workflow.service');

function resolveOutletId(req) {
    return Number(req?.user?.outlet_id) || 0;
}

exports.getWorkflowRules = async (req, res) => {
    try {
        const outletId = resolveOutletId(req);
        const data = await workflowService.getWorkflowRules(req.propertyDb, outletId);
        return res.json({
            success: true,
            data
        });
    } catch (error) {
        console.error('[WORKFLOW CONTROLLER ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: 'Failed to fetch workflow rules'
        });
    }
};

exports.toggleWorkflowRule = async (req, res) => {
    try {
        const outletId = resolveOutletId(req);
        const { id } = req.params;
        const { isActive } = req.body;

        const data = await workflowService.toggleWorkflowRule(req.propertyDb, outletId, id, isActive);
        return res.json({
            success: true,
            data
        });
    } catch (error) {
        console.error('[WORKFLOW TOGGLE CONTROLLER ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: 'Failed to toggle workflow rule'
        });
    }
};

exports.triggerWorkflow = async (req, res) => {
    try {
        const outletId = resolveOutletId(req);
        const { triggerType, payload } = req.body;

        const data = await workflowService.executeWorkflowTrigger(req.propertyDb, outletId, triggerType, payload);
        return res.json({
            success: true,
            data
        });
    } catch (error) {
        console.error('[WORKFLOW TRIGGER CONTROLLER ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: 'Failed to execute workflow trigger'
        });
    }
};
