const audit = require('../../services/audit.service');
const fs = require('fs');
const path = require('path');
const { Op } = require('sequelize');

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

        const [receiptCount, requestCount, issueCount] = await Promise.all([
            req.propertyDb.models.goods_receipts.count({ where: { outlet_id } }),
            req.propertyDb.models.request_headers.count({ where: { outlet_id } }),
            req.propertyDb.models.issue_headers.count({ where: { outlet_id } })
        ]);

        const totalRecords = receiptCount + requestCount + issueCount;
        res.json({
            success: true,
            canImport: totalRecords === 0
        });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};


exports.bulkImportItems = async (req, res) => {
    const t = await req.propertyDb.transaction();

    try {
        const outlet_id = req.user.outlet_id;
        const items = req.body;

        const [receiptCount, requestCount, issueCount] = await Promise.all([
            req.propertyDb.models.goods_receipts.count({ where: { outlet_id } }),
            req.propertyDb.models.request_headers.count({ where: { outlet_id } }),
            req.propertyDb.models.issue_headers.count({ where: { outlet_id } })
        ]);

        const totalRecords = receiptCount + requestCount + issueCount;

        if (totalRecords > 0) {
            return res.status(400).json({
                success: false,
                message: 'Import allowed only on first setup'
            });
        }

        for (const row of items) {
            await ensureMasterData(req, { outlet_id, row, transaction: t });

            await req.propertyDb.models.item_master.create({
                outlet_id,
                item_code: row.item_code,
                item_code: row.item_code,
                item_name: row.item_name,
                hsn_sac_code: row.hsn_sac_code || null,
                item_group: row.item_group,
                sub_category: row.sub_category,
                brand: row.brand,
                unit: row.unit,
                barcode: row.barcode || null,
                image_path: row.image_path || null,
                rate: parseFloat(row.rate) || 0,
                retail_sale_price: parseFloat(row.retail_sale_price) || 0,
                tax_type: row.tax_type || 'GST',
                tax_percent: parseFloat(row.tax_percent) || 0,
                discount_applicable: row.discount_applicable !== false && row.discount_applicable !== 'NO',
                scheme_applicable: row.scheme_applicable !== false && row.scheme_applicable !== 'NO',
                opening_balance: parseFloat(row.opening_balance) || 0,
                min_level: parseInt(row.min_level) || 0,
                max_level: parseInt(row.max_level) || 0,
                stockable: row.stockable === true || row.stockable === 'YES',
                is_active: true
            }, { transaction: t });
        }

        await t.commit();

        res.json({ success: true, message: 'Items imported successfully' });

    } catch (err) {
        await t.rollback();
        res.status(500).json({ success: false, error: err.message });
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
