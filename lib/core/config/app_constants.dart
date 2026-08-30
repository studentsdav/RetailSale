import '../auth/token_storage.dart';
import '../permissions/module_capability.dart';

class AppConstants {
  // APP
  static const appName = 'FAMALTH LYNX';
  static const appVersion = '1.0.0';

  // ROLES (must match backend)
  static const roleAdmin = 'ADMIN';
  static const roleManager = 'MANAGER';
  static const roleReception = 'RECEPTIONIST';
  static const roleCashier = 'CASHIER';
  static const roleStore = 'STORE';
  static const roleRetail = 'RETAIL';
  static const roleAccounts = 'ACCOUNTS';
  static const roleHr = 'HR';
  static const roleWaiter = 'WAITER';
  static const roleCaptain = 'CAPTAIN';
  static const roleKds = 'KDS';
  static const roleMarketing = 'MARKETING';

  static const List<String> availableRoles = [
    'ADMIN',
    'MANAGER',
    'STORE',
    'RETAIL',
    'CASHIER',
    'ACCOUNTS',
    'HR',
    'WAITER',
    'CAPTAIN',
    'KDS',
    'MARKETING',
  ];

  static List<String> getRolesForModule(String? module) {
    final mod = (module ?? 'ALL').toUpperCase().trim();
    if (mod == 'INVENTORY') {
      return ['ADMIN', 'MANAGER', 'STORE', 'ACCOUNTS', 'HR', 'MARKETING'];
    }
    if (mod == 'RETAIL') {
      return ['ADMIN', 'MANAGER', 'STORE', 'RETAIL', 'CASHIER', 'ACCOUNTS', 'HR', 'MARKETING'];
    }
    if (mod == 'RESTAURANT' || mod == 'HOTEL' || mod == 'CAPTAIN' || mod == 'KDS') {
      return ['ADMIN', 'MANAGER', 'STORE', 'CASHIER', 'ACCOUNTS', 'HR', 'WAITER', 'CAPTAIN', 'KDS', 'MARKETING'];
    }
    return availableRoles;
  }

