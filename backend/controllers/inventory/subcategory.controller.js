exports.create = async (req, res) => {
    const outlet_id = req.user.outlet_id;
    const group_id = req.body.group_id;
    const subcategory_name = String(req.body.subcategory_name || '').trim();

    const existing = await req.propertyDb.models.item_subcategories.findOne({
        where: { outlet_id, group_id, subcategory_name }
    });
    if (existing) {
        return res.status(400).json({ success: false, message: 'Subcategory already exists' });
    }


    const sub = await req.propertyDb.models.item_subcategories.create({
        outlet_id,
        group_id,
        subcategory_name,
        is_active: true
    });

    res.json({ success: true, data: sub });
};

exports.getAll = async (req, res) => {
    const outlet_id = req.user.outlet_id;

    const data = await req.propertyDb.models.item_subcategories.findAll({
        where: { outlet_id, is_active: true },
        order: [['subcategory_name', 'ASC']]
    });

    res.json({ success: true, data });
};

exports.update = async (req, res) => {
    const outlet_id = req.user.outlet_id;
    const subcategory_name = String(req.body.subcategory_name || '').trim();
    const current = await req.propertyDb.models.item_subcategories.findOne({
        where: { id: req.params.id, outlet_id }
    });
    const existing = await req.propertyDb.models.item_subcategories.findOne({
        where: {
            outlet_id,
            group_id: current?.group_id,
            subcategory_name,
            id: { [require('sequelize').Op.ne]: req.params.id }
        }
    });
    if (existing) {
        return res.status(400).json({ success: false, message: 'Subcategory already exists' });
    }
    await req.propertyDb.models.item_subcategories.update(
        { subcategory_name },
        { where: { id: req.params.id, outlet_id } }
    );

    res.json({ success: true });
};

exports.delete = async (req, res) => {
    await req.propertyDb.models.item_subcategories.update(
        { is_active: false },
        { where: { id: req.params.id } }
    );

    res.json({ success: true });
};
