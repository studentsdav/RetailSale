import { DataTypes } from 'sequelize';
import propertyDb from '../propertyDb';
const { contextStorage } = require('../../utils/context');

(propertyDb as any).models = (propertyDb as any).models || {};
const models: Record<string, any> = (propertyDb as any).models;

/* ===========================
   PROPERTY MODELS
   =========================== */

// ITEM / INVENTORY
models.supplier_payments =
    require('../../models/property/supplierPayment.model')(propertyDb, DataTypes);
models.supplier_return_headers =
    require('../../models/property/supplierReturnHeader.model')(propertyDb, DataTypes);
models.supplier_return_items =
    require('../../models/property/supplierReturnItem.model')(propertyDb, DataTypes);
models.supplier_return_refunds =
    require('../../models/property/supplierReturnRefund.model')(propertyDb, DataTypes);
models.outlets =
    require('../../models/property/outlet.model')(propertyDb, DataTypes);

models.item_master =
    require('../../models/property/itemMaster.model')(propertyDb, DataTypes);
models.product_templates =
    require('../../models/property/productTemplate.model')(propertyDb, DataTypes);
models.attributes =
    require('../../models/property/attribute.model')(propertyDb, DataTypes);
models.attribute_values =
    require('../../models/property/attributeValue.model')(propertyDb, DataTypes);
models.variant_attribute_values =
    require('../../models/property/variantAttributeValue.model')(propertyDb, DataTypes);

models.stock_locations =
    require('../../models/property/stockLocation.model')(propertyDb, DataTypes);

models.numbering_settings =
    require('../../models/property/numberingSettings.model')(propertyDb, DataTypes);

// ISSUE / DAMAGE / RETURN
models.issue_headers =
    require('../../models/property/issueHeader.model')(propertyDb, DataTypes);

models.issue_items =
    require('../../models/property/issueItem.model')(propertyDb, DataTypes);

models.damage_headers =
    require('../../models/property/damageHeader.model')(propertyDb, DataTypes);

models.damage_items =
    require('../../models/property/damageItem.model')(propertyDb, DataTypes);

models.return_headers =
    require('../../models/property/returnHeader.model')(propertyDb, DataTypes);

models.return_items =
    require('../../models/property/returnItem.model')(propertyDb, DataTypes);

// REQUESTS
models.request_headers =
    require('../../models/property/requestHeader.model')(propertyDb, DataTypes);

models.request_items =
    require('../../models/property/requestItem.model')(propertyDb, DataTypes);
models.customers =
    require('../../models/property/customer.model')(propertyDb, DataTypes);
models.customer_repayments =
    require('../../models/property/customerRepayment.model')(propertyDb, DataTypes);
models.customer_advances =
    require('../../models/property/customerAdvance.model')(propertyDb, DataTypes);
// PURCHASE / RECEIVING
models.purchase_orders =
    require('../../models/property/purchaseOrder.model')(propertyDb, DataTypes);
models.purchase_order_items = require('../../models/property/purchaseOrderItem.model')(propertyDb, DataTypes);
models.daily_opening_balances =
    require('../../models/property/dailyOpeningBalance.model')(propertyDb, DataTypes);
models.goods_receipts =
    require('../../models/property/goodsReceipt.model')(propertyDb, DataTypes);

models.goods_receipt_items =
    require('../../models/property/goodsReceiptItem.model')(propertyDb, DataTypes);

// SALES
models.sales_headers =
    require('../../models/property/salesHeader.model')(propertyDb, DataTypes);

// LUCKY DRAW CAMPAIGNS
models.lucky_draw_campaigns =
    require('../../models/property/luckyDrawCampaign.model')(propertyDb, DataTypes);
models.customer_draw_progress =
    require('../../models/property/customerDrawProgress.model')(propertyDb, DataTypes);
models.draw_vouchers =
    require('../../models/property/drawVoucher.model')(propertyDb, DataTypes);

models.sales_items =
    require('../../models/property/salesItem.model')(propertyDb, DataTypes);

models.sales_refunds =
    require('../../models/property/salesRefund.model')(propertyDb, DataTypes);

models.sales_credit_notes =
    require('../../models/property/salesCreditNote.model')(propertyDb, DataTypes);

models.sales_schemes =
    require('../../models/property/salesScheme.model')(propertyDb, DataTypes);
