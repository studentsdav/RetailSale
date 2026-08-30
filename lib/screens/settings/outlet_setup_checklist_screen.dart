import 'package:flutter/material.dart';

import '../../controllers/settings/outlet_onboarding_controller.dart';
import '../auth/user_management_screen.dart';
import '../dashboard/main_dashboard_screen.dart';
import '../inventory/item_master_screen.dart';
import '../inventory/supplier_master_screen.dart';
import '../restaurant/restaurant_setup_screen.dart';
import 'document_sequence_screen.dart';
import 'property_info_screen.dart';
import 'stock_location_screen.dart';

class OutletSetupChecklistScreen extends StatefulWidget {
  const OutletSetupChecklistScreen({super.key});

  @override
  State<OutletSetupChecklistScreen> createState() => _OutletSetupChecklistScreenState();
}

class _OutletSetupChecklistScreenState extends State<OutletSetupChecklistScreen> {
  final OutletOnboardingController _controller = OutletOnboardingController();

  @override
  void initState() {
    super.initState();
    _controller.refreshStatus();
  }

  void _navigateToStep(String key) async {
    Widget? destination;
    switch (key) {
      case 'PROPERTY':
        destination = const PropertyInfoScreen(outletid: 0);
        break;
      case 'SEQUENCE':
        destination = const DocumentSequenceScreen();
        break;
      case 'LOCATION':
        destination = const StockLocationScreen();
        break;
      case 'ITEM_MASTER':
        destination = const ItemMasterScreen();
        break;
      case 'SUPPLIER':
        destination = const SupplierMasterScreen();
        break;
      case 'RESTAURANT':
        destination = const RestaurantSetupScreen();
        break;
      case 'USERS':
        destination = const UserManagementScreen();
        break;
    }

    if (destination != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => destination!),
      );
      // Auto-refresh step status upon returning
      await _controller.refreshStatus();
      if (_controller.is100PercentComplete && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainDashboardScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryTeal = theme.primaryColor != Colors.blue ? theme.primaryColor : const Color(0xFF0D9488);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final steps = _controller.steps;
        final completedCount = _controller.completedStepsCount;
        final totalCount = _controller.totalStepsCount;
        final progress = _controller.completionPercentage;
        final isComplete = _controller.is100PercentComplete;

        return Scaffold(
          backgroundColor: const Color(0xFFF1F5F9), // Standard Famalth Polaris Slate Background
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0.5,
            iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
            title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Store Onboarding & Setup Guide',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Complete required outlet configurations step-by-step',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const MainDashboardScreen()),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF334155),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.dashboard_outlined, size: 18),
                  label: const Text(
                    'Dashboard',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Refresh Status',
                icon: const Icon(Icons.sync_rounded, color: Color(0xFF475569)),
                onPressed: () => _controller.refreshStatus(),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: _controller.isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: primaryTeal),
                      const SizedBox(height: 16),
                      const Text(
                        'Checking store setup status...',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 13.5),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 920),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Famalth Hero Onboarding Progress Banner Card
                          Card(
                            elevation: 0,
                            color: isComplete ? const Color(0xFFF0FDF4) : const Color(0xFFF0FDFA),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: isComplete ? const Color(0xFFBBF7D0) : const Color(0xFFCCFBF1),
                                width: 1.5,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: isComplete
                                              ? const Color(0xFF16A34A).withOpacity(0.12)
                                              : primaryTeal.withOpacity(0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          isComplete ? Icons.verified_rounded : Icons.rocket_launch_rounded,
                                          color: isComplete ? const Color(0xFF16A34A) : primaryTeal,
                                          size: 28,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              isComplete
                                                  ? '🎉 Store Setup 100% Complete!'
                                                  : 'Outlet Setup Progress ($completedCount of $totalCount Steps)',
                                              style: const TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              isComplete
                                                  ? 'Your outlet is fully configured and ready for live billing, inventory, and operations.'
                                                  : 'Complete the setup steps below step-by-step to start billing and managing your store.',
                                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 13.5),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  // Progress Bar
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 10,
                                      backgroundColor: const Color(0xFFE2E8F0),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        isComplete ? const Color(0xFF16A34A) : primaryTeal,
                                      ),
                                    ),
                                  ),
                                  if (isComplete) ...[
                                    const SizedBox(height: 20),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: FilledButton.icon(
                                        onPressed: () {
                                          Navigator.pushReplacement(
                                            context,
                                            MaterialPageRoute(builder: (_) => const MainDashboardScreen()),
                                          );
                                        },
                                        style: FilledButton.styleFrom(
                                          backgroundColor: const Color(0xFF16A34A),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                                        label: const Text(
                                          'Launch Store Dashboard & POS Billing',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          const Text(
                            'Required Setup Tasks',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Step Cards Grid in Famalth Theme
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: steps.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final step = steps[index];
                              final isDone = step.isConfigured;

                              return Card(
                                margin: EdgeInsets.zero,
                                elevation: 0,
                                color: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: isDone ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
                                    width: 1.2,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    children: [
                                      // Step Icon Box
                                      Container(
                                        width: 46,
                                        height: 46,
                                        decoration: BoxDecoration(
                                          color: isDone
                                              ? const Color(0xFFF0FDF4)
                                              : const Color(0xFFFFF7ED),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: isDone
                                                ? const Color(0xFFDCFCE7)
                                                : const Color(0xFFFFEDD5),
                                          ),
                                        ),
                                        child: Icon(
                                          step.icon,
                                          color: isDone
                                              ? const Color(0xFF16A34A)
                                              : const Color(0xFFEA580C),
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    step.title,
                                                    style: const TextStyle(
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.w700,
                                                      color: Color(0xFF0F172A),
                                                    ),
                                                  ),
                                                ),
                                                // Status Badge (Soft Amber / Soft Green)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: isDone ? const Color(0xFFF0FDF4) : const Color(0xFFFFF7ED),
                                                    borderRadius: BorderRadius.circular(20),
                                                    border: Border.all(
                                                      color: isDone ? const Color(0xFFDCFCE7) : const Color(0xFFFFEDD5),
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        isDone ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                                                        size: 13,
                                                        color: isDone ? const Color(0xFF15803D) : const Color(0xFFC2410C),
                                                      ),
                                                      const SizedBox(width: 5),
                                                      Text(
                                                        isDone ? 'CONFIGURED' : 'NEEDS SETUP',
                                                        style: TextStyle(
                                                          color: isDone ? const Color(0xFF15803D) : const Color(0xFFC2410C),
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              step.subtitle,
                                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Action Button
                                      FilledButton(
                                        onPressed: () => _navigateToStep(step.key),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: isDone ? const Color(0xFFF1F5F9) : primaryTeal,
                                          foregroundColor: isDone ? const Color(0xFF475569) : Colors.white,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: Text(
                                          isDone ? 'Modify Setup' : step.actionText,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}
