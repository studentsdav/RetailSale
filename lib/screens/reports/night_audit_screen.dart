import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/reports/night_audit_controller.dart';
import '../../controllers/settings/property_info_controller.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/auth/token_storage.dart';
import '../../core/permissions/module_capability.dart';

class NightAuditScreen extends StatefulWidget {
  const NightAuditScreen({super.key});

  @override
  State<NightAuditScreen> createState() => _NightAuditScreenState();
}

class _NightAuditScreenState extends State<NightAuditScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _notesController = TextEditingController();
  String? _currentModule;

  // Retail POS Design System Colors
  static const Color posBgColor = Color(0xFFF4EEE8);
  static const Color posOrange = Color(0xFFFF7A1A);
  static const Color posCardBg = Color(0xFFF9FAFC);
  static const Color posHeaderBg = Color(0xFFF8F1EB);
  static const Color posTextDark = Color(0xFF1E293B);
  static const Color posTextMuted = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });

    _loadUserModule();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<NightAuditController>();
      controller.fetchStatus();
      controller.fetchHistory();
    });
  }

  bool get _isRestaurantModule {
    return ModuleCapability.hasRestaurant(_currentModule);
  }

  Future<void> _loadUserModule() async {
    try {
      final userMap = await TokenStorage.getUser();
      String? mod;
      if (userMap != null) {
        mod = userMap['business_module'] ??
            userMap['outlet_module'] ??
            userMap['outletmodule'] ??
            userMap['module'];
      }

      final propCtrl = PropertyInfoController();
      await propCtrl.load();
      if (propCtrl.data != null && propCtrl.data!.outletModule.trim().isNotEmpty) {
        final pMod = propCtrl.data!.outletModule.trim();
        if (pMod == 'INVENTORY' || pMod == 'RETAIL' || pMod == 'RESTAURANT' || pMod == 'ALL') {
          mod = pMod;
        }
      }

      if (mounted && mod != null && mod.isNotEmpty) {
        setState(() {
          _currentModule = mod;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: posBgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 22,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              children: [
                // Retail POS Custom Top Header Bar
                _buildPosTopHeader(context),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                // Tab Content Body
                Expanded(
                  child: Consumer<NightAuditController>(
                    builder: (context, controller, child) {
                      if (controller.isLoading) {
                        return const Center(
                          child: CircularProgressIndicator(color: posOrange),
                        );
                      }

                      return TabBarView(
                        controller: _tabController,
                        children: [
                          _buildRunAuditTab(context, controller),
                          _buildHistoryTab(context, controller),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPosTopHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          // Back Button
          GestureDetector(
            onTap: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            },
            child: Tooltip(
              message: 'Back',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: posOrange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'Back',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Header Title
          const Text(
            'Night Audit (End of Day)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: posTextDark,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),

          // Custom Pill Navigation Tabs
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: posHeaderBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPillTab(
                  index: 0,
                  icon: Icons.nightlight_round,
                  label: 'Run Audit',
                ),
                const SizedBox(width: 4),
                _buildPillTab(
                  index: 1,
                  icon: Icons.history,
                  label: 'Audit History',
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Refresh Button
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: posTextDark),
            tooltip: 'Refresh',
            onPressed: () {
              final controller = context.read<NightAuditController>();
              controller.fetchStatus();
              controller.fetchHistory();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPillTab({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final bool isSelected = _tabController.index == index;
    return GestureDetector(
      onTap: () => _tabController.animateTo(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? posOrange : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : posTextMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : posTextMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRunAuditTab(BuildContext context, NightAuditController controller) {
    final day = controller.currentBusinessDay;
    final validation = controller.validationData;
    final warnings = (validation?['warnings'] as List?) ?? [];
    final bool hasWarnings = warnings.isNotEmpty;

    final bool isOverdue = validation?['isOverdue'] == true;
    final bool isRestricted = validation?['isRestricted'] == true;
    final String todayDate = validation?['todayDate'] ?? DateTime.now().toString().split(' ')[0];
    final String targetNextDate = validation?['targetNextDate'] ?? todayDate;
    final String businessDate = day?['business_date'] ?? 'N/A';
    final String dayStatus = day?['status'] ?? 'OPEN';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isOverdue) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '⚠️ NIGHT AUDIT OVERDUE',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF92400E),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Yesterday\'s business day was not closed because the system was offline at 2:00 AM. Please verify cash and execute audit now to advance to $targetNextDate.',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF78350F),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (isRestricted) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF3B82F6), width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_clock_outlined, color: Color(0xFF1D4ED8), size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '🔒 NIGHT AUDIT RESTRICTED',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF1E40AF),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Current business date ($businessDate) is up to date with today\'s calendar date ($todayDate). Night Audit cannot advance into future dates.',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          // Business Day Status Banner (Retail POS Style)
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: dayStatus == 'OPEN' ? const Color(0xFFEFF6FF) : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: dayStatus == 'OPEN' ? const Color(0xFFBFDBFE) : const Color(0xFFFECACA),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: dayStatus == 'OPEN' ? const Color(0xFF3B82F6) : const Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.calendar_today_rounded,
                    size: 24,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Business Date: $businessDate',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: posTextDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Operational Status: $dayStatus',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: dayStatus == 'OPEN' ? const Color(0xFF1D4ED8) : const Color(0xFFB91C1C),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: dayStatus == 'OPEN' ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    dayStatus,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: dayStatus == 'OPEN' ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // Pre-Audit Validation Checklist
          const Text(
            'Pre-Audit Validation Checklist',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: posTextDark,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: posCardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                if (_isRestaurantModule) ...[
                  _buildChecklistItem(
                    title: 'Open Kitchen Orders (KOTs)',
                    count: validation?['openKotCount'] ?? 0,
                    icon: Icons.restaurant,
                    onTap: () => _showOpenKotsResolveDialog(context),
                  ),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                ],
                _buildChecklistItem(
                  title: 'Unclosed Cashier Shifts',
                  count: validation?['unclosedShiftCount'] ?? 0,
                  unclosedCashiers: validation?['unclosedCashiers'] as List?,
                  icon: Icons.badge,
                  onTap: () => _showCashierHandoverDialogFromAudit(context),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                _buildChecklistItem(
                  title: 'Draft Invoices / Bills',
                  count: validation?['draftBillCount'] ?? 0,
                  icon: Icons.drafts,
                ),
              ],
            ),
          ),

          if (hasWarnings) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                border: Border.all(color: const Color(0xFFFCD34D)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309), size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Audit Warnings Detected',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ...warnings.map((w) => Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Text(
                          '• ${w['message']}',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF78350F)),
                        ),
                      )),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),

          // Physical Cash Drawer Counter
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Physical Cash Drawer Counter',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: posTextDark,
                ),
              ),
              TextButton.icon(
                onPressed: () => controller.clearDenominations(),
                icon: const Icon(Icons.clear_all, size: 16, color: posOrange),
                label: const Text(
                  'Reset',
                  style: TextStyle(color: posOrange, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: posCardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Denominations Breakdown',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: posTextMuted,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildPosDenomField(controller, '2000', '₹2000'),
                    _buildPosDenomField(controller, '500', '₹500'),
                    _buildPosDenomField(controller, '200', '₹200'),
                    _buildPosDenomField(controller, '100', '₹100'),
                    _buildPosDenomField(controller, '50', '₹50'),
                    _buildPosDenomField(controller, '20', '₹20'),
                    _buildPosDenomField(controller, '10', '₹10'),
                    _buildPosDenomField(controller, 'coins', 'Coins Total'),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFEDD5)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Physical Cash Count:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: posTextDark,
                        ),
                      ),
                      Text(
                        '₹${controller.physicalCashTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 19,
                          color: Color(0xFFC2410C),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Remarks / Notes Input
          TextField(
            controller: _notesController,
            onChanged: (val) => controller.auditNotes = val,
            decoration: InputDecoration(
              labelText: 'Night Audit Remarks / Notes',
              hintText: 'Add operational notes for this day close...',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: posOrange, width: 1.5),
              ),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 24),

          // Primary POS Action Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isRestricted
                    ? Colors.grey.shade400
                    : (hasWarnings ? const Color(0xFFD97706) : posOrange),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: (controller.isExecuting || isRestricted)
                  ? null
                  : () => _confirmAndExecuteAudit(context, controller, hasWarnings),
              icon: controller.isExecuting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Icon(isRestricted
                      ? Icons.lock_outline
                      : (hasWarnings ? Icons.warning_amber_rounded : Icons.check_circle_outline)),
              label: Text(
                controller.isExecuting
                    ? 'Executing Night Audit...'
                    : (isRestricted
                        ? 'Night Audit Restricted (Up to Date)'
                        : (hasWarnings ? 'Force Run Night Audit' : 'Execute Night Audit & Close Day')),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildChecklistItem({
    required String title,
    required int count,
    required IconData icon,
    List? unclosedCashiers,
    VoidCallback? onTap,
  }) {
    final bool isPassed = count == 0;
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: isPassed ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
        child: Icon(
          icon,
          size: 18,
          color: isPassed ? const Color(0xFF16A34A) : const Color(0xFFD97706),
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: posTextDark),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isPassed ? 'Clear (0 pending)' : '$count pending item(s) - Tap to resolve',
            style: TextStyle(
              fontSize: 13,
              color: isPassed ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
              fontWeight: FontWeight.w500,
            ),
          ),
          if (!isPassed && unclosedCashiers != null && unclosedCashiers.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Unclosed Cashier(s): ${unclosedCashiers.map((c) => "${c['name']} (${c['billCount']} bill${(c['billCount'] ?? 1) > 1 ? 's' : ''})").join(', ')}',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFB91C1C),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onTap != null && !isPassed)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: posOrange,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Close Shift',
                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          Icon(
            isPassed ? Icons.check_circle_rounded : Icons.warning_rounded,
            color: isPassed ? const Color(0xFF16A34A) : const Color(0xFFD97706),
            size: 22,
          ),
        ],
      ),
    );
  }

  Future<void> _showCashierHandoverDialogFromAudit(BuildContext context) async {
    final Map<String, int> denoms = {
      '2000': 0, '500': 0, '200': 0, '100': 0, '50': 0, '20': 0, '10': 0, 'coins': 0
    };
    final auditCtrl = context.read<NightAuditController>();
    final String businessDate = auditCtrl.currentBusinessDay?['business_date'] ??
        DateTime.now().toIso8601String().split('T')[0];

    final List unclosedCashiers = (auditCtrl.validationData?['unclosedCashiers'] as List?) ?? [];
    
    final userMap = await TokenStorage.getUser();
    final int? currentUserId = userMap?['id'] != null ? int.tryParse(userMap!['id'].toString()) : null;

    int? selectedCashierId = currentUserId;
    if (unclosedCashiers.isNotEmpty) {
      final firstMatch = unclosedCashiers.firstWhere(
        (c) => (int.tryParse(c['id']?.toString() ?? '') == currentUserId),
        orElse: () => unclosedCashiers.first,
      );
      selectedCashierId = int.tryParse(firstMatch['id']?.toString() ?? '') ?? currentUserId;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            double totalCash = 0;
            denoms.forEach((k, v) {
              if (k == 'coins') {
                totalCash += v * 1.0;
              } else {
                totalCash += (double.tryParse(k) ?? 0) * v;
              }
            });

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.point_of_sale_outlined, color: posOrange),
                  SizedBox(width: 10),
                  Text('Close Shift / Cashier Handover', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Submit physical cash handover for business date: $businessDate',
                        style: const TextStyle(fontSize: 13, color: posTextMuted),
                      ),
                      const SizedBox(height: 12),

                      if (unclosedCashiers.isNotEmpty) ...[
                        const Text(
                          'Select Cashier to Close Shift:',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: posTextDark),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.white,
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              isExpanded: true,
                              value: selectedCashierId,
                              items: unclosedCashiers.map<DropdownMenuItem<int>>((c) {
                                final cId = int.tryParse(c['id']?.toString() ?? '') ?? 0;
                                final name = c['name'] ?? 'User #$cId';
                                final bCount = c['billCount'] ?? 1;
                                return DropdownMenuItem<int>(
                                  value: cId,
                                  child: Text('$name ($bCount bill${bCount > 1 ? 's' : ''})'),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() {
                                    selectedCashierId = val;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: denoms.keys.map((k) {
                          final label = k == 'coins' ? 'Coins' : '₹$k';
                          return SizedBox(
                            width: 105,
                            child: TextFormField(
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: label,
                                isDense: true,
                                border: const OutlineInputBorder(),
                              ),
                              initialValue: denoms[k].toString(),
                              onChanged: (val) {
                                setDialogState(() {
                                  denoms[k] = int.tryParse(val) ?? 0;
                                });
                              },
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFFEDD5)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Physical Cash Total:', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text('₹${totalCash.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: posOrange)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: posOrange,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                    try {
                      await ApiClient.post(ApiEndpoints.hrmsHandover, {
                        if (selectedCashierId != null) 'cashier_id': selectedCashierId,
                        'handover_date': businessDate,
                        'physical_cash': totalCash,
                        'denominations': denoms,
                      });

                      if (mounted) {
                        Navigator.pop(dialogCtx);
                        scaffoldMessenger.showSnackBar(
                          const SnackBar(
                            content: Text('✅ Shift Handover submitted successfully!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        await auditCtrl.fetchStatus();
                      }
                    } catch (e) {
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text('❌ Error submitting shift handover: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('Submit Shift Handover'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showOpenKotsResolveDialog(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final auditCtrl = context.read<NightAuditController>();

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.restaurant, color: posOrange),
            SizedBox(width: 10),
            Text('Clear Open Kitchen Orders (KOTs)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Clear all remaining open/unbilled Kitchen Orders (KOTs) for the current business date?',
                style: TextStyle(fontSize: 14, color: posTextDark),
              ),
              SizedBox(height: 10),
              Text(
                'This will mark unbilled kitchen tickets as CLOSED so Night Audit can proceed smoothly.',
                style: TextStyle(fontSize: 12, color: posTextMuted),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: posOrange, foregroundColor: Colors.white),
            onPressed: () async {
              try {
                await ApiClient.post('/api/night-audit/clear-kots', {});
                if (mounted) {
                  Navigator.pop(dialogCtx);
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('✅ Open KOTs cleared successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  auditCtrl.runValidation();
                }
              } catch (e) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(content: Text('❌ Error clearing KOTs: $e'), backgroundColor: Colors.red),
                );
              }
            },
            icon: const Icon(Icons.check_circle, size: 16),
            label: const Text('Clear All Open KOTs'),
          ),
        ],
      ),
    );
  }

  Widget _buildPosDenomField(
    NightAuditController controller,
    String key,
    String label,
  ) {
    return SizedBox(
      width: 145,
      child: TextFormField(
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: posOrange, width: 1.5),
          ),
        ),
        initialValue: controller.denominations[key]?.toString() ?? '0',
        onChanged: (val) {
          final count = int.tryParse(val) ?? 0;
          controller.updateDenomination(key, count);
        },
      ),
    );
  }

  Widget _buildHistoryTab(BuildContext context, NightAuditController controller) {
    final history = controller.historyList;

    if (history.isEmpty) {
      return const Center(
        child: Text('No previous Night Audit runs found.', style: TextStyle(color: posTextMuted)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: history.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final run = history[index];
        final String auditDate = run['audit_date'] ?? 'N/A';
        final String status = run['status'] ?? 'SUCCESS';
        final double netSales = double.tryParse(run['net_sales']?.toString() ?? '0') ?? 0.0;
        final double cashVariance = double.tryParse(run['cash_variance']?.toString() ?? '0') ?? 0.0;
        final String userName = run['user']?['full_name'] ?? run['user']?['username'] ?? 'System';

        return Container(
          decoration: BoxDecoration(
            color: posCardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: status == 'SUCCESS'
                  ? const Color(0xFFDCFCE7)
                  : status == 'COMPLETED_WITH_WARNINGS'
                      ? const Color(0xFFFEF3C7)
                      : const Color(0xFFFEE2E2),
              child: Icon(
                status == 'SUCCESS'
                    ? Icons.check_circle_outline
                    : status == 'COMPLETED_WITH_WARNINGS'
                        ? Icons.warning_amber_rounded
                        : Icons.error_outline,
                color: status == 'SUCCESS'
                    ? const Color(0xFF16A34A)
                    : status == 'COMPLETED_WITH_WARNINGS'
                        ? const Color(0xFFD97706)
                        : const Color(0xFFDC2626),
              ),
            ),
            title: Text(
              'Audit Date: $auditDate',
              style: const TextStyle(fontWeight: FontWeight.bold, color: posTextDark),
            ),
            subtitle: Text('Net Sales: ₹${netSales.toStringAsFixed(2)} | By: $userName', style: const TextStyle(fontSize: 13, color: posTextMuted)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: status == 'SUCCESS' ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: status == 'SUCCESS' ? const Color(0xFF15803D) : const Color(0xFFB45309),
                ),
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildRowDetail('Gross Sales', '₹${run['gross_sales'] ?? '0.00'}'),
                    _buildRowDetail('Total Discounts', '₹${run['total_discounts'] ?? '0.00'}'),
                    _buildRowDetail('Total Taxes', '₹${run['total_taxes'] ?? '0.00'}'),
                    _buildRowDetail('Expected Cash', '₹${run['cash_expected'] ?? '0.00'}'),
                    _buildRowDetail('Physical Cash', '₹${run['cash_physical'] ?? '0.00'}'),
                    _buildRowDetail('Cash Variance', '₹${cashVariance.toStringAsFixed(2)}'),
                    if (_isRestaurantModule)
                      _buildRowDetail('Open KOT Count', '${run['open_kot_count'] ?? 0}'),
                    _buildRowDetail('Execution Time', '${run['completed_at'] ?? 'N/A'}'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRowDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: posTextMuted, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: posTextDark, fontSize: 13)),
        ],
      ),
    );
  }

  void _confirmAndExecuteAudit(
    BuildContext context,
    NightAuditController controller,
    bool hasWarnings,
  ) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Confirm Night Audit', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          hasWarnings
              ? 'There are open warnings in the checklist. Are you sure you want to FORCE RUN the Night Audit and close the day?'
              : 'Are you sure you want to run the Night Audit? This will close the current business date and advance the system date to the next day.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: posTextMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: hasWarnings ? const Color(0xFFD97706) : posOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final success = await controller.executeAudit(forceRun: hasWarnings);
              if (mounted) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? '✅ Night Audit completed successfully!'
                          : '❌ Night Audit failed: ${controller.lastRunResult?['message'] ?? 'Error'}',
                    ),
                    backgroundColor: success ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                  ),
                );
              }
            },
            child: Text(hasWarnings ? 'Force Execute' : 'Confirm & Run'),
          ),
        ],
      ),
    );
  }
}
