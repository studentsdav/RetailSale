const dashboardService = require('../../services/dashboard.service');

exports.inventoryDashboard = async (req, res) => {
    try {
        const outletId = req.user.outlet_id;

        const data = await dashboardService.getInventoryDashboard(outletId, req.propertyDb);

        res.json({
            success: true,
            data
        });

    } catch (err) {
        console.error(err);
        res.status(500).json({
            success: false,
            message: 'Dashboard load failed',
            error: err.message
        });
    }
};
