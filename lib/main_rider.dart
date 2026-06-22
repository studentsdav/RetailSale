import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/security/recovery_controller.dart';
import 'controllers/security/user_controller.dart';
import 'controllers/settings/notification_services.dart';
import 'controllers/settings/app_branding_controller.dart';
import 'controllers/settings/system_settings_controller.dart';
import 'controllers/settings/theme_controller.dart';
import 'controllers/settings/ui_preferences_controller.dart';
import 'controllers/inventory/bom_controller.dart';
import 'core/config/app_config.dart';
import 'main.dart'; // To reuse MyApp and global keys
import 'screens/auth/rider_splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  await AppConfig.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SystemSettingsController()),
        ChangeNotifierProvider(create: (_) => ThemeController()..load()),
        ChangeNotifierProvider(create: (_) => UiPreferencesController()..load()),
        ChangeNotifierProvider(create: (_) => AppBrandingController()..loadLocal()),
        ChangeNotifierProvider(create: (_) => UserController()),
        ChangeNotifierProvider(create: (_) => RecoveryController()),
        ChangeNotifierProvider(create: (_) => BOMController()),
      ],
      child: const MyApp(homeWidget: RiderAppSplashScreen()),
    ),
  );
}
