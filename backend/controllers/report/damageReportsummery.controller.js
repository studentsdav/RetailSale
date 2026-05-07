const { Op } = require('sequelize');

exports.getDamageReport = async (req, res) => {
    try {
        const { from_date, to_date, item_id } = req.query;
        const outlet_id = req.user.outlet_id;

        if (!from_date || !to_date) {
            return res.status(400).json({
                success: false,
                message: 'from_date and to_date required'
            });
        }

        const whereHeader = {
            outlet_id,
            damage_date: {
                [Op.between]: [from_date, to_date]
            }
        };

        const whereItem = {};
        if (item_id) {
            whereItem.item_id = item_id;
        }

        const damages = await req.propertyDb.models.damage_headers.findAll({
            where: whereHeader,
            include: [
                {
                    model: req.propertyDb.models.damage_items,
                    as: 'items',
                    include: [
                        {
                            model: req.propertyDb.models.item_master,
                            as: 'item',
                            attributes: ['item_name', 'unit']
                        }
                    ]
                }
            ],
            order: [['damage_date', 'DESC']]
        });

        const data = damages.map((damage) => ({
            id: damage.id,
            damage_no: damage.damage_no,
            damage_date: damage.damage_date,
            total_value: Number(damage.total_value || 0),
            status: damage.status,
            approval_status: damage.approval_status || 'PENDING',
            approved_by: damage.approved_by,
            approved_at: damage.approved_at,
            rejected_by: damage.rejected_by,
            rejected_at: damage.rejected_at,
            rejection_reason: damage.rejection_reason,
            items: damage.items
        }));

        res.json({
            success: true,
            data
        });

    } catch (err) {
        console.error(err);
        res.status(500).json({
            success: false,
            message: 'Failed to generate damage report'
        });
    }
};
