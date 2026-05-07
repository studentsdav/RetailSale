import 'dart:async';

import 'package:flutter/material.dart';
import 'dart:io';
import 'package:inventory/models/security/app_user_model.dart';
import 'package:inventory/screens/dashboard/system_update_screen.dart';
import 'package:inventory/screens/reports/return_report_screen.dart';
import 'package:inventory/screens/settings/settinginv.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../controllers/dashboard/dashboard_controller.dart'
    as UserProfiledata;
import '../../controllers/reports/inventory_dashboard_controller.dart';
import '../../controllers/security/user_controller.dart';
import '../../controllers/settings/notification_services.dart';
import '../../controllers/settings/property_info_controller.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/token_storage.dart';
import '../../core/settings/local_preferences.dart';
import '../../models/auth/permission_service.dart';
import '../../models/common/property_info_model.dart';
import '../auth/inventorylogin.dart' show InventoryLoginScreen;
import '../auth/usermanagementinv.dart';
import '../inventory/damageiteminv.dart';
import '../inventory/issuescreen.dart';
import '../inventory/itemmasterinv.dart';
import '../inventory/purchaseorderinv.dart';
import '../inventory/receiving.dart';
import '../inventory/requestiteminv.dart';
import '../inventory/salescreen.dart';
import '../inventory/returnissueitem.dart';
import '../inventory/subscription_screen.dart';
import '../inventory/supplier_return_refund_screen.dart';
import '../inventory/supplier_return_screen.dart';
import '../inventory/returnissueitem.dart';
import '../inventory/suppliermaster.dart';
import '../modify/purchase_modify.dart';
import '../modify/receiving_modify.dart';
import '../modify/request_modify.dart';
import '../modify/sales_reprint_modify_screen.dart';
import '../modify/stock_out_modify.dart';
import '../recovery/backup_service.dart';
import '../reports/closingreportinv.dart';
import '../reports/cash_ledger_screen.dart';
import '../reports/closingreportinv.dart';
import '../reports/damage_report_screen.dart';
import '../reports/damagereportinv.dart';
import '../reports/purchasereport.dart';
import '../reports/request_report_screen.dart';
import '../reports/scheme_report_screen.dart';
import '../reports/loyalty_report_screen.dart';
import '../reports/subscription_report_screen.dart';
import '../reports/sales_report_screen.dart';
import '../reports/store_analysis_screen.dart';
import '../reports/stock_ledger_report_screen.dart';
import '../reports/stockbalance.dart';
import '../reports/stockinreport.dart';
import '../reports/stockoutreportfo.dart';
import '../reports/supplierpayment.dart';
import '../settings/helpinv.dart';
import '../settings/numbering.dart';
import '../settings/propertyinfoinv.dart';
import '../settings/stocklocationinv.dart';
import '../settings/loyalty_master_config_screen.dart';
import 'notification_screen.dart';

class UserInventoryDashboard extends StatefulWidget {
  const UserInventoryDashboard({super.key});

  @override
  State<UserInventoryDashboard> createState() => _UserInventoryDashboardState();
}

class _UserInventoryDashboardState extends State<UserInventoryDashboard> {
  // USER SESSION

  final DateTime _loginTime =
      DateTime.now().subtract(const Duration(hours: 3, minutes: 20));

  UserProfile? user;
  // ðŸ”¥ SUPPLIER FINANCE DATA
  // KPI
  int todayIn = 24;
  int todayOut = 31;
  int lowStock = 12;
  double stockValue = 642300;
  double totalRevenue = 0;
  double totalProfit = 0;
  double totalLoss = 0;
  double cogsTotal = 0;
  double grossMarginPercent = 0;
  double expenseTotal = 0;
  double withdrawalTotal = 0;
  double customerOutstanding = 0;
  double supplierOutstanding = 0;
  double cashInTotal = 0;
  double cashOutTotal = 0;
  double cashNetTotal = 0;
  double netOperatingProfit = 0;
  final UserController userCtrl = UserController();
  // DATA
  List<String> lowStockItems = [];
  List<_TxnDay> issueReceive7 = [];
  List<_DeptIssue> deptIssue = [];
  List<_DamageDay> damage7 = [];
  List<_CategoryStock> categoryStock = [];
  List<_SupplierPayment> supplierPayments = [];
  List<_UnpaidSupplier> unpaidSuppliers = [];
  List<_HeatmapItem> topHeatmapItems = [];
  List<_TransactionTypeSummary> monthlyTransactionTypes = [];
  Map<String, _GrowthComparison> growthComparisons = {};
  Timer? _notificationTimer;
  String currentVersion = "";
  final InventoryDashboardController dashboardCtrl =
      InventoryDashboardController();
  final propertyCtrl = PropertyInfoController();
  PropertyInfo? property;
  bool _showNotifications = true;
  bool _isSyncing = false;
  String _userRole = '';

  String get _businessType => (user?.outletType ?? '').toUpperCase();
  bool get _isRetailBusiness => _businessType == 'RETAIL';
  bool get _isWarehouseBusiness => _businessType == 'WAREHOUSE';
  bool get _isHospitalityBusiness =>
      const {'HOTEL', 'RESTAURANT', 'CAFE', 'BAR'}.contains(_businessType);
  bool get _showRetailSalesSection =>
      _isRetailBusiness || PermissionService.can('RETAIL_SALES');
  bool get _showRetailSalesReportSection =>
      _isRetailBusiness || PermissionService.can('RETAIL_SALES_REPORT');
  String get _dashboardTitle {
    if (_isWarehouseBusiness) return 'Warehouse Inventory Dashboard';
    if (_isRetailBusiness) return 'Retail Inventory Dashboard';
    if (_isHospitalityBusiness) return 'Department Inventory Dashboard';
    return 'Inventory Dashboard';
  }

  @override
  void initState() {
    super.initState();

    _loadPropertyInfo();

    _loadDashboard();

    _verifyDataProtection();

    _loadNotificationPreference();

    loadUser();

    _loadUserRole();
  }

