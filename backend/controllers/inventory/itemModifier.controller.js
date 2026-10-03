const { resolveOutletScope } = require('../../utils/outletScopeHelper');

async function ensureItemMasterModifierColumns(db) {
    try {
        await db.query(`
            ALTER TABLE item_master 
            ADD COLUMN IF NOT EXISTS is_modifier BOOLEAN DEFAULT FALSE,
            ADD COLUMN IF NOT EXISTS applicable_item_ids TEXT DEFAULT NULL,
            ADD COLUMN IF NOT EXISTS deduct_raw_item_id INTEGER DEFAULT NULL,
            ADD COLUMN IF NOT EXISTS deduct_qty DECIMAL(12, 4) DEFAULT 0.0000;
        `);
    } catch (_) {}
}

exports.getModifiers = async (req, res) => {
    try {
        await ensureItemMasterModifierColumns(req.propertyDb);

        const reqOutlet = req.query.outlet_id || req.query.outletId;
        const scope = await resolveOutletScope(req, reqOutlet);
        const { item_id, search, is_active } = req.query;

        let whereConditions = ['im.outlet_id IN (:outletIds)', 'im.is_modifier = true'];
        let replacements = { outletIds: scope.outletIds };

        if (search && search.trim() !== '') {
            whereConditions.push('(im.item_name ILIKE :search OR im.item_code ILIKE :search OR inv.item_name ILIKE :search)');
            replacements.search = `%${search.trim()}%`;
        }

        if (is_active !== undefined && is_active !== '') {
            whereConditions.push('im.is_active = :is_active');
            replacements.is_active = is_active === 'true' || is_active === true;
        }

        const whereClause = `WHERE ${whereConditions.join(' AND ')}`;

        const [rows] = await req.propertyDb.query(`
            SELECT
                im.id,
                im.outlet_id,
                im.item_name AS modifier_name,
                im.item_name,
                im.item_code,
                COALESCE(im.retail_sale_price, im.rate, 0) AS price,
                COALESCE(im.tax_percent, 0) AS tax_percent,
                im.applicable_item_ids,
                im.deduct_raw_item_id AS inventory_item_id,
                im.deduct_raw_item_id,
                COALESCE(im.deduct_qty, 0) AS deduct_qty,
                im.is_active,
                im.is_modifier,
                im.created_at,
                inv.item_name AS inventory_item_name,
                inv.item_code AS inventory_item_code,
                inv.unit AS inventory_item_unit
            FROM item_master im
            LEFT JOIN item_master inv
                ON inv.id = im.deduct_raw_item_id
            ${whereClause}
            ORDER BY im.id DESC
        `, { replacements });

        let filteredRows = rows;
        if (item_id && item_id !== '0' && item_id !== 'ALL') {
            const targetItemId = String(item_id).trim();
            filteredRows = rows.filter((r) => {
                const appIds = (r.applicable_item_ids || '').toString().trim();
                if (!appIds || appIds === 'ALL' || appIds === '*' || appIds === '0') return true;
                const list = appIds.split(',').map((s) => s.trim());
                return list.includes(targetItemId);
            });
        }

        res.json({
            success: true,
            data: filteredRows
        });
    } catch (err) {
        console.error('Error fetching modifiers from item_master:', err);
        res.status(500).json({ success: false, message: 'Failed to load modifiers' });
    }
};

