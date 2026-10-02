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
        email: String(body.email ?? '').trim() || null,
        state: String(body.state ?? '').trim() || null,
        gstin: String(body.gstin ?? body.tax_id_number ?? '')
            .trim()
            .toUpperCase() || null,
        tax_country_code: String(body.tax_country_code ?? 'IN').trim() || null
    };
}

function normalizeSupplierPayload(body = {}) {
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

async function syncVendorToCoa(req, outlet_id, supplier, newOpening, oldOpening = 0, asOfDate = null) {
    if (!req.propertyDb || !req.propertyDb.models) return;

    const diff = Number((newOpening - oldOpening).toFixed(2));

    // 1. Manage supplier_bills (Opening Bill)
    if (req.propertyDb.models.supplier_bills) {
        try {
            const billNo = `OPN-${supplier.supplier_code || supplier.id}`;
            const existingBill = await req.propertyDb.models.supplier_bills.findOne({
                where: { outlet_id, supplier_id: supplier.id, bill_no: billNo }
            });

            if (newOpening > 0) {
                if (existingBill) {
                    const paid = Number(existingBill.paid_amount || 0);
                    const newStatus = paid >= newOpening ? 'PAID' : (paid > 0 ? 'PARTIAL' : 'UNPAID');
                    await existingBill.update({
                        bill_amount: newOpening,
                        status: newStatus,
                        bill_date: asOfDate || existingBill.bill_date || new Date()
                    });
                } else {
                    await req.propertyDb.models.supplier_bills.create({
                        outlet_id,
                        supplier_id: supplier.id,
                        bill_no: billNo,
                        bill_date: asOfDate || new Date(),
                        bill_amount: newOpening,
                        paid_amount: 0.00,
                        status: 'UNPAID',
                        remarks: 'Opening Balance on Vendor Creation'
                    });
                }
            } else if (existingBill && newOpening <= 0) {
                if (Number(existingBill.paid_amount || 0) === 0) {
                    await existingBill.destroy();
                } else {
                    await existingBill.update({ bill_amount: 0, status: 'PAID' });
                }
            }
        } catch (billErr) {
            console.warn('[SUPPLIER BILL SYNC WARN]', billErr.message);
        }
    }

    // 2. Manage Chart of Accounts
    if (req.propertyDb.models.chart_of_accounts) {
        try {
            // Check if default accounts exist; if none, auto-seed
            const totalCoaCount = await req.propertyDb.models.chart_of_accounts.count({ where: { outlet_id } });
            if (totalCoaCount === 0) {
                const DEFAULT_COA_SEEDS = [
                    { account_code: '1001', account_name: 'Main Cash Drawer', group_name: 'Current Assets', nature: 'ASSET', is_system: true },
                    { account_code: '1100', account_name: 'Sundry Debtors (Customer Receivables)', group_name: 'Current Assets', nature: 'ASSET', is_system: true },
                    { account_code: '1200', account_name: 'Closing Stock (Inventory Asset)', group_name: 'Stock / Inventory', nature: 'ASSET', is_system: true },
                    { account_code: '2001', account_name: 'Sundry Creditors (Vendor Payables)', group_name: 'Current Liabilities', nature: 'LIABILITY', is_system: true },
                    { account_code: '3001', account_name: 'Proprietor / Owner Capital', group_name: 'Capital Account', nature: 'EQUITY', is_system: true },
                    { account_code: '3100', account_name: 'Retained Earnings', group_name: 'Retained Earnings', nature: 'EQUITY', is_system: true },
                    { account_code: '4001', account_name: 'Retail Sales Revenue', group_name: 'Sales Income', nature: 'REVENUE', is_system: true },
                    { account_code: '5001', account_name: 'Purchases (Cost of Goods Sold)', group_name: 'Direct Expenses', nature: 'EXPENSE', is_system: true },
                ];
                const seeds = DEFAULT_COA_SEEDS.map(s => ({
                    ...s,
                    outlet_id,
                    opening_debit: 0.00,
                    opening_credit: 0.00,
                    current_balance: 0.00,
                    is_active: true
                }));
                await req.propertyDb.models.chart_of_accounts.bulkCreate(seeds);
            }

            // Vendor Sub-Account
            const vendorAccCode = `2001-${supplier.supplier_code || supplier.id}`;
            let vendorAcc = await req.propertyDb.models.chart_of_accounts.findOne({
                where: { outlet_id, account_code: vendorAccCode }
            });

            if (vendorAcc) {
                await vendorAcc.update({
                    account_name: `${supplier.supplier_name} (Vendor)`,
                    opening_credit: newOpening,
                    current_balance: Number((Number(vendorAcc.current_balance || 0) + diff).toFixed(2))
                });
            } else if (newOpening > 0) {
                await req.propertyDb.models.chart_of_accounts.create({
                    outlet_id,
                    account_code: vendorAccCode,
                    account_name: `${supplier.supplier_name} (Vendor)`,
                    group_name: 'Sundry Creditors',
                    nature: 'LIABILITY',
                    opening_debit: 0.00,
                    opening_credit: newOpening,
                    current_balance: newOpening,
                    is_system: false,
                    is_active: true
                });
            }

            if (diff !== 0) {
                // Update Master Sundry Creditors (Account 2001)
                const creditorAcc = await req.propertyDb.models.chart_of_accounts.findOne({
                    where: { outlet_id, account_code: '2001' }
                });
                if (creditorAcc) {
                    const newOpeningCredit = Math.max(0, Number((Number(creditorAcc.opening_credit || 0) + diff).toFixed(2)));
                    const newCurrentBalance = Math.max(0, Number((Number(creditorAcc.current_balance || 0) + diff).toFixed(2)));
                    await creditorAcc.update({
                        opening_credit: newOpeningCredit,
                        current_balance: newCurrentBalance
                    });
                }

                // Balance Equity: Account 3001 (Proprietor Capital) / 3100
                const equityAcc = await req.propertyDb.models.chart_of_accounts.findOne({
                    where: {
                        outlet_id,
                        account_code: { [Op.in]: ['3001', '3100'] }
                    }
                });
                if (equityAcc) {
                    const newOpeningDebit = Math.max(0, Number((Number(equityAcc.opening_debit || 0) + diff).toFixed(2)));
                    await equityAcc.update({
                        opening_debit: newOpeningDebit
                    });
                }
            }
        } catch (coaErr) {
            console.warn('[COA SYNC WARN]', coaErr.message);
        }
    }
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
            email: payload.email,
            state: payload.state,
            gstin: payload.gstin,
            tax_id_number: payload.tax_id_number,
            tax_id_type: payload.tax_id_type,
            tax_country_code: payload.tax_country_code,
            opening_balance: payload.opening_balance,
            is_active: true
        });

        // Sync opening balance to supplier_bills and Chart of Accounts
        if (payload.opening_balance > 0) {
            await syncVendorToCoa(req, outlet_id, supplier, payload.opening_balance, 0, payload.as_of_date);
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
        const { q, activeOnly, active_only, all } = req.query;

        const where = {
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

            const searchConditions = [
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

        const isActiveVal = req.body.is_active !== undefined ? (req.body.is_active === true || req.body.is_active === 'true') : supplier.is_active;

        const oldOpening = parseFloat(oldData.opening_balance || 0) || 0;
        const newOpening = payload.opening_balance;

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
            opening_balance: payload.opening_balance,
            is_active: isActiveVal
        });

        // Sync opening balance changes to supplier_bills and Chart of Accounts
        await syncVendorToCoa(req, outlet_id, supplier, newOpening, oldOpening, payload.as_of_date);

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

exports.toggleSupplierStatus = async (req, res) => {
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

    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};
