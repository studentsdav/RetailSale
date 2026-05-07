const { Op, Sequelize } = require('sequelize');

exports.getReturnReport = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;

        const {
            from_date,
            to_date,
            search,
            issue_no
        } = req.query;

        const where = { outlet_id };

        // 📅 Date filter
        if (from_date && to_date) {
            where.return_date = {
                [Op.between]: [from_date, to_date]
            };
        }

        // 🔎 Search by return no
        if (search) {
            where.return_no = {
                [Op.iLike]: `%${search}%`
            };
        }

        const headers = await req.propertyDb.models.return_headers.findAll({
            where,
            include: [
                {
                    model: req.propertyDb.models.return_items,
                    as: 'return_items',
                    include: [
                        {
                            model: req.propertyDb.models.item_master,
                            as: 'item_master',
                            attributes: ['item_name']
                        }
                    ]
                },
                {
                    model: req.propertyDb.models.issue_headers,
                    as: 'issue',
                    attributes: ['issue_no']
                }
            ],
            order: [['return_date', 'DESC']]
        });

        // 🔁 Format grouped response
        const formatted = headers.map(h => {

            let totalQty = 0;
            let totalAmount = 0;

            const items = h.return_items.map(i => {
                const amount = i.qty * i.rate;
                totalQty += Number(i.qty);
                totalAmount += amount;

                return {
                    item_name: i.item_master?.item_name || '',
                    qty: i.qty,
                    rate: i.rate,
                    amount
                };
            });

            return {
                id: h.id,
                return_no: h.return_no,
                return_date: h.return_date,
                issue_no: h.issue?.issue_no || null,
                total_qty: totalQty,
                total_amount: totalAmount,
                items
            };
        });

        res.json({
            success: true,
            count: formatted.length,
            data: formatted
        });

    } catch (err) {
        res.status(500).json({
            success: false,
            message: err.message
        });
    }
};