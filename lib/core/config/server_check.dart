import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:inventory/core/config/app_config.dart' show AppConfig;

class HealthResponse {
  final bool isRunning;
  final String action;
  final String message;

  HealthResponse({
    required this.isRunning,
    required this.action,
    required this.message,
  });
}

Future<HealthResponse> checkServer() async {
  try {
    final response = await http
        .get(Uri.parse('${AppConfig.baseUrl}/health'))
        .timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      return HealthResponse(
        isRunning: data["success"] ?? false,
        action: data["action"] ?? 'ERROR',
        message: data["message"] ?? 'Unknown server state.',
      );
    } else {
      return HealthResponse(
        isRunning: false,
        action: 'SERVER_ERROR',
        message: 'Server encountered an error (Code: ${response.statusCode}).',
      );
    }
  } catch (e) {
    return HealthResponse(
      isRunning: false,
      action: 'SERVER_DOWN',
      message:
          'Cannot connect to the server. Please ensure the backend is running.',
    );
  }
}
