const audit = require('../../services/audit.service');

const TRANSACTION_TABLES = [
    // KOT & Restaurant transactional tables (dependent children first)
    'kot_revisions',
    'kot_items',
    'kot_headers',
    'restaurant_audit_trail',
    'table_reservations',

    // Lucky Draw Campaign tables (dependent children first)
    'draw_vouchers',
    'customer_draw_progress',
    'lucky_draw_campaigns',

    // WhatsApp tables (dependent children first)
    'whatsapp_logs',
    'whatsapp_campaigns',

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

    // Milk Subscription tables
    'milk_subscription_consumptions',
    'milk_subscription_settlements',
    'milk_subscription_schemes',
    'milk_subscriptions',

    // HRMS tables (dependent children first)
    'hr_loan_transactions',
    'hr_loans',
    'hr_sales_commissions',
    'hr_cashier_handovers',
    'hr_payroll_details',
    'hr_payroll_runs',
    'hr_salary_revisions',
    'hr_arrears',
    'hr_attendance_punches',
    'hr_leave_balances',
    'hr_leave_applications',
    'hr_employees',
    'hr_pay_structure_components',
    'hr_pay_structures',
    'hr_salary_components',
    'hr_leave_types',
    'hr_shifts',
    'hr_designations',
    'hr_holidays',

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
    'expenses',
    'expense_taxes',
    'expense_deductions',
    'expense_categories',
    'taxes_master',
    'daily_opening_balances',
    'stock_ledger',
    'system_notifications',
    'audit_logs',
    'commission_rules'
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
                    sub_delivery_free_above: 0.0,
                    enable_salesperson_tagging: false,
                    bill_copies_count: 1,
                    show_brand_name: true,
                    enable_token_system: false,
                    token_copies_count: 1,
                    device_printer_mappings: {}
                }
            });
        }

        let settingsData = settings.toJSON ? settings.toJSON() : settings;
        if (typeof settingsData.device_printer_mappings === 'string') {
            try {
                settingsData.device_printer_mappings = JSON.parse(settingsData.device_printer_mappings);
            } catch (e) {
                settingsData.device_printer_mappings = {};
            }
        }

        res.json({ success: true, data: settingsData });
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

        let rawMappings = req.body.device_printer_mappings;
        if (typeof rawMappings === 'string') {
            try {
                rawMappings = JSON.parse(rawMappings);
            } catch (e) {
                rawMappings = null;
            }
        }

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
            sub_delivery_free_above: req.body.sub_delivery_free_above ?? 0.0,
            enable_salesperson_tagging: req.body.enable_salesperson_tagging ?? false,
            bill_copies_count: req.body.bill_copies_count ?? 1,
            show_brand_name: req.body.show_brand_name ?? true,
            enable_token_system: req.body.enable_token_system ?? false,
            token_copies_count: req.body.token_copies_count ?? 1,
            device_printer_mappings: (rawMappings && typeof rawMappings === 'object' && Object.keys(rawMappings).length > 0)
                ? rawMappings
                : (existing?.device_printer_mappings || {})
        };

        if (req.body.outlet_max_discount_percent !== undefined) {
            payload.outlet_max_discount_percent = req.body.outlet_max_discount_percent;
        }

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
        res.json({ success: true, message: 'Settings saved successfully', data: record });

    } catch (err) {
        await t.rollback();
        res.status(500).json({ success: false, error: err.message });
    }
};

const PRESERVED_MODELS = new Set([
    'schema_version',
    'system_settings',
    'item_master',
    'item_masters',
    'categories',
    'category_master',
    'brands',
    'brand_master',
    'units',
    'unit_master',
    'groups',
    'group_master',
    'subcategories',
    'subcategory_master',
    'customers',
    'customer',
    'users',
    'user',
    'outlets',
    'outlet',
    'app_branding',
    'dining_tables',
    'dining_areas',
    'floors',
    'email_configs',
    'email_templates',
    'feature_modules',
    'licenses',
    'owners',
    'properties',
    'attributes',
    'attribute_values',
    'hsn_master'
]);

exports.clearTransactionData = async (req, res) => {
    try {
        const confirmText = String(req.body.confirm_text || '').trim().toUpperCase();
        if (confirmText !== 'DELETE ALL DATA') {
            return res.status(400).json({
                success: false,
                message: 'Type DELETE ALL DATA to confirm the wipe'
            });
        }

        const isPostgres = req.propertyDb.options?.dialect === 'postgres';

        const wipeTableList = [
            'kot_revisions',
            'kot_items',
            'kot_headers',
            'restaurant_audit_trail',
            'table_reservations',
            'draw_vouchers',
            'customer_draw_progress',
            'lucky_draw_campaigns',
            'whatsapp_logs',
            'whatsapp_campaigns',
            'supplier_return_refunds',
            'supplier_return_items',
            'supplier_return_headers',
            'goods_receipt_items',
            'goods_receipts',
            'supplier_payments',
            'supplier_bills',
            'purchase_order_items',
            'purchase_orders',
            'return_items',
            'return_headers',
            'issue_items',
            'issue_headers',
            'damage_items',
            'damage_headers',
            'assembly_items',
            'assembly_headers',
            'request_items',
            'request_headers',
            'milk_subscription_consumptions',
            'milk_subscription_settlements',
            'milk_subscription_schemes',
            'milk_subscriptions',
            'sales_items',
            'sales_refunds',
            'sales_credit_notes',
            'customer_repayments',
            'customer_item_advances',
            'customer_advances',
            'customer_orders',
            'sales_headers',
            'sales_scheme_customers',
            'customer_loyalty_ledger',
            'loyalty_master_config',
            'cash_ledger',
            'expense_entries',
            'expense_taxes',
            'expense_deductions',
            'expenses',
            'expense_categories',
            'daily_opening_balances',
            'stock_ledger',
            'system_notifications',
            'audit_logs',
            'commission_rules'
        ];

        if (isPostgres) {
            const tableNamesQuoted = wipeTableList.map(t => `"${t}"`).join(', ');
            try {
                await req.propertyDb.query(`TRUNCATE TABLE ${tableNamesQuoted} RESTART IDENTITY CASCADE;`);
            } catch (truncErr) {
                console.warn('⚠️ TRUNCATE CASCADE failed, falling back to individual deletes:', truncErr.message);
                for (const tableName of wipeTableList) {
                    await req.propertyDb.query(`DELETE FROM "${tableName}"`).catch(() => {});
                }
            }
        } else {
            await req.propertyDb.query('PRAGMA foreign_keys = OFF;').catch(() => {});
            for (const tableName of wipeTableList) {
                await req.propertyDb.query(`DELETE FROM "${tableName}"`).catch(() => {});
                await req.propertyDb.query(`DELETE FROM ${tableName}`).catch(() => {});
            }
            await req.propertyDb.query('PRAGMA foreign_keys = ON;').catch(() => {});
        }

        res.json({
            success: true,
            message: 'All transaction data cleared successfully',
            preserved: ['masters', 'customer_master', 'system_settings', 'schema_version']
        });
    } catch (err) {
        console.error("❌ Error clearing transaction data:", err);
        res.status(500).json({ success: false, message: err.message || 'Failed to clear transaction data' });
    }
};
