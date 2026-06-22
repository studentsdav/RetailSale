class ApiEndpoints {
  static const login = '/api/auth/login';

  static const items = '/api/inventory/items';
  static const stockTransfer = '/api/inventory/stock-transfer';

  static const propertyInfo = '/api/inventory/property-info';

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

  static const stockBalance = '/api/reports/stock-balance';

  static const purReport = '/api/reports/purchase-orders';

  static const returnReport = '/api/reports/return';
  static const supplierPaymentsReport = '/api/reports/supplier-payments';

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
}
