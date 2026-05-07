class PropertyInfo {
  final String propertyName;
  final String legalName;
  final String address;
  final String city;
  final String state;
  final String pinCode;
  final String contactPerson;
  final String mobile;
  final String email;
  final String gstNo;
  final String panNo;
  final String fssaiNo;
  final String? logoPath;
  final bool isActive;

  PropertyInfo({
    required this.propertyName,
    required this.legalName,
    required this.address,
    required this.city,
    required this.state,
    required this.pinCode,
    required this.contactPerson,
    required this.mobile,
    required this.email,
    required this.gstNo,
    required this.panNo,
    required this.fssaiNo,
    this.logoPath,
    required this.isActive,
  });

  factory PropertyInfo.fromJson(Map<String, dynamic> json) {
    return PropertyInfo(
      propertyName: json['property_name'] ?? '',
      legalName: json['legal_name'] ?? '',
      address: json['address'] ?? '',
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      pinCode: json['pin_code'] ?? '',
      contactPerson: json['contact_person'] ?? '',
      mobile: json['mobile'] ?? '',
      email: json['email'] ?? '',
      gstNo: json['gst_no'] ?? '',
      panNo: json['pan_no'] ?? '',
      fssaiNo: json['fssai_no'] ?? '',
      logoPath: json['logo_path'],
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'property_name': propertyName,
      'legal_name': legalName,
      'address': address,
      'city': city,
      'state': state,
      'pin_code': pinCode,
      'contact_person': contactPerson,
      'mobile': mobile,
      'email': email,
      'gst_no': gstNo,
      'pan_no': panNo,
      'fssai_no': fssaiNo,
      'logo_path': logoPath,
      'is_active': isActive,
    };
  }
}
