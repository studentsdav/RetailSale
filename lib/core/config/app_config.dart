import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static String baseUrl = 'http://127.0.0.1:3000';
  static List<String> outlets = [];
  static late String _configPath;

  static Future<void> init() async {
    if (kIsWeb) {
      _configPath = 'server_config.json';
    } else if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      final directory = await getApplicationDocumentsDirectory();
      _configPath = p.join(directory.path, 'server_config.json');
    } else {
      _configPath = p.join(Directory.current.path, 'server_config.json');
    }
    await loadConfig();
  }

  static Future<bool> configExists() async {
    if (kIsWeb) return true;
    return File(_configPath).exists();
  }

  static Future<bool> loadConfig() async {
    try {
      if (kIsWeb) {
        final origin = Uri.base.origin;
        final host = Uri.base.host.toLowerCase();
        final port = Uri.base.port;

        // When running under 'flutter run -d chrome' (e.g. localhost:51617), point API to local backend port 3000
        if ((host == 'localhost' || host == '127.0.0.1') && port != 3000) {
          baseUrl = 'http://localhost:3000';
        } else {
          baseUrl = origin;
        }

        try {
          final prefs = await SharedPreferences.getInstance();
          final saved = prefs.getStringList('web_linked_outlets') ?? [];
          outlets = saved;
        } catch (_) {}
        return true;
      }
      final file = File(_configPath);
      if (await file.exists()) {
        final String contents = await file.readAsString();
        final data = jsonDecode(contents);

        if (data['baseUrl'] != null && data['baseUrl'].toString().isNotEmpty) {
          baseUrl = data['baseUrl'];
        }

        if (data['outlets'] != null) {
          outlets = List<String>.from(data['outlets']);
        }

        return true;
      }
    } catch (e) {
      print('Error loading config: $e');
    }
    return false;
  }

  static Future<void> saveConfig(String url, List<String> newOutlets) async {
    try {
      baseUrl = url;
      outlets = newOutlets;

      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('web_linked_outlets', newOutlets);
        return;
      }

      final file = File(_configPath);
      await file
          .writeAsString(jsonEncode({'baseUrl': url, 'outlets': newOutlets}));
    } catch (e) {
      print('Error saving config: $e');
      throw Exception(
          "Failed to save configuration to disk. Please check folder permissions.");
    }
  }

  static bool get isLocalServer {
    if (kIsWeb) return false;
    try {
      final uri = Uri.parse(baseUrl);
      final host = uri.host.toLowerCase();
      return host == 'localhost' || host == '127.0.0.1';
    } catch (_) {
      final lower = baseUrl.toLowerCase();
      return lower.contains('localhost') || lower.contains('127.0.0.1');
    }
  }

  static Future<void> fetchOutletsFromServer() async {
    if (kIsWeb) return; // Do NOT pull global server outlets on Web for privacy & security
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/api/public/outlets'))
          .timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['data'] is List) {
          final List list = data['data'];
          final fetched = list
              .map((item) =>
                  (item['outlet_code'] ?? item['code'] ?? '').toString().trim())
              .where((s) => s.isNotEmpty)
              .toList();
          if (fetched.isNotEmpty) {
            outlets = fetched;
          }
        }
      }
    } catch (_) {}
  }
}
