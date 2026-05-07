const audit = require('../../services/audit.service');

const TRANSACTION_TABLES = [
    'sales_items',
    'sales_headers',
    'customer_repayments',
    'customer_advances',
    'customer_item_advances',
    'sales_scheme_customers',
    'milk_subscriptions',
    'milk_subscription_schemes',
    'milk_subscription_consumptions',
    'milk_subscription_settlements',
    'customer_loyalty_ledger',
    'loyalty_master_config',
    'cash_ledger',
    'expense_entries',
    'daily_opening_balances',
    'stock_ledger',
    'goods_receipt_items',
    'goods_receipts',
    'purchase_order_items',
    'purchase_orders',
    'issue_items',
    'issue_headers',
    'damage_items',
    'damage_headers',
    'return_items',
    'return_headers',
    'supplier_return_items',
    'supplier_return_headers',
    'supplier_return_refunds',
    'supplier_bills',
    'supplier_payments',
    'request_items',
    'request_headers',
    'audit_logs',
    'cash_ledger',
    'expense_entries'
];

const PROTECTED_TABLES = new Set([
    'schema_version',
]);

const WIPE_TABLES = [...new Set(TRANSACTION_TABLES)].filter(
    (tableName) => !PROTECTED_TABLES.has(tableName)
);
exports.getSettings = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;

        const settings = await req.propertyDb.models.system_settings.findOne({
            where: { outlet_id }
        });

        // first time → defaults
        if (!settings) {
            return res.json({
                success: true,
                data: {
                    auto_reorder: true,
                    allow_negative_stock: false,
                    damage_approval_required: true,
                    enable_audit_log: true,
                    auto_print_on_save: false,
                    enable_item_images_in_sales: false,
                    print_mode: 'PRINT_DIALOG',
                    default_printer_name: '',
                    default_printer_url: '',
                    billing_country: 'India',
                    billing_tax_mode: 'CGST_SGST',
                    bill_format: 'A4',
                    default_charges: [],
                    voucher_rules: [],
                    is_cloud_enabled: false
                }
            });
        }

        res.json({ success: true, data: settings });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.saveSettings = async (req, res) => {
    const t = await req.propertyDb.transaction();

    try {
        const outlet_id = req.user.outlet_id;
        const user_id = req.user.id;

        const Model = req.propertyDb.models.system_settings;

        const existing = await Model.findOne({
            where: { outlet_id },
            transaction: t
        });

        const oldData = existing ? existing.toJSON() : null;

        const payload = {
            outlet_id,
            auto_reorder: req.body.auto_reorder,
            allow_negative_stock: req.body.allow_negative_stock,
            damage_approval_required: req.body.damage_approval_required,
            is_cloud_enabled: req.body.is_cloud_enabled,
            enable_audit_log: req.body.enable_audit_log,
            auto_print_on_save: req.body.auto_print_on_save,
            enable_item_images_in_sales: req.body.enable_item_images_in_sales,
            print_mode: req.body.print_mode || 'PRINT_DIALOG',
            default_printer_name: req.body.default_printer_name || '',
            default_printer_url: req.body.default_printer_url || '',
            billing_country: req.body.billing_country || 'India',
            billing_tax_mode: req.body.billing_tax_mode || 'CGST_SGST',
            bill_format: req.body.bill_format || 'A4',
            default_charges: Array.isArray(req.body.default_charges)
                ? req.body.default_charges
                : [],
            voucher_rules: Array.isArray(req.body.voucher_rules)
                ? req.body.voucher_rules
                : (existing?.voucher_rules || [])
        };

        let record;
        if (existing) {
            record = await existing.update(payload, { transaction: t });
        } else {
            record = await Model.create(payload, { transaction: t });
        }

        await audit.log({
            req,
            module: 'SYSTEM_SETTINGS',
            action: existing ? 'UPDATE' : 'CREATE',
            table: 'system_settings',
            recordId: record.id,
            oldData,
            newData: record.toJSON(),
            outlet_id: req.user.outlet_id,
            user_id: req.user.id
        });


        await t.commit();
        res.json({ success: true, message: 'Settings saved successfully' });

    } catch (err) {
        await t.rollback();
        res.status(500).json({ success: false, error: err.message });
    }
};

exports.clearTransactionData = async (req, res) => {
    const t = await req.propertyDb.transaction();

    try {
        const confirmText = String(req.body.confirm_text || '').trim().toUpperCase();
        if (confirmText !== 'DELETE ALL DATA') {
            throw new Error('Type DELETE ALL DATA to confirm the wipe');
        }

        const existingTablesResult = await req.propertyDb.query(`
            SELECT tablename
            FROM pg_tables
            WHERE schemaname = 'public'
              AND tablename IN (:tables)
        `, {
            replacements: { tables: WIPE_TABLES },
            transaction: t
        });

        const existingTables = Array.isArray(existingTablesResult) ? existingTablesResult[0] : existingTablesResult;
        const tableNames = (existingTables || [])
            .map((row) => row.tablename)
            .filter(Boolean);

        if (tableNames.length > 0) {
            const quotedNames = tableNames.map((name) => `"${name}"`).join(', ');
            await req.propertyDb.query(
                `TRUNCATE TABLE ${quotedNames} RESTART IDENTITY CASCADE`,
                { transaction: t }
            );
        }

        await t.commit();
        res.json({
            success: true,
            message: 'Transaction data cleared successfully',
            preserved: ['masters', 'system_settings', 'schema_version']
        });
    } catch (err) {
        await t.rollback();
        res.status(500).json({ success: false, error: err.message });
    }
};