  Future<void> _performSync() async {
    setState(() => _isSyncing = true);

    try {
      final success = await BackupService.syncLatest();

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Database synced successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to sync database. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _loadUserRole() async {
    final role = await TokenStorage.getRole();

    if (mounted) {
      setState(() {
        _userRole = role!;
      });
    }
  }

  Future<void> _verifyDataProtection() async {
    final alertStatus = await BackupService.checkStatus();

    if (!mounted) return;

    if (alertStatus == 'ENABLE_PROMPT') {
      _showEnableCloudDialog();
    } else if (alertStatus == 'SYNC_FAILED') {
      _showSyncWarningDialog();
    }
  }

// =====================================================================
  // CLOUD OPT-IN
  // =====================================================================
  void _showEnableCloudDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevents accidental dismissal
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: EdgeInsets.zero, // We use custom padding inside
        content: ConstrainedBox(
          constraints: const BoxConstraints(
              maxWidth: 400), // Keeps it looking good on Desktop/Web
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- Header Section ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.cloud_done_outlined,
                        size: 56, color: Colors.blue.shade700),
                    const SizedBox(height: 16),
                    Text(
                      'Secure Your Data',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              // --- Body Section ---
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Text(
                  'Your inventory data is currently stored only on this device. '
                  'Enable automatic Google Drive backups to ensure your business data is protected against hardware failure or loss.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14, height: 1.5, color: Colors.black87),
                ),
              ),
              // --- Action Buttons ---
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          'Remind Me Later',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const SettingsScreen()));
                        },
                        icon: const Icon(Icons.security, size: 18),
                        label: const Text('Enable Backup'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =====================================================================
  //  SYNC WARNING
  // =====================================================================
  void _showSyncWarningDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: EdgeInsets.zero,
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- Header Section ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 56, color: Colors.orange.shade700),
                    const SizedBox(height: 16),
                    Text(
                      'Action Required',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade900,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              // --- Body Section ---
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Text(
                  'Your data has not successfully synced to the cloud in over 24 hours. '
                  'Please check your internet connection to ensure your store data remains safely backed up.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14, height: 1.5, color: Colors.black87),
                ),
              ),
              // --- Action Buttons ---
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.orange.shade700,
                    ),
                    child: const Text('I Understand'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadNotificationPreference() async {
    final value = await LocalPreferences.getShowNotifications();
    if (!mounted) return;
    setState(() => _showNotifications = value);
  }

  Future<void> _loadPropertyInfo() async {
    await propertyCtrl.load();
    property = propertyCtrl.data;
    setState(() {});
  }

  Future<void> loadUser() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    currentVersion = packageInfo.version;
    final u = await UserProfiledata.load();
    try {
      setState(() {
        user = u;
      });

      var token = await TokenStorage.read();

      final bool isTokenValid = token != null && !TokenStorage.isExpired(token);

      if (!isTokenValid) {
        return;
      }

      _notificationTimer?.cancel(); // prevent duplicate timers

      _notificationTimer =
          Timer.periodic(const Duration(minutes: 1), (timer) async {
        final allowNotifications =
            await LocalPreferences.getShowNotifications();
        if (!allowNotifications) {
          return;
        }
        final bool isTokenValid = !TokenStorage.isExpired(token);
        if (!isTokenValid) {
          await TokenStorage.clear();
          _notificationTimer?.cancel();
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const InventoryLoginScreen()));
          return;
        }
        try {
          final res = await ApiClient.get('/api/notifications');
          for (final n in res['data']) {
            if (n['is_read'] == false) {
              NotificationService.show(n['id'], n['title'], n['message']);
            }
          }
        } catch (e) {
          _notificationTimer?.cancel();
        }
      });
    } catch (e) {
      _notificationTimer?.cancel();
    }
  }

  Future<void> _loadDashboard() async {
    try {
      Future.delayed(const Duration(seconds: 1));
      final data = await dashboardCtrl.load();

      int safeInt(dynamic value) {
        if (value is int) return value;
        if (value is num) return value.round();
        return double.tryParse(value?.toString() ?? '')?.round() ?? 0;
      }

      double safeDouble(dynamic value) {
        if (value is double) return value;
        if (value is num) return value.toDouble();
        return double.tryParse(value?.toString() ?? '') ?? 0;
      }

      setState(() {
        // KPI
        todayIn = safeInt(data['kpis']['todayIn']);
        todayOut = safeInt(data['kpis']['todayOut']);
        lowStock = safeInt(data['kpis']['lowStock']);
        stockValue = safeDouble(data['kpis']['stockValue']);
        totalRevenue = safeDouble(data['kpis']['totalRevenue']);
        totalProfit = safeDouble(data['kpis']['grossProfit']);
        totalLoss = safeDouble(data['kpis']['grossLoss']);
        cogsTotal = safeDouble(data['kpis']['cogsTotal']);
        grossMarginPercent = safeDouble(data['kpis']['grossMarginPercent']);
        expenseTotal = safeDouble(data['kpis']['expenseTotal']);
        withdrawalTotal = safeDouble(data['kpis']['withdrawalTotal']);
        customerOutstanding = safeDouble(data['kpis']['customerOutstanding']);
        supplierOutstanding = safeDouble(data['kpis']['supplierOutstanding']);
        cashInTotal = safeDouble(data['kpis']['cashInTotal']);
        cashOutTotal = safeDouble(data['kpis']['cashOutTotal']);
        cashNetTotal = safeDouble(data['kpis']['cashNetTotal']);
        netOperatingProfit = safeDouble(data['kpis']['netOperatingProfit']);

        // Low stock list
        lowStockItems = List<String>.from(data['lowStockItems']);

        // Issue vs Receive
        issueReceive7 = (data['issueReceive7Days'] as List)
            .map((e) => _TxnDay(
                  e['day'],
                  safeDouble(e['received']),
                  safeDouble(e['issued']),
                ))
            .toList();

        // Department issue
        deptIssue = (data['departmentIssue'] as List)
            .map((e) => _DeptIssue(
                  e['dept'] ?? "HK",
                  safeDouble(e['qty']),
                ))
            .toList();

        // Damage trend
        damage7 = (data['damageTrend7Days'] as List)
            .map((e) => _DamageDay(
                  e['day'],
                  safeDouble(e['qty']),
                ))
            .toList();

        // Category stock
        categoryStock = (data['categoryStock'] as List)
            .map((e) => _CategoryStock(
                  e['category'],
                  safeInt(e['percent']),
                ))
            .toList();

        // Supplier payments
        supplierPayments = (data['supplierPayments'] as List)
            .map((e) => _SupplierPayment(
                  e['supplier'],
                  safeDouble(e['paid']),
                  safeDouble(e['unpaid']),
                ))
            .toList();

        // Unpaid suppliers
        unpaidSuppliers = (data['unpaidSuppliers'] as List)
            .map((e) => _UnpaidSupplier(
                  e['supplier'],
                  safeDouble(e['amount']),
                ))
            .toList();

        topHeatmapItems = (data['heatmapTopItems'] as List? ?? [])
            .map((e) => _HeatmapItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();

        monthlyTransactionTypes = (data['monthlyTransactionTypes'] as List? ??
                [])
            .map((e) =>
                _TransactionTypeSummary.fromJson(Map<String, dynamic>.from(e)))
            .toList();

        final comparisonData =
            Map<String, dynamic>.from(data['comparisons'] as Map? ?? {});
        growthComparisons = {
          'day': _GrowthComparison.fromJson(
            Map<String, dynamic>.from(
              comparisonData['day_to_yesterday'] as Map? ?? {},
            ),
          ),
          'week': _GrowthComparison.fromJson(
            Map<String, dynamic>.from(
              comparisonData['week_to_previous_week'] as Map? ?? {},
            ),
          ),
          'month': _GrowthComparison.fromJson(
            Map<String, dynamic>.from(
              comparisonData['month_to_previous_month'] as Map? ?? {},
            ),
          ),
          'year': _GrowthComparison.fromJson(
            Map<String, dynamic>.from(
              comparisonData['year_to_previous_year'] as Map? ?? {},
            ),
          ),
        };
      });
    } catch (e) {
      if (e
              .toString()
              .toLowerCase()
              .contains("SESSION_EXPIRED".toLowerCase()) ||
          e.toString().toLowerCase().contains("INVALID_TOKEN".toLowerCase())) {
        await TokenStorage.clear();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("SESSION_EXPIRED")),
          );

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
                builder: (context) => const InventoryLoginScreen()),
            (route) => false,
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }

  String get sessionDuration {
    final d = DateTime.now().difference(_loginTime);
    return '${d.inHours}h ${d.inMinutes % 60}m';
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 1000;

    return Scaffold(
      drawer: _buildInventoryDrawer(),
      appBar: AppBar(
        title: Text(_dashboardTitle),
        actions: [
          if (_userRole == 'ADMIN')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: _isSyncing
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.cloud_download),
                      tooltip: 'Sync Latest Data',
                      onPressed: _performSync,
                    ),
            ),
          IconButton(
              tooltip: 'Refresh',
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const UserInventoryDashboard()));
              },
              icon: const Icon(Icons.refresh)),
          if (_showNotifications)
            IconButton(
                tooltip: 'Notifications',
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const NotificationScreen()));
                },
                icon: const Icon(Icons.notifications_none)),
          IconButton(
              tooltip: 'Logout',
              onPressed: () async {
                await TokenStorage.clear();
                _notificationTimer?.cancel();
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const InventoryLoginScreen()));
              },
              icon: const Icon(Icons.logout)),
        ],
      ),
      body: property == null
          ? Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 450),
                padding: const EdgeInsets.all(40.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.storefront_outlined,
                          size: 56, color: Colors.blue.shade700),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "Business Profile Incomplete",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Your property details have not been configured yet. Please update your business information to ensure invoices and reports are generated correctly.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.black54,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const PropertyInfoScreen(
                                        outletid: 0,
                                      )));
                        },
                        icon: const Icon(Icons.edit_document),
                        label: const Text(
                          "Update Property Info",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _kpiRow(),
                    const SizedBox(height: 12),
                    _lowStockAlert(),
                    const SizedBox(height: 12),
                    _ownerAnalyticsSection(),
                    const SizedBox(height: 12),
                    _financialOverviewSection(),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 760,
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: SingleChildScrollView(
                              child: Column(
                                children: [
                                  _card(_issueReceiveChart()),
                                  const SizedBox(height: 12),
                                  _card(_damageChart()),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: isWide ? 420 : 320,
                            child: SingleChildScrollView(
                              child: Column(
                                children: [
                                  _card(_deptIssueChart()),
                                  const SizedBox(height: 12),
                                  _card(_categoryStockChart()),
                                  const SizedBox(height: 12),
                                  _card(_supplierPaidUnpaidChart()),
                                  const SizedBox(height: 12),
                                  _card(_supplierValueChart()),
                                  const SizedBox(height: 12),
                                  _card(_unpaidSupplierList()),
                                ],
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _ownerAnalyticsSection() {
    final day = growthComparisons['day'];
    final week = growthComparisons['week'];
    final month = growthComparisons['month'];
    final year = growthComparisons['year'];

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _statCard(
                'Revenue',
                'Rs. ${totalRevenue.toStringAsFixed(0)}',
                Icons.payments_outlined,
                const Color(0xFF2563EB),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                'COGS',
                'Rs. ${totalProfit.toStringAsFixed(0)}',
                Icons.trending_up,
                const Color(0xFF16A34A),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                'Gross Loss',
                'Rs. ${totalLoss.toStringAsFixed(0)}',
                Icons.trending_down,
                const Color(0xFFDC2626),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                'Month Growth',
                '${month?.growthPercent.toStringAsFixed(1) ?? '0.0'}%',
                Icons.auto_graph,
                const Color(0xFF7C3AED),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _comparisonChartCard('Day vs Yesterday', day)),
            const SizedBox(width: 12),
            Expanded(
                child: _comparisonChartCard('Week vs Previous Week', week)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
                child: _comparisonChartCard('Month vs Previous Month', month)),
            const SizedBox(width: 12),
            Expanded(
                child: _comparisonChartCard('Year vs Previous Year', year)),
          ],
        ),
        const SizedBox(height: 12),
        _topItemHeatmapCard(),
      ],
    );
  }

  Widget _financialOverviewSection() {
    final financialPoints = [
      _PeriodPoint('Gross Profit', totalProfit),
      _PeriodPoint('COGS', cogsTotal),
      _PeriodPoint('Gross Loss', totalLoss),
      _PeriodPoint('Expenses', expenseTotal),
      _PeriodPoint('Withdrawals', withdrawalTotal),
      _PeriodPoint('Customer Due', customerOutstanding),
      _PeriodPoint('Supplier Due', supplierOutstanding),
      _PeriodPoint('Net Cash', cashNetTotal),
      _PeriodPoint('Net Operating Profit', netOperatingProfit),
    ];

    Color resolveMetricColor(String label) {
      switch (label) {
        case 'Gross Profit':
          return const Color(0xFF16A34A);
        case 'COGS':
          return const Color(0xFFF97316);
        case 'Gross Loss':
          return const Color(0xFFDC2626);
        case 'Expenses':
          return const Color(0xFF8B5CF6);
        case 'Withdrawals':
          return const Color(0xFFEF4444);
        case 'Customer Due':
          return const Color(0xFF0EA5E9);
        case 'Supplier Due':
          return const Color(0xFF64748B);
        case 'Net Cash':
          return cashNetTotal >= 0
              ? const Color(0xFF16A34A)
              : const Color(0xFFDC2626);
        case 'Net Operating Profit':
          return netOperatingProfit >= 0
              ? const Color(0xFF16A34A)
              : const Color(0xFFDC2626);
        default:
          return const Color(0xFF2563EB);
      }
    }

    final transactionSeries = [...monthlyTransactionTypes]
      ..sort((a, b) => b.net.abs().compareTo(a.net.abs()));

    return Column(
      children: [
        _chartCard(
          'Financial Overview',
          'Current month business snapshot',
          SfCartesianChart(
            primaryXAxis: const CategoryAxis(),
            legend: const Legend(isVisible: false),
            series: [
              ColumnSeries<_PeriodPoint, String>(
                dataSource: financialPoints,
                xValueMapper: (d, _) => d.label,
                yValueMapper: (d, _) => d.value.abs(),
                pointColorMapper: (d, _) => resolveMetricColor(d.label),
                dataLabelSettings: const DataLabelSettings(isVisible: true),
                borderRadius: const BorderRadius.all(Radius.circular(6)),
              ),
            ],
          ),
          height: 340,
        ),
        // const SizedBox(height: 12),
        // _chartCard(
        //   'Monthly Transaction Types',
        //   'Credited vs debited by ledger type',
        //   SingleChildScrollView(
        //     scrollDirection: Axis.horizontal,
        //     child: SizedBox(
        //       width: transactionSeries.isEmpty ? 700.0 : transactionSeries.length * 140.0,
        //       child: SfCartesianChart(
        //         primaryXAxis: const CategoryAxis(),
        //         legend: const Legend(isVisible: true),
        //         series: [
        //           ColumnSeries<_TransactionTypeSummary, String>(
        //             name: 'Credited',
        //             dataSource: transactionSeries,
        //             xValueMapper: (d, _) => d.transactionLabel,
        //             yValueMapper: (d, _) => d.credited,
        //             color: const Color(0xFF16A34A),
        //             dataLabelSettings: const DataLabelSettings(isVisible: true),
        //           ),
        //           ColumnSeries<_TransactionTypeSummary, String>(
        //             name: 'Debited',
        //             dataSource: transactionSeries,
        //             xValueMapper: (d, _) => d.transactionLabel,
        //             yValueMapper: (d, _) => d.debited,
        //             color: const Color(0xFFDC2626),
        //             dataLabelSettings: const DataLabelSettings(isVisible: true),
        //           ),
        //         ],
        //       ),
        //     ),
        //   ),
        //   height: 420,
        // ),
      ],
    );
  }

  Widget _transactionTypeSummaryCard() {
    final rows = [...monthlyTransactionTypes]
      ..sort((a, b) => b.net.abs().compareTo(a.net.abs()));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Monthly Transaction Type Summary',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Which ledger types are higher this month: credited, debited, and net flow.',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
              columns: const [
                DataColumn(label: Text('Type')),
                DataColumn(label: Text('Credited')),
                DataColumn(label: Text('Debited')),
                DataColumn(label: Text('Net')),
                DataColumn(label: Text('Count')),
              ],
              rows: rows
                  .map(
                    (entry) => DataRow(
                      cells: [
                        DataCell(Text(entry.transactionLabel)),
                        DataCell(
                            Text('Rs. ${entry.credited.toStringAsFixed(0)}')),
                        DataCell(
                            Text('Rs. ${entry.debited.toStringAsFixed(0)}')),
                        DataCell(
                          Text(
                            'Rs. ${entry.net.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: entry.net >= 0
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFDC2626),
                            ),
                          ),
                        ),
                        DataCell(Text(entry.count.toString())),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.14)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Color(0xFF64748B))),
              const SizedBox(height: 4),
              Text(value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: color,
                  )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _comparisonChartCard(String title, _GrowthComparison? comparison) {
    final current = comparison?.current?.sales ?? 0;
    final previous = comparison?.previous?.sales ?? 0;
    final growth = comparison?.growthPercent ?? 0;
    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Growth: ${growth.toStringAsFixed(1)}%',
              style: const TextStyle(color: Color(0xFF64748B))),
          const SizedBox(height: 8),
          Expanded(
            child: SfCartesianChart(
              primaryXAxis: const CategoryAxis(),
              legend: const Legend(isVisible: true),
              series: [
                ColumnSeries<_PeriodPoint, String>(
                  name: 'Current',
                  dataSource: [
                    _PeriodPoint('Sales', current),
                  ],
                  xValueMapper: (d, _) => d.label,
                  yValueMapper: (d, _) => d.value,
                  color: const Color(0xFF2563EB),
                ),
                ColumnSeries<_PeriodPoint, String>(
                  name: 'Previous',
                  dataSource: [
                    _PeriodPoint('Sales', previous),
                  ],
                  xValueMapper: (d, _) => d.label,
                  yValueMapper: (d, _) => d.value,
                  color: const Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topItemHeatmapCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top 5 Item Sale Heatmap',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Morning, afternoon, evening, and night sales by item.',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
              columns: const [
                DataColumn(label: Text('Item')),
                DataColumn(label: Text('Morning')),
                DataColumn(label: Text('Afternoon')),
                DataColumn(label: Text('Evening')),
                DataColumn(label: Text('Night')),
                DataColumn(label: Text('Total')),
              ],
              rows: topHeatmapItems
                  .map(
                    (item) => DataRow(
                      cells: [
                        DataCell(Text(item.itemName)),
                        DataCell(_heatCell(item.zones['MORNING']?.sales ?? 0)),
                        DataCell(
                            _heatCell(item.zones['AFTERNOON']?.sales ?? 0)),
                        DataCell(_heatCell(item.zones['EVENING']?.sales ?? 0)),
                        DataCell(_heatCell(item.zones['NIGHT']?.sales ?? 0)),
                        DataCell(
                          Text(
                            'Rs. ${item.totalSales.toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heatCell(double value) {
    final amount = value.abs();
    final intensity = (amount / 10000).clamp(0.0, 1.0);
    final color = Color.lerp(
            const Color(0xFFE0F2FE), const Color(0xFF0EA5E9), intensity) ??
        const Color(0xFFE0F2FE);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        'Rs. ${amount.toStringAsFixed(0)}',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: intensity > 0.55 ? Colors.white : const Color(0xFF0F172A),
        ),
      ),
    );
  }

  // ================= SUPPLIER CHARTS =================

  Widget _supplierPaidUnpaidChart() {
    return SfCartesianChart(
      title: const ChartTitle(text: 'Vendor Paid vs Unpaid'),
      primaryXAxis: const CategoryAxis(),
      legend: const Legend(isVisible: true),
      series: [
        ColumnSeries<_SupplierPayment, String>(
          name: 'Paid',
          dataSource: supplierPayments,
          xValueMapper: (d, _) => d.supplier,
          yValueMapper: (d, _) => d.paid,
        ),
        ColumnSeries<_SupplierPayment, String>(
          name: 'Unpaid',
          dataSource: supplierPayments,
          xValueMapper: (d, _) => d.supplier,
          yValueMapper: (d, _) => d.unpaid,
        ),
      ],
    );
  }

  Widget _supplierValueChart() {
    return SfCircularChart(
      title: const ChartTitle(text: 'Vendor Value Share'),
      legend: const Legend(isVisible: true),
      series: [
        DoughnutSeries<_SupplierPayment, String>(
          dataSource: supplierPayments,
          xValueMapper: (d, _) => d.supplier,
          yValueMapper: (d, _) => d.paid + d.unpaid,
          dataLabelSettings: const DataLabelSettings(isVisible: true),
        ),
      ],
    );
  }

  Widget _unpaidSupplierList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Unpaid Vendors',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...unpaidSuppliers.map(
          (e) => ListTile(
            leading: const Icon(Icons.warning_amber, color: Colors.red),
            title: Text(e.supplier),
            trailing: Text(
              'Rs. ${e.amount.toStringAsFixed(0)}',
              style: const TextStyle(
                  color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  // ================= DRAWER =================
  Widget _buildInventoryDrawer() {
    // replace with logged-in user data
    final userName = user?.username ?? "";
    final userRole = user?.role ?? "";
    final userEmail = user?.name ?? "";
    final hotelName = user?.propertyName ?? "";

    return Drawer(
      child: ListView(
        children: [
          // ================= HEADER =================
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              backgroundImage: (property?.logoPath != null &&
                      property!.logoPath!.isNotEmpty &&
                      File(property!.logoPath!).existsSync())
                  ? FileImage(File(property!.logoPath!))
                  : null,
              child: (property?.logoPath != null &&
                      property!.logoPath!.isNotEmpty &&
                      File(property!.logoPath!).existsSync())
                  ? null
                  : userName.isNotEmpty
                      ? Text(
                          userName.substring(0, 1).toUpperCase(),
                          style: const TextStyle(color: Colors.black),
                        )
                      : const Icon(Icons.person),
            ),
            accountName: Text(
              userRole,
              style: const TextStyle(
                  color: Colors.black, fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(
              '$userEmail | $userName',
              style: const TextStyle(color: Colors.black),
            ),
            otherAccountsPictures: [
              IconButton(
                tooltip: 'Profile',
                onPressed: () {
                  // Navigator.push(
                  //   context,
                  //   MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  // );
                },
                icon: const Icon(Icons.person),
              ),
            ],
          ),

          // ================= STOCK OPERATIONS =================
          if (_hasAnyPermission([
            'PURCHASE_ORDER',
            'ITEM_REQUEST',
            'STOCK_IN',
            'STOCK_OUT',
            'RETAIL_SALES',
            'RETURN',
            'DAMAGE',
            'SUPPLIER_PAYMENT'
          ])) ...[
            _sectionTitle('Operations'),
            _drawerItem(Icons.shopping_cart_checkout, 'Purchase Order',
                permission: 'PURCHASE_ORDER', onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PurchaseOrderScreen()),
              );
            }),
            _drawerItem(Icons.assignment_outlined, 'Item Request',
                permission: 'ITEM_REQUEST', onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RequestItemScreen()),
              );
            }),
            _drawerItem(Icons.download, 'Receive from Vendor',
                permission: 'STOCK_IN', onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ReceivingScreen()));
            }),
            if (_showRetailSalesSection)
              _drawerItem(Icons.point_of_sale, 'Retail Sales',
                  permission: 'RETAIL_SALES', onTap: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SaleScreen()));
              }),
            if (_showRetailSalesSection)
              _drawerItem(Icons.water_drop_outlined, 'Subscription Billing',
                  permission: 'RETAIL_SALES', onTap: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
              }),
            _drawerItem(Icons.upload, 'Stock Out', permission: 'STOCK_OUT',
                onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const IssueScreen()));
            }),
            _drawerItem(Icons.undo, 'Return Department Items',
                permission: 'RETURN', onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ReturnIssuedItemScreen()));
            }),
            _drawerItem(
              Icons.assignment_return,
              'Return Purchase to Vendor',
              permission: 'RETURN',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SupplierReturnScreen(),
                  ),
                );
              },
            ),
            _drawerItem(Icons.warning_amber, 'Damage Items',
                permission: 'DAMAGE', onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const DamageItemScreen()));
            }),
            _drawerItem(Icons.payment, 'Vendor Payment',
                permission: 'SUPPLIER_PAYMENT', onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SupplierPaymentScreen()));
            }),
            _drawerItem(Icons.account_balance_wallet, 'Vendor Return Refund',
                permission: 'SUPPLIER_PAYMENT', onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SupplierReturnRefundScreen(),
                ),
              );
            }),
            const Divider(),
          ],

          if (_hasAnyPermission([
            'MODIFY_REQUEST',
            'MODIFY_PURCHASE',
            'MODIFY_RECEIVING',
            'MODIFY_ISSUE',
            'RETAIL_SALES'
          ])) ...[
            _sectionTitle('Modify'),
            _drawerItem(
              Icons.edit_note,
              'Modify Request',
              permission: 'MODIFY_REQUEST',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const RequestModifyScreen()),
                );
              },
            ),
            _drawerItem(
              Icons.assignment,
              'Modify Purchase Order',
              permission: 'MODIFY_PURCHASE',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const PurchaseOrderModifyScreen()),
                );
              },
            ),
            _drawerItem(
              Icons.inventory_2,
              'Modify Receiving (GRN)',
              permission: 'MODIFY_RECEIVING',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ModifyReceivingScreen()),
                );
              },
            ),
            if (_showRetailSalesSection)
              _drawerItem(
                Icons.receipt_long,
                'Reprint / Modify Sales Bill',
                permission: 'RETAIL_SALES',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SalesReprintModifyScreen(),
                    ),
                  );
                },
              ),
            _drawerItem(
              Icons.outbox,
              'Modify Stock Out',
              permission: 'MODIFY_ISSUE',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const IssueModifyScreen()),
                );
              },
            ),
            const Divider(),
          ],

          if (_hasAnyPermission([
            'ITEM_MASTER',
            'SUPPLIER_MASTER',
            'NUMBERING_SETTINGS',
            'PROPERTY_INFORMATION',
            'STOCK_LOCATION',
            'USER_MANAGEMENT',
            'SETTINGS'
          ])) ...[
            // ================= MASTERS =================
            _sectionTitle(
                _isHospitalityBusiness ? 'Masters & Departments' : 'Masters'),

            _drawerItem(Icons.inventory_2_outlined, 'Item Master',
                permission: 'ITEM_MASTER', onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ItemMasterScreen()));
            }),
            _drawerItem(Icons.store, 'Vendor Master',
                permission: 'SUPPLIER_MASTER', onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SupplierMasterScreen()));
            }),

            _drawerItem(Icons.settings_suggest_outlined, 'Numbering Settings',
                permission: 'NUMBERING_SETTINGS', onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const NumberingSettingsScreen()));
            }),

            _drawerItem(Icons.business_outlined, 'Property Information',
                permission: 'PROPERTY_INFORMATION', onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const PropertyInfoScreen(
                            outletid: 0,
                          )));
            }),

            _drawerItem(Icons.location_on_outlined,
                _isHospitalityBusiness ? 'Department' : 'Location',
                permission: 'STOCK_LOCATION', onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const StockLocationScreen()));
            }),

            _drawerItem(Icons.supervised_user_circle, 'User Management',
                permission: 'USER_MANAGEMENT', onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const UserManagementScreen()));
            }),
            _drawerItem(Icons.stars_outlined, 'Loyalty Program',
                permission: 'SETTINGS', onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const LoyaltyMasterConfigScreen()));
            }),

            const Divider(),
          ],

          if (_hasAnyPermission([
            'STOCK_BALANCE',
            'DAMAGE_SUMMARY',
          ])) ...[
            _sectionTitle('Stock View'),
            _drawerItem(Icons.inventory_2, 'Stock Balance',
                permission: 'STOCK_BALANCE', onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const StockBalanceScreen()));
            }),
            _drawerItem(Icons.warning, 'Damage Summary',
                permission: 'DAMAGE_SUMMARY', onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const DamageReportScreen()));
            }),
            const Divider(),
          ],

          if (_hasAnyPermission([
            'REPORTS',
            'STOCK_IN_REPORT',
            'STOCK_OUT_REPORT',
            'RETAIL_SALES_REPORT',
            'CLOSING_REPORT',
            'PURCHASE_REPORT',
            'RETURN_REPORT',
            'REQUEST_REPORT',
            'DAMAGE_REPORT'
          ])) ...[
            // ================= REPORTS =================
            _sectionTitle('Reports'),
            _drawerItem(Icons.receipt_long, 'Purchase Report',
                permission: 'STOCK_IN_REPORT', onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const StockInReportScreen()));
            }),
            _drawerItem(Icons.receipt, 'Stock Out Report',
                permission: 'STOCK_OUT_REPORT', onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const StockOutReportScreen()));
            }),
            if (_showRetailSalesReportSection)
              _drawerItem(Icons.point_of_sale, 'Retail Sales Report',
                  permission: 'RETAIL_SALES_REPORT', onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SalesReportScreen()));
              }),
            if (_showRetailSalesReportSection)
              _drawerItem(Icons.water_drop, 'Subscription Report',
                  permission: 'REPORTS', onTap: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SubscriptionReportScreen()));
              }),
            _drawerItem(Icons.local_offer_outlined, 'Scheme Report',
                permission: 'REPORTS', onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SchemeReportScreen()));
            }),
            _drawerItem(Icons.workspace_premium_outlined, 'Loyalty Report',
                permission: 'REPORTS', onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const LoyaltyReportScreen()));
            }),
            _drawerItem(Icons.insights_outlined, 'Store Analysis',
                permission: 'REPORTS', onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const StoreAnalysisScreen()));
            }),
            _drawerItem(Icons.inventory, 'Closing Report',
                permission: 'CLOSING_REPORT', onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ClosingReportScreen()));
            }),
            _drawerItem(Icons.receipt_long_outlined, 'Stock Ledger Report',
                permission: 'CLOSING_REPORT', onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const StockLedgerReportScreen()));
            }),
            _drawerItem(Icons.store, 'Vendor Purchase Order',
                permission: 'PURCHASE_REPORT', onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const PurchaseOrderReportScreen()));
            }),
            _drawerItem(Icons.account_balance, 'Finance & Reports',
                permission: 'REPORTS', onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CashLedgerScreen(),
                ),
              );
            }),
            _drawerItem(Icons.refresh, 'Return Report',
                permission: 'RETURN_REPORT', onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ReturnReportScreen()));
            }),
            _drawerItem(Icons.outbond_rounded, 'Request Report',
                permission: 'REQUEST_REPORT', onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const RequestReportScreen()));
            }),
            _drawerItem(Icons.warehouse, 'Damage Report',
                permission: 'DAMAGE_REPORT', onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const DamageReportSumScreen()));
            }),

            const Divider(),
          ],

          if (_hasAnyPermission(['SETTINGS'])) ...[
            _sectionTitle('System'),
            _drawerItem(Icons.help_outline, 'Help', onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const HelpScreen()));
            }),
            _drawerItem(Icons.settings, 'Settings', permission: 'SETTINGS',
                onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()));
            }),
            _drawerItem(Icons.lock_reset, 'Change Password', onTap: () async {
              Navigator.pop(context);
              _changePassword(userName);
            }),
            _drawerItem(Icons.logout, 'Logout', onTap: () async {
              await TokenStorage.clear();
              _notificationTimer?.cancel();

              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const InventoryLoginScreen()),
              );
            }),
          ],
          // ================= FOOTER =================

          if (PermissionService.can('SYSTEM_UPDATE')) ...[
            const Divider(),
            _drawerItem(
              Icons.system_update_alt,
              'Check for Updates',
              permission: 'SYSTEM_UPDATE',
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SystemUpdateScreen()));
              },
            ),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    hotelName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('v $currentVersion',
                        style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 4),
                    const Text('Build: 2025-12-04',
                        style: TextStyle(fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerItem(
    IconData ic,
    String label, {
    VoidCallback? onTap,
    String? permission,
  }) {
    if (permission != null && !PermissionService.can(permission)) {
      return const SizedBox();
    }

    return ListTile(
      leading: Icon(ic),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap ?? () => Navigator.of(context).pop(),
    );
  }

  void _changePassword(String username) {
    final formKey = GlobalKey<FormState>();
    final oldPass = TextEditingController();
    final newPass = TextEditingController();
    final confirm = TextEditingController();

    bool obscureOld = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool loading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.security, color: Colors.blue),
                  SizedBox(width: 12),
                  Text('Change Password', style: TextStyle(fontSize: 18)),
                ],
              ),
              content: SizedBox(
                width: 400,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(
                          "Updating password for: $username",
                          style:
                              const TextStyle(color: Colors.blue, fontSize: 13),
                        ),
                      ),

                      // CURRENT PASSWORD
                      TextFormField(
                        controller: oldPass,
                        obscureText: obscureOld,
                        decoration: InputDecoration(
                          labelText: 'Current Password *',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(obscureOld
                                ? Icons.visibility
                                : Icons.visibility_off),
                            onPressed: () =>
                                setDialogState(() => obscureOld = !obscureOld),
                          ),
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),

                      // NEW PASSWORD
                      TextFormField(
                        controller: newPass,
                        obscureText: obscureNew,
                        decoration: InputDecoration(
                          labelText: 'New Password *',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock_reset),
                          suffixIcon: IconButton(
                            icon: Icon(obscureNew
                                ? Icons.visibility
                                : Icons.visibility_off),
                            onPressed: () =>
                                setDialogState(() => obscureNew = !obscureNew),
                          ),
                        ),
                        validator: (v) => v == null || v.length < 8
                            ? 'Must be at least 8 characters'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // CONFIRM PASSWORD
                      TextFormField(
                        controller: confirm,
                        obscureText: obscureConfirm,
                        decoration: InputDecoration(
                          labelText: 'Confirm New Password *',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.check_circle_outline),
                          suffixIcon: IconButton(
                            icon: Icon(obscureConfirm
                                ? Icons.visibility
                                : Icons.visibility_off),
                            onPressed: () => setDialogState(
                                () => obscureConfirm = !obscureConfirm),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (v != newPass.text)
                            return 'Passwords do not match';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actionsPadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              actionsAlignment: MainAxisAlignment.spaceBetween,
              actions: [
                TextButton(
                  onPressed: loading ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: loading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;

                          setDialogState(() => loading = true);

                          try {
                            await userCtrl.changePassword(
                                username, oldPass.text, newPass.text);

                            if (!context.mounted) return;
                            Navigator.pop(ctx); // Close dialog

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Password updated successfully.'),
                                  backgroundColor: Colors.green),
                            );
                            await TokenStorage.clear();
                            _notificationTimer?.cancel();
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const InventoryLoginScreen()));
                          } catch (e) {
                            setDialogState(() => loading = false);

                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(e
                                      .toString()
                                      .replaceAll("Exception: ", "")),
                                  backgroundColor: Colors.red),
                            );
                          }
                        },
                  child: loading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Update Password'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  // Widget _drawerItem(IconData ic, String label, {VoidCallback? onTap}) {
  //   return ListTile(
  //     leading: Icon(ic),
  //     title: Text(label),
  //     trailing: const Icon(Icons.chevron_right, size: 20),
  //     onTap: onTap ?? () => Navigator.of(context).pop(),
  //   );
  // }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  bool _hasAnyPermission(List<String> perms) {
    for (final p in perms) {
      if (PermissionService.can(p)) {
        return true;
      }
    }
    return false;
  }

  // ================= KPI =================
  Widget _kpiRow() {
    return Row(
      children: [
        _kpi('Today In', '$todayIn', Icons.input, Colors.green),
        const SizedBox(width: 12),
        _kpi('Today Out', '$todayOut', Icons.output, Colors.orange),
        const SizedBox(width: 12),
        _kpi('Low Stock', '$lowStock', Icons.warning, Colors.red),
        const SizedBox(width: 12),
        _kpi('Stock Value', 'Rs. ${stockValue.toStringAsFixed(0)}',
            Icons.currency_rupee, Colors.purple),
      ],
    );
  }

  Widget _kpi(String t, String v, IconData i, Color c) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.withOpacity(.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            CircleAvatar(
                backgroundColor: c, child: Icon(i, color: Colors.white)),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t, style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 6),
                Text(v,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            )
          ],
        ),
      ),
    );
  }

  // ================= ALERT =================
  Widget _lowStockAlert() {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Low Stock / Reorder Alert',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            children: lowStockItems
                .map((e) => Chip(
                      label: Text(e),
                      backgroundColor: Colors.red.shade50,
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  // ================= CHARTS =================
  Widget _issueReceiveChart() {
    return SfCartesianChart(
      title: const ChartTitle(text: 'Stock Out vs Receive (7 Days)'),
      primaryXAxis: const CategoryAxis(),
      legend: const Legend(isVisible: true),
      series: [
        ColumnSeries<_TxnDay, String>(
          name: 'Received',
          dataSource: issueReceive7,
          xValueMapper: (d, _) => d.day,
          yValueMapper: (d, _) => d.received,
        ),
        ColumnSeries<_TxnDay, String>(
          name: 'Stock Out',
          dataSource: issueReceive7,
          xValueMapper: (d, _) => d.day,
          yValueMapper: (d, _) => d.issued,
        ),
      ],
    );
  }

  Widget _deptIssueChart() {
    return SfCartesianChart(
      title: const ChartTitle(text: 'Department-wise Stock Out'),
      primaryXAxis: const CategoryAxis(),
      series: [
        BarSeries<_DeptIssue, String>(
          dataSource: deptIssue,
          xValueMapper: (d, _) => d.dept,
          yValueMapper: (d, _) => d.qty,
          dataLabelSettings: const DataLabelSettings(isVisible: true),
        ),
      ],
    );
  }

  Widget _damageChart() {
    return SfCartesianChart(
      title: const ChartTitle(text: 'Damage / Wastage (7 Days)'),
      primaryXAxis: const CategoryAxis(),
      series: [
        LineSeries<_DamageDay, String>(
          dataSource: damage7,
          xValueMapper: (d, _) => d.day,
          yValueMapper: (d, _) => d.qty,
          markerSettings: const MarkerSettings(isVisible: true),
        ),
      ],
    );
  }

  Widget _categoryStockChart() {
    return SfCircularChart(
      title: const ChartTitle(text: 'Stock Balance'),
      legend: const Legend(isVisible: true),
      series: [
        DoughnutSeries<_CategoryStock, String>(
          dataSource: categoryStock,
          xValueMapper: (d, _) => d.category,
          yValueMapper: (d, _) => d.percent,
          dataLabelSettings: const DataLabelSettings(isVisible: true),
        ),
      ],
    );
  }

  Widget _card(Widget c) => Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(padding: const EdgeInsets.all(12), child: c),
      );

  Widget _chartCard(String title, String subtitle, Widget child,
      {double height = 320}) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Color(0xFF64748B))),
          const SizedBox(height: 12),
          Expanded(child: child),
        ],
      ),
    );
  }
}

