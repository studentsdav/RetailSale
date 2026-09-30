const nightAuditService = require('../../services/nightAudit.service');

exports.getStatus = async (req, res) => {
    try {
        const outletId = req.outletId || req.user?.outlet_id || 1;
        const currentDay = await nightAuditService.getCurrentBusinessDay(req.propertyDb, outletId, req.user?.id);
        const validation = await nightAuditService.validatePreAuditConditions(req.propertyDb, outletId, currentDay.business_date);

        res.json({
            success: true,
            data: {
                currentBusinessDay: currentDay,
                validation
            }
        });
    } catch (err) {
        console.error('Night audit getStatus error:', err);
        res.status(500).json({ success: false, message: err.message });
    }
};

exports.validate = async (req, res) => {
    try {
        const outletId = req.outletId || req.user?.outlet_id || 1;
        const currentDay = await nightAuditService.getCurrentBusinessDay(req.propertyDb, outletId, req.user?.id);
        const validation = await nightAuditService.validatePreAuditConditions(req.propertyDb, outletId, currentDay.business_date);

        res.json({
            success: true,
            data: validation
        });
    } catch (err) {
        console.error('Night audit validate error:', err);
        res.status(500).json({ success: false, message: err.message });
    }
};

exports.execute = async (req, res) => {
    try {
        const outletId = req.outletId || req.user?.outlet_id || 1;
        const userId = req.user?.id || 1;
        const { physicalCash, denominations, forceRun, notes } = req.body;

        const result = await nightAuditService.executeNightAudit(req.propertyDb, outletId, userId, {
            physicalCash,
            denominations,
            forceRun,
            notes,
            runType: 'MANUAL'
        });

        if (!result.success) {
            return res.status(400).json(result);
        }

        res.json(result);
    } catch (err) {
        console.error('Night audit execute error:', err);
        res.status(500).json({ success: false, message: err.message });
    }
};

exports.getHistory = async (req, res) => {
    try {
        const outletId = req.outletId || req.user?.outlet_id || 1;
        const { limit = 20, offset = 0 } = req.query;

        const history = await nightAuditService.getAuditHistory(req.propertyDb, outletId, limit, offset);

        res.json({
            success: true,
            data: history.rows,
            total: history.count
        });
    } catch (err) {
        console.error('Night audit getHistory error:', err);
        res.status(500).json({ success: false, message: err.message });
    }
};

exports.clearKots = async (req, res) => {
    try {
        const outletId = req.outletId || req.user?.outlet_id || 1;
        await nightAuditService.clearOpenKots(req.propertyDb, outletId);
        res.json({ success: true, message: 'All open KOTs have been cleared.' });
    } catch (err) {
        console.error('Night audit clearKots error:', err);
        res.status(500).json({ success: false, message: err.message });
    }
};
