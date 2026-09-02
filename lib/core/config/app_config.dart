import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static String baseUrl = 'http://127.0.0.1:3000';
  static List<String> outlets = [];
  static late String _configPath;

  static Future<void> init() async {
    try {
      if (kIsWeb) {
        _configPath = 'server_config.json';
      } else if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        final directory = await getApplicationDocumentsDirectory();
        _configPath = p.join(directory.path, 'server_config.json');
      } else {
        _configPath = p.join(Directory.current.path, 'server_config.json');
      }
    } catch (_) {
      _configPath = 'server_config.json';
    }
    await loadConfig();
  }

  static Future<bool> configExists() async {
    if (kIsWeb) return true;
    try {
      return File(_configPath).existsSync();
    } catch (_) {
      return false;
    }
  }

  static Future<bool> loadConfig() async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final savedUrl = prefs.getString('server_base_url');

        if (savedUrl != null && savedUrl.trim().isNotEmpty) {
          baseUrl = savedUrl.trim();
        } else {
          final origin = Uri.base.origin;
          final host = Uri.base.host.toLowerCase();
          final port = Uri.base.port;

          if ((host == 'localhost' || host == '127.0.0.1') && port != 3000) {
            baseUrl = 'http://localhost:3000';
          } else {
            baseUrl = origin;
          }
        }

        final saved = prefs.getStringList('web_linked_outlets') ?? [];
        outlets = saved;
        return true;
      }

      final file = File(_configPath);
      if (await file.exists()) {
        final String contents = await file.readAsString();
        final data = jsonDecode(contents);

        if (data['baseUrl'] != null && data['baseUrl'].toString().isNotEmpty) {
          baseUrl = data['baseUrl'].toString().trim();
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
      String cleanUrl = url.trim();
      if (cleanUrl.endsWith('/')) {
        cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
      }

      baseUrl = cleanUrl;
      outlets = newOutlets;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('server_base_url', cleanUrl);

      if (kIsWeb) {
        await prefs.setStringList('web_linked_outlets', newOutlets);
        return;
      }

      final file = File(_configPath);
      await file.writeAsString(jsonEncode({'baseUrl': cleanUrl, 'outlets': newOutlets}));
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
}
