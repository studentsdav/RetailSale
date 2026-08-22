const operationsService = require('../services/operations.service');

function resolveOutletId(req) {
    return Number(req?.user?.outlet_id) || 0;
}

exports.getHealthSnapshot = async (req, res) => {
    try {
        const outletId = resolveOutletId(req);
        const data = await operationsService.getOperationalHealthSnapshot(req.propertyDb, outletId);
        return res.json({
            success: true,
            data
        });
    } catch (error) {
        console.error('[OPERATIONS HEALTH CONTROLLER ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: 'Failed to fetch operational health snapshot'
        });
    }
};

exports.getReorderAlerts = async (req, res) => {
    try {
        const outletId = resolveOutletId(req);
        const data = await operationsService.getReorderAlerts(req.propertyDb, outletId);
        return res.json({
            success: true,
            data
        });
    } catch (error) {
        console.error('[OPERATIONS REORDER CONTROLLER ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: 'Failed to fetch reorder alerts'
        });
    }
};

exports.getExpiryAlerts = async (req, res) => {
    try {
        const outletId = resolveOutletId(req);
        const { days } = req.query;
        const data = await operationsService.getExpiryAlerts(req.propertyDb, outletId, days || 60);
        return res.json({
            success: true,
            data
        });
    } catch (error) {
        console.error('[OPERATIONS EXPIRY CONTROLLER ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: 'Failed to fetch expiry alerts'
        });
    }
};