  static List<String> getDefaultPermissionsForRole(String role, [String? module]) {
    final r = role.toUpperCase().trim();
    List<String> raw;
    switch (r) {
      case 'ADMIN':
        raw = [
          'ITEM_REQUEST', 'PURCHASE_ORDER', 'STOCK_IN', 'STOCK_OUT', 'STOCK_TRANSFER',
          'PRODUCT_ASSEMBLY', 'RETURN', 'RETURN_ISSUE', 'SUPPLIER_RETURN', 'DAMAGE',
          'ITEM_MASTER', 'SUPPLIER_MASTER', 'STOCK_LOCATION', 'SUBMISSIONS_STATUS',
          'ITEM_BARCODE_MANAGER', 'APPROVAL_CENTER', 'RETAIL_SALES', 'ENTERPRISE_POS',
          'REPRINT_SALES_BILL', 'MODIFY_SALES_BILL', 'MODIFY_SALES_PAYMENT', 'CUSTOMER_LIST',
          'CUSTOMER_APP', 'RETAILER_CONSOLE', 'RIDER_PORTAL', 'SUPPLIER_PAYMENT',
          'SUPPLIER_RETURN_REFUND', 'PENDING_REFUNDS', 'CASH_LEDGER', 'FINANCE_HUB',
          'ACCOUNTING_VOUCHERS', 'BANK_ACCOUNTS', 'LOAN_EMI', 'CREDIT_ANALYSIS',
          'EXPENSE_ANALYTICS', 'CASHIER_HANDOVER', 'NIGHT_AUDIT', 'HR_PAYROLL',
          'RETAIL_SALES_REPORT', 'CLOSING_REPORT', 'STOCK_LEDGER_REPORT', 'VENDOR_PAYMENT_REPORT',
          'PURCHASE_REPORT', 'RETURN_REPORT', 'REQUEST_REPORT', 'DAMAGE_REPORT',
          'MODIFY_REQUEST', 'MODIFY_PURCHASE', 'MODIFY_RECEIVING', 'MODIFY_ISSUE',
          'REPRINT_REQUEST', 'REPRINT_PURCHASE', 'REPRINT_RECEIVING', 'REPRINT_ISSUE',
          'HR_EMPLOYEES', 'HR_ATTENDANCE', 'HR_MASTERS', 'PAY_SCHEDULE',
          'RESTAURANT_CONSOLE', 'RESTAURANT_FLOOR_DESIGN', 'RESTAURANT_KDS',
          'RESTAURANT_SETUP', 'RESTAURANT_ANALYTICS', 'DELIVERY_CHALLANS', 'RECURRING_EXPENSES',
          'TABLE_RESERVATIONS', 'RUNNING_ORDERS', 'KOTS_HISTORY', 'WHATSAPP_INTEGRATION',
          'LUCKY_DRAW', 'PROMO_VOUCHERS', 'HAPPY_HOUR', 'COMMISSION_RULES', 'STOCK_BALANCE',
          'ITEM_ADVANCE_REPORT', 'OPERATIONS_INTELLIGENCE', 'DAMAGE_SUMMARY',
          'STOCK_IN_REPORT', 'STOCK_OUT_REPORT', 'STOCK_TRANSFER_REPORT', 'SUBSCRIPTION_REPORT',
          'SCHEME_REPORT', 'SCHEME_ANALYSIS', 'LOYALTY_REPORT', 'STORE_ANALYSIS',
          'BRAND_ANALYSIS', 'SOURCE_ANALYSIS', 'COMMISSION_REPORT', 'PAYMENT_ANALYSIS',
          'AI_QUERY_ANALYTICS', 'LYNX_TESTING', 'AUTONOMOUS_AGENT', 'PROPERTY_INFORMATION',
          'NUMBERING_SETTINGS', 'SETTINGS', 'SYSTEM_UPDATE', 'SMTP_SETTINGS',
          'WORKFLOW_AUTOMATION', 'DEVELOPER_ECOSYSTEM', 'PLUGIN_MARKETPLACE',
          'USER_MANAGEMENT', 'LOYALTY_PROGRAM'
        ];
        break;
      case 'MANAGER':
        raw = [
          'ITEM_REQUEST', 'PURCHASE_ORDER', 'STOCK_IN', 'STOCK_OUT', 'STOCK_TRANSFER',
          'PRODUCT_ASSEMBLY', 'RETURN', 'RETURN_ISSUE', 'SUPPLIER_RETURN', 'DAMAGE',
          'ITEM_MASTER', 'SUPPLIER_MASTER', 'STOCK_LOCATION', 'SUBMISSIONS_STATUS',
          'ITEM_BARCODE_MANAGER', 'APPROVAL_CENTER', 'RETAIL_SALES', 'ENTERPRISE_POS',
          'REPRINT_SALES_BILL', 'MODIFY_SALES_BILL', 'MODIFY_SALES_PAYMENT', 'CUSTOMER_LIST',
          'CUSTOMER_APP', 'RETAILER_CONSOLE', 'RIDER_PORTAL', 'SUPPLIER_PAYMENT',
          'SUPPLIER_RETURN_REFUND', 'PENDING_REFUNDS', 'CASH_LEDGER',
          'RETAIL_SALES_REPORT', 'CLOSING_REPORT', 'STOCK_LEDGER_REPORT', 'VENDOR_PAYMENT_REPORT',
          'PURCHASE_REPORT', 'RETURN_REPORT', 'REQUEST_REPORT', 'DAMAGE_REPORT',
          'HR_EMPLOYEES', 'HR_ATTENDANCE', 'HR_MASTERS', 'PAY_SCHEDULE',
          'RESTAURANT_CONSOLE', 'RESTAURANT_FLOOR_DESIGN', 'RESTAURANT_KDS',
          'RESTAURANT_ANALYTICS', 'DELIVERY_CHALLANS', 'RECURRING_EXPENSES',
          'TABLE_RESERVATIONS', 'RUNNING_ORDERS', 'KOTS_HISTORY', 'WHATSAPP_INTEGRATION',
          'PROMO_VOUCHERS', 'HAPPY_HOUR', 'COMMISSION_RULES', 'STOCK_BALANCE',
          'ITEM_ADVANCE_REPORT', 'OPERATIONS_INTELLIGENCE', 'DAMAGE_SUMMARY',
          'SCHEME_REPORT', 'SCHEME_ANALYSIS', 'SUBSCRIPTION_REPORT', 'LOYALTY_PROGRAM',
          'LOYALTY_REPORT', 'STORE_ANALYSIS', 'BRAND_ANALYSIS', 'SOURCE_ANALYSIS',
          'COMMISSION_REPORT', 'PAYMENT_ANALYSIS', 'SMTP_SETTINGS'
        ];
        break;
      case 'STORE':
        raw = [
          'ITEM_REQUEST', 'PURCHASE_ORDER', 'STOCK_IN', 'STOCK_OUT', 'STOCK_TRANSFER',
          'PRODUCT_ASSEMBLY', 'RETURN', 'RETURN_ISSUE', 'SUPPLIER_RETURN', 'DAMAGE',
          'ITEM_MASTER', 'SUPPLIER_MASTER', 'STOCK_LOCATION', 'SUBMISSIONS_STATUS',
          'ITEM_BARCODE_MANAGER', 'APPROVAL_CENTER', 'MODIFY_REQUEST', 'MODIFY_PURCHASE',
          'MODIFY_RECEIVING', 'MODIFY_ISSUE', 'REPRINT_REQUEST', 'REPRINT_PURCHASE',
          'REPRINT_RECEIVING', 'REPRINT_ISSUE', 'STOCK_BALANCE', 'ITEM_ADVANCE_REPORT',
          'OPERATIONS_INTELLIGENCE', 'DAMAGE_SUMMARY', 'STOCK_IN_REPORT', 'STOCK_OUT_REPORT',
          'STOCK_TRANSFER_REPORT', 'DAMAGE_REPORT', 'REQUEST_REPORT', 'PURCHASE_REPORT',
          'DELIVERY_CHALLANS', 'RECURRING_EXPENSES'
        ];
        break;
      case 'RETAIL':
        raw = [
          'RETAIL_SALES', 'ENTERPRISE_POS', 'REPRINT_SALES_BILL', 'CUSTOMER_LIST',
          'CUSTOMER_APP', 'RETAILER_CONSOLE', 'RIDER_PORTAL', 'RETAIL_SALES_REPORT',
          'CLOSING_REPORT', 'ITEM_REQUEST', 'SUBMISSIONS_STATUS', 'LUCKY_DRAW',
          'DELIVERY_CHALLANS', 'RECURRING_EXPENSES', 'SETTINGS'
        ];
        break;
      case 'CASHIER':
        raw = [
          'RETAIL_SALES', 'ENTERPRISE_POS', 'REPRINT_SALES_BILL', 'MODIFY_SALES_BILL',
          'MODIFY_SALES_PAYMENT', 'RESTAURANT_CONSOLE', 'RETAIL_SALES_REPORT', 'CLOSING_REPORT',
          'CASH_LEDGER', 'PENDING_REFUNDS', 'CASHIER_HANDOVER', 'DELIVERY_CHALLANS',
          'RECURRING_EXPENSES', 'SETTINGS'
        ];
        break;
      case 'ACCOUNTS':
        raw = [
          'SUPPLIER_PAYMENT', 'SUPPLIER_RETURN_REFUND', 'PENDING_REFUNDS', 'CASH_LEDGER',
          'FINANCE_HUB', 'ACCOUNTING_VOUCHERS', 'BANK_ACCOUNTS', 'LOAN_EMI',
          'CREDIT_ANALYSIS', 'EXPENSE_ANALYTICS', 'NIGHT_AUDIT', 'HR_PAYROLL',
          'RETAIL_SALES_REPORT', 'CLOSING_REPORT', 'STOCK_LEDGER_REPORT', 'VENDOR_PAYMENT_REPORT',
          'PURCHASE_REPORT', 'RETURN_REPORT', 'REQUEST_REPORT', 'DAMAGE_REPORT',
          'PAYMENT_ANALYSIS', 'STORE_ANALYSIS', 'COMMISSION_REPORT', 'DELIVERY_CHALLANS',
          'RECURRING_EXPENSES'
        ];
        break;
      case 'HR':
        raw = [
          'HR_EMPLOYEES', 'HR_ATTENDANCE', 'HR_MASTERS', 'PAY_SCHEDULE', 'HR_PAYROLL',
          'CASHIER_HANDOVER'
        ];
        break;
      case 'WAITER':
        raw = [
          'RESTAURANT_CONSOLE', 'ITEM_REQUEST', 'SUBMISSIONS_STATUS'
        ];
        break;
      case 'CAPTAIN':
        raw = [
          'RESTAURANT_CONSOLE', 'RESTAURANT_FLOOR_DESIGN', 'REPRINT_SALES_BILL',
          'ITEM_REQUEST', 'SUBMISSIONS_STATUS', 'DELIVERY_CHALLANS', 'RECURRING_EXPENSES',
          'TABLE_RESERVATIONS'
        ];
        break;
      case 'KDS':
        raw = [
          'RESTAURANT_KDS'
        ];
        break;
      case 'MARKETING':
        raw = [
          'WHATSAPP_INTEGRATION', 'LUCKY_DRAW', 'PROMO_VOUCHERS', 'HAPPY_HOUR',
          'COMMISSION_RULES', 'SCHEME_REPORT', 'SCHEME_ANALYSIS', 'SUBSCRIPTION_REPORT',
          'LOYALTY_PROGRAM', 'LOYALTY_REPORT', 'STORE_ANALYSIS', 'RESTAURANT_ANALYTICS',
          'BRAND_ANALYSIS', 'SOURCE_ANALYSIS', 'COMMISSION_REPORT'
        ];
        break;
      default:
        raw = [
          'ITEM_REQUEST', 'SUBMISSIONS_STATUS'
        ];
        break;
    }

    if (module != null && module.isNotEmpty) {
      return raw.where((p) => ModuleCapability.isPermissionAllowed(p, module)).toList();
    }
    return raw;
  }

