import 'package:flutter/material.dart';

import '../../controllers/dashboard/dashboard_controller.dart' as dashboard_user;
import '../../core/settings/local_preferences.dart';
import '../../models/auth/permission_service.dart';
import '../../screens/dashboard/main_dashboard_screen.dart';
import '../../screens/inventory/salescreen.dart';

class HomeRouteHelper {
  HomeRouteHelper._();

  static Future<Widget> resolve() async {
    final preference = await LocalPreferences.getDefaultStartupScreen();
    final user = await dashboard_user.load();
    final businessType = (user?.outletType ?? '').toUpperCase();
    final canOpenRetail = PermissionService.can('RETAIL_SALES') ||
        businessType == 'RETAIL';

    if (preference == 'RETAIL_SALES' && canOpenRetail) {
      return const SaleScreen();
    }

    return const MainDashboardScreen();
  }
}
