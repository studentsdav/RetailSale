import 'dart:async';
import 'dart:convert';
import 'package:intl/intl.dart';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../controllers/reports/night_audit_controller.dart';
import 'dart:io';
import 'package:retailpos/models/security/app_user_model.dart';
import 'package:retailpos/screens/dashboard/system_update_screen.dart';
import 'package:retailpos/screens/reports/return_report_screen.dart';
import 'package:retailpos/screens/reports/cashier_handover_report_screen.dart';
import 'package:retailpos/screens/settings/settings_screen.dart';
import 'package:retailpos/widgets/brand_logo_widget.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../controllers/dashboard/dashboard_controller.dart'
    as UserProfiledata;
import '../../controllers/reports/inventory_dashboard_controller.dart';
import '../../controllers/security/user_controller.dart';
import '../../controllers/settings/notification_services.dart';
import '../../controllers/settings/property_info_controller.dart';
import '../../controllers/settings/system_settings_controller.dart';
import '../../core/config/date_time_service.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/token_storage.dart';
import '../../core/config/app_config.dart';
import '../../core/navigation/ai_navigation_registry.dart';
import '../../controllers/notes/user_notes_controller.dart';
import '../../widgets/sticky_notes_modal.dart';
import '../../core/settings/local_preferences.dart';
import '../../models/auth/permission_service.dart';
import '../../core/permissions/module_capability.dart';
import '../../models/common/property_info_model.dart';
import '../auth/login_screen.dart' show LoginScreen;
import '../auth/user_management_screen.dart';
import '../inventory/damage_item_screen.dart';
import '../inventory/stock_issue_screen.dart';
import '../inventory/item_master_screen.dart';
import '../inventory/purchase_order_screen.dart';
import '../inventory/goods_receiving_screen.dart';
import '../inventory/stock_request_screen.dart';
import '../inventory/salescreen.dart';
import '../inventory/stock_transfer_screen.dart';
import '../inventory/assembly_screen.dart';
import '../inventory/return_issue_screen.dart';
import '../inventory/supplier_return_refund_screen.dart';
import '../inventory/supplier_return_screen.dart';
import '../hrms/employee_screen.dart';
import '../hrms/attendance_screen.dart';
import '../hrms/payroll_screen.dart';
import '../hrms/hrms_masters_screen.dart';
import '../inventory/supplier_master_screen.dart';
import '../restaurant/captain_dashboard_screen.dart';
import '../restaurant/floor_plan_configurator.dart';
import '../restaurant/restaurant_setup_screen.dart';
import '../restaurant/kds_screen.dart';
import '../restaurant/delivery_challan_screen.dart';
import '../restaurant/recurring_expenses_screen.dart';
import '../restaurant/restaurant_analytics_reports_screen.dart';
import '../inventory/approval_center_screen.dart';
import '../inventory/submitted_status_screen.dart';
import '../settings/property_info_screen.dart';
import '../settings/outlet_detail_modification_screen.dart';
import '../settings/outlet_setup_checklist_screen.dart';
import 'customer_app_screen.dart';
import 'lynx_feature_testing_screen.dart';
import 'autonomous_agent_screen.dart';
import 'retailer_console_screen.dart';
import 'rider_console_screen.dart';
import '../reports/operations_intelligence_screen.dart';
import '../reports/night_audit_screen.dart';
import '../settings/workflow_automation_screen.dart';
import '../settings/developer_ecosystem_screen.dart';
import '../settings/plugin_marketplace_screen.dart';
import '../modify/purchase_modify.dart';
import '../modify/receiving_modify.dart';
import '../modify/request_modify.dart';
import '../modify/sales_reprint_modify_screen.dart';
import '../modify/stock_out_modify.dart';
import '../recovery/backup_service.dart';
import '../reports/closing_report_screen.dart';
import '../reports/cash_ledger_screen.dart';
import '../accounting/accounting_dashboard_screen.dart';
import '../accounting/bank_accounts_screen.dart';
import '../accounting/accounting_vouchers_screen.dart';
import '../accounting/trial_balance_screen.dart';
import '../accounting/profit_loss_screen.dart';
import '../accounting/balance_sheet_screen.dart';
import '../reports/damage_report_screen.dart';
import '../reports/damage_summary_screen.dart';
import '../reports/purchase_report_screen.dart';
import '../reports/request_report_screen.dart';
import '../reports/scheme_report_screen.dart';
import '../reports/loyalty_report_screen.dart';
import '../reports/subscription_report_screen.dart';
import '../reports/sales_report_screen.dart';
import '../reports/store_analysis_screen.dart';
import '../reports/lucky_draw_campaign_screen.dart';
import '../reports/brand_analysis_screen.dart';
import '../reports/scheme_analysis_screen.dart';
import '../reports/source_analysis_screen.dart';
import '../reports/payment_analysis_screen.dart';
import '../reports/ai_query_analytics_screen.dart';
import '../reports/stock_ledger_report_screen.dart';
import '../reports/commission_report_screen.dart';
import '../reports/supplier_payments_report_screen.dart';
import '../reports/refund_pending_report_screen.dart';
import '../reports/stock_transfer_report_screen.dart';
import '../reports/stock_balance_screen.dart';
import '../reports/stock_in_report_screen.dart';
import '../reports/stock_out_report_screen.dart';
import '../reports/supplier_payment_screen.dart';
import '../settings/help_screen.dart';
import '../settings/document_sequence_screen.dart';
import '../settings/property_info_screen.dart';
import '../settings/stock_location_screen.dart';
import '../settings/loyalty_master_config_screen.dart';
import '../settings/whatsapp_dashboard_screen.dart';
import '../settings/smtp_settings_screen.dart';
import 'notification_screen.dart';
import '../../widgets/lynx_assist_modal.dart';

