import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/app_config.dart';
import '../dashboard/rider_console_screen.dart';
import '../dashboard/server_config_screen.dart';
import 'rider_auth_screen.dart';

class RiderAppSplashScreen extends StatefulWidget {
  const RiderAppSplashScreen({super.key});

  @override
  State<RiderAppSplashScreen> createState() => _RiderAppSplashScreenState();
}

class _RiderAppSplashScreenState extends State<RiderAppSplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    await Future.delayed(const Duration(seconds: 2));

    try {
      bool hasConfig = await AppConfig.configExists();
      if (!hasConfig) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const ServerConfigScreen(
              nextScreen: RiderAppSplashScreen(),
            ),
          ),
        );
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final riderDataStr = prefs.getString('delivery_logged_in_rider');

      if (!mounted) return;

      if (riderDataStr != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const RiderConsoleScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const RiderAuthScreen()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const RiderAuthScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = Colors.teal.shade700;

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
                  Icons.delivery_dining_outlined,
                  size: 80,
                  color: accentColor,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "FreshExpress Rider",
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Enterprise Logistics & Delivery Partner",
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
