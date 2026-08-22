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
  String? aiModelName;
  String? aiBaseUrl;
  String? aiApiKey;
  int maxRows = 100;

  Future<void> initPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      aiProvider = prefs.getString('ai_provider');
      aiModelName = prefs.getString('ai_model_name');
      aiBaseUrl = prefs.getString('ai_base_url');
      aiApiKey = prefs.getString('ai_api_key');
      final storedMax = prefs.getInt('ai_max_rows') ?? 100;
      maxRows = storedMax.clamp(1, 1000);
      notifyListeners();
    } catch (e) {
      debugPrint('[AI CONTROLLER] Failed to load preferences: $e');
    }
  }

  Future<void> savePrefs({
    required String provider,
    required String modelName,
    required String baseUrl,
    required String apiKey,
    int? maxRowsLimit,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final cleanProvider = provider.trim();
      final cleanModel = modelName.trim();
      final cleanUrl = baseUrl.trim();
      final cleanKey = apiKey.trim();
      final clampedMax = (maxRowsLimit ?? 100).clamp(1, 1000);

      if (cleanProvider.isEmpty) {
        await prefs.remove('ai_provider');
        aiProvider = null;
      } else {
        await prefs.setString('ai_provider', cleanProvider);
        aiProvider = cleanProvider;
      }

      if (cleanModel.isEmpty) {
        await prefs.remove('ai_model_name');
        aiModelName = null;
      } else {
        await prefs.setString('ai_model_name', cleanModel);
        aiModelName = cleanModel;
      }

      if (cleanUrl.isEmpty) {
        await prefs.remove('ai_base_url');
        aiBaseUrl = null;
      } else {
        await prefs.setString('ai_base_url', cleanUrl);
        aiBaseUrl = cleanUrl;
      }

      if (cleanKey.isEmpty) {
        await prefs.remove('ai_api_key');
        aiApiKey = null;
      } else {
        await prefs.setString('ai_api_key', cleanKey);
        aiApiKey = cleanKey;
      }

      await prefs.setInt('ai_max_rows', clampedMax);
      maxRows = clampedMax;

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
          'maxRows': maxRows,
          if (aiProvider != null && aiProvider!.isNotEmpty) 'aiProvider': aiProvider,
          if (aiModelName != null && aiModelName!.isNotEmpty) 'aiModelName': aiModelName,
          if (aiBaseUrl != null && aiBaseUrl!.isNotEmpty) 'aiBaseUrl': aiBaseUrl,
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
