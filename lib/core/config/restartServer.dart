import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:inventory/core/config/app_config.dart'; // Make sure to import where your URL is stored

class ServerBootstrapper {
  static Future<bool> ensureServerIsRunning() async {
    // Get the dynamic base URL instead of hardcoding it
    // Example: 'http://127.0.0.1:3000' OR 'http://192.168.1.50:3000'
    final String serverUrl = AppConfig.baseUrl;

    // 1. Try to ping the server first
    bool isRunning = await _pingServer(serverUrl);

    if (isRunning) {
      return true; // Server is already alive!
    }

    // 2. NETWORK CHECK: Are we the Host or a Client?
    bool isLocalHost =
        serverUrl.contains('127.0.0.1') || serverUrl.contains('localhost');

    // If we are a Client terminal, DO NOT start the local server!
    if (!isLocalHost) {
      print(
          "Client Mode: Cannot reach Main Server at $serverUrl. Waking up aborted.");
      return false; // Let the UI show a "Cannot connect to Main Computer" error
    }

    // 3. If we are the Host machine, wake up the local server!
    if (Platform.isWindows) {
      try {
        final String appDir = Directory.current.path;
        final String vbsPath = '$appDir\\run_hidden.vbs';

        if (File(vbsPath).existsSync()) {
          await Process.start(
            'wscript.exe',
            [vbsPath],
            workingDirectory: appDir,
            mode: ProcessStartMode.detached,
          );

          await Future.delayed(const Duration(seconds: 5));

          return await _pingServer(serverUrl);
        }
      } catch (e) {
        print("Failed to start local server: $e");
        return false;
      }
    }

    return false;
  }

  static Future<bool> _pingServer(String baseUrl) async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 2));

      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
