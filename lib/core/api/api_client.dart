import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../main.dart';
import '../auth/token_storage.dart';
import '../config/app_config.dart';

class ApiClient {
  static Uri _uri(String path) {
    // Avoid accidental double slashes when baseUrl ends with '/' and path starts with '/'.
    // Also supports users configuring baseUrl with/without trailing slash.
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Uri.parse(path);
    }
    final base = Uri.parse(AppConfig.baseUrl);
    return base.resolve(path);
  }

  // ---------------- COMMON HEADERS ----------------
  static Future<Map<String, String>> _headers() async {
    final token = await TokenStorage.read();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ---------------- GET ----------------
  static Future<dynamic> get(String path) async {
    final response = await http.get(
      _uri(path),
      headers: await _headers(),
    );
    return _handleResponse(response);
  }

  // ---------------- POST ----------------
  static Future<dynamic> post(String path, dynamic body) async {
    final response = await http.post(
      _uri(path),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return _handleResponse(response);
  }

  // ---------------- PUT ----------------
  static Future<dynamic> put(String path, Map body) async {
    final response = await http.put(
      _uri(path),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return _handleResponse(response);
  }

  // ---------------- DELETE ----------------
  static Future<dynamic> delete(String path) async {
    final response = await http.delete(
      _uri(path),
      headers: await _headers(),
    );
    return _handleResponse(response);
  }

  // ---------------- RESPONSE HANDLER ----------------
  static dynamic _handleResponse(http.Response response) {
    if (response.body.isEmpty) {
      showErrorSnackbar('Empty server response');
      throw Exception('Empty server response');
    }
    final data = jsonDecode(response.body);
    if (response.statusCode >= 400 || data['success'] == false) {
      String errorMessage = data['error'] ?? data['message'] ?? "API Error";

      showErrorSnackbar(errorMessage);

      throw Exception(errorMessage);
    }

    return data;
  }
}

void showErrorSnackbar(String message) {
  globalSnackbarKey.currentState?.showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.red.shade600,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
    ),
  );
}
