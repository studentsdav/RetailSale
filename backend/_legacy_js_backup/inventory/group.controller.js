exports.create = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const group_name = String(req.body.group_name || '').trim();

        if (!group_name) {
            return res.status(400).json({ success: false, message: 'Group name is required' });
        }

        const existing = await req.propertyDb.models.item_groups.findOne({
            where: { outlet_id, group_name }
        });
        if (existing) {
            return res.status(400).json({ success: false, message: 'Group already exists' });
        }

        const group = await req.propertyDb.models.item_groups.create({
            outlet_id,
            group_name,
            is_active: true
        });

        res.json({ success: true, data: group });

    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.getAll = async (req, res) => {
    const outlet_id = req.user.outlet_id;

    const data = await req.propertyDb.models.item_groups.findAll({
        where: { outlet_id, is_active: true },
        order: [['group_name', 'ASC']]
    });

    res.json({ success: true, data });
};

exports.update = async (req, res) => {
    const outlet_id = req.user.outlet_id;
    const group_name = String(req.body.group_name || '').trim();
    const existing = await req.propertyDb.models.item_groups.findOne({
        where: {
            outlet_id,
            group_name,
            id: { [require('sequelize').Op.ne]: req.params.id }
        }
    });
    if (existing) {
        return res.status(400).json({ success: false, message: 'Group already exists' });
    }
    await req.propertyDb.models.item_groups.update(
        { group_name },
        { where: { id: req.params.id, outlet_id } }
    );
    res.json({ success: true });
};

exports.delete = async (req, res) => {
    await req.propertyDb.models.item_groups.update(
        { is_active: false },
        { where: { id: req.params.id } }
    );

    res.json({ success: true });
};
