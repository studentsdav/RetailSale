import 'package:inventory/core/api/endpoints.dart';

import '../../core/api/api_client.dart';

class PasswordRecoveryController {
  // 1. REQUEST OTP FOR PASSWORD RESET
  Future<String> requestOtp(
      {required String outletCode, required String username}) async {
    try {
      final res = await ApiClient.post(ApiEndpoints.requestPasswordResetOtp, {
        'outletCode': outletCode,
        'username': username,
      });

      if (res['success'] == true) {
        return res['message'] ?? 'OTP sent successfully.';
      } else {
        throw Exception(res['message'] ?? 'Failed to send OTP.');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  // 2. VERIFY OTP & SET NEW PASSWORD
  Future<String> resetPassword({
    required String outletCode,
    required String username,
    required String otp,
    required String newPassword,
  }) async {
    try {
      final res = await ApiClient.post(ApiEndpoints.verifyAndResetPassword, {
        'outletCode': outletCode,
        'username': username,
        'otp': otp,
        'newPassword': newPassword,
      });

      if (res['success'] == true) {
        return res['message'] ?? 'Password reset successfully.';
      } else {
        throw Exception(res['message'] ?? 'Failed to reset password.');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }

  Future<String> recoverUsername(
      {required String outletCode, required String email}) async {
    try {
      final res = await ApiClient.post(ApiEndpoints.recoverUsername, {
        'outletCode': outletCode,
        'email': email,
      });

      if (res['success'] == true) {
        return res['message'] ?? 'Check your email for your usernames.';
      } else {
        throw Exception(res['message'] ?? 'Failed to recover username.');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
  }
}
