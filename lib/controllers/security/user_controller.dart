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

  // ---------- CREATE ----------
  Future<void> create({
    required String username,
    required String fullName,
    required String mobile,
    required String role,
    required String contact_email,
    List<String>? permissions,
    required String password,
  }) async {
    loading = true;
    notifyListeners();

    await ApiClient.post(ApiEndpoints.users, {
      'username': username,
      'full_name': fullName,
      'mobile': mobile,
      'role': role,
      'contact_email': contact_email,
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
    required String contact_email,
  }) async {
    loading = true;
    notifyListeners();

    await ApiClient.put(
      '${ApiEndpoints.users}/$id',
      {
        'full_name': fullName,
        'mobile': mobile,
        'role': role,
        'contact_email': contact_email
      },
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
}
