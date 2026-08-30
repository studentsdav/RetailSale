import 'dart:io' show Platform;
import 'package:flutter/material.dart';

import '../../controllers/dashboard/dashboard_controller.dart' as dashboard_user;
import '../../controllers/settings/outlet_onboarding_controller.dart';
import '../../core/settings/local_preferences.dart';
import '../../models/auth/permission_service.dart';
import '../../screens/dashboard/main_dashboard_screen.dart';
import '../../screens/dashboard/retailer_console_screen.dart';
import '../../screens/inventory/salescreen.dart';
import '../../screens/restaurant/captain_dashboard_screen.dart';
import '../../screens/restaurant/kds_screen.dart';
import '../../screens/settings/outlet_setup_checklist_screen.dart';

class HomeRouteHelper {
  HomeRouteHelper._();

  static Future<Widget> resolve() async {
    // 1. Check if store onboarding setup is incomplete for this outlet
    try {
      final onboardingCtrl = OutletOnboardingController();
      await onboardingCtrl.refreshStatus();
      if (!onboardingCtrl.is100PercentComplete) {
        return const OutletSetupChecklistScreen();
      }
    } catch (_) {}

    if (Platform.isAndroid || Platform.isIOS) {
      return const RetailerConsoleScreen();
    }

    final preference = await LocalPreferences.getDefaultStartupScreen();
    final user = await dashboard_user.load();
    final businessType = (user?.outletType ?? '').toUpperCase();
    final userRole = (user?.role ?? '').toUpperCase();

    final canOpenRetail = PermissionService.can('RETAIL_SALES') ||
        businessType == 'RETAIL' ||
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
        }.contains(businessType);

    if ((userRole == 'RETAIL' || userRole == 'CASHIER' || preference == 'RETAIL_SALES') && canOpenRetail) {
      return const SaleScreen();
    }

    if (userRole == 'KDS') {
      return const KdsScreen();
    }

    if (preference == 'RESTAURANT_CONSOLE' ||
        preference == 'CAPTAIN_POS' ||
        userRole == 'CAPTAIN' ||
        userRole == 'WAITER') {
      return const CaptainDashboardScreen();
    }

    return const MainDashboardScreen();
  }
}
