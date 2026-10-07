import { Request, Response } from 'express';
const audit = require('../../services/audit.service');
const fs = require('fs');
const path = require('path');
const { Op } = require('sequelize');
const { insertLedger } = require('../../services/stockLedger.service');

async function ensureMasterData(req: any, { outlet_id, row, transaction }: any) {
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

async function ensureItemMasterModifierColumns(propertyDb: any) {
    try {
        await propertyDb.query(`
            ALTER TABLE item_master
            ADD COLUMN IF NOT EXISTS is_modifier BOOLEAN DEFAULT FALSE,
            ADD COLUMN IF NOT EXISTS applicable_item_ids TEXT,
            ADD COLUMN IF NOT EXISTS deduct_raw_item_id INTEGER,
            ADD COLUMN IF NOT EXISTS deduct_qty DECIMAL(12, 4) DEFAULT 0,
            ADD COLUMN IF NOT EXISTS food_type VARCHAR(20) DEFAULT 'VEG',
            ADD COLUMN IF NOT EXISTS dietary_type VARCHAR(20) DEFAULT 'VEG',
            ADD COLUMN IF NOT EXISTS is_veg BOOLEAN DEFAULT TRUE;
        `);
    } catch (_) {}
}

async function hasAnyInventoryTransactions(req: any, outlet_id: any) {
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

async function hasItemLinkedTransactions(req: any, itemId: any, outlet_id: any) {
    const models = req.propertyDb.models;
    const checks = [
        models.purchase_order_items?.count({
            include: [{
                model: models.purchase_orders,
                as: 'purchase_order',
                where: { outlet_id }
            }],
            where: { item_id: itemId }
        }) ?? Promise.resolve(0),
        models.sales_items?.count({
            include: [{
                model: models.sales_headers,
                as: 'sale',
                where: { outlet_id }
            }],
            where: { item_id: itemId }
        }) ?? Promise.resolve(0),
        models.goods_receipt_items?.count({
            include: [{
                model: models.goods_receipts,
                as: 'grn',
                where: { outlet_id }
            }],
            where: { item_id: itemId }
        }) ?? Promise.resolve(0),
        models.request_items?.count({
            include: [{
                model: models.request_headers,
                as: 'header',
                where: { outlet_id }
            }],
            where: { item_id: itemId }
        }) ?? Promise.resolve(0),
        models.issue_items?.count({
            include: [{
                model: models.issue_headers,
                as: 'issue',
                where: { outlet_id }
            }],
            where: { item_id: itemId }
        }) ?? Promise.resolve(0)
    ];

    const counts = await Promise.all(checks);
    return counts.some((count) => Number(count || 0) > 0);
}

function generateBarcodeValue(item: any) {
    const numericId = Number(item.id || 0);
    return String(200000000000 + numericId).padStart(12, '0').slice(-12);
}

function resolveImageExtension(fileName: any, mimeType: any) {
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

async function saveItemImageFromPayload(req: any, item: any, payload: any) {
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

export const createItem = async (req: Request, res: Response) => {
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
            mrp,
            tax_type,
            tax_percent,
            tax_group_id,
            discount_applicable,
            scheme_applicable,
            opening_balance,
            pack_qty,
            loose_item_code,
            min_level,
            max_level,
            stockable,
            is_saleable,
            is_modifier,
            applicable_item_ids,
            deduct_raw_item_id,
            deduct_qty,
            is_tax_inclusive,
            is_happy_hour,
            location,
            kitchen_location,
            food_type,
            dietary_type,
            is_veg
        } = req.body;

        const outlet_id = (req as any).user.outlet_id;
        await ensureItemMasterModifierColumns((req as any).propertyDb);

        // Item code must always be unique
        const codeConflict = await (req as any).propertyDb.models.item_master.findOne({ where: { outlet_id, item_code } });
        if (codeConflict) {
            return res.status(400).json({
                success: false,
                message: `Item Code "${item_code}" is already used by "${codeConflict.item_name} (${codeConflict.brand})". Please use a unique item code.`
            });
        }

        // Same item name + same brand = duplicate (same name with different brand is allowed)
        const nameBrandConflict = await (req as any).propertyDb.models.item_master.findOne({
            where: { outlet_id, item_name, brand: brand || '' }
        });
        if (nameBrandConflict) {
            return res.status(400).json({
                success: false,
                message: `Item "${item_name}" with Brand "${brand}" already exists. Please use a different brand or a different item name.`
            });
        }

        const resolvedFoodType = food_type || dietary_type || (is_veg === false ? 'NON_VEG' : 'VEG');

        const item = await (req as any).propertyDb.models.item_master.create({
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
            location: (location || kitchen_location || 'Kitchen').trim() || 'Kitchen',
            rate,
            retail_sale_price: retail_sale_price || 0,
            mrp: mrp || 0,
            tax_type: tax_type || 'GST',
            tax_percent: tax_percent || 0,
            tax_group_id: tax_group_id || null,
            discount_applicable: discount_applicable ?? true,
            scheme_applicable: scheme_applicable ?? true,
            opening_balance,
            pack_qty: Number(pack_qty) || 0,
            loose_item_code: String(loose_item_code || '').trim() || null,
            min_level,
            max_level,
            stockable,
            is_saleable: is_saleable ?? true,
            is_modifier: is_modifier ?? false,
            applicable_item_ids: applicable_item_ids ? String(applicable_item_ids) : null,
            deduct_raw_item_id: deduct_raw_item_id ? Number(deduct_raw_item_id) : null,
            deduct_qty: Number(deduct_qty) || 0,
            food_type: resolvedFoodType,
            dietary_type: resolvedFoodType,
            is_veg: is_veg !== undefined ? Boolean(is_veg) : (resolvedFoodType !== 'NON_VEG'),
            is_tax_inclusive: is_tax_inclusive ?? false,
            is_happy_hour: is_happy_hour ?? false,
            is_active: true
        });

        // Explicit safeguard update for modifier and dietary columns
        await (req as any).propertyDb.query(`
            UPDATE item_master
            SET is_modifier = :is_modifier,
                applicable_item_ids = :applicable_item_ids,
                deduct_raw_item_id = :deduct_raw_item_id,
                deduct_qty = :deduct_qty,
                food_type = :food_type,
                dietary_type = :dietary_type,
                is_veg = :is_veg
            WHERE id = :id AND outlet_id = :outlet_id
        `, {
            replacements: {
                id: item.id,
                outlet_id: (req as any).user.outlet_id,
                is_modifier: is_modifier === true || is_modifier === 'true' || is_modifier === 1,
                applicable_item_ids: applicable_item_ids ? String(applicable_item_ids).trim() : null,
                deduct_raw_item_id: deduct_raw_item_id ? Number(deduct_raw_item_id) : null,
                deduct_qty: Number(deduct_qty) || 0,
                food_type: resolvedFoodType,
                dietary_type: resolvedFoodType,
                is_veg: is_veg !== undefined ? Boolean(is_veg) : (resolvedFoodType !== 'NON_VEG')
            }
        });

        await audit.log({
            req,
            module: 'ITEM_MASTER',
            action: 'CREATE',
            table: 'item_master',
            recordId: item.id,
            oldData: item.id,
            newData: item.toJSON(),
            outlet_id: (req as any).user.outlet_id,
            user_id: (req as any).user.id
        });

        res.json({ success: true, data: item });

    } catch (err: any) {
        res.status(500).json({ success: false, error: err.message });
    }
};

export const canImportItems = async (req: Request, res: Response) => {
    try {
        const outlet_id = (req as any).user.outlet_id;
        const hasTransactions = await hasAnyInventoryTransactions(req, outlet_id);
        res.json({
            success: true,
            canImport: !hasTransactions
        });
    } catch (err: any) {
        res.status(500).json({ success: false, error: err.message });
    }
};

export const canResetAndImportItems = async (req: Request, res: Response) => {
    try {
        const outlet_id = (req as any).user.outlet_id;
        const hasTransactions = await hasAnyInventoryTransactions(req, outlet_id);
        res.json({
            success: true,
            canResetAndImport: !hasTransactions
        });
    } catch (err: any) {
        res.status(500).json({ success: false, error: err.message });
    }
};

export const deleteAllItemsForFreshImport = async (req: Request, res: Response) => {
    const t = await (req as any).propertyDb.transaction();
    try {
        const outlet_id = (req as any).user.outlet_id;
        const hasTransactions = await hasAnyInventoryTransactions(req, outlet_id);
        if (hasTransactions) {
            await t.rollback();
            return res.status(400).json({
                success: false,
                message: 'Cannot delete all items because transactions already exist.'
            });
        }

        await (req as any).propertyDb.models.item_master.update(
            { is_active: false },
            { where: { outlet_id, is_active: true }, transaction: t }
        );

        await audit.log({
            req,
            module: 'ITEM_MASTER',
            action: 'BULK_DEACTIVATE',
            table: 'item_master',
            recordId: null,
            oldData: { scope: 'all_active_items' },
            newData: { is_active: false },
            outlet_id,
            user_id: (req as any).user.id
        });

        await t.commit();
        res.json({ success: true, message: 'All items deleted successfully.' });
    } catch (err: any) {
        await t.rollback();
        res.status(500).json({ success: false, error: err.message });
    }
};

export const bulkImportItems = async (req: Request, res: Response) => {
    const t = await (req as any).propertyDb.transaction();

    try {
        const outlet_id = (req as any).user.outlet_id;
        const items = req.body;

        const hasTransactions = await hasAnyInventoryTransactions(req, outlet_id);
        if (hasTransactions) {
            return res.status(400).json({
                success: false,
                message: 'Import is blocked because transactions already exist.'
            });
        }

        await (req as any).propertyDb.models.item_master.update(
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

            const payload: any = {
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
                location: String(row.location || row.kitchen_location || 'Kitchen').trim() || 'Kitchen',
                rate: parseFloat(row.rate) || 0,
                retail_sale_price: parseFloat(row.retail_sale_price) || 0,
                mrp: parseFloat(row.mrp) || 0,
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
                is_saleable: row.is_saleable !== false && row.is_saleable !== 'NO',
                is_modifier: row.is_modifier === true || row.is_modifier === 'YES' || row.is_modifier === 'true' || row.is_modifier === 1,
                applicable_item_ids: row.applicable_item_ids ? String(row.applicable_item_ids) : null,
                deduct_raw_item_id: row.deduct_raw_item_id ? Number(row.deduct_raw_item_id) : null,
                deduct_qty: parseFloat(row.deduct_qty) || 0,
                food_type: row.food_type || row.dietary_type || (row.is_veg === false || row.is_veg === 'false' || row.is_veg === 'NO' ? 'NON_VEG' : 'VEG'),
                dietary_type: row.dietary_type || row.food_type || (row.is_veg === false || row.is_veg === 'false' || row.is_veg === 'NO' ? 'NON_VEG' : 'VEG'),
                is_veg: row.is_veg !== undefined ? (row.is_veg !== false && row.is_veg !== 'false' && row.is_veg !== 'NO') : true,
                is_tax_inclusive: row.is_tax_inclusive === true || row.is_tax_inclusive === 'YES' || row.is_tax_inclusive === 'true' || row.is_tax_inclusive === 1,
                is_happy_hour: row.is_happy_hour === true || row.is_happy_hour === 'YES' || row.is_happy_hour === 'true' || row.is_happy_hour === 1,
                is_active: true
            };

            const existing = await (req as any).propertyDb.models.item_master.findOne({
                where: { outlet_id, item_code: normalizedCode },
                transaction: t
            });

            if (existing) {
                await existing.update(payload, { transaction: t });
            } else {
                await (req as any).propertyDb.models.item_master.create(payload, { transaction: t });
            }
        }

        await t.commit();

        res.json({ success: true, message: 'Items imported successfully' });

    } catch (err: any) {
        await t.rollback();
        const details = Array.isArray(err?.errors)
            ? err.errors.map((e: any) => e.message).join(', ')
            : null;
        res.status(500).json({
            success: false,
            error: details || err.message || 'Validation error during import'
        });
    }
};

export const getItems = async (req: Request, res: Response) => {
    try {
        await ensureItemMasterModifierColumns((req as any).propertyDb);
        const { q } = req.query as any;
        const outlet_id = (req as any).user.outlet_id;

        const where: any = {
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

        const items = await (req as any).propertyDb.models.item_master.findAll({
            where,
            include: [
                {
                    model: (req as any).propertyDb.models.product_templates,
                    as: 'product_template',
                    required: false
                },
                {
                    model: (req as any).propertyDb.models.attribute_values,
                    as: 'attribute_values',
                    required: false,
                    include: [
                        {
                            model: (req as any).propertyDb.models.attributes,
                            as: 'attribute',
                            required: false
                        }
                    ]
                },
                {
                    model: (req as any).propertyDb.models.tax_groups,
                    as: 'tax_group',
                    required: false,
                    include: [
                        {
                            model: (req as any).propertyDb.models.tax_group_components,
                            as: 'components',
                            required: false
                        }
                    ]
                }
            ],
            order: [['item_name', 'ASC']]
        });

        // Get the latest balances from stock_ledger for all items in this outlet
        const [ledgerStockRows]: any = await (req as any).propertyDb.query(`
            SELECT sl.item_code, sl.balance
            FROM stock_ledger sl
            INNER JOIN (
                SELECT item_code, MAX(id) AS max_id
                FROM stock_ledger
                WHERE outlet_id = :outlet_id
                GROUP BY item_code
            ) latest ON sl.id = latest.max_id
        `, {
            replacements: { outlet_id }
        });

        const ledgerStockMap: any = {};
        for (const row of ledgerStockRows || []) {
            ledgerStockMap[row.item_code] = Number(row.balance);
        }

        // Calculate dynamic held stock from active KOTs
        const [heldStockRows]: any = await (req as any).propertyDb.query(`
            SELECT ki.item_id, COALESCE(SUM(ki.qty), 0) AS held_qty
            FROM kot_items ki
            INNER JOIN kot_headers kh ON ki.kot_header_id = kh.id
            WHERE ki.status NOT IN ('Cancelled', 'Rejected')
              AND kh.sales_header_id IS NULL
              AND kh.status NOT IN ('Closed', 'closed', 'billed', 'Billed', 'BILLED', 'Cancelled', 'cancelled', 'Rejected')
              AND kh.outlet_id = :outlet_id
            GROUP BY ki.item_id
        `, {
            replacements: { outlet_id }
        });

        const heldStockMap: any = {};
        for (const row of heldStockRows || []) {
            heldStockMap[row.item_id] = Number(row.held_qty);
        }

        const itemsWithAvailableStock = items.map((item: any) => {
            const itemJson = item.toJSON();
            const heldQty = heldStockMap[item.id] || 0;
            const currentStock = ledgerStockMap[item.item_code] !== undefined 
                ? ledgerStockMap[item.item_code] 
                : Number(item.opening_balance || 0);

            itemJson.opening_balance = Math.max(0, currentStock - heldQty);
            return itemJson;
        });

        res.json({ success: true, data: itemsWithAvailableStock });

    } catch (err: any) {
        res.status(500).json({ success: false, error: err.message });
    }
};

export const getItemById = async (req: Request, res: Response) => {
    try {
        await ensureItemMasterModifierColumns((req as any).propertyDb);
        const { id } = req.params;
        const outlet_id = (req as any).user.outlet_id;

        const item = await (req as any).propertyDb.models.item_master.findOne({
            where: { id, outlet_id },
            include: [
                {
                    model: (req as any).propertyDb.models.product_templates,
                    as: 'product_template',
                    required: false
                },
                {
                    model: (req as any).propertyDb.models.attribute_values,
                    as: 'attribute_values',
                    required: false,
                    include: [
                        {
                            model: (req as any).propertyDb.models.attributes,
                            as: 'attribute',
                            required: false
                        }
                    ]
                }
            ]
        });

        if (!item) {
            return res.status(404).json({
                success: false,
                message: 'Item not found'
            });
        }

        res.json({ success: true, data: item });

    } catch (err: any) {
        res.status(500).json({ success: false, error: err.message });
    }
};

export const updateItem = async (req: Request, res: Response) => {
    try {
        const id = req.params.id;
        const outlet_id = (req as any).user.outlet_id;

        const item = await (req as any).propertyDb.models.item_master.findOne({
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
        // Item code must always be unique (excluding self)
        const codeConflict = await (req as any).propertyDb.models.item_master.findOne({ where: { outlet_id, item_code: payload.item_code, id: { [Op.ne]: id } } });
        if (codeConflict) {
            return res.status(400).json({
                success: false,
                message: `Item Code "${payload.item_code}" is already used by "${codeConflict.item_name} (${codeConflict.brand})". Please use a unique item code.`
            });
        }

        // Same item name + same brand = duplicate (excluding self)
        const nameBrandConflict = await (req as any).propertyDb.models.item_master.findOne({
            where: { outlet_id, item_name: payload.item_name, brand: payload.brand || '', id: { [Op.ne]: id } }
        });
        if (nameBrandConflict) {
            return res.status(400).json({
                success: false,
                message: `Item "${payload.item_name}" with Brand "${payload.brand}" already exists. Please use a different brand or a different item name.`
            });
        }

        await item.update(payload);

        // Explicit safeguard update for modifier and dietary columns
        await (req as any).propertyDb.query(`
            UPDATE item_master
            SET is_modifier = :is_modifier,
                applicable_item_ids = :applicable_item_ids,
                deduct_raw_item_id = :deduct_raw_item_id,
                deduct_qty = :deduct_qty,
                food_type = :food_type,
                dietary_type = :dietary_type,
                is_veg = :is_veg
            WHERE id = :id AND outlet_id = :outlet_id
        `, {
            replacements: {
                id: item.id,
                outlet_id,
                is_modifier: payload.is_modifier === true || payload.is_modifier === 'true' || payload.is_modifier === 1,
                applicable_item_ids: payload.applicable_item_ids ? String(payload.applicable_item_ids).trim() : null,
                deduct_raw_item_id: payload.deduct_raw_item_id ? Number(payload.deduct_raw_item_id) : null,
                deduct_qty: Number(payload.deduct_qty) || 0,
                food_type: payload.food_type || 'VEG',
                dietary_type: payload.dietary_type || payload.food_type || 'VEG',
                is_veg: payload.is_veg !== undefined ? Boolean(payload.is_veg) : (payload.food_type !== 'NON_VEG')
            }
        });

        await audit.log({
            req,
            module: 'ITEM_MASTER',
            action: 'UPDATE',
            table: 'item_master',
            recordId: item.id,
            oldData,
            newData: item.toJSON(),
            outlet_id: (req as any).user.outlet_id,
            user_id: (req as any).user.id
        });

        res.json({ success: true, data: item });

    } catch (err: any) {
        res.status(500).json({ success: false, error: err.message });
    }
};

export const deleteItem = async (req: Request, res: Response) => {
    try {
        const id = req.params.id;
        const outlet_id = (req as any).user.outlet_id;

        const item = await (req as any).propertyDb.models.item_master.findOne({
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
            oldData: { is_active: true },
            newData: { is_active: false },
            outlet_id: (req as any).user.outlet_id,
            user_id: (req as any).user.id
        });

        res.json({ success: true, message: 'Item deactivated' });

    } catch (err: any) {
        res.status(500).json({ success: false, error: err.message });
    }
};

export const openPackStock = async (req: Request, res: Response) => {
    const t = await (req as any).propertyDb.transaction();

    try {
        const outlet_id = (req as any).user.outlet_id;
        const itemId = Number(req.params.id ?? req.body.item_id);
        const packCount = Number(req.body.pack_count ?? 1);
        const note = String(req.body.note || '').trim() || null;

        if (!Number.isFinite(itemId) || itemId <= 0) {
            throw new Error('Valid item id is required');
        }
        if (!Number.isFinite(packCount) || packCount <= 0) {
            throw new Error('Pack count must be greater than 0');
        }

        const sourceItem = await (req as any).propertyDb.models.item_master.findOne({
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

        const targetItem = await (req as any).propertyDb.models.item_master.findOne({
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
            db: (req as any).propertyDb,
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
            db: (req as any).propertyDb,
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
            oldData: { source_item_code: sourceItem.item_code, loose_item_code: looseItemCode, pack_count: 0 },
            newData: { source_item_code: sourceItem.item_code, loose_item_code: looseItemCode, pack_count: packCount, loose_qty: openQty, note: remark },
            outlet_id,
            user_id: (req as any).user.id
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
    } catch (err: any) {
        await t.rollback();
        res.status(400).json({ success: false, error: err.message });
    }
};

export const generateBarcodes = async (req: Request, res: Response) => {
    const t = await (req as any).propertyDb.transaction();

    try {
        const outlet_id = (req as any).user.outlet_id;
        const selectedIds = Array.isArray(req.body.item_ids)
            ? req.body.item_ids
                .map((id: any) => parseInt(id, 10))
                .filter((id: any) => Number.isInteger(id) && id > 0)
            : [];
        const forceRegenerate = req.body.force_regenerate === true;

        const where: any = { outlet_id, is_active: true };
        if (selectedIds.length > 0) {
            where.id = { [Op.in]: selectedIds };
        }

        const items = await (req as any).propertyDb.models.item_master.findAll({
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
            data: items.map((item: any) => item.toJSON())
        });
    } catch (err: any) {
        await t.rollback();
        res.status(500).json({ success: false, error: err.message });
    }
};

export const getNextItemCode = async (req: Request, res: Response) => {
    try {
        const outlet_id = (req as any).user.outlet_id;

        const items = await (req as any).propertyDb.models.item_master.findAll({
            where: { outlet_id },
            attributes: ['item_code'],
            order: [['id', 'ASC']],
        });

        const usedCodes = new Set();
        let maxNum = 0;

        for (const row of items) {
            const code = String(row.item_code || '').trim();
            if (!code) continue;
            usedCodes.add(code.toUpperCase());

            const match = code.match(/(\d+)$/);
            if (match) {
                const num = parseInt(match[1], 10);
                if (Number.isFinite(num) && num > maxNum) {
                    maxNum = num;
                }
            }
        }

        let nextNum = maxNum + 1;
        let nextCode = `ITEM${nextNum}`;
        while (usedCodes.has(nextCode.toUpperCase())) {
            nextNum += 1;
            nextCode = `ITEM${nextNum}`;
        }

        res.json({
            success: true,
            data: nextCode,
        });

    } catch (err: any) {
        res.status(500).json({ success: false, error: err.message });
    }
};

export const uploadItemImage = async (req: Request, res: Response) => {
    try {
        const outlet_id = (req as any).user.outlet_id;
        const { id } = req.params;
        const item = await (req as any).propertyDb.models.item_master.findOne({
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
            oldData: { image_path: item.image_path || null },
            newData: { image_path: imagePath },
            outlet_id,
            user_id: (req as any).user.id
        });

        res.json({ success: true, data: { image_path: imagePath } });
    } catch (err: any) {
        res.status(500).json({ success: false, error: err.message });
    }
};

export const deleteItemImage = async (req: Request, res: Response) => {
    try {
        const outlet_id = (req as any).user.outlet_id;
        const { id } = req.params;
        const item = await (req as any).propertyDb.models.item_master.findOne({
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
            oldData: { image_path: oldImagePath },
            newData: { image_path: null },
            outlet_id,
            user_id: (req as any).user.id
        });

        res.json({ success: true, data: { image_path: null } });
    } catch (err: any) {
        res.status(500).json({ success: false, error: err.message });
    }
};

export const bulkUpdateLocation = async (req: Request, res: Response) => {
    try {
        const outlet_id = (req as any).user?.outlet_id || 1;
        const { item_ids, location } = req.body;

        if (!location || !String(location).trim()) {
            return res.status(400).json({ success: false, message: 'Stock Location is required' });
        }

        const targetLocation = String(location).trim();
        const whereClause: any = { outlet_id };

        if (Array.isArray(item_ids) && item_ids.length > 0) {
            whereClause.id = { [Op.in]: item_ids };
        }

        const ItemModel = (req as any).propertyDb.models.item_master || (req as any).propertyDb.models.items;
        const [affectedCount] = await ItemModel.update(
            { location: targetLocation },
            { where: whereClause }
        );

        await audit.log({
            req,
            module: 'ITEM_MASTER',
            action: 'BULK_UPDATE_LOCATION',
            table: 'items',
            recordId: 0,
            oldData: {},
            newData: { location: targetLocation, affectedCount },
            outlet_id,
            user_id: (req as any).user?.id || 1
        });

        return res.json({
            success: true,
            message: `Successfully updated location to "${targetLocation}" for ${affectedCount} item(s)`,
            data: { updatedCount: affectedCount, location: targetLocation }
        });
    } catch (e: any) {
        console.error('Error in bulkUpdateLocation:', e);
        return res.status(500).json({ success: false, message: e.message });
    }
};

const itemMasterController = {
    createItem,
    canImportItems,
    canResetAndImportItems,
    deleteAllItemsForFreshImport,
    bulkImportItems,
    getItems,
    getItemById,
    updateItem,
    deleteItem,
    openPackStock,
    generateBarcodes,
    getNextItemCode,
    uploadItemImage,
    deleteItemImage,
    bulkUpdateLocation
};

module.exports = itemMasterController;
export default itemMasterController;
