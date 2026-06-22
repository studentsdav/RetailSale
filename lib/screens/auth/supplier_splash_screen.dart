import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../core/auth/token_storage.dart';
import '../../core/navigation/home_route_helper.dart';
import 'supplier_otp_login_screen.dart';

class SupplierAppSplashScreen extends StatefulWidget {
  const SupplierAppSplashScreen({super.key});

  @override
  State<SupplierAppSplashScreen> createState() => _SupplierAppSplashScreenState();
}

class _SupplierAppSplashScreenState extends State<SupplierAppSplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    await Future.delayed(const Duration(seconds: 2));

    try {
      if (!kIsWeb && Platform.isWindows) {
        // Bypass login on Windows for testing!
        final nextWidget = await HomeRouteHelper.resolve();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => nextWidget),
        );
        return;
      }

      final token = await TokenStorage.read();
      final bool isTokenValid = token != null && !TokenStorage.isExpired(token);

      if (!mounted) return;

      if (isTokenValid) {
        final nextWidget = await HomeRouteHelper.resolve();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => nextWidget),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const SupplierOtpLoginScreen()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SupplierOtpLoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = Colors.indigo.shade700;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              accentColor.withOpacity(0.08),
              theme.colorScheme.surface,
            ],
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
                  color: accentColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warehouse_outlined,
                  size: 80,
                  color: accentColor,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "FreshConsole Supplier",
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Enterprise Resource & Merchant Dashboard",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              CircularProgressIndicator(strokeWidth: 3, color: accentColor),
              const SizedBox(height: 32),
              const Text(
                "Powered by RetailPOS",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
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