models.sales_scheme_customers =
    require('../../models/property/salesSchemeCustomer.model')(propertyDb, DataTypes);
models.customer_item_advances =
    require('../../models/property/customerItemAdvance.model')(propertyDb, DataTypes);
models.loyalty_master_config =
    require('../../models/property/loyaltyMasterConfig.model')(propertyDb, DataTypes);
models.customer_loyalty_ledger =
    require('../../models/property/customerLoyaltyLedger.model')(propertyDb, DataTypes);
models.milk_subscriptions =
    require('../../models/property/milkSubscription.model')(propertyDb, DataTypes);
models.milk_subscription_schemes =
    require('../../models/property/milkSubscriptionScheme.model')(propertyDb, DataTypes);
models.milk_subscription_consumptions =
    require('../../models/property/milkSubscriptionConsumption.model')(propertyDb, DataTypes);
models.milk_subscription_settlements =
    require('../../models/property/milkSubscriptionSettlement.model')(propertyDb, DataTypes);

// SUPPLIER
models.supplier_master =
    require('../../models/property/supplierMaster.model')(propertyDb, DataTypes);

models.supplier_bills =
    require('../../models/property/supplierBill.model')(propertyDb, DataTypes);

// USERS / AUTH
models.users =
    require('../../models/property/users.model')(propertyDb, DataTypes);

models.user_permissions =
    require('../../models/property/userPermissions.model')(propertyDb, DataTypes);

// SETTINGS
models.property_info =
    require('../../models/property/propertyInfo.model')(propertyDb, DataTypes);

models.system_settings =
    require('../../models/property/systemSettings.model')(propertyDb, DataTypes);

models.outlet_settings =
    require('../../models/property/outletSettings.model')(propertyDb, DataTypes);

models.app_branding =
    require('../../models/property/appBranding.model')(propertyDb, DataTypes);

// WHATSAPP INTEGRATION
models.whatsapp_configurations =
    require('../../models/property/whatsappConfig.model')(propertyDb, DataTypes);
models.whatsapp_templates =
    require('../../models/property/whatsappTemplate.model')(propertyDb, DataTypes);
models.whatsapp_campaigns =
    require('../../models/property/whatsappCampaign.model')(propertyDb, DataTypes);
models.whatsapp_logs =
    require('../../models/property/whatsappLog.model')(propertyDb, DataTypes);

models.cash_ledger =
    require('../../models/property/cashLedger.model')(propertyDb, DataTypes);

models.expense_entries =
    require('../../models/property/expenseEntry.model')(propertyDb, DataTypes);

models.expense_categories =
    require('../../models/property/expenseCategory.model')(propertyDb, DataTypes);
models.taxes_master =
    require('../../models/property/taxesMaster.model')(propertyDb, DataTypes);
models.tax_profiles =
    require('../../models/property/taxProfile.model')(propertyDb, DataTypes);
models.tax_groups =
    require('../../models/property/taxGroup.model')(propertyDb, DataTypes);
models.tax_group_components =
    require('../../models/property/taxGroupComponent.model')(propertyDb, DataTypes);
models.expenses =
    require('../../models/property/expense.model')(propertyDb, DataTypes);
models.expense_taxes =
    require('../../models/property/expenseTax.model')(propertyDb, DataTypes);
models.expense_deductions =
    require('../../models/property/expenseDeduction.model')(propertyDb, DataTypes);

models.item_groups =
    require('../../models/property/group.model')(propertyDb, DataTypes);

// AUDIT & STOCK
models.business_day_status =
    require('../../models/property/businessDay.model')(propertyDb, DataTypes);
models.night_audit_runs =
    require('../../models/property/nightAuditRun.model')(propertyDb, DataTypes);
models.night_audit_details =
    require('../../models/property/nightAuditDetail.model')(propertyDb, DataTypes);

models.audit_logs =
    require('../../models/property/auditLog.model')(propertyDb, DataTypes);

models.stock_ledger =
    require('../../models/property/stockLedger.model')(propertyDb, DataTypes);
models.stock_transfer_headers =
    require('../../models/property/stockTransferHeader.model')(propertyDb, DataTypes);
models.stock_transfer_items =
    require('../../models/property/stockTransferItem.model')(propertyDb, DataTypes);

models.item_subcategories =
    require('../../models/property/subcategory.model')(propertyDb, DataTypes);

