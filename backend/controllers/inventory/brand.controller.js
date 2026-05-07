exports.create = async (req, res) => {
    const outlet_id = req.user.outlet_id;
    const brand_name = String(req.body.brand_name || '').trim();

    if (!brand_name) {
        return res.status(400).json({ success: false, message: 'Brand name is required' });
    }

    const existing = await req.propertyDb.models.brands.findOne({
        where: { outlet_id, brand_name }
    });
    if (existing) {
        return res.status(400).json({ success: false, message: 'Brand already exists' });
    }
    const brand = await req.propertyDb.models.brands.create({
        outlet_id,
        brand_name,
        is_active: true
    });

    res.json({ success: true, data: brand });
};

exports.getAll = async (req, res) => {
    const outlet_id = req.user.outlet_id;

    const data = await req.propertyDb.models.brands.findAll({
        where: { outlet_id, is_active: true },
        order: [['brand_name', 'ASC']]
    });

    res.json({ success: true, data });
};

exports.update = async (req, res) => {
    const outlet_id = req.user.outlet_id;
    const brand_name = String(req.body.brand_name || '').trim();
    const existing = await req.propertyDb.models.brands.findOne({
        where: {
            outlet_id,
            brand_name,
            id: { [require('sequelize').Op.ne]: req.params.id }
        }
    });
    if (existing) {
        return res.status(400).json({ success: false, message: 'Brand already exists' });
    }
    await req.propertyDb.models.brands.update(
        { brand_name },
        { where: { id: req.params.id, outlet_id } }
    );


    res.json({ success: true });
};

exports.delete = async (req, res) => {
    await req.propertyDb.models.brands.update(
        { is_active: false },
        { where: { id: req.params.id } }
    );

    res.json({ success: true });
};
