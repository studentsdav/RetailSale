import 'package:flutter/material.dart';

// Inventory & POS Screens
import '../../screens/inventory/salescreen.dart';
import '../../screens/inventory/enterprise_pos_screen.dart';
import '../../screens/inventory/item_master_screen.dart';
import '../../screens/inventory/stock_transfer_screen.dart';
import '../../screens/inventory/stock_issue_screen.dart';
import '../../screens/inventory/stock_request_screen.dart';
import '../../screens/inventory/damage_item_screen.dart';
import '../../screens/inventory/assembly_screen.dart';
import '../../screens/inventory/purchase_order_screen.dart';
import '../../screens/inventory/goods_receiving_screen.dart';
import '../../screens/inventory/supplier_master_screen.dart';
import '../../screens/inventory/supplier_return_screen.dart';
import '../../screens/inventory/return_issue_screen.dart';
import '../../screens/inventory/subscription_screen.dart';
import '../../screens/inventory/item_barcode_manager_screen.dart';
import '../../screens/inventory/approval_center_screen.dart';
import '../../screens/inventory/customer_list_screen.dart';
import '../../controllers/inventory/item_controller.dart';

// Reports Screens
import '../../screens/reports/sales_report_screen.dart';
import '../../screens/reports/closing_report_screen.dart';
import '../../screens/reports/cash_ledger_screen.dart';
import '../../screens/reports/stock_ledger_report_screen.dart';
import '../../screens/reports/stock_balance_screen.dart';
import '../../screens/reports/ai_query_analytics_screen.dart';
import '../../screens/reports/operations_intelligence_screen.dart';
import '../../screens/reports/subscription_report_screen.dart';
import '../../screens/reports/credit_analysis_screen.dart';
import '../../screens/reports/loyalty_report_screen.dart';
import '../../screens/reports/expense_analytics_screen.dart';
import '../../screens/reports/supplier_payment_screen.dart';
import '../../controllers/reports/finance_hub_controller.dart';

// HRMS Screens
import '../../screens/hrms/employee_screen.dart';
import '../../screens/hrms/attendance_screen.dart';
import '../../screens/hrms/payroll_screen.dart';
import '../../screens/hrms/hrms_masters_screen.dart';

// Restaurant Screens
import '../../screens/restaurant/captain_dashboard_screen.dart';
import '../../screens/restaurant/restaurant_setup_screen.dart';
import '../../screens/restaurant/kds_screen.dart';
import '../../screens/restaurant/delivery_challan_screen.dart';
import '../../screens/restaurant/recurring_expenses_screen.dart';

// Settings & Auth Screens
import '../../screens/settings/whatsapp_dashboard_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../screens/settings/property_info_screen.dart';
import '../../screens/settings/workflow_automation_screen.dart';
import '../../screens/settings/developer_ecosystem_screen.dart';
import '../../screens/settings/plugin_marketplace_screen.dart';
import '../../screens/settings/help_screen.dart';
import '../../screens/settings/loyalty_master_config_screen.dart';
import '../../screens/settings/happy_hour_config_screen.dart';
import '../../screens/settings/document_sequence_screen.dart';
import '../../screens/settings/stock_location_screen.dart';
import '../../screens/auth/user_management_screen.dart';
import '../../screens/dashboard/autonomous_agent_screen.dart';
import '../../screens/dashboard/lynx_feature_testing_screen.dart';
import '../../screens/dashboard/customer_app_screen.dart';

