const numberingHelper = require('./numberingSettingsV2.controller');

exports.getNextGrnNo = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { date } = req.query;

        if (!date) {
            return res.status(400).json({
                success: false,
                message: 'Date is required'
            });
        }

        const data = await numberingHelper.resolveNextNumber({
            req,
            module: 'RECEIVING',
            date,
            outlet_id
        });

        if (!data) {
            return res.status(400).json({
                success: false,
                message: 'GRN numbering not configured for this date'
            });
        }

        res.json({
            success: true,
            data
        });
    } catch (err) {
        res.status(500).json({
            success: false,
            error: err.message
        });
    }
};
