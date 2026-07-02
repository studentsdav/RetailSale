const { Op } = require('sequelize');

exports.getAttributes = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const attributes = await req.propertyDb.models.attributes.findAll({
            where: { outlet_id, is_active: true },
            include: [
                {
                    model: req.propertyDb.models.attribute_values,
                    as: 'values',
                    where: { is_active: true },
                    required: false
                }
            ],
            order: [
                ['name', 'ASC'],
                [{ model: req.propertyDb.models.attribute_values, as: 'values' }, 'value', 'ASC']
            ]
        });
        res.json({ success: true, data: attributes });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.createAttribute = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const name = String(req.body.name || '').trim();

        if (!name) {
            return res.status(400).json({ success: false, message: 'Attribute name is required' });
        }

        const existing = await req.propertyDb.models.attributes.findOne({
            where: { outlet_id, name, is_active: true }
        });
        if (existing) {
            return res.status(400).json({ success: false, message: 'Attribute already exists' });
        }

        const attribute = await req.propertyDb.models.attributes.create({
            outlet_id,
            name,
            is_active: true
        });

        res.json({ success: true, data: attribute });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.createAttributeValue = async (req, res) => {
    try {
        const attribute_id = req.params.id;
        const value = String(req.body.value || '').trim();

        if (!value) {
            return res.status(400).json({ success: false, message: 'Value is required' });
        }

        const attribute = await req.propertyDb.models.attributes.findOne({
            where: { id: attribute_id, is_active: true }
        });
        if (!attribute) {
            return res.status(404).json({ success: false, message: 'Attribute not found' });
        }

        const existing = await req.propertyDb.models.attribute_values.findOne({
            where: { attribute_id, value, is_active: true }
        });
        if (existing) {
            return res.status(400).json({ success: false, message: 'Value already exists' });
        }

        const attrValue = await req.propertyDb.models.attribute_values.create({
            attribute_id,
            value,
            is_active: true
        });

        res.json({ success: true, data: attrValue });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};
