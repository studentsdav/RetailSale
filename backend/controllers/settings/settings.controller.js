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

        const outletId = Number(
            req.outlet_id ||
            req.user?.outlet_id ||
            req.headers['x-outlet-id'] ||
            req.body?.outlet_id ||
            req.query?.outlet_id
        );

        if (!outletId || isNaN(outletId)) {
            return res.status(400).json({
                success: false,
                message: 'Outlet ID is required to clear transaction data'
            });
        }

        const isPostgres = req.propertyDb.options?.dialect === 'postgres';

        // Order matters: child/dependent tables deleted first
        const deleteQueries = [
            // 1. Restaurant / KOT child & header tables
            `DELETE FROM "kot_revisions" WHERE kot_header_id IN (SELECT id FROM "kot_headers" WHERE outlet_id = :outletId)`,
            `DELETE FROM "kot_items" WHERE outlet_id = :outletId OR kot_header_id IN (SELECT id FROM "kot_headers" WHERE outlet_id = :outletId)`,
            `DELETE FROM "kot_headers" WHERE outlet_id = :outletId`,
            `DELETE FROM "restaurant_audit_trail" WHERE outlet_id = :outletId`,
            `DELETE FROM "table_reservations" WHERE outlet_id = :outletId`,

            // 2. Lucky Draw Campaign & WhatsApp tables
            `DELETE FROM "draw_vouchers" WHERE outlet_id = :outletId`,
            `DELETE FROM "customer_draw_progress" WHERE outlet_id = :outletId`,
            `DELETE FROM "lucky_draw_campaigns" WHERE outlet_id = :outletId`,
            `DELETE FROM "whatsapp_logs" WHERE outlet_id = :outletId`,
            `DELETE FROM "whatsapp_campaigns" WHERE outlet_id = :outletId`,

            // 3. Supplier Returns & Goods Receipts
            `DELETE FROM "supplier_return_refunds" WHERE outlet_id = :outletId OR return_id IN (SELECT id FROM "supplier_return_headers" WHERE outlet_id = :outletId)`,
            `DELETE FROM "supplier_return_items" WHERE return_id IN (SELECT id FROM "supplier_return_headers" WHERE outlet_id = :outletId)`,
            `DELETE FROM "supplier_return_headers" WHERE outlet_id = :outletId`,
            `DELETE FROM "goods_receipt_items" WHERE grn_id IN (SELECT id FROM "goods_receipts" WHERE outlet_id = :outletId)`,
            `DELETE FROM "goods_receipts" WHERE outlet_id = :outletId`,
            `DELETE FROM "supplier_payments" WHERE outlet_id = :outletId`,
            `DELETE FROM "supplier_bills" WHERE outlet_id = :outletId`,

            // 4. Purchase Orders
            `DELETE FROM "purchase_order_items" WHERE po_id IN (SELECT id FROM "purchase_orders" WHERE outlet_id = :outletId)`,
            `DELETE FROM "purchase_orders" WHERE outlet_id = :outletId`,

            // 5. Stock Issues / Returns / Damages / Assembly / Requests / Delivery Challans
            `DELETE FROM "return_items" WHERE return_id IN (SELECT id FROM "return_headers" WHERE outlet_id = :outletId)`,
            `DELETE FROM "return_headers" WHERE outlet_id = :outletId`,
            `DELETE FROM "issue_items" WHERE issue_id IN (SELECT id FROM "issue_headers" WHERE outlet_id = :outletId)`,
            `DELETE FROM "issue_headers" WHERE outlet_id = :outletId`,
            `DELETE FROM "damage_items" WHERE damage_id IN (SELECT id FROM "damage_headers" WHERE outlet_id = :outletId)`,
            `DELETE FROM "damage_headers" WHERE outlet_id = :outletId`,
            `DELETE FROM "assembly_items" WHERE outlet_id = :outletId OR assembly_id IN (SELECT id FROM "assembly_headers" WHERE outlet_id = :outletId)`,
            `DELETE FROM "assembly_headers" WHERE outlet_id = :outletId`,
            `DELETE FROM "request_items" WHERE request_id IN (SELECT id FROM "request_headers" WHERE outlet_id = :outletId)`,
            `DELETE FROM "request_headers" WHERE outlet_id = :outletId`,
            `DELETE FROM "delivery_challan_items" WHERE challan_id IN (SELECT id FROM "delivery_challan_headers" WHERE outlet_id = :outletId)`,
            `DELETE FROM "delivery_challan_headers" WHERE outlet_id = :outletId`,

            // 6. Milk Subscriptions
            `DELETE FROM "milk_subscription_consumptions" WHERE outlet_id = :outletId`,
            `DELETE FROM "milk_subscription_settlements" WHERE outlet_id = :outletId`,
            `DELETE FROM "milk_subscription_schemes" WHERE outlet_id = :outletId`,
            `DELETE FROM "milk_subscriptions" WHERE outlet_id = :outletId`,

            // 7. HRMS Transactional Tables
            `DELETE FROM "hr_loan_transactions" WHERE loan_id IN (SELECT id FROM "hr_loans" WHERE outlet_id = :outletId)`,
            `DELETE FROM "hr_loans" WHERE outlet_id = :outletId`,
            `DELETE FROM "hr_sales_commissions" WHERE outlet_id = :outletId`,
            `DELETE FROM "hr_cashier_handovers" WHERE outlet_id = :outletId`,
            `DELETE FROM "hr_payroll_details" WHERE payroll_run_id IN (SELECT id FROM "hr_payroll_runs" WHERE outlet_id = :outletId)`,
            `DELETE FROM "hr_payroll_runs" WHERE outlet_id = :outletId`,
            `DELETE FROM "hr_salary_revisions" WHERE outlet_id = :outletId`,
            `DELETE FROM "hr_arrears" WHERE outlet_id = :outletId`,
            `DELETE FROM "hr_attendance_punches" WHERE outlet_id = :outletId`,
            `DELETE FROM "hr_leave_balances" WHERE outlet_id = :outletId`,
            `DELETE FROM "hr_leave_applications" WHERE outlet_id = :outletId`,

            // 8. Sales & Customer Transactions
            `DELETE FROM "sales_items" WHERE sale_id IN (SELECT id FROM "sales_headers" WHERE outlet_id = :outletId)`,
            `DELETE FROM "sales_refunds" WHERE outlet_id = :outletId OR sale_id IN (SELECT id FROM "sales_headers" WHERE outlet_id = :outletId)`,
            `DELETE FROM "sales_credit_notes" WHERE outlet_id = :outletId`,
            `DELETE FROM "customer_repayments" WHERE outlet_id = :outletId`,
            `DELETE FROM "customer_item_advances" WHERE outlet_id = :outletId`,
            `DELETE FROM "customer_advances" WHERE outlet_id = :outletId`,
            `DELETE FROM "customer_orders" WHERE outlet_id = :outletId`,
            `DELETE FROM "sales_headers" WHERE outlet_id = :outletId`,
            `DELETE FROM "sales_scheme_customers" WHERE outlet_id = :outletId`,
            `DELETE FROM "customer_loyalty_ledger" WHERE outlet_id = :outletId`,
            `DELETE FROM "loyalty_master_config" WHERE outlet_id = :outletId`,

            // 9. Finance, Expenses & Accounting
            `DELETE FROM "cash_ledger" WHERE outlet_id = :outletId`,
            `DELETE FROM "expense_taxes" WHERE expense_id IN (SELECT id FROM "expenses" WHERE outlet_id = :outletId)`,
            `DELETE FROM "expense_deductions" WHERE expense_id IN (SELECT id FROM "expenses" WHERE outlet_id = :outletId)`,
            `DELETE FROM "expense_entries" WHERE outlet_id = :outletId`,
            `DELETE FROM "expenses" WHERE outlet_id = :outletId`,
            `DELETE FROM "expense_categories" WHERE outlet_id = :outletId`,
            `DELETE FROM "daily_opening_balances" WHERE outlet_id = :outletId`,
            `DELETE FROM "accounting_vouchers" WHERE outlet_id = :outletId`,
            `DELETE FROM "business_day_status" WHERE outlet_id = :outletId`,

            // 10. Stock Ledger, Notifications, Audits, Night Audit
            `DELETE FROM "stock_ledger" WHERE outlet_id = :outletId`,
            `DELETE FROM "system_notifications" WHERE outlet_id = :outletId`,
            `DELETE FROM "audit_logs" WHERE outlet_id = :outletId`,
            `DELETE FROM "commission_rules" WHERE outlet_id = :outletId`,
            `DELETE FROM "night_audit_details" WHERE audit_run_id IN (SELECT id FROM "night_audit_runs" WHERE outlet_id = :outletId) OR outlet_id = :outletId`,
            `DELETE FROM "night_audit_runs" WHERE outlet_id = :outletId`
        ];

        if (!isPostgres) {
            await req.propertyDb.query('PRAGMA foreign_keys = OFF;').catch(() => {});
        }

        for (const queryStr of deleteQueries) {
            try {
                await req.propertyDb.query(queryStr, {
                    replacements: { outletId }
                });
            } catch (err) {
                // Ignore errors if table or column doesn't exist in a specific schema
                console.warn(`[ClearData] Warning executing query on outlet #${outletId}: ${err.message}`);
            }
        }

        if (!isPostgres) {
            await req.propertyDb.query('PRAGMA foreign_keys = ON;').catch(() => {});
        }

        try {
            await audit.log(req, 'CLEAR_TRANSACTION_DATA', {
                details: `Cleared transaction data specifically for outlet ID #${outletId}`
            });
        } catch (_) {}

        res.json({
            success: true,
            message: `All transaction data for outlet #${outletId} cleared successfully`,
            outlet_id: outletId,
            preserved: ['masters', 'customer_master', 'system_settings', 'other_outlets']
        });
    } catch (err) {
        console.error("❌ Error clearing transaction data:", err);
        res.status(500).json({ success: false, message: err.message || 'Failed to clear transaction data' });
    }
};