  static double getDefaultMaxDiscountForRole(String role) {
    final r = role.toUpperCase().trim();
    switch (r) {
      case 'ADMIN':
        return 100.0;
      case 'STORE':
        return 20.0;
      case 'RETAIL':
        return 15.0;
      case 'CASHIER':
        return 10.0;
      case 'ACCOUNTS':
        return 25.0;
      case 'HR':
        return 10.0;
      case 'WAITER':
        return 5.0;
      case 'CAPTAIN':
        return 15.0;
      case 'KDS':
        return 0.0;
      case 'MARKETING':
        return 25.0;
      default:
        return 10.0;
    }
  }

  static Future<double> getEffectiveUserMaxDiscount() async {
    final userMap = await TokenStorage.getUser();
    if (userMap != null && userMap['max_discount_percent'] != null) {
      final val = userMap['max_discount_percent'];
      final customDisc = val is num
          ? val.toDouble()
          : (double.tryParse(val.toString()) ?? 100.0);
      return customDisc;
    }
    final role = (await TokenStorage.getRole()) ?? 'CASHIER';
    return getDefaultMaxDiscountForRole(role);
  }

  // MODULES (license-based)
  static const moduleInventory = 'INVENTORY';
  static const modulePurchase = 'PURCHASE';
  static const moduleReports = 'REPORTS';
  static const moduleUsers = 'USERS';

  // DATE FORMAT
  static const dateFormat = 'dd-MM-yyyy';
  static const dateTimeFormat = 'dd-MM-yyyy HH:mm';

  // UI
  static const desktopWidth = 900;
}
