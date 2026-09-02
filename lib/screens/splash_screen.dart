import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:io';

import '../utils/branding_storage.dart';
import '../core/auth/token_storage.dart';
import '../core/config/app_brand.dart';
import '../core/config/app_config.dart';
import '../core/config/server_check.dart';
import '../core/navigation/home_route_helper.dart';
import '../models/auth/permission_service.dart';
import '../widgets/famalth_watermark.dart';
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
  String? _clientLogoPath;

  @override
  void initState() {
    super.initState();
    _loadClientLogo();
    _runBootSequence();
  }

  Future<void> _loadClientLogo() async {
    try {
      final logo = await BrandingStorage.getCurrentLogoPath();
      if (mounted) {
        setState(() {
          _clientLogoPath = logo;
        });
      }
    } catch (_) {}
  }

  Widget _buildSplashLogo(double size) {
    if (_clientLogoPath != null && _clientLogoPath!.trim().isNotEmpty) {
      final path = _clientLogoPath!.trim();

      // 1. Base64 Data URI or raw Base64 string
      if (path.startsWith('data:image') || path.length > 200) {
        try {
          final base64Str = path.contains(',') ? path.split(',').last : path;
          final bytes = base64Decode(base64Str.trim());
          return ClipOval(
            child: Image.memory(
              bytes,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _famalthMascotFallback(size),
            ),
          );
        } catch (_) {}
      }

      // 2. HTTP / HTTPS URL
      if (path.startsWith('http://') || path.startsWith('https://')) {
        return ClipOval(
          child: Image.network(
            path,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _famalthMascotFallback(size),
          ),
        );
      }

      // 3. Local File Path (non-web)
      if (!kIsWeb && File(path).existsSync()) {
        return ClipOval(
          child: Image.file(
            File(path),
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _famalthMascotFallback(size),
          ),
        );
      }
    }

    // 4. Fallback Platform Mascot Logo (FAMALTH LYNX)
    return _famalthMascotFallback(size);
  }

  Widget _famalthMascotFallback(double size) {
    return ClipOval(
      child: Image.asset(
        'assets/images/famalth_lynx_logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 40),
        ),
      ),
    );
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

    if (token == null) {
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
                    width: 110,
                    height: 110,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _buildSplashLogo(102),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    AppBrand.productName,
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
              child: FamalthWatermark(showVersion: true),
            ),
          ],
        ),
      ),
    );
  }
}

