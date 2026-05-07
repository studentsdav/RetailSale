import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

class AppConfig {
  static String baseUrl = 'http://127.0.0.1:3000';
  static List<String> outlets = [];
  static late String _configPath;

  static Future<void> init() async {
    _configPath = p.join(Directory.current.path, 'server_config.json');
    await loadConfig();
  }

  static Future<bool> configExists() async {
    return File(_configPath).exists();
  }

  static Future<bool> loadConfig() async {
    try {
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

      final file = File(_configPath);
      await file
          .writeAsString(jsonEncode({'baseUrl': url, 'outlets': newOutlets}));
    } catch (e) {
      print('Error saving config: $e');
      throw Exception(
          "Failed to save configuration to disk. Please check folder permissions.");
    }
  }
}
