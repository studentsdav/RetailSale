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

propertyDb.models.sales_items =
    require('../../models/property/salesItem.model')(propertyDb, DataTypes);

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

propertyDb.models.app_branding =
    require('../../models/property/appBranding.model')(propertyDb, DataTypes);


propertyDb.models.cash_ledger =
    require('../../models/property/cashLedger.model')(propertyDb, DataTypes);

propertyDb.models.expense_entries =
    require('../../models/property/expenseEntry.model')(propertyDb, DataTypes);

propertyDb.models.item_groups =
    require('../../models/property/group.model')(propertyDb, DataTypes);

// AUDIT & STOCK
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


Object.values(propertyDb.models).forEach(model => {
    if (typeof model.associate === 'function') {
        model.associate(propertyDb.models);
    }
});

module.exports = propertyDb;
