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
  bool _isLoading = false;
  bool _isFetching = false;
  bool _hasFetched = false;
  List<dynamic> _fetchedOutlets = [];
  String? _selectedOutletCode;

  @override
  void initState() {
    super.initState();
    _urlCtrl.text = AppConfig.baseUrl;

    // Auto-fetch outlets if baseUrl is already configured
    if (AppConfig.baseUrl.isNotEmpty) {
      Future.microtask(() => _fetchOutletsAndPreselect());
    }
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchOutlets() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Server URL is required to fetch outlets"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isFetching = true;
      _fetchedOutlets = [];
      _selectedOutletCode = null;
      _hasFetched = true;
    });

    try {
      String finalUrl = url;
      if (finalUrl.endsWith('/')) {
        finalUrl = finalUrl.substring(0, finalUrl.length - 1);
      }

      final res = await ApiClient.get("$finalUrl/api/public/outlets");
      if (res['success'] == true && res['data'] is List) {
        final list = res['data'] as List;
        setState(() {
          _fetchedOutlets = list;
          if (_fetchedOutlets.isNotEmpty) {
            _selectedOutletCode = _fetchedOutlets.first['outlet_code']?.toString();
          }
        });
      } else {
        setState(() {
          _fetchedOutlets = [];
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fetchedOutlets = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to fetch outlets: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isFetching = false;
        });
      }
    }
  }

  Future<void> _fetchOutletsAndPreselect() async {
    await _fetchOutlets();
    if (AppConfig.outlets.isNotEmpty) {
      final configuredOutlet = AppConfig.outlets.first;
      if (_fetchedOutlets.any((item) => item['outlet_code'] == configuredOutlet)) {
        setState(() {
          _selectedOutletCode = configuredOutlet;
        });
      }
    }
  }

  Future<void> _saveAndRestart() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Server URL is required"),
            backgroundColor: Colors.red),
      );
      return;
    }

    if (_fetchedOutlets.isNotEmpty && _selectedOutletCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Please select an outlet"),
            backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String finalUrl = url;
      if (finalUrl.endsWith('/')) {
        finalUrl = finalUrl.substring(0, finalUrl.length - 1);
      }

      List<String> finalOutlets = [];
      if (_selectedOutletCode != null && _fetchedOutlets.isNotEmpty) {
        finalOutlets = [_selectedOutletCode!];
      }

      await AppConfig.saveConfig(finalUrl, finalOutlets);

      if (!mounted) return;

      final Widget destination = finalOutlets.isEmpty
          ? (widget.nextScreen ?? const OutletSetupScreen())
          : (widget.nextScreen ?? const SplashScreen());

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => destination,
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
    final bool canSave = _urlCtrl.text.trim().isNotEmpty &&
        !_isLoading &&
        !_isFetching &&
        (_fetchedOutlets.isEmpty || _selectedOutletCode != null);

    final String buttonText = _fetchedOutlets.isNotEmpty
        ? "Save Configuration"
        : "Save & Proceed to Outlet Setup";

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
                "Configure the server connection and select your outlet.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _urlCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: "Server URL",
                        hintText: "http://192.168.1.100:3000",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.link),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isFetching ? null : _fetchOutlets,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: _isFetching
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.sync),
                    ),
                  ),
                ],
              ),
              if (_fetchedOutlets.isNotEmpty) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedOutletCode,
                  decoration: const InputDecoration(
                    labelText: "Select Outlet",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.storefront),
                  ),
                  items: _fetchedOutlets.map<DropdownMenuItem<String>>((dynamic item) {
                    return DropdownMenuItem<String>(
                      value: item['outlet_code']?.toString(),
                      child: Text(item['outlet_name']?.toString() ?? ''),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedOutletCode = value;
                    });
                  },
                ),
              ] else if (_hasFetched) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "No registered outlets found on this server. Proceed to registration and outlet setup.",
                          style: TextStyle(color: Colors.blue, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: canSave ? _saveAndRestart : null,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text(buttonText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
