import 'package:flutter/material.dart';

import '../core/auth/token_storage.dart';
import '../core/config/app_config.dart';
import '../core/config/server_check.dart';
import '../core/navigation/home_route_helper.dart';
import '../models/auth/permission_service.dart';
import 'auth/login_screen.dart';
import 'dashboard/server_config_screen.dart';
import 'recovery/auto_reinstall_screen.dart';
import 'recovery/config_recovery_screen.dart';
import 'recovery/full_recovery_screen.dart';
import 'settings/outlet_setup_screen.dart';
import 'system/server_error_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _runBootSequence();
  }

  Future<void> _runBootSequence() async {
    bool hasConfig = await AppConfig.configExists();
    if (!hasConfig) {
      if (!mounted) return;
      _navigate(const ServerConfigScreen());
      return;
    }

    final health = await checkServer();

    if (!mounted) return;

    switch (health.action) {
      case 'OK':
        await _handleNormalLoginFlow();
        break;
      case 'RECOVER_CONFIG':
        _navigate(ConfigRecoveryScreen(message: health.message));
        break;
      case 'AUTO_REINSTALL' || 'LICENSE_ERROR':
        _navigate(const AutoReinstallScreen());
        break;
      case 'FULL_RECOVERY':
        _navigate(FullRecoveryScreen(message: health.message));
        break;
      case 'SERVER_DOWN':
      default:
        _navigate(const ServerErrorScreen());
        break;
    }
  }

  Future<void> _handleNormalLoginFlow() async {
    final bool hasOutlet = AppConfig.outlets.isNotEmpty;

    var token = await TokenStorage.read();
    final bool isTokenValid = token != null && !TokenStorage.isExpired(token);

    if (token != null && !isTokenValid) {
      await TokenStorage.clear();
      token = null;
    }

    final role = await TokenStorage.getRole();
    final perms = await TokenStorage.getPermissions();
    if (role != null) {
      PermissionService.init(role: role, permissions: perms);
    }

    if (!mounted) return;

    if (!hasOutlet) {
      _navigate(const OutletSetupScreen());
    } else if (token == null) {
      _navigate(const LoginScreen());
    } else {
      _navigate(await HomeRouteHelper.resolve());
    }
  }

  void _navigate(Widget screen) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            // Logo Area
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.inventory_2_rounded,
                        size: 80, color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    AppConfig.outlets.isNotEmpty ? "RETAILPOS" : "SETUP",
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                        ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Enterprise Management System",
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            // Loading Indicator
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const Spacer(),
            // Footer
            const Padding(
              padding: EdgeInsets.only(bottom: 24.0),
              child: Text(
                "Version 1.1.32 • Initiating Secure Boot...",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

