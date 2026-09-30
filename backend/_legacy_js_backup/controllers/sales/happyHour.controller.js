const toNumber = (val) => {
    const parsed = parseFloat(val);
    return Number.isFinite(parsed) ? parsed : 0;
};

exports.listHappyHours = async (req, res) => {
    try {
        const outlet_id = req.user?.outlet_id;

        const rules = await req.propertyDb.models.happy_hours.findAll({
            where: { outlet_id },
            include: [
                {
                    model: req.propertyDb.models.item_master,
                    as: 'parent_item',
                    attributes: ['id', 'item_name', 'item_code'],
                    required: false
                },
                {
                    model: req.propertyDb.models.item_master,
                    as: 'free_item',
                    attributes: ['id', 'item_name', 'item_code'],
                    required: false
                }
            ],
            order: [['id', 'ASC']]
        });

        res.json({ success: true, data: rules });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.createHappyHour = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const {
            start_time,
            end_time,
            days_of_week,
            buy_qty,
            free_qty,
            apply_to_all_happy_hour_items,
            parent_item_id,
            free_item_id,
            is_active
        } = req.body;

        if (!start_time || !end_time) {
            return res.status(400).json({ success: false, message: 'start_time and end_time are required' });
        }

        const rule = await req.propertyDb.models.happy_hours.create({
            outlet_id,
            start_time,
            end_time,
            days_of_week: days_of_week || null,
            buy_qty: toNumber(buy_qty || 2),
            free_qty: toNumber(free_qty || 1),
            apply_to_all_happy_hour_items: apply_to_all_happy_hour_items !== false,
            parent_item_id: parent_item_id || null,
            free_item_id: free_item_id || null,
            is_active: is_active !== false
        });

        res.json({ success: true, data: rule });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.updateHappyHour = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { id } = req.params;
        const {
            start_time,
            end_time,
            days_of_week,
            buy_qty,
            free_qty,
            apply_to_all_happy_hour_items,
            parent_item_id,
            free_item_id,
            is_active
        } = req.body;

        const rule = await req.propertyDb.models.happy_hours.findOne({
            where: { id, outlet_id }
        });

        if (!rule) {
            return res.status(404).json({ success: false, message: 'Happy hour configuration not found' });
        }

        await rule.update({
            start_time: start_time !== undefined ? start_time : rule.start_time,
            end_time: end_time !== undefined ? end_time : rule.end_time,
            days_of_week: days_of_week !== undefined ? (days_of_week || null) : rule.days_of_week,
            buy_qty: buy_qty !== undefined ? toNumber(buy_qty) : rule.buy_qty,
            free_qty: free_qty !== undefined ? toNumber(free_qty) : rule.free_qty,
            apply_to_all_happy_hour_items: apply_to_all_happy_hour_items !== undefined ? apply_to_all_happy_hour_items : rule.apply_to_all_happy_hour_items,
            parent_item_id: parent_item_id !== undefined ? (parent_item_id || null) : rule.parent_item_id,
            free_item_id: free_item_id !== undefined ? (free_item_id || null) : rule.free_item_id,
            is_active: is_active !== undefined ? is_active : rule.is_active
        });

        res.json({ success: true, data: rule });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.deleteHappyHour = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { id } = req.params;

        const rule = await req.propertyDb.models.happy_hours.findOne({
            where: { id, outlet_id }
        });

        if (!rule) {
            return res.status(404).json({ success: false, message: 'Happy hour configuration not found' });
        }

        await rule.destroy();
        res.json({ success: true, message: 'Happy hour configuration deleted successfully' });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};
