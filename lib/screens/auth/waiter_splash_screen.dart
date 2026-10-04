import 'package:flutter/material.dart';
import '../../core/auth/token_storage.dart';
import '../../core/config/app_config.dart';
import '../dashboard/server_config_screen.dart';
import '../restaurant/waiter_app_screen.dart';
import 'waiter_auth_screen.dart';

class WaiterAppSplashScreen extends StatefulWidget {
  const WaiterAppSplashScreen({super.key});

  @override
  State<WaiterAppSplashScreen> createState() => _WaiterAppSplashScreenState();
}

class _WaiterAppSplashScreenState extends State<WaiterAppSplashScreen> {
  static const Color primaryTeal = Color(0xFF0D9488);

  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    await Future.delayed(const Duration(milliseconds: 1200));

    try {
      bool hasConfig = await AppConfig.configExists();
      if (!hasConfig) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const ServerConfigScreen(
              nextScreen: WaiterAppSplashScreen(),
            ),
          ),
        );
        return;
      }

      final token = await TokenStorage.read();
      final user = await TokenStorage.getUser();
      final role = (user?['role'] ?? '').toString().toUpperCase().trim();

      if (!mounted) return;

      final bool isAllowed = role == 'WAITER' ||
          role == 'CAPTAIN' ||
          role == 'CAPTION' ||
          role == 'STEWARD' ||
          role == 'SERVER' ||
          role == 'ADMIN' ||
          role == 'MANAGER';

      if (token != null && token.isNotEmpty && isAllowed) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const WaiterAppScreen()),
        );
      } else {
        if (token != null && token.isNotEmpty && !isAllowed) {
          await TokenStorage.clear();
        }
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const WaiterAuthScreen()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const WaiterAuthScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF0F172A), const Color(0xFF020617)]
                : [const Color(0xFFF0FDFA), const Color(0xFFFFFFFF)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: primaryTeal.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.restaurant_rounded,
                  size: 72,
                  color: primaryTeal,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "RetailPOS Waiter Floor",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: primaryTeal,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Tables • KOT Kitchen Orders • Split Billing",
                style: TextStyle(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              const CircularProgressIndicator(strokeWidth: 3, color: primaryTeal),
              const SizedBox(height: 28),
              const Text(
                "Powered by FAMALTH RETAIL LYNX",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
