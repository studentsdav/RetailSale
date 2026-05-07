import 'package:flutter/material.dart';
import 'package:inventory/screens/splash_screen.dart';

import '../../core/config/app_config.dart';
import '../../main.dart'; // Adjust import to where your main() or restart logic is

class ServerConfigScreen extends StatefulWidget {
  const ServerConfigScreen({super.key});

  @override
  State<ServerConfigScreen> createState() => _ServerConfigScreenState();
}

class _ServerConfigScreenState extends State<ServerConfigScreen> {
  final _urlCtrl = TextEditingController();
  final _outletsCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    _urlCtrl.text = AppConfig.baseUrl;

    if (AppConfig.outlets.isNotEmpty) {
      _outletsCtrl.text = AppConfig.outlets.join(', ');
    }
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _outletsCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveAndRestart() async {
    if (_urlCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Server URL is required"),
            backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String finalUrl = _urlCtrl.text.trim();
      if (finalUrl.endsWith('/')) {
        finalUrl = finalUrl.substring(0, finalUrl.length - 1);
      }

      List<String> finalOutlets = _outletsCtrl.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      await AppConfig.saveConfig(finalUrl, finalOutlets);

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const SplashScreen(),
        ),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(title: const Text("System Configuration")),
      body: Center(
        child: Container(
          width: 450,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.dns, size: 64, color: Colors.blue),
              const SizedBox(height: 16),
              const Text("Terminal Setup",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                "Configure the server connection and assign outlets to this terminal.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _urlCtrl,
                decoration: const InputDecoration(
                  labelText: "Server URL",
                  hintText: "http://192.168.1.100:3000",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _outletsCtrl,
                decoration: const InputDecoration(
                  labelText: "Assigned Outlets (Comma Separated)",
                  hintText: "e.g. OUTLETID_1, OUTLETID_2",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.storefront),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _isLoading ? null : _saveAndRestart,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text("Save Configuration"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
