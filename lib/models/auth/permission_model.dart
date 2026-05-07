class UserPermission {
  final String role;
  final List<String> permissions;

  UserPermission({
    required this.role,
    required this.permissions,
  });

  bool has(String code) {
    if (role == 'ADMIN') return true;
    return permissions.contains(code);
  }
}


