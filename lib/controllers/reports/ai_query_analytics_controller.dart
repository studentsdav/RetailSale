import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/auth/token_storage.dart';
import '../../core/config/app_config.dart';
import '../../core/api/endpoints.dart';

class AiQueryAnalyticsController extends ChangeNotifier {
  bool loading = false;
  String? error;
  String? cacheId;
  String? summaryText;
  List<dynamic> sampleRows = [];
  int totalRows = 0;
  String? generatedQuery;

  // AI Configuration properties
  String? aiProvider;
  String? aiApiKey;

  Future<void> initPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      aiProvider = prefs.getString('ai_provider');
      aiApiKey = prefs.getString('ai_api_key');
      notifyListeners();
    } catch (e) {
      debugPrint('[AI CONTROLLER] Failed to load preferences: $e');
    }
  }

  Future<void> savePrefs(String provider, String apiKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final cleanProvider = provider.trim();
      final cleanApiKey = apiKey.trim();

      if (cleanProvider.isEmpty) {
        await prefs.remove('ai_provider');
        aiProvider = null;
      } else {
        await prefs.setString('ai_provider', cleanProvider);
        aiProvider = cleanProvider;
      }

      if (cleanApiKey.isEmpty) {
        await prefs.remove('ai_api_key');
        aiApiKey = null;
      } else {
        await prefs.setString('ai_api_key', cleanApiKey);
        aiApiKey = cleanApiKey;
      }

      notifyListeners();
    } catch (e) {
      debugPrint('[AI CONTROLLER] Failed to save preferences: $e');
      rethrow;
    }
  }

  Future<void> executeQuery(String question) async {
    if (question.trim().isEmpty) return;

    loading = true;
    error = null;
    cacheId = null;
    summaryText = null;
    sampleRows = [];
    totalRows = 0;
    generatedQuery = null;
    notifyListeners();

    try {
      final token = await TokenStorage.read();
      final uri = Uri.parse('${AppConfig.baseUrl}${ApiEndpoints.aiQuery}');
      
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'question': question.trim(),
          if (aiProvider != null && aiProvider!.isNotEmpty) 'aiProvider': aiProvider,
          if (aiApiKey != null && aiApiKey!.isNotEmpty) 'aiApiKey': aiApiKey,
        }),
      );

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200 && data['success'] == true) {
        cacheId = data['cacheId'];
        summaryText = data['summaryText'];
        sampleRows = List<dynamic>.from(data['sampleRows'] ?? const []);
        totalRows = data['totalRows'] ?? 0;
        generatedQuery = data['query'];
      } else {
        error = data['message'] ?? data['error'] ?? 'Failed to translate or execute natural language query.';
        generatedQuery = data['query'];
      }
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void clear() {
    loading = false;
    error = null;
    cacheId = null;
    summaryText = null;
    sampleRows = [];
    totalRows = 0;
    generatedQuery = null;
    notifyListeners();
  }
}
