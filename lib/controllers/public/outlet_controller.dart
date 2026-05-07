import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';

class OutletController {
  Future<OutletCheckResult> outletExists() async {
    try {
      final res = await ApiClient.get(ApiEndpoints.checkOutlet);
      if (res['success'] == true) {
        return OutletCheckResult(
          exists: res['exists'] == true,
          outletId: res['data']?['outlet_id'] ?? 0,
        );
      }

      return OutletCheckResult(exists: false, outletId: 0);
    } catch (e) {
      return OutletCheckResult(exists: false, outletId: 0);
    }
  }

  Future<Map<String, dynamic>> createOutlet(Map<String, dynamic> data) async {
    final response = await ApiClient.post(ApiEndpoints.createOutlet, data);
    return response;
  }

  Future<String> sendSetupOtp(String email) async {
    try {
      final res =
          await ApiClient.post(ApiEndpoints.sendSetpOtp, {
        'email': email,
      });

      if (res['success'] == true) {
        return res['message'];
      } else {
        throw Exception(res['message'] ?? 'Failed to send OTP.');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  Future<void> verifySetupOtp(String email, String otp) async {
    try {
      final res = await ApiClient.post(
          ApiEndpoints.verifySetpOtp, {
        'email': email,
        'otp': otp,
      });

      if (res['success'] != true) {
        throw Exception(res['message'] ?? 'Invalid OTP code.');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }
}

class OutletCheckResult {
  final bool exists;
  final int outletId;

  OutletCheckResult({
    required this.exists,
    required this.outletId,
  });
}
