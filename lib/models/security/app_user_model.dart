class AppUser {
  final int id;
  final String username;
  String fullName;
  String role;
  String mobile;
  String email;
  bool isActive;
  Set<String> permissions;

  AppUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    required this.mobile,
    required this.isActive,
    required this.email,
    Set<String>? permissions,
  }) : permissions = permissions ?? {};

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'],
      username: json['username'],
      fullName: json['full_name'],
      role: json['role'],
      mobile: json['mobile'] ?? "",
      isActive: json['is_active'],
      email: json['contact_email'] ?? "",
    );
  }
}

class UserProfile {
  final String username;
  final String name;
  final String role;
  final String outletCode;
  final String propertyName;
  final String outletType;

  UserProfile({
    required this.username,
    required this.name,
    required this.role,
    required this.outletCode,
    required this.propertyName,
    required this.outletType,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      username: json['username'] ?? '',
      name: json['name'] ?? '',
      role: json['role'] ?? '',
      outletCode: json['outlet_code'] ?? '',
      propertyName: json['property_name'] ?? '',
      outletType: json['outlet_type'] ?? '',
    );
  }
}
