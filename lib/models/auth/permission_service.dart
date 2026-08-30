import 'package:retailpos/models/auth/permission_model.dart';
import '../../core/permissions/module_capability.dart';

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

  static bool can(String permission, [String? currentModule]) {
    if (user == null) return false;

    if (currentModule != null && currentModule.isNotEmpty) {
      if (!ModuleCapability.isPermissionAllowed(permission, currentModule)) {
        return false;
      }
    }

    if (user!.role == 'ADMIN') return true;

    return user!.permissions.contains(permission);
  }
}