models.brands =
    require('../../models/property/brand.model')(propertyDb, DataTypes);

models.system_notification =
    require('../../models/property/system_notification.model')(propertyDb, DataTypes);

models.delivery_partners =
    require('../../models/property/deliveryPartner.model')(propertyDb, DataTypes);
models.customer_orders =
    require('../../models/property/customerOrder.model')(propertyDb, DataTypes);
models.delivery_customers =
    require('../../models/property/deliveryCustomer.model')(propertyDb, DataTypes);
models.sale_sources =
    require('../../models/property/saleSource.model')(propertyDb, DataTypes);
models.commission_rules =
    require('../../models/property/commissionRule.model')(propertyDb, DataTypes);
models.payment_methods =
    require('../../models/property/paymentMethod.model')(propertyDb, DataTypes);
models.happy_hours =
    require('../../models/property/happyHour.model')(propertyDb, DataTypes);
models.bill_value_promos =
    require('../../models/property/billValuePromo.model')(propertyDb, DataTypes);

// BOM & ASSEMBLY
models.item_boms =
    require('../../models/property/itemBom.model')(propertyDb, DataTypes);
models.assembly_headers =
    require('../../models/property/assemblyHeader.model')(propertyDb, DataTypes);
models.assembly_items =
    require('../../models/property/assemblyItem.model')(propertyDb, DataTypes);

// HRMS
models.hr_salary_components =
    require('../../models/property/hrSalaryComponent.model')(propertyDb, DataTypes);
models.hr_pay_structures =
    require('../../models/property/hrPayStructure.model')(propertyDb, DataTypes);
models.hr_pay_structure_components =
    require('../../models/property/hrPayStructureComponent.model')(propertyDb, DataTypes);
models.hr_leave_types =
    require('../../models/property/hrLeaveType.model')(propertyDb, DataTypes);
models.hr_shifts =
    require('../../models/property/hrShift.model')(propertyDb, DataTypes);
models.hr_holidays =
    require('../../models/property/hrHoliday.model')(propertyDb, DataTypes);
models.hr_designations =
    require('../../models/property/hrDesignation.model')(propertyDb, DataTypes);
models.hr_employees =
    require('../../models/property/hrEmployee.model')(propertyDb, DataTypes);
models.hr_attendance_punches =
    require('../../models/property/hrAttendancePunch.model')(propertyDb, DataTypes);
models.hr_leave_applications =
    require('../../models/property/hrLeaveApplication.model')(propertyDb, DataTypes);
models.hr_leave_balances =
    require('../../models/property/hrLeaveBalance.model')(propertyDb, DataTypes);
models.hr_salary_revisions =
    require('../../models/property/hrSalaryRevision.model')(propertyDb, DataTypes);
models.hr_arrears =
    require('../../models/property/hrArrear.model')(propertyDb, DataTypes);
models.hr_loans =
    require('../../models/property/hrLoan.model')(propertyDb, DataTypes);
models.hr_loan_transactions =
    require('../../models/property/hrLoanTransaction.model')(propertyDb, DataTypes);
models.hr_sales_commissions =
    require('../../models/property/hrSalesCommission.model')(propertyDb, DataTypes);
models.hr_cashier_handovers =
    require('../../models/property/hrCashierHandover.model')(propertyDb, DataTypes);
models.hr_payroll_runs =
    require('../../models/property/hrPayrollRun.model')(propertyDb, DataTypes);
models.hr_payroll_details =
    require('../../models/property/hrPayrollDetail.model')(propertyDb, DataTypes);

// RESTAURANT & CORE ADDONS
models.floors =
    require('../../models/property/floor.model')(propertyDb, DataTypes);
models.dining_areas =
    require('../../models/property/diningArea.model')(propertyDb, DataTypes);
models.table_types =
    require('../../models/property/tableType.model')(propertyDb, DataTypes);
models.restaurant_printers =
    require('../../models/property/restaurantPrinter.model')(propertyDb, DataTypes);
models.restaurant_tables =
    require('../../models/property/restaurantTable.model')(propertyDb, DataTypes);
models.kitchen_stations =
    require('../../models/property/kitchenStation.model')(propertyDb, DataTypes);
models.table_reservations =
    require('../../models/property/tableReservation.model')(propertyDb, DataTypes);
models.email_configurations =
    require('../../models/property/emailConfig.model')(propertyDb, DataTypes);
