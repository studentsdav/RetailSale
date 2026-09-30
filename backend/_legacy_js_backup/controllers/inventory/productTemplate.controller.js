const audit = require('../../services/audit.service');
const { Op } = require('sequelize');

exports.getProductTemplates = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const templates = await req.propertyDb.models.product_templates.findAll({
            where: { outlet_id, is_active: true },
            include: [
                {
                    model: req.propertyDb.models.item_master,
                    as: 'variants',
                    where: { is_active: true },
                    required: false,
                    include: [
                        {
                            model: req.propertyDb.models.attribute_values,
                            as: 'attribute_values',
                            include: [
                                {
                                    model: req.propertyDb.models.attributes,
                                    as: 'attribute'
                                }
                            ]
                        }
                    ]
                }
            ],
            order: [['name', 'ASC']]
        });
        res.json({ success: true, data: templates });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.createProductTemplate = async (req, res) => {
    const t = await req.propertyDb.transaction();
    try {
        const outlet_id = req.user.outlet_id;
        const {
            name,
            item_group,
            sub_category,
            brand,
            hsn_sac_code,
            tax_type,
            tax_percent,
            discount_applicable,
            scheme_applicable,
            unit,
            variants // Array of: { item_code, item_name, barcode, rate, retail_sale_price, opening_balance, min_level, max_level, stockable, is_saleable, choiceIds }
        } = req.body;

        if (!name || !item_group || !sub_category || !unit) {
            await t.rollback();
            return res.status(400).json({ success: false, message: 'Name, Group, Sub-category, and Unit are required' });
        }

        // 1. Check if template name already exists
        const existingTemplate = await req.propertyDb.models.product_templates.findOne({
            where: { outlet_id, name, is_active: true },
            transaction: t
        });
        if (existingTemplate) {
            await t.rollback();
            return res.status(400).json({ success: false, message: 'Product template name already exists' });
        }

        // 2. Create Product Template
        const template = await req.propertyDb.models.product_templates.create({
            outlet_id,
            name,
            item_group,
            sub_category,
            brand: brand || null,
            hsn_sac_code: hsn_sac_code || null,
            tax_type: tax_type || 'GST',
            tax_percent: tax_percent || 0,
            discount_applicable: discount_applicable ?? true,
            scheme_applicable: scheme_applicable ?? true,
            is_active: true
        }, { transaction: t });

        const createdVariants = [];

        // 3. Create individual variant SKUs in item_master
        if (variants && Array.isArray(variants)) {
            for (const v of variants) {
                // Ensure unique SKU
                const existingSku = await req.propertyDb.models.item_master.findOne({
                    where: { outlet_id, item_code: v.item_code },
                    transaction: t
                });
                if (existingSku) {
                    await t.rollback();
                    return res.status(400).json({ success: false, message: `SKU Code ${v.item_code} already exists` });
                }

                const item = await req.propertyDb.models.item_master.create({
                    outlet_id,
                    product_template_id: template.id,
                    item_code: v.item_code,
                    item_name: v.item_name,
                    hsn_sac_code: hsn_sac_code || null,
                    item_group,
                    sub_category,
                    brand: brand || null,
                    unit,
                    barcode: v.barcode || null,
                    image_path: null,
                    rate: v.rate || 0,
                    retail_sale_price: v.retail_sale_price || 0,
                    tax_type: tax_type || 'GST',
                    tax_percent: tax_percent || 0,
                    discount_applicable: discount_applicable ?? true,
                    scheme_applicable: scheme_applicable ?? true,
                    opening_balance: v.opening_balance || 0,
                    pack_qty: 0,
                    loose_item_code: null,
                    min_level: v.min_level || 0,
                    max_level: v.max_level || 0,
                    stockable: v.stockable ?? true,
                    is_saleable: v.is_saleable ?? true,
                    is_active: true
                }, { transaction: t });

                // Map variant to selected choice attribute values
                if (v.choiceIds && Array.isArray(v.choiceIds)) {
                    for (const choiceId of v.choiceIds) {
                        await req.propertyDb.models.variant_attribute_values.create({
                            item_id: item.id,
                            attribute_value_id: choiceId
                        }, { transaction: t });
                    }
                }

                createdVariants.push(item);
            }
        }

        // Audit log template creation
        await audit.log({
            req,
            module: 'ITEM_MASTER',
            action: 'CREATE_TEMPLATE',
            table: 'product_templates',
            recordId: template.id,
            old_data: null,
            new_data: { template: template.toJSON(), variants_count: createdVariants.length },
            outlet_id,
            user_id: req.user.id
        });

        await t.commit();
        res.json({ success: true, data: { template, variants: createdVariants } });

    } catch (err) {
        await t.rollback();
        res.status(500).json({ success: false, error: err.message });
    }
};
