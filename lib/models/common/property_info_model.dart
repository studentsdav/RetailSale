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
  final String drugLicenseNo;
  final String? logoPath;
  final bool isActive;
  final String website;
  final bool printMobile;
  final bool printEmail;
  final bool printWebsite;
  final String thermalFooterNote;

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
    this.drugLicenseNo = '',
    this.logoPath,
    required this.isActive,
    this.website = '',
    this.printMobile = true,
    this.printEmail = true,
    this.printWebsite = true,
    this.thermalFooterNote = 'Thank you for shopping with us. Please visit again.\nReturn Policy: Exchange within 7 days with original receipt.\nHave a nice day!',
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
      drugLicenseNo: json['drug_license_no'] ?? json['drugLicenseNo'] ?? '',
      logoPath: json['logo_path'],
      isActive: json['is_active'] ?? true,
      website: json['website'] ?? '',
      printMobile: json['print_mobile'] ?? true,
      printEmail: json['print_email'] ?? true,
      printWebsite: json['print_website'] ?? true,
      thermalFooterNote: (json['thermal_footer_note'] ?? '').toString().trim().isNotEmpty
          ? json['thermal_footer_note'].toString()
          : 'Thank you for shopping with us. Please visit again.\nReturn Policy: Exchange within 7 days with original receipt.\nHave a nice day!',
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
      'drug_license_no': drugLicenseNo,
      'logo_path': logoPath,
      'is_active': isActive,
      'website': website,
      'print_mobile': printMobile,
      'print_email': printEmail,
      'print_website': printWebsite,
      'thermal_footer_note': thermalFooterNote,
    };
  }
}
