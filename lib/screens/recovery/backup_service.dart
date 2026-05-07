import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';

class BackupService {
  static Future<String> checkStatus() async {
    try {
      final res = await ApiClient.get(ApiEndpoints.backupStatus);

      if (res['success'] == true) {
        return res['alert'] ?? 'NONE';
      }

      return 'NONE';
    } catch (e) {
      debugPrint("Error checking backup status: $e");
      return 'NONE';
    }
  }

  static Future<bool> syncLatest() async {
    try {
      final res = await ApiClient.get(ApiEndpoints.syncLatest);

      if (res['success'] == true) {
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error syncing database: $e");
      return false;
    }
  }

  static Future<bool> toggleCloudSync(bool enable) async {
    try {
      final res = await ApiClient.post(
        ApiEndpoints.toggleBackup,
        {'enabled': enable},
      );

      if (res['success'] == true) {
        return true;
      }

      return false;
    } catch (e) {
      debugPrint("Error toggling backup: $e");
      return false;
    }
  }
}