models.email_templates =
    require('../../models/property/emailTemplate.model')(propertyDb, DataTypes);
models.kot_headers =
    require('../../models/property/kotHeader.model')(propertyDb, DataTypes);
models.kot_items =
    require('../../models/property/kotItem.model')(propertyDb, DataTypes);
models.kot_revisions =
    require('../../models/property/kotRevision.model')(propertyDb, DataTypes);
models.item_modifiers =
    require('../../models/property/itemModifier.model')(propertyDb, DataTypes);
models.restaurant_audit_trail =
    require('../../models/property/restaurantAuditTrail.model')(propertyDb, DataTypes);
models.delivery_challan_headers =
    require('../../models/property/deliveryChallanHeader.model')(propertyDb, DataTypes);
models.delivery_challan_items =
    require('../../models/property/deliveryChallanItem.model')(propertyDb, DataTypes);
models.recurring_expenses =
    require('../../models/property/recurringExpense.model')(propertyDb, DataTypes);
models.milk_subscription_items =
    require('../../models/property/milkSubscriptionItem.model')(propertyDb, DataTypes);
models.bank_accounts =
    require('../../models/property/bankAccount.model')(propertyDb, DataTypes);
models.chart_of_accounts =
    require('../../models/property/chartOfAccounts.model')(propertyDb, DataTypes);
models.accounting_vouchers =
    require('../../models/property/accountingVoucher.model')(propertyDb, DataTypes);
models.voucher_lines =
    require('../../models/property/voucherLine.model')(propertyDb, DataTypes);
models.business_loans =
    require('../../models/property/businessLoan.model')(propertyDb, DataTypes);
models.capital_assets =
    require('../../models/property/capitalAsset.model')(propertyDb, DataTypes);

Object.values(models).forEach((model: any) => {
    if (typeof model?.associate === 'function') {
        model.associate(models);
    }
});

// Enforce request-scoped outlet context automatically on all database queries and writes
function hasOutletIdCondition(where: any): boolean {
    if (!where) return false;
    if (where.outlet_id !== undefined) return true;
    if (Array.isArray(where)) {
        return where.some(cond => hasOutletIdCondition(cond));
    }
    if (typeof where === 'object') {
        const symbols = Object.getOwnPropertySymbols(where);
        for (const sym of symbols) {
            if (Array.isArray(where[sym])) {
                if (where[sym].some((cond: any) => hasOutletIdCondition(cond))) return true;
            }
        }
    }
    return false;
}

function applyOutletFilter(options: any, outletId: string | number) {
    if (!options) return;
    if (options.bypassOutletFilter) return;

    if (options.model && options.model.rawAttributes && options.model.rawAttributes.outlet_id) {
        if (!hasOutletIdCondition(options.where)) {
            if (!options.where) {
                options.where = { outlet_id: outletId };
            } else if (Array.isArray(options.where)) {
                options.where.push({ outlet_id: outletId });
            } else if (typeof options.where === 'object') {
                options.where.outlet_id = outletId;
            }
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

(propertyDb as any).addHook('beforeFind', (options: any) => {
    if (options.bypassOutletFilter) return;
    const store = contextStorage.getStore();
    const outletId = store?.get('outlet_id');
    if (outletId) {
        applyOutletFilter(options, outletId);
    }
});

(propertyDb as any).addHook('beforeCreate', (instance: any, options: any) => {
    if (options.bypassOutletFilter) return;
    const store = contextStorage.getStore();
    const outletId = store?.get('outlet_id');
    if (outletId && instance.constructor.rawAttributes && instance.constructor.rawAttributes.outlet_id) {
        if (!instance.outlet_id) {
            instance.outlet_id = outletId;
        }
    }
});

(propertyDb as any).addHook('beforeBulkCreate', (instances: any[], options: any) => {
    if (options.bypassOutletFilter) return;
    const store = contextStorage.getStore();
    const outletId = store?.get('outlet_id');
    if (outletId) {
        instances.forEach(instance => {
            if (instance.constructor.rawAttributes && instance.constructor.rawAttributes.outlet_id) {
                if (!instance.outlet_id) {
                    instance.outlet_id = outletId;
                }
            }
        });
    }
});

(propertyDb as any).addHook('beforeBulkUpdate', (options: any) => {
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

(propertyDb as any).addHook('beforeBulkDestroy', (options: any) => {
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
export default propertyDb;
