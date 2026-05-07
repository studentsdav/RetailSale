const analyticsService = require('../../services/analytics.service');

function resolveOutletId(req) {
    return Number(req?.user?.outlet_id) || 0;
}

exports.getRfmSegments = async (req, res) => {
    try {
        const outletId = resolveOutletId(req);
        const data = await analyticsService.getRfmSegments(req.propertyDb, outletId);
        return res.json({ success: true, data });
    } catch (error) {
        console.error('[ANALYTICS] rfm-segments failed:', error.message);
        return res.status(500).json({
            success: false,
            message: 'Failed to load RFM segments'
        });
    }
};

exports.getSalesTrend = async (req, res) => {
    try {
        const outletId = resolveOutletId(req);
        const data = await analyticsService.getSalesTrend(req.propertyDb, outletId);
        return res.json({ success: true, data });
    } catch (error) {
        console.error('[ANALYTICS] sales-trend failed:', error.message);
        return res.status(500).json({
            success: false,
            message: 'Failed to load sales trend'
        });
    }
};

exports.getMarketBasket = async (req, res) => {
    try {
        const outletId = resolveOutletId(req);
        const data = await analyticsService.getMarketBasket(req.propertyDb, outletId);
        return res.json({ success: true, data });
    } catch (error) {
        console.error('[ANALYTICS] market-basket failed:', error.message);
        return res.status(500).json({
            success: false,
            message: 'Failed to load market basket analytics'
        });
    }
};

exports.getTopCustomerItems = async (req, res) => {
    try {
        const outletId = resolveOutletId(req);
        const data = await analyticsService.getTopCustomerItems(req.propertyDb, outletId);
        return res.json({ success: true, data });
    } catch (error) {
        console.error('[ANALYTICS] top-customer-items failed:', error.message);
        return res.status(500).json({
            success: false,
            message: 'Failed to load top customer item analytics'
        });
    }
};
