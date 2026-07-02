import 'dart:io' show Platform;
import 'package:flutter/material.dart';

import '../../controllers/dashboard/dashboard_controller.dart' as dashboard_user;
import '../../core/settings/local_preferences.dart';
import '../../models/auth/permission_service.dart';
import '../../screens/dashboard/main_dashboard_screen.dart';
import '../../screens/dashboard/retailer_console_screen.dart';
import '../../screens/inventory/salescreen.dart';

class HomeRouteHelper {
  HomeRouteHelper._();

  static Future<Widget> resolve() async {
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
