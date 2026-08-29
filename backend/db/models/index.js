const propertyDb = require('../propertyDb');
const { DataTypes } = require('sequelize');

propertyDb.models = {};

/* ===========================
   PROPERTY MODELS
   =========================== */

// ITEM / INVENTORY
propertyDb.models.supplier_payments =
    require('../../models/property/supplierPayment.model')(propertyDb, DataTypes);
propertyDb.models.supplier_return_headers =
    require('../../models/property/supplierReturnHeader.model')(propertyDb, DataTypes);
propertyDb.models.supplier_return_items =
    require('../../models/property/supplierReturnItem.model')(propertyDb, DataTypes);
propertyDb.models.supplier_return_refunds =
    require('../../models/property/supplierReturnRefund.model')(propertyDb, DataTypes);
propertyDb.models.outlets =
    require('../../models/property/outlet.model')(propertyDb, DataTypes);

propertyDb.models.item_master =
    require('../../models/property/itemMaster.model')(propertyDb, DataTypes);
propertyDb.models.product_templates =
    require('../../models/property/productTemplate.model')(propertyDb, DataTypes);
propertyDb.models.attributes =
    require('../../models/property/attribute.model')(propertyDb, DataTypes);
propertyDb.models.attribute_values =
    require('../../models/property/attributeValue.model')(propertyDb, DataTypes);
propertyDb.models.variant_attribute_values =
    require('../../models/property/variantAttributeValue.model')(propertyDb, DataTypes);

propertyDb.models.stock_locations =
    require('../../models/property/stockLocation.model')(propertyDb, DataTypes);

propertyDb.models.numbering_settings =
    require('../../models/property/numberingSettings.model')(propertyDb, DataTypes);

// ISSUE / DAMAGE / RETURN
propertyDb.models.issue_headers =
    require('../../models/property/issueHeader.model')(propertyDb, DataTypes);

propertyDb.models.issue_items =
    require('../../models/property/issueItem.model')(propertyDb, DataTypes);

propertyDb.models.damage_headers =
    require('../../models/property/damageHeader.model')(propertyDb, DataTypes);

propertyDb.models.damage_items =
    require('../../models/property/damageItem.model')(propertyDb, DataTypes);

propertyDb.models.return_headers =
    require('../../models/property/returnHeader.model')(propertyDb, DataTypes);

propertyDb.models.return_items =
    require('../../models/property/returnItem.model')(propertyDb, DataTypes);

// REQUESTS
propertyDb.models.request_headers =
    require('../../models/property/requestHeader.model')(propertyDb, DataTypes);

propertyDb.models.request_items =
    require('../../models/property/requestItem.model')(propertyDb, DataTypes);
propertyDb.models.customers =
    require('../../models/property/customer.model')(propertyDb, DataTypes);
propertyDb.models.customer_repayments =
    require('../../models/property/customerRepayment.model')(propertyDb, DataTypes);
propertyDb.models.customer_advances =
    require('../../models/property/customerAdvance.model')(propertyDb, DataTypes);
// PURCHASE / RECEIVING
propertyDb.models.purchase_orders =
    require('../../models/property/purchaseOrder.model')(propertyDb, DataTypes);
propertyDb.models.purchase_order_items = require('../../models/property/purchaseOrderItem.model')(propertyDb, DataTypes);
propertyDb.models.daily_opening_balances =
    require('../../models/property/dailyOpeningBalance.model')(propertyDb, DataTypes);
propertyDb.models.goods_receipts =
    require('../../models/property/goodsReceipt.model')(propertyDb, DataTypes);

propertyDb.models.goods_receipt_items =
    require('../../models/property/goodsReceiptItem.model')(propertyDb, DataTypes);

// SALES
propertyDb.models.sales_headers =
    require('../../models/property/salesHeader.model')(propertyDb, DataTypes);

// LUCKY DRAW CAMPAIGNS
propertyDb.models.lucky_draw_campaigns =
    require('../../models/property/luckyDrawCampaign.model')(propertyDb, DataTypes);
propertyDb.models.customer_draw_progress =
    require('../../models/property/customerDrawProgress.model')(propertyDb, DataTypes);
propertyDb.models.draw_vouchers =
    require('../../models/property/drawVoucher.model')(propertyDb, DataTypes);

propertyDb.models.sales_items =
    require('../../models/property/salesItem.model')(propertyDb, DataTypes);

propertyDb.models.sales_refunds =
    require('../../models/property/salesRefund.model')(propertyDb, DataTypes);

propertyDb.models.sales_credit_notes =
    require('../../models/property/salesCreditNote.model')(propertyDb, DataTypes);

propertyDb.models.sales_schemes =
    require('../../models/property/salesScheme.model')(propertyDb, DataTypes);
