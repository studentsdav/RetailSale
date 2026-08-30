class AppUser {
  final int id;
  final String username;
  String fullName;
  String role;
  String mobile;
  String email;
  bool isActive;
  double maxDiscountPercent;
  Set<String> permissions;

  AppUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    required this.mobile,
    required this.isActive,
    required this.email,
    this.maxDiscountPercent = 100.0,
    Set<String>? permissions,
  }) : permissions = permissions ?? {};

  factory AppUser.fromJson(Map<String, dynamic> json) {
    double parseMaxDisc(dynamic val) {
      if (val == null) return 100.0;
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 100.0;
      return 100.0;
    }

    return AppUser(
      id: json['id'],
      username: json['username'],
      fullName: json['full_name'],
      role: json['role'] ?? '',
      mobile: json['mobile'] ?? "",
      isActive: json['is_active'] ?? true,
      email: json['contact_email'] ?? "",
      maxDiscountPercent: parseMaxDisc(json['max_discount_percent']),
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
  final String businessModule;

  UserProfile({
    required this.username,
    required this.name,
    required this.role,
    required this.outletCode,
    required this.propertyName,
    required this.outletType,
    required this.businessModule,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      username: json['username'] ?? '',
      name: json['name'] ?? '',
      role: json['role'] ?? '',
      outletCode: json['outlet_code'] ?? '',
      propertyName: json['property_name'] ?? '',
      outletType: json['outlet_type'] ?? '',
      businessModule: json['business_module'] ?? json['outlet_module'] ?? 'ALL',
    );
  }
}
