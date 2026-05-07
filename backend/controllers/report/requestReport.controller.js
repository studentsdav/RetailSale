const { Op } = require('sequelize');

exports.getRequestReport = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;

        const {
            from_date,
            to_date,
            status,
            approval_status,
            department,
            search
        } = req.query;

        const where = { outlet_id };

        // 📅 Date filter
        if (from_date && to_date) {
            where.request_date = {
                [Op.between]: [from_date, to_date]
            };
        }

        // 📌 Status filter
        if (status) {
            where.status = status;
        }

        if (approval_status) {
            where.approval_status = approval_status;
        }

        // 🏢 Department filter
        if (department) {
            where.department = department;
        }

        // 🔎 Search by request no
        if (search) {
            where.request_no = {
                [Op.iLike]: `%${search}%`
            };
        }

        const headers = await req.propertyDb.models.request_headers.findAll({
            where,
            include: [
                {
                    model: req.propertyDb.models.request_items,
                    as: 'items',
                    include: [
                        {
                            model: req.propertyDb.models.item_master,
                            as: 'item_master',
                            attributes: ['item_name']
                        }
                    ]
                }
            ],
            order: [['request_date', 'DESC']]
        });

        // 🔁 Format response grouped by header
        const formatted = headers.map(h => {

            let totalQty = 0;
            let totalAmount = 0;

            const items = h.items.map(i => {
                const amount = Number(i.qty) * Number(i.rate);
                totalQty += Number(i.qty);
                totalAmount += amount;

                return {
                    item_name: i.item_master?.item_name || '',
                    qty: Number(i.qty),
                    rate: Number(i.rate),
                    amount
                };
            });

            return {
                id: h.id,
                request_no: h.request_no,
                request_date: h.request_date,
                department: h.department,
                status: h.status,
                approval_status: h.approval_status || 'PENDING',
                approved_at: h.approved_at,
                rejected_at: h.rejected_at,
                rejection_reason: h.rejection_reason,
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
