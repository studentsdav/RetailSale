const audit = require('../../services/audit.service');
const fs = require('fs');
const path = require('path');
const { Op } = require('sequelize');
const { insertLedger } = require('../../services/stockLedger.service');

async function ensureMasterData(req, { outlet_id, row, transaction }) {
    const groupName = String(row.item_group || '').trim();
    const subCategoryName = String(row.sub_category || '').trim();
    const brandName = String(row.brand || '').trim();

    if (groupName) {
        await req.propertyDb.models.item_groups.findOrCreate({
            where: { outlet_id, group_name: groupName },
            defaults: { outlet_id, group_name: groupName, is_active: true },
            transaction
        });
    }

    let group = null;
    if (groupName) {
        group = await req.propertyDb.models.item_groups.findOne({
            where: { outlet_id, group_name: groupName },
            transaction
        });
    }

    if (group && subCategoryName) {
        await req.propertyDb.models.item_subcategories.findOrCreate({
            where: {
                outlet_id,
                group_id: group.id,
                subcategory_name: subCategoryName
            },
            defaults: {
                outlet_id,
                group_id: group.id,
                subcategory_name: subCategoryName,
                is_active: true
            },
            transaction
        });
    }

    if (brandName) {
        await req.propertyDb.models.brands.findOrCreate({
            where: { outlet_id, brand_name: brandName },
            defaults: { outlet_id, brand_name: brandName, is_active: true },
            transaction
        });
    }
}

async function hasAnyInventoryTransactions(req, outlet_id) {
    const models = req.propertyDb.models;
    const [purchaseOrderCount, salesCount, receiptCount, requestCount, issueCount] = await Promise.all([
        models.purchase_orders.count({ where: { outlet_id } }),
        models.sales_headers.count({ where: { outlet_id } }),
        models.goods_receipts.count({ where: { outlet_id } }),
        models.request_headers.count({ where: { outlet_id } }),
        models.issue_headers.count({ where: { outlet_id } })
    ]);

    return (purchaseOrderCount + salesCount + receiptCount + requestCount + issueCount) > 0;
}

async function hasItemLinkedTransactions(req, itemId, outlet_id) {
    const models = req.propertyDb.models;
    const checks = [
        models.purchase_order_items?.count({ where: { item_id: itemId, outlet_id } }) ?? Promise.resolve(0),
        models.sales_items?.count({ where: { item_id: itemId, outlet_id } }) ?? Promise.resolve(0),
        models.goods_receipt_items?.count({ where: { item_id: itemId, outlet_id } }) ?? Promise.resolve(0),
        models.request_items?.count({ where: { item_id: itemId, outlet_id } }) ?? Promise.resolve(0),
        models.issue_items?.count({ where: { item_id: itemId, outlet_id } }) ?? Promise.resolve(0)
    ];

    const counts = await Promise.all(checks);
    return counts.some((count) => Number(count || 0) > 0);
}

function generateBarcodeValue(item) {
    const numericId = Number(item.id || 0);
    return String(200000000000 + numericId).padStart(12, '0').slice(-12);
}

function resolveImageExtension(fileName, mimeType) {
    const name = String(fileName || '').toLowerCase();
    if (name.endsWith('.png')) return '.png';
    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return '.jpg';
    if (name.endsWith('.webp')) return '.webp';
    if (name.endsWith('.gif')) return '.gif';
    const mime = String(mimeType || '').toLowerCase();
    if (mime.includes('png')) return '.png';
    if (mime.includes('jpeg') || mime.includes('jpg')) return '.jpg';
    if (mime.includes('webp')) return '.webp';
    if (mime.includes('gif')) return '.gif';
    return '.jpg';
}

async function saveItemImageFromPayload(req, item, payload) {
    const base64Data = String(payload.base64_data || payload.base64 || '').trim();
    if (!base64Data) throw new Error('Image data is required');

    const cleanBase64 = base64Data.includes(',')
        ? base64Data.split(',').pop()
        : base64Data;
    const buffer = Buffer.from(cleanBase64, 'base64');
    if (!buffer.length) throw new Error('Invalid image data');

    const ext = resolveImageExtension(payload.file_name || payload.fileName, payload.mime_type || payload.mimeType);
    const folder = path.join(process.cwd(), 'uploads', 'items', String(req.user.outlet_id));
    await fs.promises.mkdir(folder, { recursive: true });

    const fileName = `item_${item.id}_${Date.now()}${ext}`;
    const absolutePath = path.join(folder, fileName);
    await fs.promises.writeFile(absolutePath, buffer);

    const imagePath = `/uploads/items/${req.user.outlet_id}/${fileName}`;
    await item.update({ image_path: imagePath });
    return imagePath;
}


