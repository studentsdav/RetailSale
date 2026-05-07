class UserModel {
  final int id;
  final String username;
  final String name;
  final String role;
  final String mobile;
  final List<String> permissions;

  UserModel({
    required this.id,
    required this.username,
    required this.name,
    required this.role,
    required this.mobile,
    required this.permissions,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      name: json['name'] ?? '',
      role: json['role'] ?? '',
      mobile: json['mobile'] ?? '',
      permissions: json['permissions'] != null
          ? List<String>.from(json['permissions'])
          : [],
    );
  }
}
