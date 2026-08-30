import 'dart:io' show Platform;
import 'package:flutter/material.dart';

import '../../controllers/dashboard/dashboard_controller.dart' as dashboard_user;
import '../../controllers/settings/outlet_onboarding_controller.dart';
import '../../core/settings/local_preferences.dart';
import '../../models/auth/permission_service.dart';
import '../../screens/dashboard/main_dashboard_screen.dart';
import '../../screens/dashboard/retailer_console_screen.dart';
import '../../screens/inventory/salescreen.dart';
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

    if (preference == 'RETAIL_SALES' && canOpenRetail) {
      return const SaleScreen();
    }

    return const MainDashboardScreen();
  }
}
