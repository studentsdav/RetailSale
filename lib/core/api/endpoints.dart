class ApiEndpoints {
  /// Trusted server time — no auth required. Flutter anchors its internal clock here.
  static const serverTime = '/api/system/server-time';

  static const login = '/api/auth/login';

  static const items = '/api/inventory/items';
  static const stockTransfer = '/api/inventory/stock-transfer';

  static const propertyInfo = '/api/inventory/property-info';
  static const userNotes = '/api/notes';

  static const checkOutlet = '/api/public/outlet/check';

  static const String verifyPin = '/api/public/recovery/verify-pin';
  static const String requestOtp = '/api/public/recovery/request-otp';
  static const String verifyOtp = '/api/public/recovery/verify-otp';
  static const String executeRecovery = '/api/public/recovery/execute';
  static const String sendSetpOtp = '/api/public/setup/request-otp';
  static const String verifySetpOtp = '/api/public/setup/verify-otp';
  static const String verifyAndRecoverConfig =
      '/api/public/verify-and-download';
  static const String triggerAutoReinstall = '/api/public/trigger-reinstall';
  static const createOutlet = '/api/public/outlet';
  static const updateOutletModule = '/api/public/outlet/module';

  static const stockLocations = '/api/inventory/locations';

  static const suppliers = '/api/inventory/suppliers';

  static const documentSequence = '/api/inventory/numbering';

  static const users = '/api/users';

  static const backupStatus = '/api/inventory/status';
  static const toggleBackup = '/api/inventory/toggle';
  static const syncLatest = '/api/inventory/sync-latest';
  static const uploadLatest = '/api/inventory/backup/upload-latest';
  static const localEncBackup = '/api/inventory/backup/local-enc';
  static const restoreLocalEncBackup = '/api/inventory/backup/restore-local-enc';

  static const String settings = '/api/inventory/settings';
  static const String appBranding = '/api/inventory/branding';

  static const purchaseOrders = '/api/purchase-orders';

  static const receiving = '/api/receiving';

  static const issue = '/api/inventory/issue';

  static const damage = '/api/inventory/damage';

  static const returns = '/api/inventory/returns';

  static const closingReport = '/api/reports/closing';
  static const nightAuditStatus = '/api/night-audit/status';
  static const nightAuditValidate = '/api/night-audit/validate';
  static const nightAuditExecute = '/api/night-audit/execute';
  static const nightAuditHistory = '/api/night-audit/history';

  static const stockBalance = '/api/reports/stock-balance';

  static const purReport = '/api/reports/purchase-orders';

  static const returnReport = '/api/reports/return';
  static const supplierPaymentsReport = '/api/reports/supplier-payments';
  static const commissionReport = '/api/reports/commission';

  static const requestReport = '/api/reports/request';

  static const damageReport = '/api/reports/damage';

  static const damagesumReport = '/api/reports/dmgsummery';

  static const stockInReport = '/api/reports/stock-in';

  static const stockOutReport = '/api/reports/stock-out';

  static const stockTransferReport = '/api/reports/stock-transfer';

  static const supplierAvailableCredit = '/api/suppliers';
  static const supplierBills = '/api/suppliers/bills/list';
  static const supplierBillDetails = '/api/suppliers/bills';

  static const requests = '/api/inventory/requests';
  static const financeLedger = '/api/finance/ledger';
  static const financeExpenses = '/api/finance/expenses';
  static const financeExpenseCategories = '/api/finance/expense-categories';
  static const financeTaxesMaster = '/api/finance/taxes-master';
  static const financeExpenseAnalytics = '/api/finance/expense-analytics';
  static const financeIncome = '/api/finance/income';
  static const financeWithdrawals = '/api/finance/withdrawals';
  static const financeRepayments = '/api/finance/repayments';
  static const financeAdvances = '/api/finance/advances';
  static const financeApplyAdvance = '/api/finance/advances/apply';
  static const financeOpeningBalance = '/api/finance/opening-balance';
  static const financeCreditReport = '/api/finance/credit-report';
  static const financeDeliveryReport = '/api/finance/delivery-report';
  static const financeExpiryReport = '/api/finance/expiry-report';
  static const paySupplierBill = '/api/suppliers/bills/pay';
  static const sales = '/api/sales';
  static const commissionRules = '/api/sales/commission-rules';
  static const salesSchemes = '/api/sales/schemes';
  static const salesCustomers = '/api/sales/customers';
  static const salesRefunds = '/api/sales/refunds';
  static const salesPayRefund = '/api/sales/refunds/pay';
  static const salesSubscriptions = '/api/sales/subscriptions';
  static const salesSubscriptionCustomer = '/api/sales/subscriptions/customer';
  static const salesVouchers = '/api/sales/vouchers';
  static const salesValidateVoucher = '/api/sales/validate-voucher';
  static const salesLoyaltyConfig = '/api/sales/loyalty/config';
  static const salesLoyaltyCustomerSummary =
      '/api/sales/loyalty/customer-summary';
  static const salesReport = '/api/reports/sales';
  static const loyaltyMasterReport = '/api/reports/loyalty/master';
  static const loyaltyLedgerReport = '/api/reports/loyalty/ledger';
  static const analyticsRfmSegments = '/api/analytics/rfm-segments';
  static const analyticsSalesTrend = '/api/analytics/sales-trend';
  static const analyticsMarketBasket = '/api/analytics/market-basket';
  static const analyticsTopCustomerItems = '/api/analytics/top-customer-items';
  static const aiQuery = '/api/analytics/query';
  static const aiQueryExportCsv = '/api/analytics/export/csv';
  static const aiQueryExportPdf = '/api/analytics/export/pdf';
  static const schemeReport = '/api/reports/scheme-report';
  static const schemeCycleDetail = '/api/reports/scheme-cycle-detail';
  static const String requestPasswordResetOtp =
      '/api/public/emergency-reset/request-otp';
  static const String verifyAndResetPassword =
      '/api/public/emergency-reset/verify-and-reset';
  static const String recoverUsername =
      '/api/public/emergency-reset/recover-username';

  // WhatsApp Integration Endpoints
  static const String whatsappConfig = '/api/whatsapp/config';
  static const String whatsappTemplates = '/api/whatsapp/templates';
  static const String whatsappCampaigns = '/api/whatsapp/campaigns';
  static const String whatsappLogs = '/api/whatsapp/logs';
  static const String whatsappAudience = '/api/whatsapp/campaigns/audience';
  static const String whatsappBilling = '/api/whatsapp/billing/dashboard';

  // Sale Sources & Payment Methods
  static const saleSources = '/api/sales/sources';
  static const paymentMethods = '/api/sales/payment-methods';

  // HRMS Endpoints
  static const hrmsEmployees = '/api/hrms/employees';
  static const hrmsAttendance = '/api/hrms/attendance';
  static const hrmsLeaves = '/api/hrms/leaves';
  static const hrmsShifts = '/api/hrms/shifts';
  static const hrmsLeaveTypes = '/api/hrms/leave-types';
  static const hrmsDesignations = '/api/hrms/designations';
  static const hrmsPayStructures = '/api/hrms/pay-structures';
  static const hrmsSalaryComponents = '/api/hrms/salary-components';
  static const hrmsLoans = '/api/hrms/loans';
  static const hrmsPayroll = '/api/hrms/payroll';
  static const hrmsPayrollHistory = '/api/hrms/payroll/history';
  static const hrmsPayrollSettings = '/api/hrms/payroll/settings';
  static const hrmsHandover = '/api/hrms/handover';
  static const hrmsHandovers = '/api/hrms/handovers';

  // Restaurant & Core Addon Endpoints
  static const String restaurantFloors = '/api/restaurant/floors';
  static const String restaurantDiningAreas = '/api/restaurant/dining-areas';
  static const String restaurantTableTypes = '/api/restaurant/table-types';
  static const String restaurantTables = '/api/restaurant/tables';
  static const String restaurantReservations = '/api/restaurant/reservations';
  static const String restaurantPrinters = '/api/restaurant/printers';
  static const String restaurantKitchenStations = '/api/restaurant/kitchen-stations';
  static const String restaurantKots = '/api/restaurant/kots';
  static const String restaurantChallans = '/api/restaurant/challans';
  static const String emailConfigurations = '/api/restaurant/email-configurations';
  static const String emailTemplates = '/api/restaurant/email-templates';
  static const String recurringExpenses = '/api/finance/recurring-expenses';

  // LYNX ASSIST, GROW, OPERATE, AUTOMATE, AI AGENT & DEVELOPER ECOSYSTEM Endpoints
  static const String lynxAssistChat = '/api/v1/ai/chat';
  static const String lynxAssistVoice = '/api/v1/ai/voice-command';
  static const String cartRecommendations = '/api/v1/intelligence/recommendations';
  static const String customerInsights = '/api/v1/intelligence/customer-insights';
  static const String operationsHealth = '/api/v1/operations/health-snapshot';
  static const String operationsReorderAlerts = '/api/v1/operations/reorder-alerts';
  static const String operationsExpiryAlerts = '/api/v1/operations/expiry-alerts';
  static const String workflowRules = '/api/v1/workflows/rules';
  static const String workflowTrigger = '/api/v1/workflows/trigger';
  static const String agentProposals = '/api/v1/agent/proposals';
  static const String agentAuditLogs = '/api/v1/agent/audit-logs';
  static const String developerInfo = '/api/v1/developer/ecosystem/info';
  static const String developerWebhooks = '/api/v1/developer/webhooks';
  static const String developerApiKeys = '/api/v1/developer/api-keys';
  static const String pluginsMarketplace = '/api/v1/plugins/marketplace';
  static const String pluginsInstalled = '/api/v1/plugins/installed';
  static const String pluginInstall = '/api/v1/plugins/install';
}
