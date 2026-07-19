const audit = require('../../services/audit.service');

const TRANSACTION_TABLES = [
    // Lucky Draw Campaign tables (dependent children first)
    'draw_vouchers',
    'customer_draw_progress',
    'lucky_draw_campaigns',

    // 1. Supplier Return tables (dependent children first)
    'supplier_return_refunds',
    'supplier_return_items',
    'supplier_return_headers',

    // 2. Goods Receipt tables (dependent children first)
    'goods_receipt_items',
    'goods_receipts',

    // 3. Supplier Payments & Bills
    'supplier_payments',
    'supplier_bills',

    // 4. Purchase Orders
    'purchase_order_items',
    'purchase_orders',

    // 5. Return Headers & Items (reference issue_headers)
    'return_items',
    'return_headers',

    // 6. Issue Headers & Items
    'issue_items',
    'issue_headers',

    // 7. Damage Headers & Items
    'damage_items',
    'damage_headers',

    // 8. Assembly Headers & Items
    'assembly_items',
    'assembly_headers',

    // 9. Request Headers & Items
    'request_items',
    'request_headers',

    // 10. Milk Subscription tables
    'milk_subscription_consumptions',
    'milk_subscription_settlements',
    'milk_subscription_schemes',
    'milk_subscriptions',

    // 11. Sales & Customer Advances tables
    'sales_items',
    'customer_repayments',
    'customer_advances',
    'customer_item_advances',
    'sales_refunds',
    'sales_credit_notes',
    'customer_orders',
    'sales_headers',

    // 12. Miscellaneous/Independent tables
    'sales_scheme_customers',
    'customer_loyalty_ledger',
    'loyalty_master_config',
    'cash_ledger',
    'expense_entries',
    'daily_opening_balances',
    'stock_ledger',
    'system_notifications',
    'audit_logs'
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

        let settings = null;
        try {
            settings = await req.propertyDb.models.system_settings.findOne({
                where: { outlet_id }
            });
        } catch (dbErr) {
            console.warn("⚠️ System settings query failed in getSettings, trying fallback without merchant_upi_id:", dbErr.message);
            try {
                const attributes = Object.keys(req.propertyDb.models.system_settings.rawAttributes).filter(
                    attr => attr !== 'merchant_upi_id'
                );
                settings = await req.propertyDb.models.system_settings.findOne({
                    where: { outlet_id },
                    attributes: attributes
                });
            } catch (fallbackErr) {
                console.error("❌ Fallback query in getSettings failed:", fallbackErr.stack);
            }
        }

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
                    is_cloud_enabled: false,
                    enable_app_subscription: false,
                    enable_payment_gateway: false,
                    payment_gateway_provider: 'SANDBOX',
                    payment_gateway_api_key: '',
                    payment_gateway_secret_key: '',
                    merchant_upi_id: '',
                    sub_delivery_charge_enabled: false,
                    sub_delivery_charge_name: 'Subscription Delivery',
                    sub_delivery_charge_amount: 0.0,
                    sub_delivery_charge_type: 'FLAT',
                    sub_delivery_charge_gst_percent: 0.0,
                    sub_delivery_free_above: 0.0
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
            enable_app_subscription: req.body.enable_app_subscription ?? false,
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
                : (existing?.voucher_rules || []),
            enable_payment_gateway: req.body.enable_payment_gateway ?? false,
            payment_gateway_provider: req.body.payment_gateway_provider || 'SANDBOX',
            payment_gateway_api_key: req.body.payment_gateway_api_key || '',
            payment_gateway_secret_key: req.body.payment_gateway_secret_key || '',
            merchant_upi_id: req.body.merchant_upi_id || '',
            sub_delivery_charge_enabled: req.body.sub_delivery_charge_enabled ?? false,
            sub_delivery_charge_name: req.body.sub_delivery_charge_name || 'Subscription Delivery',
            sub_delivery_charge_amount: req.body.sub_delivery_charge_amount ?? 0.0,
            sub_delivery_charge_type: req.body.sub_delivery_charge_type || 'FLAT',
            sub_delivery_charge_gst_percent: req.body.sub_delivery_charge_gst_percent ?? 0.0,
            sub_delivery_free_above: req.body.sub_delivery_free_above ?? 0.0
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

        // Sort tableNames according to defined order in WIPE_TABLES to respect foreign key constraints
        tableNames.sort((a, b) => {
            return WIPE_TABLES.indexOf(a) - WIPE_TABLES.indexOf(b);
        });

        const headerModel = req.propertyDb.models.sales_headers;
        const columns = headerModel?.rawAttributes || {};
        const hasColumn = (name) => Object.prototype.hasOwnProperty.call(columns, name);

        // Preserve customer master rows that are stored in sales_headers as status='CUSTOMER'.
        const backupSelectColumns = [
            'customer_name',
            'customer_phone',
            'customer_address',
            'customer_gstin',
            ...(hasColumn('created_by') ? ['created_by'] : []),
            ...(hasColumn('updated_by') ? ['updated_by'] : [])
        ];

        const preservedCustomerRowsResult = await req.propertyDb.query(
            `
SELECT ${backupSelectColumns.join(', ')}
FROM sales_headers
WHERE outlet_id = :outlet_id
  AND status = 'CUSTOMER'
  AND is_latest = TRUE
  AND is_deleted = FALSE
            `,
            {
                replacements: { outlet_id: req.user.outlet_id },
                transaction: t
            }
        );
        const preservedCustomerRows = Array.isArray(preservedCustomerRowsResult)
            ? (preservedCustomerRowsResult[0] || [])
            : [];

        // IMPORTANT:
        // Never TRUNCATE here. TRUNCATE would remove data of all outlets.
        // Delete only rows belonging to the current outlet.
        for (const tableName of tableNames) {
            const columnCheckResult = await req.propertyDb.query(
                `
SELECT 1
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = :tableName
  AND column_name = 'outlet_id'
LIMIT 1
                `,
                {
                    replacements: { tableName },
                    transaction: t
                }
            );
            const hasOutletId = Array.isArray(columnCheckResult)
                ? (columnCheckResult[0] || []).length > 0
                : false;

            if (!hasOutletId) {
                continue;
            }

            await req.propertyDb.query(
                `DELETE FROM "${tableName}" WHERE outlet_id = :outlet_id`,
                {
                    replacements: { outlet_id: req.user.outlet_id },
                    transaction: t
                }
            );
        }

        // Restore preserved customer master rows after transaction wipe.
        for (const row of preservedCustomerRows) {
            const payload = {
                outlet_id: req.user.outlet_id,
                sale_no: `CUST-${Date.now()}-${Math.floor(Math.random() * 100000)}`,
                sale_date: new Date(),
                customer_name: row.customer_name || null,
                customer_phone: row.customer_phone || null,
                customer_address: row.customer_address || null,
                customer_gstin: row.customer_gstin || null,
                payment_mode: 'CASH',
                payment_reference: null,
                initial_amount_paid: 0,
                amount_paid: 0,
                change_amount: 0,
                balance_due: 0,
                order_type: 'B2C',
                billing_country: 'India',
                billing_tax_mode: 'CGST_SGST',
                bill_format: 'A4',
                tax_percent: 0,
                scheme_id: null,
                scheme_name: null,
                scheme_discount: 0,
                manual_discount_type: null,
                manual_discount_value: 0,
                manual_discount_amount: 0,
                total_qty: 0,
                sub_total: 0,
                taxable_amount: 0,
                cgst_amount: 0,
                sgst_amount: 0,
                igst_amount: 0,
                total_tax: 0,
                tax_breakup: [],
                charges: [],
                charge_total: 0,
                charge_tax_total: 0,
                total_discount: 0,
                round_off_amount: 0,
                net_amount: 0,
                voucher_code: null,
                voucher_label: null,
                notes: 'Customer master preserved during transaction reset',
                status: 'CUSTOMER',
                original_sale_id: null,
                previous_sale_id: null,
                replaced_by_sale_id: null,
                version_no: 1,
                is_latest: true,
                is_deleted: false
            };

            if (hasColumn('created_by')) {
                payload.created_by = row.created_by || req.user.id;
            }
            if (hasColumn('updated_by')) {
                payload.updated_by = row.updated_by || req.user.id;
            }

            await headerModel.create(payload, { transaction: t });
        }

        await t.commit();
        res.json({
            success: true,
            message: 'Transaction data cleared successfully',
            preserved: ['masters', 'customer_master', 'system_settings', 'schema_version']
        });
    } catch (err) {
        await t.rollback();
        res.status(500).json({ success: false, error: err.message });
    }
};