propertyDb.models.sales_scheme_customers =
    require('../../models/property/salesSchemeCustomer.model')(propertyDb, DataTypes);
propertyDb.models.customer_item_advances =
    require('../../models/property/customerItemAdvance.model')(propertyDb, DataTypes);
propertyDb.models.loyalty_master_config =
    require('../../models/property/loyaltyMasterConfig.model')(propertyDb, DataTypes);
propertyDb.models.customer_loyalty_ledger =
    require('../../models/property/customerLoyaltyLedger.model')(propertyDb, DataTypes);
propertyDb.models.milk_subscriptions =
    require('../../models/property/milkSubscription.model')(propertyDb, DataTypes);
propertyDb.models.milk_subscription_schemes =
    require('../../models/property/milkSubscriptionScheme.model')(propertyDb, DataTypes);
propertyDb.models.milk_subscription_consumptions =
    require('../../models/property/milkSubscriptionConsumption.model')(propertyDb, DataTypes);
propertyDb.models.milk_subscription_settlements =
    require('../../models/property/milkSubscriptionSettlement.model')(propertyDb, DataTypes);

// SUPPLIER
propertyDb.models.supplier_master =
    require('../../models/property/supplierMaster.model')(propertyDb, DataTypes);

propertyDb.models.supplier_bills =
    require('../../models/property/supplierBill.model')(propertyDb, DataTypes);



// USERS / AUTH
propertyDb.models.users =
    require('../../models/property/users.model')(propertyDb, DataTypes);

propertyDb.models.user_permissions =
    require('../../models/property/userPermissions.model')(propertyDb, DataTypes);

// SETTINGS
propertyDb.models.property_info =
    require('../../models/property/propertyInfo.model')(propertyDb, DataTypes);

propertyDb.models.system_settings =
    require('../../models/property/systemSettings.model')(propertyDb, DataTypes);

propertyDb.models.outlet_settings =
    require('../../models/property/outletSettings.model')(propertyDb, DataTypes);

propertyDb.models.app_branding =
    require('../../models/property/appBranding.model')(propertyDb, DataTypes);

// WHATSAPP INTEGRATION
propertyDb.models.whatsapp_configurations =
    require('../../models/property/whatsappConfig.model')(propertyDb, DataTypes);
propertyDb.models.whatsapp_templates =
    require('../../models/property/whatsappTemplate.model')(propertyDb, DataTypes);
propertyDb.models.whatsapp_campaigns =
    require('../../models/property/whatsappCampaign.model')(propertyDb, DataTypes);
propertyDb.models.whatsapp_logs =
    require('../../models/property/whatsappLog.model')(propertyDb, DataTypes);


propertyDb.models.cash_ledger =
    require('../../models/property/cashLedger.model')(propertyDb, DataTypes);

propertyDb.models.expense_entries =
    require('../../models/property/expenseEntry.model')(propertyDb, DataTypes);

propertyDb.models.expense_categories =
    require('../../models/property/expenseCategory.model')(propertyDb, DataTypes);
propertyDb.models.taxes_master =
    require('../../models/property/taxesMaster.model')(propertyDb, DataTypes);
propertyDb.models.expenses =
    require('../../models/property/expense.model')(propertyDb, DataTypes);
propertyDb.models.expense_taxes =
    require('../../models/property/expenseTax.model')(propertyDb, DataTypes);
propertyDb.models.expense_deductions =
    require('../../models/property/expenseDeduction.model')(propertyDb, DataTypes);

propertyDb.models.item_groups =
    require('../../models/property/group.model')(propertyDb, DataTypes);

// AUDIT & STOCK
propertyDb.models.business_day_status =
    require('../../models/property/businessDay.model')(propertyDb, DataTypes);
propertyDb.models.night_audit_runs =
    require('../../models/property/nightAuditRun.model')(propertyDb, DataTypes);
propertyDb.models.night_audit_details =
    require('../../models/property/nightAuditDetail.model')(propertyDb, DataTypes);

propertyDb.models.audit_logs =
    require('../../models/property/auditLog.model')(propertyDb, DataTypes);

propertyDb.models.stock_ledger =
    require('../../models/property/stockLedger.model')(propertyDb, DataTypes);

propertyDb.models.item_subcategories =
    require('../../models/property/subcategory.model')(propertyDb, DataTypes);

propertyDb.models.brands =
    require('../../models/property/brand.model')(propertyDb, DataTypes);


propertyDb.models.system_notification =
    require('../../models/property/system_notification.model')(propertyDb, DataTypes);

propertyDb.models.delivery_partners =
    require('../../models/property/deliveryPartner.model')(propertyDb, DataTypes);
