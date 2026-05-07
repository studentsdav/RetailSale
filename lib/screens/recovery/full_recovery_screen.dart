import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../dashboard/server_config_screen.dart';

class FullRecoveryScreen extends StatelessWidget {
  final String message;
  const FullRecoveryScreen({super.key, required this.message});

  void _showDownloadDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return InstallerDownloadDialog(
          message: message,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.red.shade200, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 72, color: Colors.red.shade600),
                  const SizedBox(height: 24),
                  const Text(
                    "System Offline",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.error_outline,
                            size: 20, color: Colors.red.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            message,
                            style: TextStyle(
                                color: Colors.red.shade900, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () => _showDownloadDialog(context),
                      icon: const Icon(Icons.download),
                      label: const Text("Run System Installer Tool",
                          style: TextStyle(fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ServerConfigScreen()),
                        );
                      },
                      icon: const Icon(Icons.settings),
                      label: const Text("Reconfigure Database",
                          style: TextStyle(fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black87,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text(
                              "Support team notified. Check your email.")));
                    },
                    icon: const Icon(Icons.support_agent),
                    label: const Text("Contact Technical Support"),
                    style:
                        TextButton.styleFrom(foregroundColor: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// THE DOWNLOAD DIALOG WIDGET
// ============================================================================

class InstallerDownloadDialog extends StatefulWidget {
  final message;
  const InstallerDownloadDialog({super.key, required this.message});

  @override
  State<InstallerDownloadDialog> createState() =>
      _InstallerDownloadDialogState();
}

class _InstallerDownloadDialogState extends State<InstallerDownloadDialog> {
  double _progress = 0.0;
  bool _isDownloading = false;
  String _statusText = "Ready to download the initialization tool.";

  Future<void> _startDownloadAndRun() async {
    final message = widget.message;
    setState(() {
      _isDownloading = true;
      _statusText = "Connecting to server...";
      _progress = 0.0;
    });

    try {
      Uri url = Uri.parse(
          'https://github.com/studentsdav/Inventory_public/releases/download/1.0.0.0/Inventory_Installer.exe');
      if (message == "Partial Recovery") {
        url = Uri.parse(
            'https://github.com/studentsdav/Inventory_public/releases/download/1.0.0.0/Inventory_Installer.exe');
      } else {
        url = Uri.parse(
            'https://github.com/studentsdav/Inventory_public/releases/download/1.0.0.0/backend_Installer.exe');
      }

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
      final file = File('${tempDir.path}\\init_Installer_Downloaded.exe');
      await file.writeAsBytes(bytes);

      setState(() {
        _statusText = "Download complete! Launching...";
        _progress = 1.0;
      });

      await Process.start(
        file.path,
        [],
        mode: ProcessStartMode.detached,
      );

      if (!mounted) return;

      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _isDownloading = false;
        _statusText = "Error: Could not download file.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Row(
        children: [
          Icon(Icons.downloading, color: Colors.blueAccent),
          SizedBox(width: 10),
          Text("Download Installer"),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_statusText, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 20),

            // Progress Bar
            LinearProgressIndicator(
              value: _isDownloading ? _progress : 0.0,
              minHeight: 10,
              borderRadius: BorderRadius.circular(5),
            ),

            const SizedBox(height: 10),

            // Percentage Text
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                "${(_progress * 100).toStringAsFixed(0)}%",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (!_isDownloading)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel"),
          ),
        ElevatedButton(
          onPressed: _isDownloading ? null : _startDownloadAndRun,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
          ),
          child: _isDownloading
              ? const Text("Downloading...")
              : const Text("Start Download"),
        ),
      ],
    );
  }
}
