const audit = require('../../services/audit.service');
const { Op } = require('sequelize');

function mapVendorPayload(body: any = {}) {
    const supplier_name = String(
        body.supplier_name ?? body.vendor_name ?? ''
    ).trim();
    const address = String(body.address ?? '').trim();

    return {
        supplier_code: String(body.supplier_code ?? '').trim(),
        supplier_name,
        address,
        phone: String(body.phone ?? '').trim(),
        email: String(body.email ?? '').trim() || null,
        state: String(body.state ?? '').trim() || null,
        gstin: String(body.gstin ?? body.tax_id_number ?? '')
            .trim()
            .toUpperCase() || null,
        tax_country_code: String(body.tax_country_code ?? 'IN').trim() || null
    };
}

function normalizeSupplierPayload(body: any = {}) {
    const rawOpening = body.opening_balance !== undefined && body.opening_balance !== null
        ? parseFloat(body.opening_balance)
        : 0.00;
    return {
        supplier_code: String(body.supplier_code || body.vendor_code || '').trim(),
        supplier_name: String(body.supplier_name || body.vendor_name || '').trim(),
        address: String(body.address || '').trim(),
        phone: String(body.phone || '').trim(),
        email: String(body.email || '').trim() || null,
        state: String(body.state || '').trim() || null,
        gstin: String(body.gstin || body.tax_id_number || '').trim().toUpperCase() || null,
        tax_id_number: String(body.tax_id_number || body.gstin || '').trim().toUpperCase() || null,
        tax_id_type: String(body.tax_id_type || '').trim().toUpperCase() || null,
        tax_country_code: String(body.tax_country_code || 'IN').trim().toUpperCase() || null,
        opening_balance: isNaN(rawOpening) ? 0.00 : rawOpening,
        as_of_date: body.as_of_date || null
    };
}

