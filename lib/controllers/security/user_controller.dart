import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../models/security/app_user_model.dart';

class UserController extends ChangeNotifier {
  bool loading = false;
  List<AppUser> list = [];

  // ---------- LIST USERS ----------
  Future<void> load() async {
    loading = true;
    notifyListeners();

    final res = await ApiClient.get(ApiEndpoints.users);

    list = (res['data'] as List).map((e) => AppUser.fromJson(e)).toList();

    loading = false;
    notifyListeners();
  }

  // ---------- FETCH QUICK USERS (PUBLIC/PRE-LOGIN) ----------
  static Future<List<QuickUser>> fetchQuickUsers({
    required String outletCode,
    String? role,
  }) async {
    try {
      final queryParams = <String, String>{
        'outlet_code': outletCode.trim(),
      };
      if (role != null && role.isNotEmpty) {
        queryParams['role'] = role.trim();
      }
      final uri = Uri.parse(ApiEndpoints.quickUsers).replace(queryParameters: queryParams);
      final res = await ApiClient.get(uri.toString());
      if (res['success'] == true && res['data'] is List) {
        return (res['data'] as List).map((e) => QuickUser.fromJson(e)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // ---------- CREATE ----------
  Future<void> create({
    required String username,
    required String fullName,
    required String mobile,
    required String role,
    String? contactEmail,
    // ignore: non_constant_identifier_names
    String? contact_email,
    double maxDiscountPercent = 100.0,
    String? pinCode,
    bool showInQuickLogin = true,
    List<String>? permissions,
    required String password,
  }) async {
    loading = true;
    notifyListeners();

    final emailToUse = (contactEmail ?? contact_email ?? '').trim();

    await ApiClient.post(ApiEndpoints.users, {
      'username': username,
      'full_name': fullName,
      'mobile': mobile,
      'role': role,
      'contact_email': emailToUse,
      'max_discount_percent': maxDiscountPercent,
      'pin_code': pinCode,
      'show_in_quick_login': showInQuickLogin,
      'permissions': permissions ?? [],
      'password': password
    });

    await load();
  }

  // ---------- UPDATE ----------
  Future<void> update(
    int id, {
    required String fullName,
    required String mobile,
    required String role,
    String? contactEmail,
    // ignore: non_constant_identifier_names
    String? contact_email,
    double maxDiscountPercent = 100.0,
    String? pinCode,
    bool? showInQuickLogin,
  }) async {
    loading = true;
    notifyListeners();

    final emailToUse = (contactEmail ?? contact_email ?? '').trim();

    final payload = <String, dynamic>{
      'full_name': fullName,
      'mobile': mobile,
      'role': role,
      'contact_email': emailToUse,
      'max_discount_percent': maxDiscountPercent,
      'pin_code': pinCode,
    };
    if (showInQuickLogin != null) {
      payload['show_in_quick_login'] = showInQuickLogin;
    }

    await ApiClient.put(
      '${ApiEndpoints.users}/$id',
      payload,
    );

    await load();
  }

  Future<void> changePassword(
    String username,
    String oldPass,
    String newPass,
  ) async {
    await ApiClient.post('${ApiEndpoints.users}/$username/change-password',
        {'oldPassword': oldPass, 'newPassword': newPass});
  }

  // ---------- STATUS ----------
  Future<void> toggleStatus(int id) async {
    await ApiClient.put('${ApiEndpoints.users}/$id/status', {});
    await load();
  }

  // ---------- RESET PASSWORD ----------
  Future<void> resetPassword(int id, String newPassword) async {
    await ApiClient.put(
      '${ApiEndpoints.users}/$id/reset-password',
      {'password': newPassword},
    );
  }

  // ---------- PERMISSIONS ----------
  Future<Set<String>> getPermissions(int id) async {
    final res = await ApiClient.get('${ApiEndpoints.users}/$id/permissions');
    return Set<String>.from(res['data']);
  }

  Future<void> updatePermissions(int id, Set<String> permissions) async {
    await ApiClient.put(
      '${ApiEndpoints.users}/$id/permissionsupdate',
      {'permissions': permissions.toList()},
    );
  }

  // ---------- SUPERVISOR PIN ----------
  Future<Map<String, dynamic>> getSupervisorPin() async {
    try {
      final res = await ApiClient.get('${ApiEndpoints.users}/supervisor-pin');
      return {
        'pin': res['supervisor_pin'] ?? '1234',
        'type': res['supervisor_pin_type'] ?? 'STATIC',
      };
    } catch (_) {
      return {'pin': '1234', 'type': 'STATIC'};
    }
  }

  Future<void> updateSupervisorPin(String pin, String type) async {
    await ApiClient.put(
      '${ApiEndpoints.users}/supervisor-pin',
      {'supervisor_pin': pin, 'supervisor_pin_type': type},
    );
  }

  Future<bool> verifySupervisorPin(String pin) async {
    final res = await ApiClient.post(
      '${ApiEndpoints.users}/supervisor-pin/verify',
      {'pin': pin},
    );
    return res['authorized'] == true;
  }

  Future<String> sendSupervisorOtp() async {
    final res = await ApiClient.post('${ApiEndpoints.users}/supervisor-pin/send-otp', {});
    return res['message'] ?? 'OTP sent to supervisor email';
  }
}