propertyDb.models.customer_orders =
    require('../../models/property/customerOrder.model')(propertyDb, DataTypes);
propertyDb.models.delivery_customers =
    require('../../models/property/deliveryCustomer.model')(propertyDb, DataTypes);
propertyDb.models.sale_sources =
    require('../../models/property/saleSource.model')(propertyDb, DataTypes);
propertyDb.models.commission_rules =
    require('../../models/property/commissionRule.model')(propertyDb, DataTypes);
propertyDb.models.payment_methods =
    require('../../models/property/paymentMethod.model')(propertyDb, DataTypes);
propertyDb.models.happy_hours =
    require('../../models/property/happyHour.model')(propertyDb, DataTypes);
propertyDb.models.bill_value_promos =
    require('../../models/property/billValuePromo.model')(propertyDb, DataTypes);

// BOM & ASSEMBLY
propertyDb.models.item_boms =
    require('../../models/property/itemBom.model')(propertyDb, DataTypes);
propertyDb.models.assembly_headers =
    require('../../models/property/assemblyHeader.model')(propertyDb, DataTypes);
propertyDb.models.assembly_items =
    require('../../models/property/assemblyItem.model')(propertyDb, DataTypes);

// HRMS
propertyDb.models.hr_salary_components =
    require('../../models/property/hrSalaryComponent.model')(propertyDb, DataTypes);
propertyDb.models.hr_pay_structures =
    require('../../models/property/hrPayStructure.model')(propertyDb, DataTypes);
propertyDb.models.hr_pay_structure_components =
    require('../../models/property/hrPayStructureComponent.model')(propertyDb, DataTypes);
propertyDb.models.hr_leave_types =
    require('../../models/property/hrLeaveType.model')(propertyDb, DataTypes);
propertyDb.models.hr_shifts =
    require('../../models/property/hrShift.model')(propertyDb, DataTypes);
propertyDb.models.hr_holidays =
    require('../../models/property/hrHoliday.model')(propertyDb, DataTypes);
propertyDb.models.hr_designations =
    require('../../models/property/hrDesignation.model')(propertyDb, DataTypes);
propertyDb.models.hr_employees =
    require('../../models/property/hrEmployee.model')(propertyDb, DataTypes);
propertyDb.models.hr_attendance_punches =
    require('../../models/property/hrAttendancePunch.model')(propertyDb, DataTypes);
propertyDb.models.hr_leave_applications =
    require('../../models/property/hrLeaveApplication.model')(propertyDb, DataTypes);
propertyDb.models.hr_leave_balances =
    require('../../models/property/hrLeaveBalance.model')(propertyDb, DataTypes);
propertyDb.models.hr_salary_revisions =
    require('../../models/property/hrSalaryRevision.model')(propertyDb, DataTypes);
propertyDb.models.hr_arrears =
    require('../../models/property/hrArrear.model')(propertyDb, DataTypes);
propertyDb.models.hr_loans =
    require('../../models/property/hrLoan.model')(propertyDb, DataTypes);
propertyDb.models.hr_loan_transactions =
    require('../../models/property/hrLoanTransaction.model')(propertyDb, DataTypes);
propertyDb.models.hr_sales_commissions =
    require('../../models/property/hrSalesCommission.model')(propertyDb, DataTypes);
propertyDb.models.hr_cashier_handovers =
    require('../../models/property/hrCashierHandover.model')(propertyDb, DataTypes);
propertyDb.models.hr_payroll_runs =
    require('../../models/property/hrPayrollRun.model')(propertyDb, DataTypes);
propertyDb.models.hr_payroll_details =
    require('../../models/property/hrPayrollDetail.model')(propertyDb, DataTypes);

// RESTAURANT & CORE ADDONS
propertyDb.models.floors =
    require('../../models/property/floor.model')(propertyDb, DataTypes);
propertyDb.models.dining_areas =
    require('../../models/property/diningArea.model')(propertyDb, DataTypes);
propertyDb.models.table_types =
    require('../../models/property/tableType.model')(propertyDb, DataTypes);
propertyDb.models.restaurant_printers =
    require('../../models/property/restaurantPrinter.model')(propertyDb, DataTypes);
propertyDb.models.restaurant_tables =
    require('../../models/property/restaurantTable.model')(propertyDb, DataTypes);
propertyDb.models.kitchen_stations =
    require('../../models/property/kitchenStation.model')(propertyDb, DataTypes);
propertyDb.models.table_reservations =
    require('../../models/property/tableReservation.model')(propertyDb, DataTypes);
propertyDb.models.email_configurations =
    require('../../models/property/emailConfig.model')(propertyDb, DataTypes);
propertyDb.models.email_templates =
    require('../../models/property/emailTemplate.model')(propertyDb, DataTypes);
