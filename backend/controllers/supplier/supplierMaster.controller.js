const audit = require('../../services/audit.service');

const { Op } = require('sequelize');

function mapVendorPayload(body = {}) {
    const supplier_name = String(
        body.supplier_name ?? body.vendor_name ?? ''
    ).trim();
    const address = String(body.address ?? '').trim();

    return {
        supplier_code: String(body.supplier_code ?? '').trim(),
        supplier_name,
        address,
        phone: String(body.phone ?? '').trim(),
        state: String(body.state ?? '').trim() || null,
        gstin: String(body.gstin ?? body.tax_id_number ?? '')
            .trim()
            .toUpperCase() || null,
        tax_country_code: String(body.tax_country_code ?? 'IN').trim() || null
    };
}

function normalizeSupplierPayload(body = {}) {
    return {
        supplier_code: String(body.supplier_code || body.vendor_code || '').trim(),
        supplier_name: String(body.supplier_name || body.vendor_name || '').trim(),
        address: String(body.address || '').trim(),
        phone: String(body.phone || '').trim(),
        state: String(body.state || '').trim() || null,
        gstin: String(body.gstin || body.tax_id_number || '').trim().toUpperCase() || null,
        tax_id_number: String(body.tax_id_number || body.gstin || '').trim().toUpperCase() || null,
        tax_id_type: String(body.tax_id_type || '').trim().toUpperCase() || null,
        tax_country_code: String(body.tax_country_code || 'IN').trim().toUpperCase() || null
    };
}

exports.createSupplier = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const user_id = req.user.id;

        const payload = normalizeSupplierPayload(req.body);

        if (!payload.supplier_name) {
            return res.status(400).json({ success: false, message: 'Vendor name is required' });
        }

        if (!payload.address) {
            return res.status(400).json({ success: false, message: 'Address is required' });
        }

        const supplier = await req.propertyDb.models.supplier_master.create({
            outlet_id,
            supplier_code: payload.supplier_code,
            supplier_name: payload.supplier_name,
            address: payload.address,
            phone: payload.phone,
            state: payload.state,
            gstin: payload.gstin,
            tax_id_number: payload.tax_id_number,
            tax_id_type: payload.tax_id_type,
            tax_country_code: payload.tax_country_code,
            is_active: true
        });


        await audit.log({
            req,
            module: 'SUPPLIER_MASTER',
            action: 'CREATE',
            table: 'supplier_master',
            recordId: supplier.id,
            old_data: null,
            new_data: supplier.toJSON(),
            outlet_id,
            user_id
        });

        res.json({ success: true, data: supplier });

    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.canImportSuppliers = async (req, res) => {
    const outlet_id = req.user.outlet_id;

    const count = await req.propertyDb.models.supplier_master.count({
        where: { outlet_id }
    });

    res.json({
        success: true,
        canImport: count === 0
    });
};

exports.bulkImportSuppliers = async (req, res) => {
    const t = await req.propertyDb.transaction();

    try {
        const outlet_id = req.user.outlet_id;
        const user_id = req.user.id;
        const suppliers = req.body;

        const count = await req.propertyDb.models.supplier_master.count({
            where: { outlet_id }
        });

        if (count > 0) {
            return res.status(400).json({
                success: false,
                message: 'Import allowed only on first setup'
            });
        }
        const formatted = suppliers.map(row => ({
            outlet_id,
            supplier_code: normalizeSupplierPayload(row).supplier_code,
            supplier_name: normalizeSupplierPayload(row).supplier_name,
            address: normalizeSupplierPayload(row).address,
            phone: normalizeSupplierPayload(row).phone,
            state: normalizeSupplierPayload(row).state,
            gstin: normalizeSupplierPayload(row).gstin,
            tax_id_number: normalizeSupplierPayload(row).tax_id_number,
            tax_id_type: normalizeSupplierPayload(row).tax_id_type,
            tax_country_code: normalizeSupplierPayload(row).tax_country_code,
            is_active: true
        }));


        await req.propertyDb.models.supplier_master.bulkCreate(formatted, {
            transaction: t
        });

        await audit.log({
            req,
            module: 'SUPPLIER_MASTER',
            action: 'BULK_IMPORT',
            table: 'supplier_master',
            recordId: null,
            old_data: null,
            new_data: { count: formatted.length },
            outlet_id,
            user_id
        });

        await t.commit();

        res.json({
            success: true,
            message: 'Suppliers imported successfully'
        });

    } catch (err) {
        await t.rollback();
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.getSuppliers = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { q } = req.query;

        const where = {
            outlet_id,
            is_active: true
        };

        if (q && q.trim() !== '') {
            const search = q.trim();

            where[Op.or] = [
                { supplier_code: { [Op.iLike]: `%${search}%` } },
                { supplier_name: { [Op.iLike]: `%${search}%` } },
                { phone: { [Op.iLike]: `%${search}%` } }
            ];
        }

        const suppliers = await req.propertyDb.models.supplier_master.findAll({
            where,
            order: [['supplier_name', 'ASC']]
        });

        res.json({ success: true, data: suppliers });

    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.updateSupplier = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const user_id = req.user.id;
        const id = req.params.id;

        const supplier = await req.propertyDb.models.supplier_master.findOne({
            where: { id, outlet_id }
        });

        if (!supplier) {
            return res.status(404).json({ success: false });
        }

        const oldData = supplier.toJSON();

        const payload = normalizeSupplierPayload({
            ...supplier.toJSON(),
            ...req.body
        });

        if (!payload.supplier_name) {
            return res.status(400).json({ success: false, message: 'Vendor name is required' });
        }

        if (!payload.address) {
            return res.status(400).json({ success: false, message: 'Address is required' });
        }

        await supplier.update({
            supplier_code: payload.supplier_code,
            supplier_name: payload.supplier_name,
            address: payload.address,
            phone: payload.phone,
            state: payload.state,
            gstin: payload.gstin,
            tax_id_number: payload.tax_id_number,
            tax_id_type: payload.tax_id_type,
            tax_country_code: payload.tax_country_code
        });

        await audit.log({
            req,
            module: 'SUPPLIER_MASTER',
            action: 'UPDATE',
            table: 'supplier_master',
            recordId: supplier.id,
            old_data: oldData,
            new_data: supplier.toJSON(),
            outlet_id: req.user.outlet_id,
            user_id: req.user.id
        });


        res.json({ success: true, data: supplier });

    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.deleteSupplier = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const user_id = req.user.id;
        const id = req.params.id;

        const supplier = await req.propertyDb.models.supplier_master.findOne({
            where: { id, outlet_id }
        });

        if (!supplier) {
            return res.status(404).json({ success: false });
        }

        await supplier.update({ is_active: false });



        await audit.log({
            req,
            module: 'SUPPLIER_MASTER',
            action: 'DEACTIVATE',
            entity: 'supplier_master',
            recordId: supplier.id,
            old_data: { is_active: true },
            new_data: { is_active: false },
            outlet_id: req.user.outlet_id,
            user_id: req.user.id
        });

        res.json({ success: true, message: 'Supplier deactivated' });

    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};


exports.getNextSupplierCode = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;

        const last = await req.propertyDb.models.supplier_master.findOne({
            where: { outlet_id },
            order: [['id', 'DESC']],
            attributes: ['supplier_code'],
        });

        let nextNum = 1;

        if (last?.supplier_code) {
            const num = parseInt(last.supplier_code.replace(/[^\d]/g, '')) || 0;
            nextNum = num + 1;
        }

        res.json({
            success: true,
            data: `sup${nextNum}`,
        });

    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};
