const { resolveOutletScope } = require('../../utils/outletScopeHelper');
const { Op } = require('sequelize');

async function ensureModifierColumns(db) {
    try {
        await db.query(`
            ALTER TABLE item_modifiers 
            ADD COLUMN IF NOT EXISTS tax_percent DECIMAL(5, 2) DEFAULT NULL,
            ADD COLUMN IF NOT EXISTS inventory_item_id INTEGER DEFAULT 0,
            ADD COLUMN IF NOT EXISTS deduct_qty DECIMAL(12, 4) DEFAULT 0.0000;
        `);
    } catch (_) {}
}

exports.getModifiers = async (req, res) => {
    try {
        await ensureModifierColumns(req.propertyDb);

        const reqOutlet = req.query.outlet_id || req.query.outletId;
        const scope = await resolveOutletScope(req, reqOutlet);
        const { item_id, search, is_active } = req.query;

        let whereConditions = ['m.outlet_id IN (:outletIds)'];
        let replacements = { outletIds: scope.outletIds };

        if (item_id && item_id !== '0' && item_id !== 'ALL') {
            whereConditions.push('m.item_master_id = :item_id');
            replacements.item_id = Number(item_id);
        }

        if (search && search.trim() !== '') {
            whereConditions.push('(m.modifier_name ILIKE :search OR im.item_name ILIKE :search OR inv.item_name ILIKE :search)');
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
                m.tax_percent,
                m.inventory_item_id,
                m.deduct_qty,
                m.is_active,
                m.created_at,
                COALESCE(im.item_name, 'All Items / Global') AS item_name,
                COALESCE(im.item_code, '-') AS item_code,
                COALESCE(im.item_group, '-') AS category,
                inv.item_name AS inventory_item_name,
                inv.item_code AS inventory_item_code,
                inv.unit AS inventory_item_unit
            FROM item_modifiers m
            LEFT JOIN item_master im
                ON im.id = m.item_master_id
            LEFT JOIN item_master inv
                ON inv.id = m.inventory_item_id
            ${whereClause}
            ORDER BY m.id DESC
        `, { replacements });

        res.json({
            success: true,
            data: rows
        });
    } catch (err) {
        console.error('Error fetching item modifiers:', err);
        res.status(500).json({ success: false, message: 'Failed to load item modifiers' });
    }
};

exports.createModifier = async (req, res) => {
    try {
        await ensureModifierColumns(req.propertyDb);

        const outlet_id = req.user?.outlet_id || req.body.outlet_id;
        const { item_master_id, modifier_name, price, tax_percent, inventory_item_id, deduct_qty, is_active = true } = req.body;

        if (!modifier_name || modifier_name.trim() === '') {
            return res.status(400).json({ success: false, message: 'Modifier name is required' });
        }

        const modifier = await req.propertyDb.models.item_modifiers.create({
            outlet_id,
            item_master_id: item_master_id ? Number(item_master_id) : 0,
            modifier_name: modifier_name.trim(),
            price: Number(price || 0),
            tax_percent: tax_percent !== undefined && tax_percent !== null && tax_percent !== '' ? Number(tax_percent) : null,
            inventory_item_id: inventory_item_id ? Number(inventory_item_id) : 0,
            deduct_qty: Number(deduct_qty || 0),
            is_active: is_active === true || is_active === 'true'
        });

        res.json({
            success: true,
            message: 'Item modifier created successfully',
            data: modifier
        });
    } catch (err) {
        console.error('Error creating modifier:', err);
        res.status(500).json({ success: false, message: 'Failed to create modifier' });
    }
};

exports.updateModifier = async (req, res) => {
    try {
        await ensureModifierColumns(req.propertyDb);

        const { id } = req.params;
        const { item_master_id, modifier_name, price, tax_percent, inventory_item_id, deduct_qty, is_active } = req.body;

        const modifier = await req.propertyDb.models.item_modifiers.findByPk(id);
        if (!modifier) {
            return res.status(404).json({ success: false, message: 'Modifier not found' });
        }

        const updateData = {};
        if (item_master_id !== undefined) updateData.item_master_id = Number(item_master_id);
        if (modifier_name !== undefined) updateData.modifier_name = modifier_name.trim();
        if (price !== undefined) updateData.price = Number(price);
        if (tax_percent !== undefined) updateData.tax_percent = (tax_percent !== null && tax_percent !== '') ? Number(tax_percent) : null;
        if (inventory_item_id !== undefined) updateData.inventory_item_id = Number(inventory_item_id || 0);
        if (deduct_qty !== undefined) updateData.deduct_qty = Number(deduct_qty || 0);
        if (is_active !== undefined) updateData.is_active = is_active;

        await modifier.update(updateData);

        res.json({
            success: true,
            message: 'Modifier updated successfully',
            data: modifier
        });
    } catch (err) {
        console.error('Error updating modifier:', err);
        res.status(500).json({ success: false, message: 'Failed to update modifier' });
    }
};

exports.deleteModifier = async (req, res) => {
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
    } catch (err) {
        console.error('Error deleting modifier:', err);
        res.status(500).json({ success: false, message: 'Failed to delete modifier' });
    }
};
