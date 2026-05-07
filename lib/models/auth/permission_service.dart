import 'package:inventory/models/auth/permission_model.dart';

class PermissionService {
  static UserPermission? user;

  static void init({
    required String role,
    required List<String> permissions,
  }) {
    user = UserPermission(
      role: role,
      permissions: permissions,
    );
  }

  static bool can(String permission) {
    if (user == null) return false;

    if (user!.role == 'ADMIN') return true;

    return user!.permissions.contains(permission);
  }
}