class MainDashboardScreen extends StatefulWidget {
  const MainDashboardScreen({super.key});

  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen> {
  // USER SESSION
  final Set<int> _shownNotificationIds = {};
  bool _hasPendingDraw = false;
  String _pendingCampaignName = '';

  DateTime _loginTime = DateTime.now();

  UserProfile? user;
  // 🔥 SUPPLIER FINANCE DATA
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
  double netSubscription = 0;
  double netDebit = 0;
  double todaySubscriptionQty = 0;
  double todaySubscriptionAmount = 0;
  double todayDiscount = 0;
  double todayRevenue = 0;
  double todayCollection = 0;
  double todayCogs = 0;
  double todayGrossProfit = 0;
  double todayGrossLoss = 0;
  double todayExpenses = 0;
  double todayNetProfit = 0;
  double todayNetLoss = 0;
  double todayGst = 0;
  double todayTaxableRevenue = 0;
  Timer? _appBarTimer;
  Timer? _dataProtectionTimer;
  DateTime _currentTime = DateTime.now();
  DateTime? _lastUploadDateTime;
  String _lastUploadTime = 'Never';
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
  String _drawerSearchQuery = '';
  Set<String> _favoriteDrawerItems = {};
  final UserNotesController _notesCtrl = UserNotesController();

  Future<void> _loadFavorites() async {
    final list = await LocalPreferences.getFavoriteDrawerItems();
    if (mounted) {
      setState(() {
        if (list.isEmpty) {
          _favoriteDrawerItems = {
            'Billing (POS)',
            'Draft & Hold Bills',
            'Captain Console',
            'Floor Designer',
            'Kitchen KDS Queue',
            'Delivery Challans',
          };
        } else {
          _favoriteDrawerItems = list.toSet();
        }
      });
    }
  }

  Future<void> _toggleFavorite(String itemLabel) async {
    setState(() {
      if (_favoriteDrawerItems.contains(itemLabel)) {
        _favoriteDrawerItems.remove(itemLabel);
      } else {
        _favoriteDrawerItems.add(itemLabel);
      }
    });
    await LocalPreferences.setFavoriteDrawerItems(_favoriteDrawerItems.toList());
  }

  void _openManageFavoritesDialog(List<Map<String, dynamic>> allDrawerItems) {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            final isDark = theme.brightness == Brightness.dark;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.star_rounded, color: Color(0xFFFFB800)),
                  SizedBox(width: 8),
                  Text('Customize Favorite Features', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 440,
                height: 480,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select features to pin directly to the top of your navigation drawer:',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView(
                        children: allDrawerItems.map((item) {
                          final label = item['label'] as String;
                          final category = item['category'] as String;
                          final icon = item['icon'] as IconData;
                          final isFav = _favoriteDrawerItems.contains(label);
                          final perm = item['permission'] as String?;
                          if (perm != null && !PermissionService.can(perm)) return const SizedBox();

                          return CheckboxListTile(
                            dense: true,
                            value: isFav,
                            activeColor: const Color(0xFFFFB800),
                            title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            subtitle: Text(category, style: const TextStyle(fontSize: 11)),
                            secondary: Icon(icon, size: 18, color: theme.colorScheme.primary),
                            onChanged: (val) async {
                              await _toggleFavorite(label);
                              setDialogState(() {});
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String get _businessType => (user?.outletType ?? '').toUpperCase();
  String get _businessModule => user?.businessModule ?? 'ALL';
  bool get _isRetailBusiness =>
      _businessType == 'RETAIL' ||
      const {
        'KIRANA',
        'MEDICAL',
        'PARTS',
        'MACHINERY',
        'PETS',
        'CLOTHES',
        'SOFTWARE',
        'SHOES',
        'MART'
      }.contains(_businessType);
  bool get _isWarehouseBusiness => _businessType == 'WAREHOUSE';
  bool get _isHospitalityBusiness =>
      const {'HOTEL', 'RESTAURANT', 'CAFE', 'BAR'}.contains(_businessType);
  bool get _showRetailSalesSection => true;
  bool get _showRetailSalesReportSection => true;
  String get _dashboardTitle {
    final clientName = (property?.propertyName ?? user?.propertyName ?? '').trim();
    if (clientName.isNotEmpty) {
      return '$clientName Dashboard';
    }
    if (_isWarehouseBusiness) return 'Warehouse Dashboard';
    if (_isHospitalityBusiness) return 'Department Dashboard';
    return 'FAMALTH LYNX Dashboard';
  }

  void _onTimeZoneChanged() {
    if (mounted) {
      setState(() {
        _currentTime = DateTimeService.instance.nowInTimeZone;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    DateTimeService.instance.addListener(_onTimeZoneChanged);
    _currentTime = DateTimeService.instance.nowInTimeZone;
    _appBarTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTimeService.instance.nowInTimeZone;
        });
      }
    });

    _loadPropertyInfo();

    _loadDashboard();

    _verifyDataProtection();
    _dataProtectionTimer = Timer.periodic(const Duration(hours: 1), (timer) {
      _verifyDataProtection();
    });

    _loadNotificationPreference();

    loadUser();

    _loadSessionTime();
    _loadUserRole();
    _loadFavorites();
    _notesCtrl.loadNotes();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<NightAuditController>().fetchStatus();
        context.read<SystemSettingsController>().load();
      }
    });
  }

  @override
  void dispose() {
    DateTimeService.instance.removeListener(_onTimeZoneChanged);
    _appBarTimer?.cancel();
    _dataProtectionTimer?.cancel();
    _notificationTimer?.cancel();
    super.dispose();
  }

  Future<bool?> _showConfirmSyncDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Sync'),
        content: const Text('Proceed to replace data from online to local?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Proceed'),
          ),
        ],
      ),
    );
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
        await _verifyDataProtection();
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

  Future<void> _performUpload() async {
    setState(() => _isSyncing = true);

    try {
      final success = await BackupService.uploadLatest();

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Database backup uploaded to cloud successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        await _verifyDataProtection();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Failed to upload backup to cloud. Please try again.'),
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
    if (!AppConfig.isLocalServer) return;

    final statusMap = await BackupService.checkDetailedStatus();
    final alertStatus = statusMap['alert'] ?? 'NONE';
    final lastSync = statusMap['lastSyncTime'];

    if (lastSync != null) {
      final dt = DateTime.fromMillisecondsSinceEpoch(lastSync as int);
      _lastUploadDateTime = dt;
      _lastUploadTime = DateFormat('dd-MMM-yyyy hh:mm a').format(dt);
    } else {
      _lastUploadDateTime = null;
      _lastUploadTime = 'Never';
    }

    if (!mounted) return;
    setState(() {});

    if (alertStatus == 'ENABLE_PROMPT') {
      _showEnableCloudDialog();
    } else if (alertStatus == 'SYNC_FAILED') {
      _showSyncWarningDialog();
    }
  }

  int get _hoursSinceLastUpload {
    if (_lastUploadDateTime == null) return 999;
    return DateTime.now().difference(_lastUploadDateTime!).inHours;
  }

  Widget _buildBackupStatusBanner() {
    if (!AppConfig.isLocalServer) return const SizedBox.shrink();

    final hours = _hoursSinceLastUpload;
    final isSafe = hours < 12;
    final bgColor = isSafe ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2);
    final borderColor =
        isSafe ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5);
    final textColor =
        isSafe ? const Color(0xFF166534) : const Color(0xFF991B1B);
    final iconColor =
        isSafe ? const Color(0xFF22C55E) : const Color(0xFFEF4444);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(
            isSafe ? Icons.cloud_done : Icons.cloud_off,
            color: iconColor,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Enterprise Data Sync Status",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Last Upload: $_lastUploadTime${hours == 999 ? ' (Never synced)' : ' ($hours hours ago)'}",
                  style: TextStyle(
                    color: textColor.withOpacity(0.85),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (!isSafe) ...[
            const SizedBox(width: 12),
            _isSyncing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFFDC2626)),
                    ),
                  )
                : FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _performUpload,
                    icon: const Icon(Icons.cloud_upload, size: 16),
                    label: const Text(
                      "Upload Data",
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
          ],
        ],
      ),
    );
  }

  Widget _buildNightAuditPendingBanner(NightAuditController nightAuditCtrl) {
    final validation = nightAuditCtrl.validationData;
    final bool isOverdue = validation?['isOverdue'] == true;
    final String businessDate = nightAuditCtrl.currentBusinessDay?['business_date'] ?? '';

    if (!isOverdue) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFF59E0B),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.nightlight_round,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '⚠️ Night Audit Overdue (Business Date: $businessDate)',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'End of Day audit for yesterday was not executed. Please run Night Audit now to close the date & open today.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF78350F),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF7A1A),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NightAuditScreen()),
              );
            },
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            label: const Text(
              'Run Now',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
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

      _notificationTimer?.cancel();
      _checkNotifications();
      _notificationTimer =
          Timer.periodic(const Duration(minutes: 1), (timer) async {
        await _checkNotifications();
      });
    } catch (e) {
      _notificationTimer?.cancel();
    }
  }

  Future<void> _checkNotifications() async {
    final allowNotifications = await LocalPreferences.getShowNotifications();
    if (!allowNotifications) return;
    try {
      final token = await TokenStorage.read();
      if (token == null || TokenStorage.isExpired(token)) return;

      final res = await ApiClient.get('/api/notifications');
      if (res != null && res['data'] is List) {
        for (final n in res['data']) {
          final id = n['id'] as int? ?? 0;
          if (id > 0 && n['is_read'] == false) {
            final key = 'sys_notif_$id';
            if (!_shownNotificationIds.contains(id)) {
              _shownNotificationIds.add(id);
              await NotificationService.show(
                id,
                n['title']?.toString() ?? 'Notification',
                n['message']?.toString() ?? '',
                uniqueKey: key,
              );
            }
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _loadDashboard() async {
    try {
      _checkNotifications();
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
        netSubscription = safeDouble(data['kpis']['netSubscription']);
        netDebit = safeDouble(data['kpis']['netDebit']);
        todaySubscriptionQty = safeDouble(data['kpis']['todaySubscriptionQty']);
        todaySubscriptionAmount =
            safeDouble(data['kpis']['todaySubscriptionAmount']);
        todayDiscount = safeDouble(data['kpis']['todayDiscount']);
        todayRevenue = safeDouble(data['kpis']['todayRevenue']);
        todayCollection = safeDouble(data['kpis']['todayCollection']);
        todayCogs = safeDouble(data['kpis']['todayCogs']);
        todayGrossProfit = safeDouble(data['kpis']['todayGrossProfit']);
        todayGrossLoss = safeDouble(data['kpis']['todayGrossLoss']);
        todayExpenses = safeDouble(data['kpis']['todayExpenses']);
        todayNetProfit = safeDouble(data['kpis']['todayNetProfit']);
        todayNetLoss = safeDouble(data['kpis']['todayNetLoss']);
        todayGst = safeDouble(data['kpis']['todayGst']);
        todayTaxableRevenue = safeDouble(data['kpis']['todayTaxableRevenue']);
        if (todayTaxableRevenue <= 0 && todayRevenue > 0) {
          todayTaxableRevenue = todayRevenue - todayGst;
        }

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
      _checkLuckyDrawCampaignStatus();
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
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
      }
    }
  }

  Future<void> _checkLuckyDrawCampaignStatus() async {
    try {
      final res = await ApiClient.get('/api/lucky-draw/campaigns/active');
      if (res['success'] == true && res['data'] != null) {
        final status = res['data']['status']?.toString();
        final name = res['data']['name']?.toString() ?? 'Lucky Draw';
        if (status == 'PENDING_RESULT') {
          setState(() {
            _hasPendingDraw = true;
            _pendingCampaignName = name;
          });
          return;
        }
      }
      setState(() {
        _hasPendingDraw = false;
        _pendingCampaignName = '';
      });
    } catch (_) {}
  }

  Widget _buildLuckyDrawPendingBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFEF2F2), Color(0xFFFEE2E2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Colors.red,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Lucky Draw Pending Winner Declaration!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF991B1B),
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Please declare the winner for campaign "$_pendingCampaignName" to reset counters and resume raffle ticket issuance at POS checkout.',
                  style: const TextStyle(
                    color: Color(0xFF7F1D1D),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const LuckyDrawCampaignScreen()),
              );
            },
            icon: const Icon(Icons.casino_outlined, size: 18),
            label: const Text(
              'Draw Winner',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadSessionTime() async {
    final loginTime = await TokenStorage.getLoginTime();
    if (mounted) {
      setState(() => _loginTime = loginTime);
    }
  }

  String get sessionDuration {
    final d = DateTime.now().difference(_loginTime);
    if (d.inDays > 0) {
      return '${d.inDays}d ${d.inHours % 24}h';
    }
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes % 60}m';
    }
    return '${d.inMinutes}m';
  }

  void _handleLynxAction(String actionType, Map<String, dynamic>? payload) {
    if (actionType == 'OPEN_NOTES') {
      StickyNotesModal.show(context, _notesCtrl);
      return;
    }
    AiNavigationRegistry.navigate(context, actionType, payload);
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 1000;

    return Scaffold(
      drawer: _buildInventoryDrawer(),
      appBar: AppBar(
        centerTitle: true,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _dashboardTitle,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : Colors.black54,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('dd-MMM-yyyy hh:mm:ss a').format(_currentTime),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF60A5FA)
                    : const Color(0xFF1D4ED8),
              ),
            ),
          ],
        ),
        actions: [
          if (_userRole == 'ADMIN' && AppConfig.isLocalServer)
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
                      onPressed: () async {
                        final confirm = await _showConfirmSyncDialog();
                        if (confirm == true) {
                          await _performSync();
                        }
                      },
                    ),
            ),
          IconButton(
              tooltip: 'Sticky Notes & Reminders',
              onPressed: () {
                StickyNotesModal.show(context, _notesCtrl);
              },
              icon: const Icon(Icons.sticky_note_2_rounded, color: Color(0xFFD97706))),
          IconButton(
              tooltip: 'LYNX ASSIST (AI Companion)',
              onPressed: () {
                LynxAssistModal.show(context, onActionTriggered: _handleLynxAction);
              },
              icon: const Icon(Icons.smart_toy_rounded, color: Color(0xFFE53935))),
          IconButton(
              tooltip: 'Refresh',
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const MainDashboardScreen()));
              },
              icon: const Icon(Icons.refresh)),
          IconButton(
              tooltip: _showNotifications ? 'Notifications (Enabled)' : 'Notifications (Disabled)',
              onPressed: () async {
                await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const NotificationScreen()));
                _loadNotificationPreference();
              },
              icon: Icon(
                _showNotifications ? Icons.notifications_active_rounded : Icons.notifications_off_outlined,
                color: _showNotifications ? const Color(0xFF2563EB) : Colors.grey,
              )),
          IconButton(
              tooltip: 'Logout',
              onPressed: () async {
                await TokenStorage.clear();
                _notificationTimer?.cancel();
                if (!mounted) return;
                Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const LoginScreen()),
                    (route) => false);
              },
              icon: const Icon(Icons.logout)),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Sticky Notes & Reminders Floating Button (Positioned right above LYNX ASSIST)
          FloatingActionButton.extended(
            heroTag: 'sticky_notes_fab',
            backgroundColor: const Color(0xFFD97706),
            foregroundColor: Colors.white,
            elevation: 4,
            icon: const Icon(Icons.sticky_note_2_rounded, size: 20),
            label: AnimatedBuilder(
              animation: _notesCtrl,
              builder: (context, _) {
                final count = _notesCtrl.activeRemindersCount;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Sticky Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    if (count > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
            onPressed: () {
              StickyNotesModal.show(context, _notesCtrl);
            },
          ),
          const SizedBox(height: 12),
          // LYNX ASSIST Floating AI Button
          FloatingActionButton.extended(
            heroTag: 'lynx_assist_fab',
            backgroundColor: const Color(0xFFC81E1E),
            foregroundColor: Colors.white,
            elevation: 6,
            icon: const Icon(Icons.smart_toy_rounded),
            label: const Text('LYNX ASSIST', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            onPressed: () {
              LynxAssistModal.show(context, onActionTriggered: _handleLynxAction);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
                child: Column(
                  children: [
                    Consumer<NightAuditController>(
                      builder: (context, nightAuditCtrl, _) {
                        return _buildNightAuditPendingBanner(nightAuditCtrl);
                      },
                    ),
                    _buildBackupStatusBanner(),
                    if (_hasPendingDraw) ...[
                      _buildLuckyDrawPendingBanner(),
                      const SizedBox(height: 12),
                    ],
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
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 260,
            mainAxisExtent: 68,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          ),
          children: [
            _statCard(
              'Today Revenue (No Sub)',
              'Rs. ${(todayRevenue - todaySubscriptionAmount).toStringAsFixed(0)}',
              Icons.payments_outlined,
              const Color(0xFF2563EB),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SalesReportScreen(),
                  ),
                );
              },
            ),
            _statCard(
              'Today Revenue (With Sub)',
              'Rs. ${todayRevenue.toStringAsFixed(0)}',
              Icons.payments_outlined,
              const Color(0xFF0EA5E9),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SalesReportScreen(),
                  ),
                );
              },
            ),
            _statCard(
              'Today COGS',
              'Rs. ${todayCogs.toStringAsFixed(0)}',
              Icons.shopping_bag_outlined,
              const Color(0xFFF97316),
              showInfoIcon: true,
              onTap: () => _showProfitFormulaDialog(context),
            ),
            todayGrossProfit >= todayGrossLoss
                ? _statCard(
                    'Gross Profit',
                    'Rs. ${todayGrossProfit.toStringAsFixed(0)}',
                    Icons.trending_up,
                    const Color(0xFF16A34A),
                    showInfoIcon: true,
                    onTap: () => _showProfitFormulaDialog(context),
                  )
                : _statCard(
                    'Gross Loss',
                    'Rs. ${todayGrossLoss.toStringAsFixed(0)}',
                    Icons.trending_down,
                    const Color(0xFFDC2626),
                    showInfoIcon: true,
                    onTap: () => _showProfitFormulaDialog(context),
                  ),
            _statCard(
              'Month Growth',
              '${month?.growthPercent.toStringAsFixed(1) ?? '0.0'}%',
              Icons.auto_graph,
              const Color(0xFF7C3AED),
            ),
            _statCard(
              'Today Subscription Sale',
              'Rs. ${todaySubscriptionAmount.toStringAsFixed(0)}',
              Icons.subscriptions_outlined,
              const Color(0xFF0EA5E9),
            ),
            _statCard(
              'Today Discount',
              'Rs. ${todayDiscount.toStringAsFixed(0)}',
              Icons.percent_outlined,
              const Color(0xFFF59E0B),
            ),
            _statCard(
              'Today Collection',
              'Rs. ${todayCollection.toStringAsFixed(0)}',
              Icons.savings_outlined,
              const Color(0xFF6366F1),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CashLedgerScreen(),
                  ),
                );
              },
            ),
            _statCard(
              'Today GST',
              'Rs. ${todayGst.toStringAsFixed(0)}',
              Icons.account_balance_outlined,
              const Color(0xFFE11D48),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            if (width < 700) {
              return Column(
                children: [
                  _comparisonChartCard('Day vs Yesterday', day),
                  const SizedBox(height: 12),
                  _comparisonChartCard('Week vs Previous Week', week),
                  const SizedBox(height: 12),
                  _comparisonChartCard('Month vs Previous Month', month),
                  const SizedBox(height: 12),
                  _comparisonChartCard('Year vs Previous Year', year),
                ],
              );
            } else {
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _comparisonChartCard('Day vs Yesterday', day)),
                      const SizedBox(width: 12),
                      Expanded(child: _comparisonChartCard('Week vs Previous Week', week)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _comparisonChartCard('Month vs Previous Month', month)),
                      const SizedBox(width: 12),
                      Expanded(child: _comparisonChartCard('Year vs Previous Year', year)),
                    ],
                  ),
                ],
              );
            }
          },
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
      _PeriodPoint('Net Collection', cashInTotal),
      _PeriodPoint('Net Subscription', netSubscription),
      _PeriodPoint('Net Debit', netDebit),
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
        case 'Net Collection':
          return const Color(0xFF16A34A);
        case 'Net Subscription':
          return const Color(0xFF0EA5E9);
        case 'Net Debit':
          return const Color(0xFFDC2626);
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

  void _showProfitFormulaDialog(BuildContext context) {
    final double taxableRev = (todayTaxableRevenue > 0) ? todayTaxableRevenue : (todayRevenue - todayGst);
    final double netGrossProfit = (todayGrossProfit > 0 || todayGrossLoss > 0)
        ? (todayGrossProfit - todayGrossLoss)
        : (taxableRev - todayCogs);
    final bool isGrossProfit = netGrossProfit >= 0;
    final double displayGrossAmount = netGrossProfit.abs();

    final double calculatedNetProfit = netGrossProfit - todayExpenses;
    final bool isNetProfit = calculatedNetProfit >= 0;
    final double displayNetAmount = calculatedNetProfit.abs();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isNetProfit ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isNetProfit ? Icons.trending_up : Icons.trending_down,
                color: isNetProfit ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Profit & Loss Formula',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'How Profit & Loss is calculated in Famalth Lynx:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📐 GROSS PROFIT FORMULA',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Gross Profit = Today Revenue (Excl. Tax) - Today COGS',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                    ),
                    const Divider(height: 16),
                    const Text(
                      '🔻 GROSS LOSS FORMULA (When Cost > Revenue)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Gross Loss = Today COGS - Today Revenue (Excl. Tax)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                    ),
                    const Divider(height: 16),
                    const Text(
                      '📈 NET PROFIT FORMULA',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Net Profit = Today Revenue (Excl. Tax) - Today COGS - Operating Expenses\n(Net Profit = Gross Profit - Operating Expenses)',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '💡 TAX & GST HANDLING NOTE:',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '• Same universal formula applies for Taxable, Non-Taxable, Inclusive, & Exclusive GST sales.\n'
                      '• GST collected is a government liability, NOT revenue. For Inclusive GST, tax is deducted before calculating Gross Profit.\n'
                      '• COGS = Sold Quantity × Item Purchase Cost Rate.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF1E3A8A), height: 1.35),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Live Today Component Values:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 8),
              if (todayDiscount > 0) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('• Gross Sale (Excl. Tax):', style: TextStyle(fontSize: 12.5, color: Color(0xFF475569))),
                    Text('Rs. ${(taxableRev + todayDiscount).toStringAsFixed(2)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('• Less Discount Given:', style: TextStyle(fontSize: 12.5, color: Color(0xFFDC2626))),
                    Text('- Rs. ${todayDiscount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                  ],
                ),
                const SizedBox(height: 4),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('• Today Net Revenue (Excl. Tax):', style: TextStyle(fontSize: 12.5, color: Color(0xFF475569))),
                  Text('Rs. ${taxableRev.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('• Today COGS (Cost of Goods):', style: TextStyle(fontSize: 12.5, color: Color(0xFF475569))),
                  Text('Rs. ${todayCogs.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFFC2410C))),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('• Less Operating Expenses:', style: TextStyle(fontSize: 12.5, color: Color(0xFF8B5CF6))),
                  Text('- Rs. ${todayExpenses.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6))),
                ],
              ),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isGrossProfit ? '• Calculated Gross Profit:' : '• Calculated Gross Loss:',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Rs. ${displayGrossAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isGrossProfit ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isNetProfit ? '• Calculated Net Profit:' : '• Calculated Net Loss:',
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Rs. ${displayNetAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isNetProfit ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '📌 Formula Breakdown: Net Profit = Today Net Revenue (Rs. ${taxableRev.toStringAsFixed(2)}) - Today COGS (Rs. ${todayCogs.toStringAsFixed(2)}) - Operating Expenses (Rs. ${todayExpenses.toStringAsFixed(2)})',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF475569), height: 1.3),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color,
      {VoidCallback? onTap, bool showInfoIcon = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.14)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (showInfoIcon)
                            Icon(Icons.info_outline, size: 13, color: color.withOpacity(0.8)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          value,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: color,
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
            'Top 5 Item Sale Heatmap (Today)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Morning, afternoon, evening, and night sales by item for today.',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
              columns: const [
                DataColumn(label: Text('Item')),
                DataColumn(label: Text('Brand')),
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
                        DataCell(
                            Text(item.brand.isNotEmpty ? item.brand : '—')),
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

  Widget _userDetailRow(IconData icon, String label, String value, bool isDark, {bool isGreen = false}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: isGreen ? const Color(0xFF10B981) : (isDark ? Colors.white60 : const Color(0xFF64748B))),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 10.5, color: isDark ? Colors.white60 : const Color(0xFF64748B))),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: isGreen ? const Color(0xFF059669) : (isDark ? Colors.white : const Color(0xFF1E293B)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showUserDetailDialog(
    BuildContext context,
    String fullUserName,
    String fullEmail,
    String role,
    String propertyName,
  ) {
    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final displayId = fullUserName.isNotEmpty ? fullUserName : 'admin';

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.badge_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              const Text('User Identity Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Copyable Full User ID Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'FULL USER ID / USERNAME',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: isDark ? Colors.white70 : const Color(0xFF64748B),
                            ),
                          ),
                          InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: displayId));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('User ID "$displayId" copied to clipboard!'),
                                  duration: const Duration(seconds: 2),
                                  backgroundColor: const Color(0xFF10B981),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Row(
                                children: [
                                  Icon(Icons.copy_rounded, size: 14, color: theme.colorScheme.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Copy',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SelectableText(
                        displayId,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _userDetailRow(Icons.shield_outlined, 'Role', role.isNotEmpty ? role.toUpperCase() : 'ADMIN', isDark),
                const SizedBox(height: 10),
                _userDetailRow(Icons.email_outlined, 'Email / Subtitle', fullEmail.isNotEmpty ? fullEmail : 'System Administrator', isDark),
                const SizedBox(height: 10),
                _userDetailRow(Icons.business_outlined, 'Property / Outlet', propertyName.isNotEmpty ? propertyName : 'Primary Workspace', isDark),
                const SizedBox(height: 10),
                _userDetailRow(Icons.timer_outlined, 'Active Session Uptime', sessionDuration, isDark, isGreen: true),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // ================= DRAWER =================
  IconData _getCategoryIcon(String name) {
    switch (name) {
      case 'Billing':
        return Icons.receipt_long_outlined;
      case 'Operations':
        return Icons.business_center_outlined;
      case 'Modify':
        return Icons.edit_outlined;
      case 'Masters':
      case 'Masters & Departments':
        return Icons.folder_shared_outlined;
      case 'HR & Payroll':
        return Icons.people_outline;
      case 'Finance & Accounting (Beta)':
      case 'Finance & Accounting':
      case 'Finance & Expenses':
      case 'Finance':
        return Icons.account_balance_outlined;
      case 'Stock View':
        return Icons.inventory_2_outlined;
      case 'Reports':
        return Icons.analytics_outlined;
      default:
        return Icons.settings_outlined;
    }
  }

  Widget _buildInventoryDrawer() {
    final userName = user?.username ?? "";
    final userRole = user?.role ?? "";
    final userEmail = user?.name ?? "";
    final hotelName = user?.propertyName ?? "";

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimaryColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSecondaryColor = isDark ? Colors.white70 : const Color(0xFF64748B);

    final List<Map<String, dynamic>> allDrawerItems = [
      // Billing Section (Primary Navigation for Cashiers & Staff)
      {
        'category': 'Billing',
        'icon': Icons.point_of_sale,
        'label': 'Billing (POS)',
        'permission': 'RETAIL_SALES',
        'keywords': ['sale', 'sales', 'retail sale', 'retail sales', 'pos', 'billing', 'bill', 'billing pos', 'counter billing', 'invoice', 'make bill', 'pos sale', 'retail'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SaleScreen())),
      },
      {
        'category': 'Billing',
        'icon': Icons.drafts_outlined,
        'label': 'Draft & Hold Bills',
        'permission': 'RETAIL_SALES',
        'keywords': ['draft', 'drafts', 'hold bill', 'hold bills', 'unsettled bill', 'draft sale', 'pending bill', 'table bill', 'sale', 'sales'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SaleScreen(openDraftsOnLaunch: true))),
      },
      {
        'category': 'Billing',
        'icon': Icons.receipt_long_outlined,
        'label': 'Reprint / Modify Bills',
        'permission': 'REPRINT_SALES_BILL',
        'keywords': ['reprint', 'modify bill', 'sales bill', 'reprint bill', 'sale bill', 'sale', 'sales'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesReprintModifyScreen())),
      },

      // Operations
      {
        'category': 'Operations',
        'icon': Icons.shopping_cart_checkout,
        'label': 'Purchase Order',
        'permission': 'PURCHASE_ORDER',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchaseOrderScreen())),
      },
      {
        'category': 'Operations',
        'icon': Icons.shopping_bag_outlined,
        'label': 'Customer App (Delivery)',
        'permission': 'CUSTOMER_APP',
        'isBeta': true,
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerAppScreen())),
      },
      {
        'category': 'Operations',
        'icon': Icons.admin_panel_settings_outlined,
        'label': 'Supplier / Retailer Console',
        'permission': 'RETAILER_CONSOLE',
        'isBeta': true,
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RetailerConsoleScreen())),
      },
      {
        'category': 'Operations',
        'icon': Icons.delivery_dining_outlined,
        'label': 'Rider Delivery Portal',
        'permission': 'RIDER_PORTAL',
        'isBeta': true,
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RiderConsoleScreen())),
      },
      {
        'category': 'Operations',
        'icon': Icons.shopping_cart_checkout,
        'label': 'Vendor Purchase Order (PO)',
        'permission': 'PURCHASE_ORDER',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchaseOrderScreen())),
      },
      {
        'category': 'Operations',
        'icon': Icons.download_rounded,
        'label': 'Vendor Receive Order (GRN)',
        'permission': 'STOCK_IN',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GoodsReceivingScreen())),
      },
      {
        'category': 'Operations',
        'icon': Icons.upload,
        'label': 'Stock Dispatch',
        'permission': 'STOCK_OUT',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StockIssueScreen())),
      },
      {
        'category': 'Operations',
        'icon': Icons.swap_horiz,
        'label': 'Stock Transfer',
        'permission': 'STOCK_TRANSFER',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StockTransferScreen())),
      },
      {
        'category': 'Operations',
        'icon': Icons.build,
        'label': 'Product Assembly',
        'permission': 'PRODUCT_ASSEMBLY',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AssemblyScreen())),
      },
      {
        'category': 'Operations',
        'icon': Icons.undo,
        'label': 'Return Department Items',
        'permission': 'RETURN_ISSUE',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReturnIssueScreen())),
      },
      {
        'category': 'Operations',
        'icon': Icons.assignment_return,
        'label': 'Return Purchase to Vendor',
        'permission': 'SUPPLIER_RETURN',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupplierReturnScreen())),
      },
      {
        'category': 'Operations',
        'icon': Icons.warning_amber,
        'label': 'Damage Items',
        'permission': 'DAMAGE',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DamageItemScreen())),
      },
      {
        'category': 'Operations',
        'icon': Icons.payment,
        'label': 'Vendor Payment',
        'permission': 'SUPPLIER_PAYMENT',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupplierPaymentScreen())),
      },
      {
        'category': 'Operations',
        'icon': Icons.account_balance_wallet,
        'label': 'Vendor Return Refund',
        'permission': 'SUPPLIER_RETURN_REFUND',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupplierReturnRefundScreen())),
      },
      {
        'category': 'Operations',
        'icon': Icons.assignment_return_outlined,
        'label': 'Pending Refunds',
        'permission': 'PENDING_REFUNDS',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RefundPendingReportScreen())),
      },
      if (userRole == 'ADMIN')
        {
          'category': 'Operations',
          'icon': Icons.verified_user_outlined,
          'label': 'Approval Center',
          'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ApprovalCenterScreen())),
        },
      {
        'category': 'Operations',
        'icon': Icons.history_edu,
        'label': 'My Submissions Status',
        'permission': 'SUBMISSIONS_STATUS',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubmittedStatusScreen())),
      },

      // Modify
      if (PermissionService.can('MODIFY_REQUEST') || PermissionService.can('REPRINT_REQUEST'))
        {
          'category': 'Modify',
          'icon': Icons.edit_note,
          'label': 'Modify Request',
          'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RequestModifyScreen())),
        },
      if (PermissionService.can('MODIFY_PURCHASE') || PermissionService.can('REPRINT_PURCHASE'))
        {
          'category': 'Modify',
          'icon': Icons.assignment,
          'label': 'Modify Purchase Order',
          'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchaseOrderModifyScreen())),
        },
      if (PermissionService.can('MODIFY_RECEIVING') || PermissionService.can('REPRINT_RECEIVING'))
        {
          'category': 'Modify',
          'icon': Icons.inventory_2,
          'label': 'Modify Receiving (GRN)',
          'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ModifyReceivingScreen())),
        },
      if (PermissionService.can('RETAIL_SALES') || PermissionService.can('REPRINT_SALES_BILL'))
        {
          'category': 'Modify',
          'icon': Icons.receipt_long,
          'label': 'Reprint / Modify Sales Bill',
          'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesReprintModifyScreen())),
        },
      if (PermissionService.can('MODIFY_ISSUE') || PermissionService.can('REPRINT_ISSUE'))
        {
          'category': 'Modify',
          'icon': Icons.outbox,
          'label': 'Modify Stock Dispatch',
          'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IssueModifyScreen())),
        },

      // Masters & Departments
      {
        'category': _isHospitalityBusiness ? 'Masters & Departments' : 'Masters',
        'icon': Icons.inventory_2_outlined,
        'label': 'Item Master',
        'permission': 'ITEM_MASTER',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ItemMasterScreen())),
      },
      {
        'category': _isHospitalityBusiness ? 'Masters & Departments' : 'Masters',
        'icon': Icons.store,
        'label': 'Vendor Master',
        'permission': 'SUPPLIER_MASTER',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupplierMasterScreen())),
      },
      {
        'category': _isHospitalityBusiness ? 'Masters & Departments' : 'Masters',
        'icon': Icons.settings_suggest_outlined,
        'label': 'Document Sequence Settings',
        'permission': 'NUMBERING_SETTINGS',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DocumentSequenceScreen())),
      },
      {
        'category': _isHospitalityBusiness ? 'Masters & Departments' : 'Masters',
        'icon': Icons.checklist_rounded,
        'label': 'Store Setup Checklist & Guide',
        'permission': 'PROPERTY_INFORMATION',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OutletSetupChecklistScreen())),
      },
      {
        'category': _isHospitalityBusiness ? 'Masters & Departments' : 'Masters',
        'icon': Icons.business_outlined,
        'label': 'Property Information',
        'permission': 'PROPERTY_INFORMATION',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PropertyInfoScreen(outletid: 0))),
      },
      {
        'category': _isHospitalityBusiness ? 'Masters & Departments' : 'Masters',
        'icon': Icons.edit_location_alt_outlined,
        'label': 'Outlet Detail Modification',
        'permission': 'PROPERTY_INFORMATION',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OutletDetailModificationScreen())),
      },
      {
        'category': _isHospitalityBusiness ? 'Masters & Departments' : 'Masters',
        'icon': Icons.location_on_outlined,
        'label': _isHospitalityBusiness ? 'Department' : 'Location',
        'permission': 'STOCK_LOCATION',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StockLocationScreen())),
      },
      {
        'category': _isHospitalityBusiness ? 'Masters & Departments' : 'Masters',
        'icon': Icons.supervised_user_circle,
        'label': 'User Management',
        'permission': 'USER_MANAGEMENT',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserManagementScreen())),
      },
      {
        'category': _isHospitalityBusiness ? 'Masters & Departments' : 'Masters',
        'icon': Icons.stars_outlined,
        'label': 'Loyalty Program',
        'permission': 'LOYALTY_PROGRAM',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoyaltyMasterConfigScreen())),
      },
      {
        'category': _isHospitalityBusiness ? 'Masters & Departments' : 'Masters',
        'icon': Icons.chat_bubble_outline,
        'label': 'WhatsApp Integration',
        'permission': 'WHATSAPP_INTEGRATION',
        'isBeta': true,
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WhatsAppDashboardScreen())),
      },
      {
        'category': _isHospitalityBusiness ? 'Masters & Departments' : 'Masters',
        'icon': Icons.email_outlined,
        'label': 'SMTP Email Setup',
        'permission': 'SMTP_SETTINGS',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SmtpSettingsScreen())),
      },

      // HR & Payroll
      {
        'category': 'HR & Payroll',
        'icon': Icons.people_outline,
        'label': 'Employee Management',
        'permission': 'HR_EMPLOYEES',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmployeeScreen())),
      },
      {
        'category': 'HR & Payroll',
        'icon': Icons.access_time,
        'label': 'Attendance & Leaves',
        'permission': 'HR_ATTENDANCE',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen())),
      },
      {
        'category': 'HR & Payroll',
        'icon': Icons.account_balance_wallet_outlined,
        'label': 'Payroll',
        'permission': 'HR_PAYROLL',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PayrollScreen())),
      },
      {
        'category': 'HR & Payroll',
        'icon': Icons.tune_outlined,
        'label': 'HR Masters',
        'permission': 'HR_MASTERS',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrmsMastersScreen())),
      },

      // Restaurant (Beta)
      {
        'category': 'Restaurant (Beta)',
        'icon': Icons.restaurant_menu,
        'label': 'Captain Console',
        'permission': 'RESTAURANT_CONSOLE',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CaptainDashboardScreen())),
      },
      {
        'category': 'Restaurant (Beta)',
        'icon': Icons.map_outlined,
        'label': 'Floor Designer',
        'permission': 'RESTAURANT_FLOOR_DESIGN',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FloorPlanConfigurator())),
      },
      {
        'category': 'Restaurant (Beta)',
        'icon': Icons.soup_kitchen_outlined,
        'label': 'Kitchen KDS Queue',
        'permission': 'RESTAURANT_KDS',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KdsScreen())),
      },
      {
        'category': 'Restaurant (Beta)',
        'icon': Icons.settings_applications_outlined,
        'label': 'Restaurant Setup',
        'permission': 'RESTAURANT_SETUP',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RestaurantSetupScreen())),
      },
      {
        'category': 'Restaurant (Beta)',
        'icon': Icons.analytics_outlined,
        'label': 'Restaurant Analytics & Reports',
        'permission': 'RESTAURANT_ANALYTICS',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RestaurantAnalyticsReportsScreen())),
      },
      {
        'category': 'Finance & Expenses',
        'icon': Icons.local_shipping_outlined,
        'label': 'Delivery Challans',
        'permission': 'DELIVERY_CHALLANS',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DeliveryChallanScreen())),
      },
      {
        'category': 'Finance & Expenses',
        'icon': Icons.schedule_outlined,
        'label': 'Recurring Expenses',
        'permission': 'RECURRING_EXPENSES',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecurringExpensesScreen())),
      },

      // Finance & Accounting (Beta) Section
      {
        'category': 'Finance & Accounting (Beta)',
        'icon': Icons.account_balance,
        'label': 'Accounting Section Hub',
        'isBeta': true,
        'permission': 'CASH_LEDGER',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountingDashboardScreen())),
      },
      {
        'category': 'Finance & Accounting (Beta)',
        'icon': Icons.receipt_long,
        'label': 'Accounting Vouchers',
        'isBeta': true,
        'permission': 'CASH_LEDGER',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountingVouchersScreen())),
      },
      {
        'category': 'Finance & Accounting (Beta)',
        'icon': Icons.account_balance_wallet,
        'label': 'Company Bank Accounts',
        'isBeta': true,
        'permission': 'CASH_LEDGER',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BankAccountsScreen())),
      },
      {
        'category': 'Finance & Accounting (Beta)',
        'icon': Icons.balance,
        'label': 'Trial Balance Report',
        'isBeta': true,
        'permission': 'CASH_LEDGER',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TrialBalanceScreen())),
      },
      {
        'category': 'Finance & Accounting (Beta)',
        'icon': Icons.show_chart,
        'label': 'Profit & Loss Statement (P&L)',
        'isBeta': true,
        'permission': 'CASH_LEDGER',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfitLossScreen())),
      },
      {
        'category': 'Finance & Accounting (Beta)',
        'icon': Icons.assessment,
        'label': 'Balance Sheet Statement',
        'isBeta': true,
        'permission': 'CASH_LEDGER',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BalanceSheetScreen())),
      },

      // Stock View
      {
        'category': 'Stock View',
        'icon': Icons.inventory_2,
        'label': 'Stock Balance',
        'permission': 'STOCK_BALANCE',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StockBalanceScreen())),
      },
      {
        'category': 'Stock View',
        'icon': Icons.warning,
        'label': 'Damage Summary',
        'permission': 'DAMAGE_SUMMARY',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DamageSummaryScreen())),
      },

      // Reports
      {
        'category': 'Reports',
        'icon': Icons.receipt_long,
        'label': 'Receiving Report',
        'permission': 'STOCK_IN_REPORT',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StockInReportScreen())),
      },
      {
        'category': 'Reports',
        'icon': Icons.receipt,
        'label': 'Stock Dispatch Report',
        'permission': 'STOCK_OUT_REPORT',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StockOutReportScreen())),
      },
      {
        'category': 'Reports',
        'icon': Icons.swap_horiz,
        'label': 'Stock Transfer Report',
        'permission': 'STOCK_TRANSFER_REPORT',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StockTransferReportScreen())),
      },
      if (_showRetailSalesReportSection) ...[
        {
          'category': 'Reports',
          'icon': Icons.point_of_sale,
          'label': 'Retail Sales Report',
          'permission': 'RETAIL_SALES_REPORT',
          'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesReportScreen())),
        },
        {
          'category': 'Reports',
          'icon': Icons.water_drop,
          'label': 'Subscription Report',
          'permission': 'SUBSCRIPTION_REPORT',
          'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionReportScreen())),
        },
      ],
      {
        'category': 'Reports',
        'icon': Icons.local_offer_outlined,
        'label': 'Scheme Report',
        'permission': 'SCHEME_REPORT',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SchemeReportScreen())),
      },
      {
        'category': 'Reports',
        'icon': Icons.analytics_outlined,
        'label': 'Scheme Analysis',
        'permission': 'SCHEME_ANALYSIS',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SchemeAnalysisScreen())),
      },
      {
        'category': 'Reports',
        'icon': Icons.workspace_premium_outlined,
        'label': 'Loyalty Report',
        'permission': 'LOYALTY_REPORT',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoyaltyReportScreen())),
      },
      {
        'category': 'Reports',
        'icon': Icons.insights_outlined,
        'label': 'Store Analysis',
        'permission': 'STORE_ANALYSIS',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StoreAnalysisScreen())),
      },
      {
        'category': 'Operations',
        'icon': Icons.confirmation_number_outlined,
        'label': 'Lucky Draw Campaigns',
        'permission': 'LUCKY_DRAW',
        'isBeta': true,
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LuckyDrawCampaignScreen())),
      },
      {
        'category': 'Reports',
        'icon': Icons.analytics_outlined,
        'label': 'Brand Analysis',
        'permission': 'BRAND_ANALYSIS',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BrandAnalysisScreen())),
      },
      {
        'category': 'Reports',
        'icon': Icons.source_outlined,
        'label': 'Sale Source Analysis',
        'permission': 'SOURCE_ANALYSIS',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SourceAnalysisScreen())),
      },
      {
        'category': 'Reports',
        'icon': Icons.percent_outlined,
        'label': 'Commission Report',
        'permission': 'COMMISSION_REPORT',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CommissionReportScreen())),
      },
      {
        'category': 'Reports',
        'icon': Icons.payments_outlined,
        'label': 'Payment Method Analysis',
        'permission': 'PAYMENT_ANALYSIS',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentAnalysisScreen())),
      },
      {
        'category': 'Reports',
        'icon': Icons.auto_awesome,
        'label': 'AI Query Analytics',
        'permission': 'AI_QUERY_ANALYTICS',
        'isBeta': true,
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiQueryAnalyticsScreen())),
      },
      {
        'category': 'Reports',
        'icon': Icons.inventory,
        'label': 'Closing Report',
        'permission': 'CLOSING_REPORT',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClosingReportScreen())),
      },
      {
        'category': 'Reports',
        'icon': Icons.nightlight_round,
        'label': 'Night Audit (EOD)',
        'permission': 'NIGHT_AUDIT',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NightAuditScreen())),
      },
      {
        'category': 'Reports',
        'icon': Icons.receipt_long_outlined,
        'label': 'Stock Ledger Report',
        'permission': 'STOCK_LEDGER_REPORT',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StockLedgerReportScreen())),
      },
      {
        'category': 'Reports',
        'icon': Icons.payment_outlined,
        'label': 'Vendor Payment Report',
        'permission': 'VENDOR_PAYMENT_REPORT',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupplierPaymentsReportScreen())),
      },
      {
        'category': 'Reports',
        'icon': Icons.store,
        'label': 'Vendor Purchase Order',
        'permission': 'PURCHASE_REPORT',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchaseReportScreen())),
      },
      {
        'category': 'Reports',
        'icon': Icons.account_balance,
        'label': 'Finance & Reports',
        'permission': 'CASH_LEDGER',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CashLedgerScreen())),
      },
      {
        'category': 'Reports',
        'icon': Icons.account_balance_wallet,
        'label': 'Accounting Section',
        'isBeta': true,
        'permission': 'CASH_LEDGER',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountingDashboardScreen())),
      },
      {
        'category': 'Reports',
        'icon': Icons.refresh,
        'label': 'Return Report',
        'permission': 'RETURN_REPORT',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReturnReportScreen())),
      },
      {
        'category': 'Reports',
        'icon': Icons.outbond_rounded,
        'label': 'Request Report',
        'permission': 'REQUEST_REPORT',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RequestReportScreen())),
      },
      {
        'category': 'Reports',
        'icon': Icons.warehouse,
        'label': 'Damage Report',
        'permission': 'DAMAGE_REPORT',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DamageReportSumScreen())),
      },

      /*
      // LYNX Innovation Hub (Hidden for future release)
      {
        'category': 'LYNX Innovation Hub',
        'icon': Icons.science_rounded,
        'label': '⚡ Feature Testing Hub',
        'subLabel': 'Test all features from Phase 1 to Plugins',
        'isNew': true,
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LynxFeatureTestingScreen())),
      },
      {
        'category': 'LYNX Innovation Hub',
        'icon': Icons.psychology_rounded,
        'label': '🤖 Autonomous AI Agent',
        'subLabel': 'Phase 5: Proactive Anomaly Proposals',
        'isNew': true,
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AutonomousAgentScreen())),
      },
      {
        'category': 'LYNX Innovation Hub',
        'icon': Icons.speed_rounded,
        'label': '⚙️ Operations Intelligence',
        'subLabel': 'Phase 3: Sales Velocity & Expiry Watcher',
        'isNew': true,
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OperationsIntelligenceScreen())),
      },
      {
        'category': 'LYNX Innovation Hub',
        'icon': Icons.bolt_rounded,
        'label': '⚡ Workflow Automation',
        'subLabel': 'Phase 4: Rule-based WhatsApp & PO engine',
        'isNew': true,
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkflowAutomationScreen())),
      },
      {
        'category': 'LYNX Innovation Hub',
        'icon': Icons.code_rounded,
        'label': '🔌 Developer & Webhooks',
        'subLabel': 'Section 6: Open REST APIs & Webhooks',
        'isNew': true,
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DeveloperEcosystemScreen())),
      },
      {
        'category': 'LYNX Innovation Hub',
        'icon': Icons.extension_rounded,
        'label': '🛍️ Add-on Plugin Marketplace',
        'subLabel': 'Tally Sync, Zomato/Swiggy, Loyalty Wheel, SMS',
        'isNew': true,
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PluginMarketplaceScreen())),
      },
      */

      // System
      /*
      {
        'category': 'System',
        'icon': Icons.science_rounded,
        'label': '⚡ LYNX Feature Testing Hub',
        'isNew': true,
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LynxFeatureTestingScreen())),
      },
      */
      {
        'category': 'System',
        'icon': Icons.help_outline,
        'label': 'Help',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpScreen())),
      },
      {
        'category': 'System',
        'icon': Icons.settings,
        'label': 'Settings',
        'permission': 'SETTINGS',
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
      },
      {
        'category': 'System',
        'icon': Icons.lock_reset,
        'label': 'Change Password',
        'onTap': () {
          Navigator.pop(context);
          _changePassword(userName);
        },
      },
      {
        'category': 'System',
        'icon': Icons.logout,
        'label': 'Logout',
        'onTap': () async {
          await TokenStorage.clear();
          _notificationTimer?.cancel();
          if (!mounted) return;
          Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false);
        },
      },
      if (PermissionService.can('SYSTEM_UPDATE'))
        {
          'category': 'System',
          'icon': Icons.system_update_alt,
          'label': 'Check for Updates',
          'permission': 'SYSTEM_UPDATE',
          'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SystemUpdateScreen())),
        },
    ];

    final categories = [
      'LYNX Innovation Hub',
      'Billing',
      'Operations',
      'Modify',
      _isHospitalityBusiness ? 'Masters & Departments' : 'Masters',
      'HR & Payroll',
      'Restaurant (Beta)',
      'Finance & Accounting (Beta)',
      'Finance & Expenses',
      'Stock View',
      'Reports',
      'System',
    ];

    final isSearching = _drawerSearchQuery.trim().isNotEmpty;
    final searchQuery = _drawerSearchQuery.trim().toLowerCase();

    final List<Map<String, dynamic>> deepSearchRegistry = [
      // Settings / System
      {
        'category': 'System',
        'icon': Icons.delete_forever_outlined,
        'label': 'Clear Transaction Data',
        'subLabel': 'Settings ➜ Clear Transaction Data',
        'permission': 'SETTINGS',
        'keywords': ['clear transaction data', 'delete data', 'wipe data', 'reset data', 'reset database', 'clear transactional data', 'transaction clear', 'database wipe'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
      },
      {
        'category': 'System',
        'icon': Icons.branding_watermark_outlined,
        'label': 'Show Brand Name in Print',
        'subLabel': 'Settings ➜ Show Brand Name in Print / Bills',
        'permission': 'SETTINGS',
        'keywords': ['show brand name', 'brand name in print', 'brand display', 'print brand name', 'toggle brand'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
      },
      {
        'category': 'System',
        'icon': Icons.remove_shopping_cart_outlined,
        'label': 'Allow Negative Stock',
        'subLabel': 'Settings ➜ Allow Negative Stock Toggle',
        'permission': 'SETTINGS',
        'keywords': ['allow negative stock', 'negative inventory', 'out of stock billing', 'negative stock', 'stock setup'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
      },
      {
        'category': 'System',
        'icon': Icons.email_outlined,
        'label': 'SMTP Email Setup',
        'subLabel': 'SMTP Email Setup ➜ outgoing mail server configurations',
        'permission': 'SETTINGS',
        'keywords': ['smtp email setup', 'mail server', 'email settings', 'smtp setup', 'outgoing mail server'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SmtpSettingsScreen())),
      },

      // Restaurant Module
      {
        'category': 'Restaurant (Beta)',
        'icon': Icons.event_seat_outlined,
        'label': 'Table Bookings & Reservations',
        'subLabel': 'Restaurant Setup ➜ Reservations (Expected Arrivals)',
        'permission': 'RESTAURANT_SETUP',
        'keywords': ['table bookings', 'reservations', 'booking setup', 'expected arrivals', 'seated bookings', 'arrivals', 'book table'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RestaurantSetupScreen())),
      },
      {
        'category': 'Restaurant (Beta)',
        'icon': Icons.soup_kitchen_outlined,
        'label': 'Kitchen Order Preparation (KDS)',
        'subLabel': 'Kitchen KDS Queue ➜ Preparing, Ready, Served, Rejected status tracking',
        'permission': 'RESTAURANT_KDS',
        'keywords': ['kitchen queue', 'kds', 'kot queue', 'cooking status', 'chef console', 'order preparation', 'ready orders', 'serve orders'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KdsScreen())),
      },
      {
        'category': 'Restaurant (Beta)',
        'icon': Icons.table_bar_outlined,
        'label': 'Billing, Settle & Consolidation',
        'subLabel': 'Captain Console ➜ Table selection, checkout billing dialog',
        'permission': 'RESTAURANT_CONSOLE',
        'keywords': ['consolidated billing', 'settle bill', 'print bill', 'table billing', 'pos checkout', 'cashier dialog', 'billing checkout'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CaptainDashboardScreen())),
      },

      // Billing & Sales
      {
        'category': 'Billing',
        'icon': Icons.point_of_sale,
        'label': 'Billing (POS) / Retail Sale Screen',
        'subLabel': 'Billing ➜ POS Cashier Counter, Sales Billing, Invoice Generation',
        'permission': 'RETAIL_SALES',
        'keywords': ['sale', 'sales', 'retail sale', 'retail sales', 'pos', 'billing', 'bill', 'billing pos', 'counter billing', 'invoice', 'make bill', 'pos sale', 'retail', 'salescreen'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SaleScreen())),
      },
      // Operations & Sales
      {
        'category': 'Operations',
        'icon': Icons.point_of_sale_outlined,
        'label': 'Customer Database & Lists',
        'subLabel': 'Retail Sales ➜ Search customer, phone number registration',
        'permission': 'RETAIL_SALES',
        'keywords': ['customer data', 'customer phone', 'customer list', 'customer name', 'customer profile', 'loyalty points', 'customer database'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SaleScreen())),
      },
      {
        'category': 'Operations',
        'icon': Icons.shopping_cart_checkout,
        'label': 'Create Purchase Order (PO)',
        'subLabel': 'Purchase Order ➜ create/modify supplier purchase orders',
        'permission': 'PURCHASE_ORDER',
        'keywords': ['purchase order', 'create po', 'vendor po', 'buy from supplier', 'purchase items'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchaseOrderScreen())),
      },
      {
        'category': 'Operations',
        'icon': Icons.download,
        'label': 'Vendor Receive Order (GRN)',
        'subLabel': 'Vendor Receive Order ➜ inbound inventory receiving logs',
        'permission': 'STOCK_IN',
        'keywords': ['vendor receive order', 'vendor receive', 'vendor order', 'vendor received order', 'grn', 'goods receiving', 'receive vendor stock', 'goods receipt note', 'stock in', 'vendor invoice', 'receive goods from vendor'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GoodsReceivingScreen())),
      },
      {
        'category': 'Operations',
        'icon': Icons.upload,
        'label': 'Stock Dispatch (Stock Out)',
        'subLabel': 'Stock Dispatch ➜ outbound department issue orders',
        'permission': 'STOCK_OUT',
        'keywords': ['stock dispatch', 'issue stock', 'department issue', 'stock out', 'issue items'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StockIssueScreen())),
      },
      {
        'category': 'Operations',
        'icon': Icons.swap_horiz,
        'label': 'Stock Transfer Orders',
        'subLabel': 'Stock Transfer ➜ move inventory between warehouse locations',
        'permission': 'STOCK_TRANSFER',
        'keywords': ['stock transfer', 'warehouse transfer', 'location transfer', 'move stock'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StockTransferScreen())),
      },
      {
        'category': 'Operations',
        'icon': Icons.warning_amber,
        'label': 'Broken & Damaged Items Log',
        'subLabel': 'Damage Items ➜ record spoilage, broken, or expired stock',
        'permission': 'DAMAGE',
        'keywords': ['damage entry', 'broken items', 'expired stock', 'waste inventory', 'spoilage'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DamageItemScreen())),
      },
      {
        'category': 'Operations',
        'icon': Icons.build,
        'label': 'Product Assembly (BOM)',
        'subLabel': 'Product Assembly ➜ Bill of Materials manufacturing items',
        'permission': 'PRODUCT_ASSEMBLY',
        'keywords': ['product assembly', 'bom', 'bill of materials', 'manufacture item', 'raw materials', 'assembling'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AssemblyScreen())),
      },

      // Masters Setup
      {
        'category': 'Masters',
        'icon': Icons.settings_suggest_outlined,
        'label': 'Document Number Sequences',
        'subLabel': 'Document Sequence Settings ➜ prefixes for invoices, GRNs, KOTs',
        'permission': 'NUMBERING_SETTINGS',
        'keywords': ['numbering settings', 'document sequences', 'kot numbering prefix', 'invoice prefix', 'grn prefix sequence'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DocumentSequenceScreen())),
      },
      {
        'category': 'Masters',
        'icon': Icons.supervised_user_circle,
        'label': 'User Management & Roles',
        'subLabel': 'User Management ➜ create user, reset passwords, set permissions',
        'permission': 'USER_MANAGEMENT',
        'keywords': ['user management', 'create user', 'reset password', 'permission setup', 'staff roles', 'access control'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserManagementScreen())),
      },
      {
        'category': 'Masters',
        'icon': Icons.stars_outlined,
        'label': 'Loyalty Rewards Program',
        'subLabel': 'Loyalty Program ➜ configurations, cashback & rewards configuration',
        'permission': 'LOYALTY_PROGRAM',
        'keywords': ['loyalty program', 'loyalty points system', 'points configuration', 'cashback rewards', 'member points'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoyaltyMasterConfigScreen())),
      },
      {
        'category': 'Masters',
        'icon': Icons.chat_bubble_outline,
        'label': 'WhatsApp API Settings',
        'subLabel': 'WhatsApp Integration ➜ automatic alerts and template setup',
        'permission': 'WHATSAPP_INTEGRATION',
        'keywords': ['whatsapp integration', 'message templates', 'whatsapp api key', 'broadcast', 'automatic invoice alerts'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WhatsAppDashboardScreen())),
      },

      // HR & Payroll
      {
        'category': 'HR & Payroll',
        'icon': Icons.people_outline,
        'label': 'Staff & Employee Profiles',
        'subLabel': 'Employee Management ➜ add staff, edit salary structures',
        'permission': 'HR_EMPLOYEES',
        'keywords': ['employee management', 'staff profiles', 'salary details', 'hr profile', 'create employee'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmployeeScreen())),
      },
      {
        'category': 'HR & Payroll',
        'icon': Icons.access_time,
        'label': 'Staff Attendance & Leaves',
        'subLabel': 'Attendance & Leaves ➜ mark attendance, submit leaves',
        'permission': 'HR_ATTENDANCE',
        'keywords': ['attendance log', 'leave application', 'mark leave', 'staff checkin', 'shift times'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen())),
      },
      {
        'category': 'HR & Payroll',
        'icon': Icons.account_balance_wallet_outlined,
        'label': 'Payroll Payouts & Payslips',
        'subLabel': 'Payroll ➜ run monthly payrolls, view staff payslips',
        'permission': 'HR_PAYROLL',
        'keywords': ['payroll generation', 'monthly salary slip', 'generate payroll', 'payslip', 'salary payout'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PayrollScreen())),
      },

      // Financials & Schemes
      {
        'category': 'Reports',
        'icon': Icons.account_balance,
        'label': 'Cash Book & Finance Ledger',
        'subLabel': 'Finance & Reports ➜ account entries, cash ledgers',
        'permission': 'CASH_LEDGER',
        'keywords': ['cash ledger', 'cash book', 'bank account ledger', 'finance summary', 'journal entry'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CashLedgerScreen())),
      },
      {
        'category': 'Reports',
        'icon': Icons.local_offer_outlined,
        'label': 'Discount Schemes Summary',
        'subLabel': 'Scheme Report ➜ promotional coupons and customer offers',
        'permission': 'SCHEME_REPORT',
        'keywords': ['scheme report', 'discount list', 'promotions summary', 'active coupons', 'special rates list'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SchemeReportScreen())),
      },
      {
        'category': 'Reports',
        'icon': Icons.badge_outlined,
        'label': 'Cashier Shift Handover Analytics',
        'subLabel': 'Handover Report ➜ day-wise physical cash count, cashier variance, shortage alerts',
        'permission': 'REPORTS',
        'keywords': ['cashier handover', 'shift handover report', 'cashier cash count', 'cashier report', 'cashier variance', 'handover analytics'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CashierHandoverReportScreen())),
      },
      {
        'category': 'Reports',
        'icon': Icons.auto_awesome,
        'label': 'AI Query Analytics',
        'subLabel': 'AI Analysis ➜ Ask natural language questions, deepseek, gemini, claude, perplexity, openai',
        'permission': 'AI_QUERY_ANALYTICS',
        'keywords': ['ai analysis', 'ai query analytics', 'ai analytics', 'ai report', 'ai assistant', 'ai query', 'natural language analytics', 'deepseek', 'gemini', 'perplexity', 'claude', 'openai', 'llm', 'ai model'],
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiQueryAnalyticsScreen())),
      },
    ];

    final filteredDrawerItems = ModuleCapability.filterDrawerItems(allDrawerItems, _businessModule);
    final filteredDeepSearch = ModuleCapability.filterDrawerItems(deepSearchRegistry, _businessModule);

    final matchingItems = !isSearching
        ? <Map<String, dynamic>>[]
        : [
            ...filteredDrawerItems.where((item) {
              final label = (item['label'] as String).toLowerCase();
              final category = (item['category'] as String).toLowerCase();
              final List<String> keywords = List<String>.from(item['keywords'] ?? []);
              final perm = item['permission'] as String?;
              if (perm != null && !PermissionService.can(perm)) return false;
              return label.contains(searchQuery) ||
                  category.contains(searchQuery) ||
                  keywords.any((kw) => kw.contains(searchQuery));
            }),
            ...filteredDeepSearch.where((item) {
              final label = (item['label'] as String).toLowerCase();
              final subLabel = (item['subLabel'] as String).toLowerCase();
              final category = (item['category'] as String).toLowerCase();
              final List<String> keywords = List<String>.from(item['keywords'] ?? []);
              final perm = item['permission'] as String?;
              if (perm != null && !PermissionService.can(perm)) return false;
              return label.contains(searchQuery) ||
                  subLabel.contains(searchQuery) ||
                  category.contains(searchQuery) ||
                  keywords.any((kw) => kw.contains(searchQuery));
            }),
          ];

    Widget buildHeader() {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 44, 16, 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          border: Border(
            bottom: BorderSide(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            // Clickable User Avatar & Profile Info (Tap to view full ID & copy)
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _showUserDetailDialog(context, userName, userEmail, userRole, hotelName),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 4.0),
                  child: Row(
                    children: [
                      _buildDrawerHeaderLogoWidget(property?.logoPath, 56),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    userRole.isNotEmpty ? userRole.toUpperCase() : 'ADMIN',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // Active session uptime duration tag
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.circle, size: 5, color: Color(0xFF10B981)),
                                      const SizedBox(width: 3),
                                      Text(
                                        sessionDuration,
                                        style: const TextStyle(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF059669),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    userName.isNotEmpty ? userName : 'System Administrator',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                      color: textPrimaryColor,
                                    ),
                                  ),
                                ),
                                Icon(Icons.info_outline_rounded, size: 14, color: textSecondaryColor.withOpacity(0.6)),
                              ],
                            ),
                            const SizedBox(height: 1),
                            Text(
                              'Tap for full User ID',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                color: textSecondaryColor.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: 'Account Security',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _changePassword(userName),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.key_outlined,
                      size: 17,
                      color: textSecondaryColor,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget buildFooter() {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          border: Border(
            top: BorderSide(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.business_outlined,
                  size: 15,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hotelName.isNotEmpty ? hotelName : 'Famalth technologies',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: textPrimaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'v$currentVersion',
                  style: TextStyle(
                    fontSize: 11,
                    color: textSecondaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Build: 2025-12-04',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: textSecondaryColor.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Drawer(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: Column(
        children: [
          buildHeader(),

          // 100% Fully Pill-Rounded Search Input Bar (Google & Microsoft style)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: TextField(
                  style: TextStyle(color: textPrimaryColor, fontSize: 13, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: 'Search Menu...',
                    hintStyle: TextStyle(
                      color: textSecondaryColor.withOpacity(0.65),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 14, right: 8),
                      child: Icon(Icons.search_rounded, color: textSecondaryColor, size: 18),
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 0),
                    suffixIcon: _drawerSearchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear_rounded, color: textSecondaryColor, size: 16),
                            onPressed: () {
                              setState(() {
                                _drawerSearchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _drawerSearchQuery = val;
                    });
                  },
                ),
              ),
            ),
          ),
          Divider(height: 1, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: [
                if (isSearching) ...[
                  if (matchingItems.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Center(
                        child: Text(
                          'No menu items found',
                          style: TextStyle(color: textSecondaryColor, fontSize: 13),
                        ),
                      ),
                    )
                  else
                    ...matchingItems.map((item) {
                      return _drawerItem(
                        item['icon'] as IconData,
                        item['label'] as String,
                        permission: item['permission'] as String?,
                        isBeta: item['isBeta'] as bool? ?? false,
                        isNew: item['isNew'] as bool? ?? false,
                        isDeprecated: item['isDeprecated'] as bool? ?? false,
                        isFutureUpdate: item['isFutureUpdate'] as bool? ?? false,
                        onTap: item['onTap'] as VoidCallback?,
                        isSubItem: false,
                        categoryName: item['category'] as String?,
                        subLabel: item['subLabel'] as String?,
                      );
                    }),
                ] else ...[
                  // FAVORITES SECTION (Show all starred features directly, no expansion tile)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 18),
                            const SizedBox(width: 6),
                            Text(
                              'FAVORITES',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                                letterSpacing: 0.8,
                                color: isDark ? Colors.white70 : const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(4),
                          onTap: () => _openManageFavoritesDialog(filteredDrawerItems),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            child: Row(
                              children: [
                                Icon(Icons.tune_rounded, size: 13, color: theme.colorScheme.primary),
                                const SizedBox(width: 4),
                                Text(
                                  'Customize',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (_favoriteDrawerItems.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.star_outline_rounded, size: 16, color: textSecondaryColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Tap the star icon on any feature to pin it here.',
                                style: TextStyle(fontSize: 11.5, color: textSecondaryColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...filteredDrawerItems.where((item) {
                      final label = item['label'] as String;
                      if (!_favoriteDrawerItems.contains(label)) return false;
                      final perm = item['permission'] as String?;
                      if (perm != null && !PermissionService.can(perm)) return false;
                      return true;
                    }).map((item) {
                      return _drawerItem(
                        item['icon'] as IconData,
                        item['label'] as String,
                        permission: item['permission'] as String?,
                        isBeta: item['isBeta'] as bool? ?? false,
                        isNew: item['isNew'] as bool? ?? false,
                        isDeprecated: item['isDeprecated'] as bool? ?? false,
                        isFutureUpdate: item['isFutureUpdate'] as bool? ?? false,
                        onTap: item['onTap'] as VoidCallback?,
                        isSubItem: false,
                        isFavoriteSectionItem: true,
                        categoryName: item['category'] as String?,
                      );
                    }),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Divider(height: 1, color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                  ),

                  // CATEGORIES SECTION
                  ...categories.map((categoryName) {
                    final categoryItems = filteredDrawerItems.where((item) {
                      if (item['category'] != categoryName) return false;
                      final perm = item['permission'] as String?;
                      if (perm != null && !PermissionService.can(perm)) return false;
                      return true;
                    }).toList();

                    if (categoryItems.isEmpty) return const SizedBox();

                    return Theme(
                      data: theme.copyWith(
                        dividerColor: Colors.transparent,
                      ),
                      child: ExpansionTile(
                        key: PageStorageKey<String>(categoryName),
                        leading: Icon(
                          _getCategoryIcon(categoryName),
                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                          size: 20,
                        ),
                        title: Text(
                          categoryName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: textPrimaryColor,
                            letterSpacing: 0.2,
                          ),
                        ),
                        children: categoryItems.map((item) {
                          return _drawerItem(
                            item['icon'] as IconData,
                            item['label'] as String,
                            permission: item['permission'] as String?,
                            isBeta: item['isBeta'] as bool? ?? false,
                            isNew: item['isNew'] as bool? ?? false,
                            isDeprecated: item['isDeprecated'] as bool? ?? false,
                            isFutureUpdate: item['isFutureUpdate'] as bool? ?? false,
                            onTap: item['onTap'] as VoidCallback?,
                            isSubItem: true,
                            categoryName: categoryName,
                          );
                        }).toList(),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),

          // FOOTER
          buildFooter(),
        ],
      ),
    );
  }

  Widget _drawerItem(
    IconData ic,
    String label, {
    VoidCallback? onTap,
    String? permission,
    bool isBeta = false,
    bool isNew = false,
    bool isDeprecated = false,
    bool isFutureUpdate = false,
    bool isSubItem = false,
    bool isFavoriteSectionItem = false,
    String? categoryName,
    String? subLabel,
  }) {
    if (permission != null && !PermissionService.can(permission)) {
      return const SizedBox();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimaryColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final textSecondaryColor = isDark ? Colors.white70 : const Color(0xFF64748B);
    final isFavorited = _favoriteDrawerItems.contains(label);

    Widget? badgeWidget;
    if (isBeta) {
      badgeWidget = _buildBadge('BETA', const Color(0xFFEF4444));
    } else if (isNew) {
      badgeWidget = _buildBadge('NEW', const Color(0xFF10B981));
    } else if (isDeprecated) {
      badgeWidget = _buildBadge('DEP', const Color(0xFF64748B));
    } else if (isFutureUpdate) {
      badgeWidget = _buildBadge('UPCOMING', const Color(0xFFF59E0B));
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(isSubItem ? 16 : 10, 1, 10, 1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap ?? () => Navigator.of(context).pop(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                if (isSubItem && !isFavoriteSectionItem) ...[
                  Container(
                    width: 1.5,
                    height: 14,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Icon(
                  ic,
                  size: (isSubItem && !isFavoriteSectionItem) ? 16 : 19,
                  color: (isSubItem && !isFavoriteSectionItem)
                      ? (isDark ? Colors.white70 : const Color(0xFF64748B))
                      : (isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              label,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: (isSubItem && !isFavoriteSectionItem) ? 12.5 : 13,
                                fontWeight: (isSubItem && !isFavoriteSectionItem) ? FontWeight.w500 : FontWeight.w600,
                                color: textPrimaryColor,
                                letterSpacing: -0.1,
                              ),
                            ),
                          ),
                          if (isFavoriteSectionItem && categoryName != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              '($categoryName)',
                              style: TextStyle(
                                fontSize: 10,
                                color: textSecondaryColor.withOpacity(0.7),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (subLabel != null) ...[
                        const SizedBox(height: 2.5),
                        Text(
                          subLabel,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: textSecondaryColor,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (badgeWidget != null) ...[
                  const SizedBox(width: 6),
                  badgeWidget,
                ],
                // Star Toggle Button for Favorites (hide for deep sub-features)
                if (subLabel == null)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _toggleFavorite(label),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Icon(
                          isFavorited ? Icons.star_rounded : Icons.star_outline_rounded,
                          size: 17,
                          color: isFavorited
                              ? const Color(0xFFFFB800)
                              : textSecondaryColor.withOpacity(0.35),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
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
                            if (!context.mounted) return;
                            Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const LoginScreen()),
                                (route) => false);
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
      title: const ChartTitle(text: 'Stock Dispatch vs Receive (7 Days)'),
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
          name: 'Stock Dispatch',
          dataSource: issueReceive7,
          xValueMapper: (d, _) => d.day,
          yValueMapper: (d, _) => d.issued,
        ),
      ],
    );
  }

  Widget _deptIssueChart() {
    return SfCartesianChart(
      title: const ChartTitle(text: 'Department-wise Stock Dispatch'),
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

  Widget _buildDrawerHeaderLogoWidget(String? logoPath, double size) {
    return BrandLogoWidget(
      logoPath: logoPath,
      size: size,
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