exports.createModifier = async (req, res) => {
    try {
        await ensureItemMasterModifierColumns(req.propertyDb);

        const outlet_id = req.user?.outlet_id || req.body.outlet_id;
        const {
            item_master_id,
            modifier_name,
            item_name,
            item_code,
            price,
            rate,
            tax_percent,
            inventory_item_id,
            deduct_raw_item_id,
            deduct_qty,
            applicable_item_ids,
            is_active = true
        } = req.body;

        const finalName = (modifier_name || item_name || '').trim();
        if (!finalName) {
            return res.status(400).json({ success: false, message: 'Modifier name is required' });
        }

        const finalPrice = Number(price !== undefined ? price : (rate || 0));
        const finalRawId = inventory_item_id ? Number(inventory_item_id) : (deduct_raw_item_id ? Number(deduct_raw_item_id) : null);
        const finalDeductQty = Number(deduct_qty || 0);
        const finalAppIds = applicable_item_ids || (item_master_id && Number(item_master_id) > 0 ? String(item_master_id) : null);
        const finalCode = item_code || `MOD-${Date.now().toString().slice(-6)}`;

        const item = await req.propertyDb.models.item_master.create({
            outlet_id,
            item_name: finalName,
            item_code: finalCode,
            item_group: 'Modifiers',
            retail_sale_price: finalPrice,
            rate: finalPrice,
            tax_percent: tax_percent !== undefined && tax_percent !== null && tax_percent !== '' ? Number(tax_percent) : 0,
            is_modifier: true,
            is_saleable: true,
            applicable_item_ids: finalAppIds,
            deduct_raw_item_id: finalRawId,
            deduct_qty: finalDeductQty,
            is_active: is_active === true || is_active === 'true'
        });

        res.json({
            success: true,
            message: 'Modifier created in item_master successfully',
            data: item
        });
    } catch (err) {
        console.error('Error creating modifier in item_master:', err);
        res.status(500).json({ success: false, message: 'Failed to create modifier' });
    }
};

exports.updateModifier = async (req, res) => {
    try {
        await ensureItemMasterModifierColumns(req.propertyDb);

        const { id } = req.params;
        const {
            item_master_id,
            modifier_name,
            item_name,
            price,
            rate,
            tax_percent,
            inventory_item_id,
            deduct_raw_item_id,
            deduct_qty,
            applicable_item_ids,
            is_active
        } = req.body;

        const item = await req.propertyDb.models.item_master.findByPk(id);
        if (!item) {
            return res.status(404).json({ success: false, message: 'Modifier item not found' });
        }

        const updateData = { is_modifier: true };
        if (modifier_name !== undefined || item_name !== undefined) {
            updateData.item_name = (modifier_name || item_name || '').trim();
        }
        if (price !== undefined || rate !== undefined) {
            const finalPrice = Number(price !== undefined ? price : rate);
            updateData.retail_sale_price = finalPrice;
            updateData.rate = finalPrice;
        }
        if (tax_percent !== undefined) {
            updateData.tax_percent = (tax_percent !== null && tax_percent !== '') ? Number(tax_percent) : 0;
        }
        if (inventory_item_id !== undefined || deduct_raw_item_id !== undefined) {
            updateData.deduct_raw_item_id = inventory_item_id ? Number(inventory_item_id) : (deduct_raw_item_id ? Number(deduct_raw_item_id) : null);
        }
        if (deduct_qty !== undefined) {
            updateData.deduct_qty = Number(deduct_qty || 0);
        }
        if (applicable_item_ids !== undefined) {
            updateData.applicable_item_ids = applicable_item_ids;
        } else if (item_master_id !== undefined) {
            updateData.applicable_item_ids = Number(item_master_id) > 0 ? String(item_master_id) : null;
        }
        if (is_active !== undefined) {
            updateData.is_active = is_active;
        }

        await item.update(updateData);

        res.json({
            success: true,
            message: 'Modifier updated in item_master successfully',
            data: item
        });
    } catch (err) {
        console.error('Error updating modifier in item_master:', err);
        res.status(500).json({ success: false, message: 'Failed to update modifier' });
    }
};

exports.deleteModifier = async (req, res) => {
    try {
        const { id } = req.params;
        const item = await req.propertyDb.models.item_master.findByPk(id);
        if (!item) {
            return res.status(404).json({ success: false, message: 'Modifier item not found' });
        }

        await item.update({ is_modifier: false });

        res.json({
            success: true,
            message: 'Modifier removed successfully'
        });
    } catch (err) {
        console.error('Error deleting modifier:', err);
        res.status(500).json({ success: false, message: 'Failed to delete modifier' });
    }
};

module.exports = exports;