exports.createSupplier = async (req: any, res: any) => {
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
            email: payload.email,
            state: payload.state,
            gstin: payload.gstin,
            tax_id_number: payload.tax_id_number,
            tax_id_type: payload.tax_id_type,
            tax_country_code: payload.tax_country_code,
            opening_balance: payload.opening_balance,
            is_active: true
        });

        // If an opening balance is specified (> 0), create opening bill and reflect in Chart of Accounts
        if (payload.opening_balance > 0) {
            try {
                if (req.propertyDb.models.supplier_bills) {
                    await req.propertyDb.models.supplier_bills.create({
                        outlet_id,
                        supplier_id: supplier.id,
                        bill_no: `OPN-${supplier.supplier_code || supplier.id}`,
                        bill_date: payload.as_of_date || new Date(),
                        bill_amount: payload.opening_balance,
                        paid_amount: 0.00,
                        status: 'UNPAID',
                        remarks: 'Opening Balance on Vendor Creation'
                    });
                }

                if (req.propertyDb.models.chart_of_accounts) {
                    // Credit Sundry Creditors (Account 2001)
                    const creditorAcc = await req.propertyDb.models.chart_of_accounts.findOne({
                        where: { outlet_id, account_code: '2001' }
                    });
                    if (creditorAcc) {
                        await creditorAcc.increment('opening_credit', { by: payload.opening_balance });
                        await creditorAcc.increment('current_balance', { by: payload.opening_balance });
                    }

                    // Debit Opening Balance Equity / Capital (Account 3001 or 3100)
                    const equityAcc = await req.propertyDb.models.chart_of_accounts.findOne({
                        where: {
                            outlet_id,
                            account_code: { [Op.in]: ['3001', '3100', '1200'] }
                        }
                    });
                    if (equityAcc) {
                        await equityAcc.increment('opening_debit', { by: payload.opening_balance });
                    }
                }
            } catch (coaErr: any) {
                console.warn('[COA OPENING BALANCE POST WARN]', coaErr.message);
            }
        }

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

    } catch (err: any) {
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.canImportSuppliers = async (req: any, res: any) => {
    const outlet_id = req.user.outlet_id;

    const count = await req.propertyDb.models.supplier_master.count({
        where: { outlet_id }
    });

    res.json({
        success: true,
        canImport: count === 0
    });
};

exports.bulkImportSuppliers = async (req: any, res: any) => {
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
        const formatted = suppliers.map((row: any) => ({
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

    } catch (err: any) {
        await t.rollback();
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.getSuppliers = async (req: any, res: any) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { q, activeOnly, active_only, all } = req.query;

        const where: any = {
            outlet_id
        };

        const fetchAll = all === 'true' || all === true || activeOnly === 'false' || activeOnly === false || active_only === 'false' || active_only === false;
        if (!fetchAll) {
            where.is_active = true;
        }

        if (q && q.trim() !== '') {
            const search = q.trim();
            const digits = search.replace(/[^\d]/g, '');
            const parsedNum = digits ? parseInt(digits, 10) : null;

            const searchConditions: any[] = [
                { supplier_code: { [Op.iLike]: `%${search}%` } },
                { supplier_name: { [Op.iLike]: `%${search}%` } },
                { phone: { [Op.iLike]: `%${search}%` } },
                { gstin: { [Op.iLike]: `%${search}%` } }
            ];

            if (parsedNum !== null) {
                searchConditions.push({ supplier_code: { [Op.iLike]: `%${parsedNum}%` } });
                searchConditions.push({ supplier_code: { [Op.iLike]: `%sup${parsedNum}%` } });
            }

            where[Op.or] = searchConditions;
        }

        const suppliers = await req.propertyDb.models.supplier_master.findAll({
            where,
            order: [['id', 'DESC']]
        });

        res.json({ success: true, data: suppliers });

    } catch (err: any) {
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.updateSupplier = async (req: any, res: any) => {
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

        const isActiveVal = req.body.is_active !== undefined ? (req.body.is_active === true || req.body.is_active === 'true') : supplier.is_active;

        await supplier.update({
            supplier_code: payload.supplier_code,
            supplier_name: payload.supplier_name,
            address: payload.address,
            phone: payload.phone,
            email: payload.email,
            state: payload.state,
            gstin: payload.gstin,
            tax_id_number: payload.tax_id_number,
            tax_id_type: payload.tax_id_type,
            tax_country_code: payload.tax_country_code,
            is_active: isActiveVal
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

    } catch (err: any) {
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.toggleSupplierStatus = async (req: any, res: any) => {
    try {
        const outlet_id = req.user.outlet_id;
        const id = req.params.id;

        const supplier = await req.propertyDb.models.supplier_master.findOne({
            where: { id, outlet_id }
        });

        if (!supplier) {
            return res.status(404).json({ success: false, message: 'Supplier not found' });
        }

        const newStatus = !supplier.is_active;
        await supplier.update({ is_active: newStatus });

        await audit.log({
            req,
            module: 'SUPPLIER_MASTER',
            action: newStatus ? 'ACTIVATE' : 'DEACTIVATE',
            table: 'supplier_master',
            recordId: supplier.id,
            old_data: { is_active: !newStatus },
            new_data: { is_active: newStatus },
            outlet_id,
            user_id: req.user.id
        });

        res.json({ success: true, data: supplier, message: `Supplier status changed to ${newStatus ? 'Active' : 'Inactive'}` });

    } catch (err: any) {
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.deleteSupplier = async (req: any, res: any) => {
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

    } catch (err: any) {
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.getNextSupplierCode = async (req: any, res: any) => {
    try {
        const outlet_id = req.user.outlet_id;

        const suppliers = await req.propertyDb.models.supplier_master.findAll({
            where: { outlet_id },
            attributes: ['supplier_code']
        });

        const usedCodes = new Set();
        let maxNum = 0;

        for (const row of suppliers) {
            const code = String(row.supplier_code || '').trim();
            if (!code) continue;
            usedCodes.add(code.toUpperCase());

            const match = code.match(/(\d+)$/);
            if (match) {
                const num = parseInt(match[1], 10);
                if (Number.isFinite(num) && num > maxNum) {
                    maxNum = num;
                }
            } else {
                const digits = parseInt(code.replace(/[^\d]/g, '')) || 0;
                if (digits > maxNum) {
                    maxNum = digits;
                }
            }
        }

        let nextNum = maxNum + 1;
        let nextCode = `sup${nextNum}`;
        while (usedCodes.has(nextCode.toUpperCase())) {
            nextNum += 1;
            nextCode = `sup${nextNum}`;
        }

        res.json({
            success: true,
            data: nextCode,
        });

    } catch (err: any) {
        res.status(500).json({ success: false, error: err.message });
    }
};

module.exports = exports;
export default exports;