// ================= MODELS =================
class _TxnDay {
  final String day;
  final double received;
  final double issued;
  _TxnDay(this.day, this.received, this.issued);
}

class _DeptIssue {
  final String dept;
  final double qty;
  _DeptIssue(this.dept, this.qty);
}

class _DamageDay {
  final String day;
  final double qty;
  _DamageDay(this.day, this.qty);
}

class _CategoryStock {
  final String category;
  final int percent;
  _CategoryStock(this.category, this.percent);
}

class _SupplierPayment {
  final String supplier;
  final double paid;
  final double unpaid;
  _SupplierPayment(this.supplier, this.paid, this.unpaid);
}

class _UnpaidSupplier {
  final String supplier;
  final double amount;
  _UnpaidSupplier(this.supplier, this.amount);
}

class _HeatmapZoneValue {
  final double qty;
  final double sales;

  _HeatmapZoneValue(this.qty, this.sales);

  factory _HeatmapZoneValue.fromJson(Map<String, dynamic> json) {
    return _HeatmapZoneValue(
      _safeDouble(json['qty']),
      _safeDouble(json['sales']),
    );
  }
}

class _HeatmapItem {
  final String itemName;
  final String itemCode;
  final String itemGroup;
  final String subCategory;
  final String brand;
  final double totalQty;
  final double totalSales;
  final Map<String, _HeatmapZoneValue> zones;