exports.createItem = async (req, res) => {
    try {
        const {
            item_code,
            item_name,
            hsn_sac_code,
            item_group,
            sub_category,
            brand,
            unit,
            barcode,
            image_path,
            rate,
            retail_sale_price,
            tax_type,
            tax_percent,
            discount_applicable,
            scheme_applicable,
            opening_balance,
            pack_qty,
            loose_item_code,
            min_level,
            max_level,
            stockable
        } = req.body;

        const outlet_id = req.user.outlet_id;

        const existing = await req.propertyDb.models.item_master.findOne({
            where: {
                outlet_id,
                [Op.or]: [
                    { item_code },
                    { item_name }
                ]
            }
        });

        if (existing) {
            return res.status(400).json({
                success: false,
                message: 'Item code or item name already exists'
            });
        }

        const item = await req.propertyDb.models.item_master.create({
            outlet_id,
            item_code,
            item_name,
            hsn_sac_code: hsn_sac_code || null,
            item_group,
            sub_category,
            brand,
            unit,
            barcode: barcode || null,
            image_path: image_path || null,
            rate,
            retail_sale_price: retail_sale_price || 0,
            tax_type: tax_type || 'GST',
            tax_percent: tax_percent || 0,
            discount_applicable: discount_applicable ?? true,
            scheme_applicable: scheme_applicable ?? true,
            opening_balance,
            pack_qty: Number(pack_qty) || 0,
            loose_item_code: String(loose_item_code || '').trim() || null,
            min_level,
            max_level,
            stockable,
            is_active: true
        });


        await audit.log({
            req,
            module: 'ITEM_MASTER',
            action: 'CREATE',
            table: 'item_master',
            recordId: item.id,
            old_data: item.id,
            new_data: item.toJSON(),
            outlet_id: req.user.outlet_id,
            user_id: req.user.id
        });

        res.json({ success: true, data: item });

    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.canImportItems = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const hasTransactions = await hasAnyInventoryTransactions(req, outlet_id);
        res.json({
            success: true,
            canImport: !hasTransactions
        });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.canResetAndImportItems = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const hasTransactions = await hasAnyInventoryTransactions(req, outlet_id);
        res.json({
            success: true,
            canResetAndImport: !hasTransactions
        });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.deleteAllItemsForFreshImport = async (req, res) => {
    const t = await req.propertyDb.transaction();
    try {
        const outlet_id = req.user.outlet_id;
        const hasTransactions = await hasAnyInventoryTransactions(req, outlet_id);
        if (hasTransactions) {
            await t.rollback();
            return res.status(400).json({
                success: false,
                message: 'Cannot delete all items because transactions already exist.'
            });
        }

        await req.propertyDb.models.item_master.update(
            { is_active: false },
            { where: { outlet_id, is_active: true }, transaction: t }
        );

        await audit.log({
            req,
            module: 'ITEM_MASTER',
            action: 'BULK_DEACTIVATE',
            table: 'item_master',
            recordId: null,
            old_data: { scope: 'all_active_items' },
            new_data: { is_active: false },
            outlet_id,
            user_id: req.user.id
        });

        await t.commit();
        res.json({ success: true, message: 'All items deleted successfully.' });
    } catch (err) {
        await t.rollback();
        res.status(500).json({ success: false, error: err.message });
    }
};


exports.bulkImportItems = async (req, res) => {
    const t = await req.propertyDb.transaction();

    try {
        const outlet_id = req.user.outlet_id;
        const items = req.body;

        const hasTransactions = await hasAnyInventoryTransactions(req, outlet_id);
        if (hasTransactions) {
            return res.status(400).json({
                success: false,
                message: 'Import is blocked because transactions already exist.'
            });
        }

        // Simple behavior:
        // If there are no transactions, clear existing active items first,
        // then import the new Excel payload.
        await req.propertyDb.models.item_master.update(
            { is_active: false },
            { where: { outlet_id, is_active: true }, transaction: t }
        );

        const seenCodes = new Set();
        for (const row of items) {
            const normalizedCode = String(row.item_code || '').trim();
            if (!normalizedCode) {
                throw new Error('Item code is required in import file.');
            }
            if (seenCodes.has(normalizedCode.toLowerCase())) {
                throw new Error(`Duplicate item code in import file: ${normalizedCode}`);
            }
            seenCodes.add(normalizedCode.toLowerCase());

            await ensureMasterData(req, { outlet_id, row, transaction: t });

            const payload = {
                outlet_id,
                item_code: normalizedCode,
                item_name: String(row.item_name || '').trim(),
                hsn_sac_code: row.hsn_sac_code || null,
                item_group: String(row.item_group || '').trim(),
                sub_category: String(row.sub_category || '').trim(),
                brand: String(row.brand || '').trim(),
                unit: String(row.unit || '').trim(),
                barcode: row.barcode || null,
                image_path: row.image_path || null,
                rate: parseFloat(row.rate) || 0,
                retail_sale_price: parseFloat(row.retail_sale_price) || 0,
                tax_type: row.tax_type || 'GST',
                tax_percent: parseFloat(row.tax_percent) || 0,
                discount_applicable: row.discount_applicable !== false && row.discount_applicable !== 'NO',
                scheme_applicable: row.scheme_applicable !== false && row.scheme_applicable !== 'NO',
                opening_balance: parseFloat(row.opening_balance) || 0,
                pack_qty: parseFloat(row.pack_qty) || 0,
                loose_item_code: String(row.loose_item_code || '').trim() || null,
                min_level: parseInt(row.min_level) || 0,
                max_level: parseInt(row.max_level) || 0,
                stockable: row.stockable === true || row.stockable === 'YES',
                is_active: true
            };

            const existing = await req.propertyDb.models.item_master.findOne({
                where: { outlet_id, item_code: normalizedCode },
                transaction: t
            });

            if (existing) {
                await existing.update(payload, { transaction: t });
            } else {
                await req.propertyDb.models.item_master.create(payload, { transaction: t });
            }
        }

        await t.commit();

        res.json({ success: true, message: 'Items imported successfully' });

    } catch (err) {
        await t.rollback();
        const details = Array.isArray(err?.errors)
            ? err.errors.map((e) => e.message).join(', ')
            : null;
        res.status(500).json({
            success: false,
            error: details || err.message || 'Validation error during import'
        });
    }
};

exports.getItems = async (req, res) => {
    try {
        const { q } = req.query;
        const outlet_id = req.user.outlet_id;

        const where = {
            outlet_id,
            is_active: true
        };

        if (q) {
            if (q && q.trim() !== '') {
                const search = q.trim();

                where[Op.or] = [
                    { item_code: { [Op.iLike]: `%${search}%` } },
                    { item_name: { [Op.iLike]: `%${search}%` } },
                    { barcode: { [Op.iLike]: `%${search}%` } },
                    { item_group: { [Op.iLike]: `%${search}%` } },
                    { sub_category: { [Op.iLike]: `%${search}%` } },
                    { brand: { [Op.iLike]: `%${search}%` } }
                ];
            }

        }

        const items = await req.propertyDb.models.item_master.findAll({
            where,
            order: [['item_name', 'ASC']]
        });

        res.json({ success: true, data: items });

    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.getItemById = async (req, res) => {
    try {
        const { id } = req.params;
        const outlet_id = req.user.outlet_id;

        const item = await req.propertyDb.models.item_master.findOne({
            where: { id, outlet_id }
        });

        if (!item) {
            return res.status(404).json({
                success: false,
                message: 'Item not found'
            });
        }

        res.json({ success: true, data: item });

    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.updateItem = async (req, res) => {
    try {
        const id = req.params.id;
        const outlet_id = req.user.outlet_id;

        const item = await req.propertyDb.models.item_master.findOne({
            where: { id, outlet_id }
        });

        if (!item) {
            return res.status(404).json({ success: false, message: 'Item not found' });
        }

        const oldData = item.toJSON();

        const payload = {
            ...item.toJSON(),
            ...req.body
        };
        if (payload.pack_qty !== undefined) {
            payload.pack_qty = Number(payload.pack_qty) || 0;
        }
        if (payload.loose_item_code !== undefined) {
            payload.loose_item_code = String(payload.loose_item_code || '').trim() || null;
        }
        const duplicate = await req.propertyDb.models.item_master.findOne({
            where: {
                outlet_id,
                id: { [Op.ne]: id },
                [Op.or]: [
                    { item_code: payload.item_code },
                    { item_name: payload.item_name }
                ]
            }
        });

        if (duplicate) {
            return res.status(400).json({
                success: false,
                message: 'Item code or item name already exists'
            });
        }

        await item.update(payload);

        await audit.log({
            req,
            module: 'ITEM_MASTER',
            action: 'UPDATE',
            table: 'item_master',
            recordId: item.id,
            old_data: oldData,
            new_data: item.toJSON(),
            outlet_id: req.user.outlet_id,
            user_id: req.user.id
        });


        res.json({ success: true, data: item });

    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};
exports.deleteItem = async (req, res) => {
    try {
        const id = req.params.id;
        const outlet_id = req.user.outlet_id;

        const item = await req.propertyDb.models.item_master.findOne({
            where: { id, outlet_id }
        });

        if (!item) {
            return res.status(404).json({ success: false, code: 404 });
        }

        const hasLinkedTransactions = await hasItemLinkedTransactions(req, item.id, outlet_id);
        if (hasLinkedTransactions) {
            return res.status(400).json({
                success: false,
                message: 'This item cannot be deleted because transaction history exists for it.'
            });
        }

        await item.update({ is_active: false });



        await audit.log({
            req,
            module: 'ITEM_MASTER',
            action: 'DEACTIVATE',
            table: 'item_master',
            recordId: item.id,
            old_data: { is_active: true },
            new_data: { is_active: false },
            outlet_id: req.user.outlet_id,
            user_id: req.user.id
        });


        res.json({ success: true, message: 'Item deactivated' });

    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }


};

exports.openPackStock = async (req, res) => {
    const t = await req.propertyDb.transaction();

    try {
        const outlet_id = req.user.outlet_id;
        const itemId = Number(req.params.id);
        const packCount = Number(req.body.pack_count ?? 1);
        const note = String(req.body.note || '').trim() || null;

        if (!Number.isFinite(itemId) || itemId <= 0) {
            throw new Error('Valid item id is required');
        }
        if (!Number.isFinite(packCount) || packCount <= 0) {
            throw new Error('Pack count must be greater than 0');
        }

        const sourceItem = await req.propertyDb.models.item_master.findOne({
            where: { id: itemId, outlet_id },
            transaction: t
        });
        if (!sourceItem) {
            throw new Error('Pack item not found');
        }

        const packQty = Number(sourceItem.pack_qty) || 0;
        const looseItemCode = String(sourceItem.loose_item_code || '').trim();
        if (packQty <= 0 || !looseItemCode) {
            throw new Error('This item is not configured for pack-to-loose conversion');
        }

        const targetItem = await req.propertyDb.models.item_master.findOne({
            where: { outlet_id, item_code: looseItemCode, is_active: true },
            transaction: t
        });
        if (!targetItem) {
            throw new Error(`Loose item ${looseItemCode} not found`);
        }

        const openQty = packQty * packCount;
        const refNo = `OPENPACK-${sourceItem.item_code}-${Date.now()}`;
        const remark = note || `Opened ${packCount} ${sourceItem.unit || 'pack'} from ${sourceItem.item_code} into ${targetItem.item_code}`;

        await insertLedger({
            db: req.propertyDb,
            outlet_id,
            item_code: sourceItem.item_code,
            txn_date: new Date(),
            txn_type: 'OPEN_PACK',
            ref_no: refNo,
            qty_in: 0,
            qty_out: packCount,
            transaction: t
        });

        await insertLedger({
            db: req.propertyDb,
            outlet_id,
            item_code: targetItem.item_code,
            txn_date: new Date(),
            txn_type: 'OPEN_PACK',
            ref_no: refNo,
            qty_in: openQty,
            qty_out: 0,
            transaction: t
        });

        await audit.log({
            req,
            module: 'ITEM_MASTER',
            action: 'OPEN_PACK',
            table: 'stock_ledger',
            recordId: sourceItem.id,
            old_data: { source_item_code: sourceItem.item_code, loose_item_code: looseItemCode, pack_count: 0 },
            new_data: { source_item_code: sourceItem.item_code, loose_item_code: looseItemCode, pack_count: packCount, loose_qty: openQty, note: remark },
            outlet_id,
            user_id: req.user.id
        });

        await t.commit();
        res.json({
            success: true,
            data: {
                source_item_code: sourceItem.item_code,
                loose_item_code: targetItem.item_code,
                pack_count: packCount,
                loose_qty: openQty,
                ref_no: refNo
            }
        });
    } catch (err) {
        await t.rollback();
        res.status(400).json({ success: false, error: err.message });
    }
};

exports.generateBarcodes = async (req, res) => {
    const t = await req.propertyDb.transaction();

    try {
        const outlet_id = req.user.outlet_id;
        const selectedIds = Array.isArray(req.body.item_ids)
            ? req.body.item_ids
                .map((id) => parseInt(id, 10))
                .filter((id) => Number.isInteger(id) && id > 0)
            : [];
        const forceRegenerate = req.body.force_regenerate === true;

        const where = { outlet_id, is_active: true };
        if (selectedIds.length > 0) {
            where.id = { [Op.in]: selectedIds };
        }

        const items = await req.propertyDb.models.item_master.findAll({
            where,
            order: [['item_name', 'ASC']],
            transaction: t
        });

        for (const item of items) {
            const currentBarcode = String(item.barcode || '').trim();
            if (!forceRegenerate && currentBarcode) {
                continue;
            }
            await item.update(
                { barcode: generateBarcodeValue(item) },
                { transaction: t }
            );
        }

        await t.commit();
        res.json({
            success: true,
            data: items.map((item) => item.toJSON())
        });
    } catch (err) {
        await t.rollback();
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.getNextItemCode = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;

        const last = await req.propertyDb.models.item_master.findOne({
            where: { outlet_id },
            order: [['id', 'DESC']],
            attributes: ['item_code'],
        });

        let nextNum = 1;

        if (last?.item_code) {
            const num = parseInt(last.item_code.replace(/[^\d]/g, '')) || 0;
            nextNum = num + 1;
        }

        res.json({
            success: true,
            data: `item${nextNum}`,
        });

    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.uploadItemImage = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { id } = req.params;
        const item = await req.propertyDb.models.item_master.findOne({
            where: { id, outlet_id }
        });

        if (!item) {
            return res.status(404).json({ success: false, message: 'Item not found' });
        }

        const imagePath = await saveItemImageFromPayload(req, item, req.body || {});
        await audit.log({
            req,
            module: 'ITEM_MASTER',
            action: 'UPLOAD_IMAGE',
            table: 'item_master',
            recordId: item.id,
            old_data: { image_path: item.image_path || null },
            new_data: { image_path: imagePath },
            outlet_id,
            user_id: req.user.id
        });

        res.json({ success: true, data: { image_path: imagePath } });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.deleteItemImage = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { id } = req.params;
        const item = await req.propertyDb.models.item_master.findOne({
            where: { id, outlet_id }
        });

        if (!item) {
            return res.status(404).json({ success: false, message: 'Item not found' });
        }

        const oldImagePath = item.image_path || null;
        if (oldImagePath) {
            const absolutePath = path.join(process.cwd(), oldImagePath.replace(/^\/+/, ''));
            if (fs.existsSync(absolutePath)) {
                fs.unlinkSync(absolutePath);
            }
        }

        await item.update({ image_path: null });
        await audit.log({
            req,
            module: 'ITEM_MASTER',
            action: 'DELETE_IMAGE',
            table: 'item_master',
            recordId: item.id,
            old_data: { image_path: oldImagePath },
            new_data: { image_path: null },
            outlet_id,
            user_id: req.user.id
        });

        res.json({ success: true, data: { image_path: null } });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};
