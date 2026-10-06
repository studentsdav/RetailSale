import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
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
    final user = await dashboard_user.load();
    final outletCode = (user?.outletCode ?? '').trim();
    final outletIdentifier = outletCode.isNotEmpty ? outletCode : (user?.outletId ?? 1).toString();

    final isDone = await LocalPreferences.isOnboardingCompleted(outletIdentifier);
    if (!isDone) {
      final onboardingCtrl = OutletOnboardingController();
      await onboardingCtrl.refreshStatus().catchError((_) {});
      if (!onboardingCtrl.is100PercentComplete) {
        return const OutletSetupChecklistScreen();
      } else {
        await LocalPreferences.setOnboardingCompleted(outletIdentifier, true);
      }
    }

    final preference = await LocalPreferences.getDefaultStartupScreen();
    final businessType = (user?.outletType ?? '').toString().toUpperCase();
    final userRole = (user?.role ?? '').toString().toUpperCase();

    // 1. Restaurant Captain / Waiter Floor Console
    if (preference == 'RESTAURANT_CONSOLE' ||
        preference == 'CAPTAIN_POS' ||
        userRole == 'CAPTAIN' ||
        userRole == 'WAITER' ||
        userRole == 'CAPTION' ||
        userRole == 'STEWARD' ||
        userRole == 'SERVER') {
      return const CaptainDashboardScreen();
    }

    // 2. Kitchen Display System (KDS)
    if (userRole == 'KDS') {
      return const KdsScreen();
    }

    // 3. Retail POS
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

    // 4. Mobile Retailer Console Fallback (for store/owner mobile apps)
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      return const RetailerConsoleScreen();
    }

    // 5. Default Enterprise Dashboard
    return const MainDashboardScreen();
  }
}