  _HeatmapItem({
    required this.itemName,
    required this.itemCode,
    required this.itemGroup,
    required this.subCategory,
    required this.brand,
    required this.totalQty,
    required this.totalSales,
    required this.zones,
  });

  factory _HeatmapItem.fromJson(Map<String, dynamic> json) {
    final zonesJson = Map<String, dynamic>.from(json['zones'] as Map? ?? {});
    final zones = <String, _HeatmapZoneValue>{};
    for (final entry in zonesJson.entries) {
      zones[entry.key] = _HeatmapZoneValue.fromJson(
        Map<String, dynamic>.from(entry.value as Map? ?? {}),
      );
    }
    return _HeatmapItem(
      itemName: json['item_name'] ?? '',
      itemCode: json['item_code'] ?? '',
      itemGroup: json['item_group'] ?? '',
      subCategory: json['sub_category'] ?? '',
      brand: json['brand'] ?? '',
      totalQty: _safeDouble(json['total_qty']),
      totalSales: _safeDouble(json['total_sales']),
      zones: zones,
    );
  }
}

class _GrowthComparison {
  final _PeriodTotals? current;
  final _PeriodTotals? previous;
  final double growthPercent;

  _GrowthComparison({
    required this.current,
    required this.previous,
    required this.growthPercent,
  });

