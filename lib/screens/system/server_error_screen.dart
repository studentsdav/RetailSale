import 'package:flutter/material.dart';
import 'package:inventory/main.dart';
import 'package:inventory/screens/splash_screen.dart';

import '../../core/config/app_config.dart';
import '../../core/config/restartServer.dart';
import '../dashboard/server_config_screen.dart';

class ServerErrorScreen extends StatefulWidget {
  const ServerErrorScreen({super.key});

  @override
  State<ServerErrorScreen> createState() => _ServerErrorScreenState();
}

class _ServerErrorScreenState extends State<ServerErrorScreen> {
  bool _isRetrying = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 80, color: Colors.red),
            const SizedBox(height: 20),
            const Text(
              "Server Not Running",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              "Could not connect to:\n${AppConfig.baseUrl}",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _isRetrying
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ServerConfigScreen(),
                            ),
                          );
                        },
                  icon: const Icon(Icons.edit),
                  label: const Text("Edit Config"),
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: _isRetrying
                      ? null
                      : () async {
                          setState(() {
                            _isRetrying = true;
                          });

                          await ServerBootstrapper.ensureServerIsRunning();
                          if (context.mounted) {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SplashScreen(),
                              ),
                              (Route<dynamic> route) => false,
                            );
                          }

                          if (mounted) {
                            setState(() {
                              _isRetrying = false;
                            });
                          }
                        },
                  icon: _isRetrying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(_isRetrying ? "Retrying..." : "Retry Connection"),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
