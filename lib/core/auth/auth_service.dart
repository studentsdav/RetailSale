import '../../models/auth/permission_service.dart';
import '../api/api_client.dart';
import '../api/endpoints.dart';
import 'token_storage.dart';

class AuthService {
  static Future<LoginResult> login(
      String username, String password, String roleNew, String oltCode) async {
    try {
      final res = await ApiClient.post(
        ApiEndpoints.login,
        {
          'username': username,
          'password': password,
          'role': roleNew,
          'outlet_code': oltCode,
        },
      );

      if (res == null) throw Exception("No response from server");

      if (res['success'] != true) {
        if (res['license_status'] == 'EXPIRED') {
          return LoginResult(
            success: false,
            licenseStatus: 'EXPIRED',
            daysRemaining: 0,
            message: res['message'] ?? 'License expired',
          );
        }
        throw Exception(res['message'] ?? "Login failed");
      }

      final token = res['token'];
      if (token == null) throw Exception("Token not received from server");

      final user = res['user'] ?? {};
      final role = user['role'] ?? '';
      final permissions = List<String>.from(user['permissions'] ?? <String>[]);

      PermissionService.init(
        role: role,
        permissions: permissions,
      );

      await TokenStorage.save(token);
      await TokenStorage.saveRole(role);
      await TokenStorage.savePermissions(permissions);
      await TokenStorage.saveUser(user);

      return LoginResult(
        success: true,
        licenseStatus: res['license_status'] ?? 'VALID',
        daysRemaining: res['days_remaining'] ?? 999,
        message: 'Success',
      );
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception:', '').trim());
    }
  }

  static Future<void> logout() async {
    await TokenStorage.clear();
  }
}

class LoginResult {
  final bool success;
  final String licenseStatus;
  final int daysRemaining;
  final String message;

  LoginResult({
    required this.success,
    required this.licenseStatus,
    required this.daysRemaining,
    required this.message,
  });
}
