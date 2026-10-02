const { resolveOutletScope } = require('../../utils/outletScopeHelper');
const { Op } = require('sequelize');

exports.getModifiers = async (req: any, res: any) => {
    try {
        const reqOutlet = req.query.outlet_id || req.query.outletId;
        const scope = await resolveOutletScope(req, reqOutlet);
        const { item_id, search, is_active } = req.query;

        let whereConditions = ['m.outlet_id IN (:outletIds)'];
        let replacements: any = { outletIds: scope.outletIds };

        if (item_id && item_id !== '0' && item_id !== 'ALL') {
            whereConditions.push('m.item_master_id = :item_id');
            replacements.item_id = Number(item_id);
        }

        if (search && search.trim() !== '') {
            whereConditions.push('(m.modifier_name ILIKE :search OR im.item_name ILIKE :search)');
            replacements.search = `%${search.trim()}%`;
        }

        if (is_active !== undefined && is_active !== '') {
            whereConditions.push('m.is_active = :is_active');
            replacements.is_active = is_active === 'true' || is_active === true;
        }

        const whereClause = `WHERE ${whereConditions.join(' AND ')}`;

        const [rows] = await req.propertyDb.query(`
            SELECT
                m.id,
                m.outlet_id,
                m.item_master_id,
                m.modifier_name,
                m.price,
                m.is_active,
                m.created_at,
                COALESCE(im.item_name, 'All Items / Global') AS item_name,
                COALESCE(im.item_code, '-') AS item_code,
                COALESCE(im.item_group, '-') AS category
            FROM item_modifiers m
            LEFT JOIN item_master im
                ON im.id = m.item_master_id
            ${whereClause}
            ORDER BY m.id DESC
        `, { replacements });

        res.json({
            success: true,
            data: rows
        });
    } catch (err: any) {
        console.error('Error fetching item modifiers:', err);
        res.status(500).json({ success: false, message: 'Failed to load item modifiers' });
    }
};

exports.createModifier = async (req: any, res: any) => {
    try {
        const outlet_id = req.user?.outlet_id || req.body.outlet_id;
        const { item_master_id, modifier_name, price, is_active = true } = req.body;

        if (!modifier_name || modifier_name.trim() === '') {
            return res.status(400).json({ success: false, message: 'Modifier name is required' });
        }

        const modifier = await req.propertyDb.models.item_modifiers.create({
            outlet_id,
            item_master_id: item_master_id ? Number(item_master_id) : 0,
            modifier_name: modifier_name.trim(),
            price: Number(price || 0),
            is_active: is_active === true || is_active === 'true'
        });

        res.json({
            success: true,
            message: 'Item modifier created successfully',
            data: modifier
        });
    } catch (err: any) {
        console.error('Error creating modifier:', err);
        res.status(500).json({ success: false, message: 'Failed to create modifier' });
    }
};

exports.updateModifier = async (req: any, res: any) => {
    try {
        const { id } = req.params;
        const { item_master_id, modifier_name, price, is_active } = req.body;

        const modifier = await req.propertyDb.models.item_modifiers.findByPk(id);
        if (!modifier) {
            return res.status(404).json({ success: false, message: 'Modifier not found' });
        }

        const updateData: any = {};
        if (item_master_id !== undefined) updateData.item_master_id = Number(item_master_id);
        if (modifier_name !== undefined) updateData.modifier_name = modifier_name.trim();
        if (price !== undefined) updateData.price = Number(price);
        if (is_active !== undefined) updateData.is_active = is_active;

        await modifier.update(updateData);

        res.json({
            success: true,
            message: 'Modifier updated successfully',
            data: modifier
        });
    } catch (err: any) {
        console.error('Error updating modifier:', err);
        res.status(500).json({ success: false, message: 'Failed to update modifier' });
    }
};

exports.deleteModifier = async (req: any, res: any) => {
    try {
        const { id } = req.params;
        const modifier = await req.propertyDb.models.item_modifiers.findByPk(id);
        if (!modifier) {
            return res.status(404).json({ success: false, message: 'Modifier not found' });
        }

        await modifier.destroy();

        res.json({
            success: true,
            message: 'Modifier deleted successfully'
        });
    } catch (err: any) {
        console.error('Error deleting modifier:', err);
        res.status(500).json({ success: false, message: 'Failed to delete modifier' });
    }
};

module.exports = exports;
export default exports;
