async function resolveOutletId(req, inputOutletId) {
    let outletId = Number(inputOutletId || req.outlet?.id || req.user?.outlet_id || req.headers?.['x-outlet-id'] || 0);
    if (!outletId || outletId <= 0) {
        try {
            const outlet = await req.propertyDb.models.outlets.findOne({
                attributes: ['id'],
                order: [['id', 'ASC']]
            });
            if (outlet) outletId = outlet.id;
        } catch (_) {}
    }
    return outletId || 1;
}

async function getTaxGroups(req, res) {
    try {
        const outlet_id = await resolveOutletId(req, req.query.outlet_id);
        const groups = await req.propertyDb.models.tax_groups.findAll({
            where: { outlet_id, is_active: true },
            include: [
                {
                    model: req.propertyDb.models.tax_group_components,
                    as: 'components'
                }
            ],
            order: [['created_at', 'ASC']]
        });
        return res.json({ success: true, data: groups });
    } catch (err) {
        console.error('Error fetching tax groups:', err);
        return res.status(500).json({ success: false, message: err.message });
    }
}

async function createTaxGroup(req, res) {
    const t = await req.propertyDb.transaction();
    try {
        const outlet_id = await resolveOutletId(req, req.body.outlet_id);
        const { group_name, group_code, is_tax_inclusive, components = [] } = req.body;

        let totalRate = 0;
        for (const c of components) {
            totalRate += Number(c.rate || 0);
        }

        const group = await req.propertyDb.models.tax_groups.create({
            outlet_id,
            group_name,
            group_code,
            total_rate: totalRate,
            is_tax_inclusive: !!is_tax_inclusive,
            is_active: true
        }, { transaction: t });

        if (Array.isArray(components) && components.length > 0) {
            const compRows = components.map((c, idx) => ({
                tax_group_id: group.id,
                component_code: c.component_code || `TAX_${idx + 1}`,
                component_name: c.component_name || `Tax Component ${idx + 1}`,
                rate: Number(c.rate || 0),
                calculation_order: c.calculation_order || (idx + 1),
                calculation_type: c.calculation_type || 'FLAT_PERCENT',
                gl_account_code: c.gl_account_code || null
            }));
            await req.propertyDb.models.tax_group_components.bulkCreate(compRows, { transaction: t });
        }

        await t.commit();

        const created = await req.propertyDb.models.tax_groups.findByPk(group.id, {
            include: [{ model: req.propertyDb.models.tax_group_components, as: 'components' }]
        });

        return res.json({ success: true, data: created });
    } catch (err) {
        await t.rollback();
        console.error('Error creating tax group:', err);
        return res.status(500).json({ success: false, message: err.message });
    }
}

async function updateTaxGroup(req, res) {
    const t = await req.propertyDb.transaction();
    try {
        const { id } = req.params;
        const { group_name, group_code, is_tax_inclusive, components = [] } = req.body;

        const group = await req.propertyDb.models.tax_groups.findByPk(id);
        if (!group) {
            await t.rollback();
            return res.status(404).json({ success: false, message: 'Tax Group not found' });
        }

        let totalRate = 0;
        for (const c of components) {
            totalRate += Number(c.rate || 0);
        }

        await group.update({
            group_name: group_name || group.group_name,
            group_code: group_code ?? group.group_code,
            total_rate: totalRate,
            is_tax_inclusive: is_tax_inclusive ?? group.is_tax_inclusive
        }, { transaction: t });

        await req.propertyDb.models.tax_group_components.destroy({
            where: { tax_group_id: id },
            transaction: t
        });

        if (Array.isArray(components) && components.length > 0) {
            const compRows = components.map((c, idx) => ({
                tax_group_id: id,
                component_code: c.component_code || `TAX_${idx + 1}`,
                component_name: c.component_name || `Tax Component ${idx + 1}`,
                rate: Number(c.rate || 0),
                calculation_order: c.calculation_order || (idx + 1),
                calculation_type: c.calculation_type || 'FLAT_PERCENT',
                gl_account_code: c.gl_account_code || null
            }));
            await req.propertyDb.models.tax_group_components.bulkCreate(compRows, { transaction: t });
        }

        await t.commit();

        const updated = await req.propertyDb.models.tax_groups.findByPk(id, {
            include: [{ model: req.propertyDb.models.tax_group_components, as: 'components' }]
        });

        return res.json({ success: true, data: updated });
    } catch (err) {
        await t.rollback();
        console.error('Error updating tax group:', err);
        return res.status(500).json({ success: false, message: err.message });
    }
}

async function deleteTaxGroup(req, res) {
    try {
        const { id } = req.params;
        const group = await req.propertyDb.models.tax_groups.findByPk(id);
        if (!group) return res.status(404).json({ success: false, message: 'Tax Group not found' });

        await group.update({ is_active: false });
        return res.json({ success: true, message: 'Tax group deleted successfully' });
    } catch (err) {
        console.error('Error deleting tax group:', err);
        return res.status(500).json({ success: false, message: err.message });
    }
}

module.exports = {
    getTaxGroups,
    createTaxGroup,
    updateTaxGroup,
    deleteTaxGroup
};
