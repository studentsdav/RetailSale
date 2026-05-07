import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';

class RecoveryController {
  Future<Map<String, dynamic>> verifyPin(String outletCode, String pin) async {
    try {
      // NOTE: Ensure ApiEndpoints.verifyPin points to '/recovery/verify-pin'
      final res = await ApiClient.post(ApiEndpoints.verifyPin, {
        'outletCode': outletCode,
        'pin': pin,
      });

      if (res['success'] == true) {
        return res;
      } else {
        throw Exception(res['message'] ?? 'PIN Verification failed.');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // ==========================================
  // 2. REQUEST / RESEND OTP
  // ==========================================
  Future<Map<String, dynamic>> requestOtp({
    String? outletCode,
    String? contactStr,
    bool isResend = false,
  }) async {
    try {
      final res = await ApiClient.post(ApiEndpoints.requestOtp, {
        if (outletCode != null && outletCode.isNotEmpty)
          'outletCode': outletCode,
        if (contactStr != null && contactStr.isNotEmpty)
          'contactStr': contactStr,
        'isResend': isResend,
      });

      if (res['success'] == true) {
        return res;
      } else {
        throw Exception(res['message'] ?? 'Failed to send OTP.');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // ==========================================
  // 3. VERIFY OTP
  // ==========================================
  Future<Map<String, dynamic>> verifyOtp({
    String? outletCode,
    String? contactStr,
    required String otp,
  }) async {
    try {
      final res = await ApiClient.post(ApiEndpoints.verifyOtp, {
        if (outletCode != null && outletCode.isNotEmpty)
          'outletCode': outletCode,
        if (contactStr != null && contactStr.isNotEmpty)
          'contactStr': contactStr,
        'otp': otp,
      });

      if (res['success'] == true) {
        return res;
      } else {
        throw Exception(res['message'] ?? 'Invalid OTP code.');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // ==========================================
  // 4. EXECUTE FULL RECOVERY
  // ==========================================
  Future<void> executeRecovery(
      String folderId, Map<String, dynamic> clientData) async {
    try {
      final res = await ApiClient.post(ApiEndpoints.executeRecovery, {
        'folderId': folderId,
        'clientData': clientData,
      });

      if (res['success'] != true) {
        throw Exception(res['message'] ?? 'Failed to execute recovery.');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }
}
