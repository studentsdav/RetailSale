const { Op } = require('sequelize');
const audit = require('../../services/audit.service');

exports.saveBOM = async (req, res) => {
    const t = await req.propertyDb.transaction();
    try {
        const outlet_id = req.user.outlet_id;
        const { parent_item_id, components } = req.body;

        if (!parent_item_id) {
            throw new Error('Parent item ID is required');
        }

        if (!Array.isArray(components)) {
            throw new Error('Components must be an array');
        }

        // Delete existing BOM components
        await req.propertyDb.models.item_boms.destroy({
            where: { outlet_id, parent_item_id },
            transaction: t
        });

        // Insert new components
        const bomItems = [];
        for (const comp of components) {
            const compId = Number(comp.component_item_id);
            const qty = Number(comp.quantity || 1);

            if (!compId || qty <= 0) {
                continue;
            }

            if (compId === Number(parent_item_id)) {
                throw new Error('An item cannot be a component of itself');
            }

            const itemBom = await req.propertyDb.models.item_boms.create({
                outlet_id,
                parent_item_id,
                component_item_id: compId,
                quantity: qty
            }, { transaction: t });

            bomItems.push(itemBom);
        }

        await audit.log({
            req,
            module: 'BOM',
            action: 'UPDATE',
            table: 'item_boms',
            recordId: parent_item_id,
            old_data: { parent_item_id },
            new_data: bomItems,
            outlet_id,
            user_id: req.user.id
        });

        await t.commit();
        res.json({ success: true, data: bomItems });

    } catch (err) {
        await t.rollback();
        res.status(400).json({ success: false, error: err.message });
    }
};

exports.getBOM = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const parentItemId = Number(req.params.parentItemId);

        if (!parentItemId) {
            return res.status(400).json({ success: false, message: 'Valid parent item ID is required' });
        }

        const components = await req.propertyDb.models.item_boms.findAll({
            where: { outlet_id, parent_item_id: parentItemId },
            include: [
                {
                    model: req.propertyDb.models.item_master,
                    as: 'component_item',
                    attributes: ['id', 'item_code', 'item_name', 'brand', 'rate', 'unit', 'retail_sale_price']
                }
            ]
        });

        let compositeCost = 0;
        const componentDetails = components.map(c => {
            const cItem = c.component_item;
            const rate = cItem ? Number(cItem.rate || 0) : 0;
            const quantity = Number(c.quantity);
            const cost = rate * quantity;
            compositeCost += cost;

            return {
                id: c.id,
                component_item_id: c.component_item_id,
                item_code: cItem?.item_code || '',
                item_name: cItem?.item_name || '',
                brand: cItem?.brand || '',
                unit: cItem?.unit || '',
                rate: rate,
                quantity: quantity,
                cost: cost
            };
        });

        res.json({
            success: true,
            data: {
                parent_item_id: parentItemId,
                components: componentDetails,
                composite_cost: Number(compositeCost.toFixed(2))
            }
        });

    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.updateParentCost = async (req, res) => {
    const t = await req.propertyDb.transaction();
    try {
        const outlet_id = req.user.outlet_id;
        const parentItemId = Number(req.params.parentItemId);

        const parentItem = await req.propertyDb.models.item_master.findOne({
            where: { id: parentItemId, outlet_id },
            transaction: t
        });

        if (!parentItem) {
            throw new Error('Parent item not found');
        }

        const components = await req.propertyDb.models.item_boms.findAll({
            where: { outlet_id, parent_item_id: parentItemId },
            include: [
                {
                    model: req.propertyDb.models.item_master,
                    as: 'component_item',
                    attributes: ['rate']
                }
            ],
            transaction: t
        });

        let compositeCost = 0;
        for (const c of components) {
            const rate = c.component_item ? Number(c.component_item.rate || 0) : 0;
            compositeCost += rate * Number(c.quantity);
        }

        const oldRate = parentItem.rate;
        await parentItem.update({
            rate: Number(compositeCost.toFixed(2))
        }, { transaction: t });

        await audit.log({
            req,
            module: 'BOM',
            action: 'UPDATE_PARENT_COST',
            table: 'item_master',
            recordId: parentItemId,
            old_data: { rate: oldRate },
            new_data: { rate: parentItem.rate },
            outlet_id,
            user_id: req.user.id
        });

        await t.commit();
        res.json({
            success: true,
            data: {
                parent_item_id: parentItemId,
                rate: parentItem.rate
            }
        });

    } catch (err) {
        await t.rollback();
        res.status(400).json({ success: false, error: err.message });
    }
};