propertyDb.models.kot_headers =
    require('../../models/property/kotHeader.model')(propertyDb, DataTypes);
propertyDb.models.kot_items =
    require('../../models/property/kotItem.model')(propertyDb, DataTypes);
propertyDb.models.kot_revisions =
    require('../../models/property/kotRevision.model')(propertyDb, DataTypes);
propertyDb.models.item_modifiers =
    require('../../models/property/itemModifier.model')(propertyDb, DataTypes);
propertyDb.models.restaurant_audit_trail =
    require('../../models/property/restaurantAuditTrail.model')(propertyDb, DataTypes);
propertyDb.models.delivery_challan_headers =
    require('../../models/property/deliveryChallanHeader.model')(propertyDb, DataTypes);
propertyDb.models.delivery_challan_items =
    require('../../models/property/deliveryChallanItem.model')(propertyDb, DataTypes);
propertyDb.models.recurring_expenses =
    require('../../models/property/recurringExpense.model')(propertyDb, DataTypes);
propertyDb.models.milk_subscription_items =
    require('../../models/property/milkSubscriptionItem.model')(propertyDb, DataTypes);
propertyDb.models.bank_accounts =
    require('../../models/property/bankAccount.model')(propertyDb, DataTypes);
propertyDb.models.chart_of_accounts =
    require('../../models/property/chartOfAccounts.model')(propertyDb, DataTypes);
propertyDb.models.accounting_vouchers =
    require('../../models/property/accountingVoucher.model')(propertyDb, DataTypes);
propertyDb.models.voucher_lines =
    require('../../models/property/voucherLine.model')(propertyDb, DataTypes);

Object.values(propertyDb.models).forEach(model => {
    if (typeof model.associate === 'function') {
        model.associate(propertyDb.models);
    }
});

// Enforce request-scoped outlet context automatically on all database queries and writes
const { contextStorage } = require('../../utils/context');

function applyOutletFilter(options, outletId) {
    if (!options) return;
    if (options.bypassOutletFilter) return;

    if (options.model && options.model.rawAttributes && options.model.rawAttributes.outlet_id) {
        if (!options.where) {
            options.where = { outlet_id: outletId };
        } else if (Array.isArray(options.where)) {
            options.where.push({ outlet_id: outletId });
        } else if (typeof options.where === 'object') {
            options.where.outlet_id = outletId;
        }
    }

    if (options.include) {
        const includes = Array.isArray(options.include) ? options.include : [options.include];
        includes.forEach(inc => {
            if (typeof inc === 'object') {
                applyOutletFilter(inc, outletId);
            }
        });
    }
}

propertyDb.addHook('beforeFind', (options) => {
    if (options.bypassOutletFilter) return;
    const store = contextStorage.getStore();
    const outletId = store?.get('outlet_id');
    if (outletId) {
        applyOutletFilter(options, outletId);
    }
});

propertyDb.addHook('beforeCreate', (instance, options) => {
    const store = contextStorage.getStore();
    const outletId = store?.get('outlet_id');
    if (outletId && instance.constructor.rawAttributes && instance.constructor.rawAttributes.outlet_id) {
        instance.outlet_id = outletId;
    }
});

propertyDb.addHook('beforeBulkCreate', (instances, options) => {
    const store = contextStorage.getStore();
    const outletId = store?.get('outlet_id');
    if (outletId) {
        instances.forEach(instance => {
            if (instance.constructor.rawAttributes && instance.constructor.rawAttributes.outlet_id) {
                instance.outlet_id = outletId;
            }
        });
    }
});

propertyDb.addHook('beforeBulkUpdate', (options) => {
    if (options.bypassOutletFilter) return;
    const store = contextStorage.getStore();
    const outletId = store?.get('outlet_id');
    if (outletId && options.model && options.model.rawAttributes && options.model.rawAttributes.outlet_id) {
        if (!options.where) {
            options.where = { outlet_id: outletId };
        } else if (Array.isArray(options.where)) {
            options.where.push({ outlet_id: outletId });
        } else if (typeof options.where === 'object') {
            options.where.outlet_id = outletId;
        }
    }
});

propertyDb.addHook('beforeBulkDestroy', (options) => {
    if (options.bypassOutletFilter) return;
    const store = contextStorage.getStore();
    const outletId = store?.get('outlet_id');
    if (outletId && options.model && options.model.rawAttributes && options.model.rawAttributes.outlet_id) {
        if (!options.where) {
            options.where = { outlet_id: outletId };
        } else if (Array.isArray(options.where)) {
            options.where.push({ outlet_id: outletId });
        } else if (typeof options.where === 'object') {
            options.where.outlet_id = outletId;
        }
    }
});

module.exports = propertyDb;

