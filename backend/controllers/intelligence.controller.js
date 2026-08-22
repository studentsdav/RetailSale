const recommendationService = require('../services/recommendation.service');

function resolveOutletId(req) {
    return Number(req?.user?.outlet_id) || 0;
}

exports.getCartRecommendations = async (req, res) => {
    try {
        const outletId = resolveOutletId(req);
        const { itemIds, itemCodes } = req.query;

        let parsedIds = [];
        let parsedCodes = [];

        if (typeof itemIds === 'string') {
            parsedIds = itemIds.split(',').map(s => s.trim()).filter(Boolean);
        } else if (Array.isArray(itemIds)) {
            parsedIds = itemIds;
        }

        if (typeof itemCodes === 'string') {
            parsedCodes = itemCodes.split(',').map(s => s.trim()).filter(Boolean);
        } else if (Array.isArray(itemCodes)) {
            parsedCodes = itemCodes;
        }

        const data = await recommendationService.getCartRecommendations(req.propertyDb, outletId, parsedIds, parsedCodes);
        return res.json({
            success: true,
            data
        });
    } catch (error) {
        console.error('[INTELLIGENCE CONTROLLER ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: 'Failed to fetch recommendations'
        });
    }
};

exports.getCustomerInsights = async (req, res) => {
    try {
        const outletId = resolveOutletId(req);
        const { id } = req.params;
        const { phone } = req.query;

        const data = await recommendationService.getCustomerInsights(req.propertyDb, outletId, id, phone);
        return res.json({
            success: true,
            data
        });
    } catch (error) {
        console.error('[CUSTOMER INSIGHTS CONTROLLER ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: 'Failed to fetch customer insights'
        });
    }
};