/// Authoritative AI Navigation Registry for FAMALTH LYNX.
/// Maps every AI action type code to its target Flutter screen.
class AiNavigationRegistry {
  static bool navigate(BuildContext context, String actionType, Map<String, dynamic>? payload) {
    Widget? targetScreen;

    switch (actionType.toUpperCase()) {
      // 0. Customer Subscriptions (Milk & Daily Consumables)
      case 'MANAGE_SUBSCRIPTIONS':
      case 'SUBSCRIPTION_DASHBOARD':
      case 'SUBSCRIPTIONS':
        targetScreen = const SubscriptionScreen();
        break;

      case 'SUBSCRIPTION_REPORTS':
      case 'SUBSCRIPTION_LOGS':
        targetScreen = const SubscriptionReportScreen();
        break;

      // 1. POS & Billing Counter
      case 'CREATE_BILL':
      case 'POS':
        targetScreen = const SaleScreen();
        break;

      case 'ENTERPRISE_POS':
        targetScreen = const EnterprisePosDemoScreen();
        break;

      // 2. Inventory & Stock Management
      case 'SEARCH_ITEM':
      case 'ITEM_MASTER':
        targetScreen = const ItemMasterScreen();
        break;

      case 'LOW_STOCK_ALERT':
      case 'STOCK_BALANCE':
        targetScreen = const StockBalanceScreen();
        break;

      case 'STOCK_TRANSFER':
        targetScreen = const StockTransferScreen();
        break;

      case 'STOCK_ISSUE':
        targetScreen = const StockIssueScreen();
        break;

      case 'STOCK_REQUEST':
        targetScreen = const StockRequestScreen();
        break;

      case 'DAMAGE_ITEMS':
      case 'DAMAGE_LOG':
        targetScreen = const DamageItemScreen();
        break;

      case 'ASSEMBLY_BOM':
        targetScreen = const AssemblyScreen();
        break;

      case 'ITEM_BARCODE':
      case 'BARCODE_MANAGER':
        targetScreen = ItemBarcodeManagerScreen(
          items: const [],
          itemController: ItemController(),
          onItemsUpdated: (_) {},
        );
        break;

      case 'APPROVAL_CENTER':
        targetScreen = const ApprovalCenterScreen();
        break;

      case 'CUSTOMER_LIST':
        targetScreen = const CustomerListScreen();
        break;

      // 3. Purchasing & Supplier Management
      case 'CREATE_PO':
      case 'PURCHASE_ORDER':
        targetScreen = const PurchaseOrderScreen();
        break;

      case 'GRN':
      case 'GOODS_RECEIPT':
        targetScreen = const GoodsReceivingScreen();
        break;

      case 'SUPPLIER_MASTER':
        targetScreen = const SupplierMasterScreen();
        break;

      case 'SUPPLIER_PAYMENTS':
        targetScreen = const SupplierPaymentScreen();
        break;

      case 'SUPPLIER_RETURN':
        targetScreen = const SupplierReturnScreen();
        break;

      case 'SALES_RETURN':
        targetScreen = const ReturnIssueScreen();
        break;

      // 4. Sales & Financial Reports
      case 'VIEW_REPORTS':
      case 'SALES_REPORTS':
        targetScreen = const SalesReportScreen();
        break;

      case 'CLOSING_REPORT':
        targetScreen = const ClosingReportScreen();
        break;

      case 'CASH_LEDGER':
        targetScreen = const CashLedgerScreen();
        break;

      case 'STOCK_LEDGER':
      case 'STOCK_LEDGER_REPORT':
        targetScreen = const StockLedgerReportScreen();
        break;

      case 'CREDIT_ANALYSIS':
        targetScreen = const CreditAnalysisScreen();
        break;

      case 'LOYALTY_REPORT':
        targetScreen = const LoyaltyReportScreen();
        break;

      case 'EXPENSE_ANALYTICS':
        targetScreen = ExpenseAnalyticsScreen(ctrl: FinanceHubController());
        break;

      // 5. HRMS & Staff
      case 'EMPLOYEES':
        targetScreen = const EmployeeScreen();
        break;

      case 'ATTENDANCE':
        targetScreen = const AttendanceScreen();
        break;

      case 'PAYROLL':
        targetScreen = const PayrollScreen();
        break;

      case 'HRMS_MASTERS':
        targetScreen = const HrmsMastersScreen();
        break;

      // 6. Restaurant & Dining POS
      case 'CAPTAIN_POS':
        targetScreen = const CaptainDashboardScreen();
        break;

      case 'RESTAURANT_SETUP':
        targetScreen = const RestaurantSetupScreen();
        break;

      case 'KDS':
        targetScreen = const KdsScreen();
        break;

      case 'DELIVERY_CHALLAN':
        targetScreen = const DeliveryChallanScreen();
        break;

      case 'RECURRING_EXPENSES':
        targetScreen = const RecurringExpensesScreen();
        break;

      // 7. System & Marketing Settings
      case 'WHATSAPP':
        targetScreen = const WhatsAppDashboardScreen();
        break;

      case 'USER_MANAGEMENT':
        targetScreen = const UserManagementScreen();
        break;

      case 'SYSTEM_SETTINGS':
        targetScreen = const SettingsScreen();
        break;

      case 'PROPERTY_INFO':
        targetScreen = const PropertyInfoScreen(outletid: 0);
        break;

      case 'AI_ANALYTICS':
        targetScreen = const AiQueryAnalyticsScreen();
        break;

      case 'OPERATIONS_INTELLIGENCE':
        targetScreen = const OperationsIntelligenceScreen();
        break;

      case 'WORKFLOW_AUTOMATION':
        targetScreen = const WorkflowAutomationScreen();
        break;

      case 'AUTONOMOUS_AGENT':
        targetScreen = const AutonomousAgentScreen();
        break;

      case 'DEVELOPER_ECOSYSTEM':
        targetScreen = const DeveloperEcosystemScreen();
        break;

      case 'PLUGIN_MARKETPLACE':
        targetScreen = const PluginMarketplaceScreen();
        break;

      case 'FEATURE_TESTING_HUB':
        targetScreen = const LynxFeatureTestingScreen();
        break;

      case 'CUSTOMER_LOOKUP':
        targetScreen = const CustomerAppScreen();
        break;

      case 'HELP_SUPPORT':
        targetScreen = const HelpScreen();
        break;

      case 'LOYALTY_CONFIG':
        targetScreen = const LoyaltyMasterConfigScreen();
        break;

      case 'HAPPY_HOUR':
        targetScreen = const HappyHourConfigScreen();
        break;

      case 'DOCUMENT_SEQUENCE':
        targetScreen = const DocumentSequenceScreen();
        break;

      case 'STOCK_LOCATION':
        targetScreen = const StockLocationScreen();
        break;

      default:
        return false;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => targetScreen!),
    );
    return true;
  }
}
