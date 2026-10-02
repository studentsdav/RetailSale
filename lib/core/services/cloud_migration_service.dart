import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../api/api_client.dart';
import '../auth/token_storage.dart';
import '../config/app_config.dart';

class CloudMigrationService {
  /// Test reachability and compatibility of the destination cloud server
  static Future<Map<String, dynamic>> testCloudConnection(String cloudUrl) async {
    String cleanUrl = cloudUrl.trim();
    if (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }

    try {
      final uri = Uri.parse('$cleanUrl/api/public/migration/ping');
      final response = await http.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'message': data['message'] ?? 'Cloud Server Connected',
          'version': data['version'] ?? '2.0',
          'supported_modes': data['supported_modes'] ?? ['MERGE_OUTLET'],
        };
      } else {
        return {
          'success': false,
          'message': 'Cloud server returned error code ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('[MIGRATION] Ping failed: $e');
      return {
        'success': false,
        'message': 'Could not connect to Cloud Server: $e',
      };
    }
  }

  /// Package and export all local store data from the offline backend
  static Future<Map<String, dynamic>> exportLocalStoreBundle() async {
    try {
      final outletCode = await TokenStorage.getOutletCode() ?? '';
      final res = await ApiClient.post('/api/public/migration/export-bundle', {
        'outlet_code': outletCode,
      });

      if (res['success'] == true && res['bundle'] != null) {
        return {
          'success': true,
          'bundle': res['bundle'],
          'stats': res['stats'] ?? {},
        };
      } else {
        return {
          'success': false,
          'message': res['message'] ?? 'Failed to export local data bundle',
        };
      }
    } catch (e) {
      debugPrint('[MIGRATION] Export failed: $e');
      return {
        'success': false,
        'message': 'Export failed: $e',
      };
    }
  }

  /// Upload the bundle to the target cloud server for automated ingestion
  static Future<Map<String, dynamic>> uploadAndMigrateToCloud({
    required String cloudUrl,
    required Map<String, dynamic> bundle,
    String? targetOutletCode,
    String? adminPassword,
    String mode = "MERGE_OUTLET",
  }) async {
    String cleanUrl = cloudUrl.trim();
    if (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }

    try {
      final uri = Uri.parse('$cleanUrl/api/public/migration/import-bundle');
      final bodyPayload = jsonEncode({
        'bundle': bundle,
        'mode': mode,
        'target_outlet_code': targetOutletCode,
        'admin_password': adminPassword,
      });

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: bodyPayload,
      ).timeout(const Duration(minutes: 5));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'message': data['message'] ?? 'Migration completed successfully!',
          'outlet_code': data['outlet_code'],
          'token': data['token'],
          'user': data['user'],
          'stats': data['stats'] ?? {},
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Cloud ingestion error (HTTP ${response.statusCode})',
        };
      }
    } catch (e) {
      debugPrint('[MIGRATION] Cloud import failed: $e');
      return {
        'success': false,
        'message': 'Transmission to cloud server failed: $e',
      };
    }
  }

  /// Finish migration by switching application configuration to the new Cloud Server URL
  static Future<void> completeCloudMigrationSwitch({
    required String cloudUrl,
    required String outletCode,
    String? token,
    Map<String, dynamic>? user,
  }) async {
    String cleanUrl = cloudUrl.trim();
    if (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }

    await AppConfig.saveConfig(cleanUrl, [outletCode]);

    if (token != null && token.isNotEmpty) {
      await TokenStorage.save(token);
    }
    if (user != null) {
      await TokenStorage.saveUser(user);
    }
    if (outletCode.isNotEmpty) {
      await TokenStorage.saveOutletCode(outletCode);
    }
  }

  /// Pull store data from online cloud server into this local offline instance (Clean Wipe & Restore)
  static Future<Map<String, dynamic>> pullOnlineToOffline({
    required String cloudUrl,
    required String outletCode,
    String? adminPassword,
  }) async {
    try {
      final res = await ApiClient.post('/api/public/migration/sync-online-to-offline', {
        'cloud_url': cloudUrl,
        'outlet_code': outletCode,
        'admin_password': adminPassword,
      });

      if (res['success'] == true) {
        return {
          'success': true,
          'message': res['message'] ?? 'Online data downloaded and restored offline successfully!',
          'outlet_code': res['outlet_code'] ?? outletCode,
          'token': res['token'],
          'user': res['user'],
          'stats': res['stats'] ?? {},
        };
      } else {
        return {
          'success': false,
          'message': res['message'] ?? 'Failed to restore online data to offline system.',
        };
      }
    } catch (e) {
      debugPrint('[MIGRATION] Pull online to offline failed: $e');
      return {
        'success': false,
        'message': 'Migration failed: $e',
      };
    }
  }
}
