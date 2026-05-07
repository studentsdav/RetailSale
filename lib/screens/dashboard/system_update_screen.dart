import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:inventory/core/config/app_config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

class SystemUpdateScreen extends StatefulWidget {
  const SystemUpdateScreen({super.key});

  @override
  State<SystemUpdateScreen> createState() => _SystemUpdateScreenState();
}

class _SystemUpdateScreenState extends State<SystemUpdateScreen> {
  double _progress = 0.0;
  String _statusText = "Downloading update...";
  bool _isChecking = true;
  bool _hasError = false;
  String _errorMessage = '';

  bool _updateAvailable = false;
  bool _isDownloading = false;

  String _currentVersion = 'Unknown';
  String _latestVersion = '';
  String _changelog = '';
  String _downloadUrl = '';

  @override
  void initState() {
    super.initState();
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    setState(() {
      _isChecking = true;
      _hasError = false;
    });

    try {
      // 1. Get current system version
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      _currentVersion = packageInfo.version;

      // 2. Fetch latest version from the Node.js API
      // Note: Replace with your ApiClient if you prefer!
      final res = await http.post(
          Uri.parse('${AppConfig.baseUrl}/api/public/system/check-update'));

      if (res.statusCode != 200) {
        throw Exception("Failed to connect to update server.");
      }

      final data = jsonDecode(res.body);

      if (data['success'] == true) {
        _latestVersion = data['latest_version'];
        _downloadUrl = data['download_url'];
        _changelog = data['changelog'] ??
            'General bug fixes and performance improvements.';

        // 3. Compare versions
        _updateAvailable = _isUpdateAvailable(_currentVersion, _latestVersion);
      } else {
        throw Exception(data['message'] ?? "Failed to verify latest version.");
      }
    } catch (e) {
      _hasError = true;
      _errorMessage = e.toString().replaceAll('Exception:', '').trim();
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  // Helper: Compares 1.0.0 with 1.2.0
  bool _isUpdateAvailable(String current, String latest) {
    try {
      List<int> currParts = current.split('.').map(int.parse).toList();
      List<int> latestParts = latest.split('.').map(int.parse).toList();

      for (int i = 0; i < 3; i++) {
        int c = currParts.length > i ? currParts[i] : 0;
        int l = latestParts.length > i ? latestParts[i] : 0;
        if (l > c) return true;
        if (l < c) return false;
      }
      return false;
    } catch (e) {
      return false; // Fallback to safe state if string is malformed
    }
  }

  Future<void> _startUpdate() async {
    setState(() {
      _isDownloading = true;
      _progress = 0.0;
      _statusText = "Starting download...";
    });

    try {
      final url = Uri.parse(_downloadUrl);
      final httpClient = HttpClient();
      final request = await httpClient.getUrl(url);

      final response = await request.close();

      if (response.statusCode != 200) {
        throw Exception("Server returned status ${response.statusCode}");
      }

      setState(() => _statusText = "Downloading installer...");

      final bytes = await consolidateHttpClientResponseBytes(
        response,
        onBytesReceived: (cumulative, total) {
          if (total != null) {
            setState(() {
              _progress = cumulative / total;
            });
          }
        },
      );

      final tempDir = Directory.systemTemp;
      final file = File('${tempDir.path}\\Inventory_Update_Downloaded.exe');
      await file.writeAsBytes(bytes);

      setState(() => _statusText = "Launch in progress...");

      if (Platform.isWindows) {
        await Process.start(
          'cmd',
          ['/c', 'start', '', file.path],
          runInShell: true,
        );
      } else {
        await Process.start(
          file.path,
          [],
          mode: ProcessStartMode.detached,
        );
      }

      exit(0);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _hasError = true;
          _errorMessage = "Update failed: $e";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("System Update"),
        centerTitle: true,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 4,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: _buildBodyContent(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBodyContent() {
    if (_isChecking) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 24),
          Text(
            "Checking for updates...",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text("Connecting to the secure cloud server.",
              style: TextStyle(color: Colors.grey)),
        ],
      );
    }

    // STATE 2: Error
    if (_hasError) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 64),
          const SizedBox(height: 16),
          const Text("Update Check Failed",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(_errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent)),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _checkForUpdates,
            icon: const Icon(Icons.refresh),
            label: const Text("Try Again"),
          )
        ],
      );
    }

    // STATE 3: Up To Date
    if (!_updateAvailable) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 80),
          const SizedBox(height: 24),
          const Text("You're all set!",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
              "Your INV system is running the latest version (v$_currentVersion).",
              style: const TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 32),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Back to Dashboard"),
          )
        ],
      );
    }

    // STATE 4: Update Available
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.system_update_alt, color: Colors.blue, size: 40),
            SizedBox(width: 16),
            Text("Update Available",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildVersionBadge(
                "Current", _currentVersion, Colors.grey.shade600),
            const Icon(Icons.arrow_forward, color: Colors.grey),
            _buildVersionBadge("Latest", _latestVersion, Colors.green.shade600),
          ],
        ),
        const SizedBox(height: 32),
        const Text("What's New:",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          height: 150,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: SingleChildScrollView(
            child: Text(_changelog,
                style: const TextStyle(fontSize: 14, height: 1.5)),
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          height: 54,
          child: FilledButton.icon(
            onPressed: _isDownloading ? null : _startUpdate,
            style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            icon: _isDownloading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.download),
            label: Text(
              _isDownloading
                  ? "Downloading & Installing..."
                  : "Download and Restart System",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        if (_isDownloading)
          Padding(
            padding: const EdgeInsets.only(top: 24.0),
            child: Column(
              children: [
                Text(_statusText,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: _progress,
                  minHeight: 12,
                  borderRadius: BorderRadius.circular(6),
                ),
                const SizedBox(height: 8),
                Text(
                  "${(_progress * 100).toStringAsFixed(1)}%",
                  style: const TextStyle(
                      color: Colors.grey, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  "The application will close automatically to apply the update.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ],
            ),
          )
      ],
    );
  }

  Widget _buildVersionBadge(String label, String version, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Text("v$version",
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      ],
    );
  }
}
