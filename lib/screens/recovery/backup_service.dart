import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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

  static Future<String> createAndSaveLocalEncBackup() async {
    final res = await ApiClient.get(ApiEndpoints.localEncBackup);
    final data = Map<String, dynamic>.from(res['data'] ?? const {});
    final fileName = (data['filename'] ?? 'backup.enc').toString();
    final base64Payload = (data['base64'] ?? '').toString();
    if (base64Payload.isEmpty) {
      throw Exception('Backup payload is empty');
    }

    final bytes = base64Decode(base64Payload);
    final downloads = await getDownloadsDirectory();
    final targetDir = downloads ?? await getApplicationDocumentsDirectory();
    final safeName = fileName.toLowerCase().endsWith('.enc')
        ? fileName
        : '${p.basenameWithoutExtension(fileName)}.enc';
    final filePath = p.join(targetDir.path, safeName);
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  static Future<void> restoreFromLocalEnc({
    required String fileName,
    required List<int> bytes,
  }) async {
    if (!fileName.toLowerCase().endsWith('.enc')) {
      throw Exception('Only .enc file is allowed');
    }
    await ApiClient.post(ApiEndpoints.restoreLocalEncBackup, {
      'filename': fileName,
      'base64': base64Encode(bytes),
    });
  }
}
