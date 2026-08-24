import '../core/api/api_client.dart';
import '../core/api/endpoints.dart';

class NightAuditService {
  static Future<Map<String, dynamic>> getStatus() async {
    final response = await ApiClient.get(ApiEndpoints.nightAuditStatus);
    return response as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> validate() async {
    final response = await ApiClient.post(ApiEndpoints.nightAuditValidate, {});
    return response as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> executeAudit({
    required double physicalCash,
    required Map<String, dynamic> denominations,
    required bool forceRun,
    required String notes,
  }) async {
    final response = await ApiClient.post(ApiEndpoints.nightAuditExecute, {
      'physicalCash': physicalCash,
      'denominations': denominations,
      'forceRun': forceRun,
      'notes': notes,
    });
    return response as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getHistory({int limit = 20, int offset = 0}) async {
    final response = await ApiClient.get(
      '${ApiEndpoints.nightAuditHistory}?limit=$limit&offset=$offset',
    );
    return response as Map<String, dynamic>;
  }
}
