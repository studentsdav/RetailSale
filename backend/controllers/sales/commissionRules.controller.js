const toNumber = (val) => {
    const parsed = parseFloat(val);
    return Number.isFinite(parsed) ? parsed : 0;
};

exports.listCommissionRules = async (req, res) => {
    try {
        const outlet_id = req.user?.outlet_id;
        const { platform_id } = req.query;

        const where = { outlet_id };
        if (platform_id) {
            where.platform_id = platform_id;
        }

        const rules = await req.propertyDb.models.commission_rules.findAll({
            where,
            include: [
                {
                    model: req.propertyDb.models.sale_sources,
                    as: 'platform',
                    attributes: ['id', 'name']
                },
                {
                    model: req.propertyDb.models.item_groups,
                    as: 'category',
                    attributes: ['id', 'group_name'],
                    required: false
                },
                {
                    model: req.propertyDb.models.item_master,
                    as: 'product',
                    attributes: ['id', 'item_name', 'item_code'],
                    required: false
                }
            ],
            order: [['priority', 'DESC'], ['id', 'ASC']]
        });

        res.json({ success: true, data: rules });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.createCommissionRule = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const {
            platform_id,
            category_id,
            product_id,
            min_price,
            max_price,
            percentage_fee,
            fixed_fee,
            priority,
            is_active
        } = req.body;

        if (!platform_id) {
            return res.status(400).json({ success: false, message: 'platform_id is required' });
        }

        const rule = await req.propertyDb.models.commission_rules.create({
            outlet_id,
            platform_id,
            category_id: category_id || null,
            product_id: product_id || null,
            min_price: toNumber(min_price || 0),
            max_price: toNumber(max_price || 9999999.99),
            percentage_fee: toNumber(percentage_fee || 0),
            fixed_fee: toNumber(fixed_fee || 0),
            priority: parseInt(priority || 0),
            is_active: is_active !== false
        });

        res.json({ success: true, data: rule });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.updateCommissionRule = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { id } = req.params;
        const {
            category_id,
            product_id,
            min_price,
            max_price,
            percentage_fee,
            fixed_fee,
            priority,
            is_active
        } = req.body;

        const rule = await req.propertyDb.models.commission_rules.findOne({
            where: { id, outlet_id }
        });

        if (!rule) {
            return res.status(404).json({ success: false, message: 'Commission rule not found' });
        }

        await rule.update({
            category_id: category_id !== undefined ? (category_id || null) : rule.category_id,
            product_id: product_id !== undefined ? (product_id || null) : rule.product_id,
            min_price: min_price !== undefined ? toNumber(min_price) : rule.min_price,
            max_price: max_price !== undefined ? toNumber(max_price) : rule.max_price,
            percentage_fee: percentage_fee !== undefined ? toNumber(percentage_fee) : rule.percentage_fee,
            fixed_fee: fixed_fee !== undefined ? toNumber(fixed_fee) : rule.fixed_fee,
            priority: priority !== undefined ? parseInt(priority) : rule.priority,
            is_active: is_active !== undefined ? is_active : rule.is_active
        });

        res.json({ success: true, data: rule });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};

exports.deleteCommissionRule = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { id } = req.params;

        const rule = await req.propertyDb.models.commission_rules.findOne({
            where: { id, outlet_id }
        });

        if (!rule) {
            return res.status(404).json({ success: false, message: 'Commission rule not found' });
        }

        await rule.destroy();
        res.json({ success: true, message: 'Commission rule deleted successfully' });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
};
