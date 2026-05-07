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

        const resolved = await numberingHelper.getEffectiveSetting({
            db: req.propertyDb,
            outlet_id,
            module: 'RECEIVING',
            date
        });

        if (!resolved) {
            return res.status(400).json({
                success: false,
                message: 'GRN numbering not configured'
            });
        }

        const { effective, nextSetting } = resolved;
        const rows = await req.propertyDb.models.goods_receipts.findAll({
            where: {
                outlet_id,
                receipt_date: nextSetting?.start_date
                    ? {
                        [require('sequelize').Op.gte]: effective.start_date,
                        [require('sequelize').Op.lt]: nextSetting.start_date
                    }
                    : { [require('sequelize').Op.gte]: effective.start_date }
            },
            attributes: ['grn_no']
        });

        let nextNo = Number(effective.start_no) || 1;
        for (const row of rows) {
            const numeric = numberingHelper.extractNumericPart(row.grn_no, effective);
            if (numeric !== null) {
                nextNo = Math.max(nextNo, numeric + 1);
            }
        }

        res.json({
            success: true,
            data: {
                number: `${effective.prefix || ''}${nextNo}${effective.postfix || ''}`,
                next_no: nextNo
            }
        });
    } catch (err) {
        res.status(500).json({
            success: false,
            error: err.message
        });
    }
};
