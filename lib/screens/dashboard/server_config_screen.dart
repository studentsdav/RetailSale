import 'package:flutter/material.dart';
import 'package:retailpos/screens/splash_screen.dart';

import '../../core/api/api_client.dart';
import '../../core/config/app_config.dart';
import '../settings/outlet_setup_screen.dart';

class ServerConfigScreen extends StatefulWidget {
  final Widget? nextScreen;
  const ServerConfigScreen({super.key, this.nextScreen});

  @override
  State<ServerConfigScreen> createState() => _ServerConfigScreenState();
}

class _ServerConfigScreenState extends State<ServerConfigScreen> {
  final _urlCtrl = TextEditingController();
  final _outletCodeCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _urlCtrl.text = AppConfig.baseUrl;
    _outletCodeCtrl.text = ""; // Keep clean to prevent pre-filling default/previous outlets
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _outletCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkAndProceed() async {
    final url = _urlCtrl.text.trim();
    final outletCode = _outletCodeCtrl.text.trim();

    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Server URL is required"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String finalUrl = url;
      if (finalUrl.endsWith('/')) {
        finalUrl = finalUrl.substring(0, finalUrl.length - 1);
      }

      if (outletCode.isEmpty) {
        // No outlet code entered -> New user registration flow
        await AppConfig.saveConfig(finalUrl, []);
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => widget.nextScreen ?? const OutletSetupScreen(),
          ),
          (route) => false,
        );
        return;
      }

      // Outlet code entered -> Check server for specific outlet existence securely
      final res = await ApiClient.post(
        "$finalUrl/api/public/outlet/check",
        {'outlet_code': outletCode},
      );

      if (res['success'] == true && res['exists'] == true) {
        // Outlet exists -> Save configuration and proceed to Login / Splash
        await AppConfig.saveConfig(finalUrl, [outletCode]);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Outlet '$outletCode' verified successfully!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => widget.nextScreen ?? const SplashScreen(),
          ),
          (route) => false,
        );
      } else {
        // Outlet code not found -> Prompt registration
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Outlet code '$outletCode' not found. Proceeding to registration...",
            ),
            backgroundColor: Colors.orange,
          ),
        );
        await AppConfig.saveConfig(finalUrl, []);
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => widget.nextScreen ?? const OutletSetupScreen(),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Connection error: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canProceed = _urlCtrl.text.trim().isNotEmpty && !_isLoading;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(title: const Text("System Configuration")),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 450,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.dns_rounded, size: 56, color: Colors.blue),
                const SizedBox(height: 16),
                const Text(
                  "Terminal Setup",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Configure server URL and enter your outlet code to proceed.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, height: 1.4),
                ),
                const SizedBox(height: 28),

                // Server URL Field
                TextField(
                  controller: _urlCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: "Server URL",
                    hintText: "https://retail-sale-backend.onrender.com",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.link_rounded),
                  ),
                ),
                const SizedBox(height: 20),

                // Outlet Code Field (Optional)
                TextField(
                  controller: _outletCodeCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: "Outlet Code (Optional)",
                    hintText: "e.g. MUMBAI_STORE (Leave blank for new store)",
                    helperText:
                        "Enter your outlet code if you have one, or leave blank to register a new store.",
                    helperMaxLines: 2,
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.storefront_rounded),
                  ),
                ),
                const SizedBox(height: 28),

                // Submit Button
                SizedBox(
                  height: 50,
                  child: FilledButton(
                    onPressed: canProceed ? _checkAndProceed : null,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text("Verifying..."),
                            ],
                          )
                        : Text(
                            _outletCodeCtrl.text.trim().isNotEmpty
                                ? "Verify & Connect Outlet"
                                : "Save & Register New Store",
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