  factory _GrowthComparison.fromJson(Map<String, dynamic> json) {
    return _GrowthComparison(
      current: json['current'] is Map
          ? _PeriodTotals.fromJson(Map<String, dynamic>.from(
              json['current'] as Map,
            ))
          : null,
      previous: json['previous'] is Map
          ? _PeriodTotals.fromJson(Map<String, dynamic>.from(
              json['previous'] as Map,
            ))
          : null,
      growthPercent: _safeDouble(json['growth_percent']),
    );
  }
}

class _TransactionTypeSummary {
  final String transactionType;
  final String transactionLabel;
  final double credited;
  final double debited;
  final double net;
  final int count;

  _TransactionTypeSummary({
    required this.transactionType,
    required this.transactionLabel,
    required this.credited,
    required this.debited,
    required this.net,
    required this.count,
  });

  factory _TransactionTypeSummary.fromJson(Map<String, dynamic> json) {
    return _TransactionTypeSummary(
      transactionType: json['transaction_type'] ?? '',
      transactionLabel: json['transaction_label'] ?? '',
      credited: _safeDouble(json['credited']),
      debited: _safeDouble(json['debited']),
      net: _safeDouble(json['net']),
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

class _PeriodTotals {
  final double sales;
  final double profit;
  final double loss;

  _PeriodTotals({
    required this.sales,
    required this.profit,
    required this.loss,
  });

  factory _PeriodTotals.fromJson(Map<String, dynamic> json) {
    return _PeriodTotals(
      sales: _safeDouble(json['sales']),
      profit: _safeDouble(json['profit']),
      loss: _safeDouble(json['loss']),
    );
  }
}

class _PeriodPoint {
  final String label;
  final double value;
  _PeriodPoint(this.label, this.value);
}

double _safeDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
