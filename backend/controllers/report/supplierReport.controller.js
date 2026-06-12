const { Op } = require('sequelize');

exports.getSupplierPaymentsReport = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { fromDate, toDate, supplierId, paymentMode, search } = req.query;

        const where = { outlet_id };

        if (supplierId && supplierId !== 'ALL' && supplierId !== 'null' && supplierId !== '') {
            where.supplier_id = Number(supplierId);
        }

        if (paymentMode && paymentMode !== 'ALL' && paymentMode !== '') {
            where.payment_mode = paymentMode;
        }

        if (fromDate && toDate) {
            where.payment_date = {
                [Op.between]: [fromDate, toDate]
            };
        }

        if (search && search.trim() !== '') {
            const searchVal = `%${search.trim()}%`;
            where[Op.or] = [
                { reference_no: { [Op.iLike]: searchVal } },
                { '$bill.bill_no$': { [Op.iLike]: searchVal } }
            ];
        }

        const payments = await req.propertyDb.models.supplier_payments.findAll({
            where,
            include: [
                {
                    model: req.propertyDb.models.supplier_master,
                    as: 'supplier',
                    attributes: ['supplier_name']
                },
                {
                    model: req.propertyDb.models.supplier_bills,
                    as: 'bill',
                    attributes: ['bill_no']
                }
            ],
            order: [
                ['payment_date', 'DESC'],
                ['id', 'DESC']
            ]
        });

        const totalPaid = payments.reduce((sum, p) => sum + Number(p.amount), 0);
        const totalCreditAdjusted = payments.reduce((sum, p) => sum + Number(p.credit_adjusted || 0), 0);

        res.json({
            success: true,
            summary: {
                totalPaid,
                totalCreditAdjusted,
                count: payments.length
            },
            data: payments
        });
    } catch (err) {
        console.error(err);
        res.status(500).json({
            success: false,
            error: err.message
        });
    }
};
