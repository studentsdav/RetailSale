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
  final String termsAndConditions;
  final String bankName;
  final String bankAccNo;
  final String bankIfsc;
  final String upiId;
  final String upiPayeeName;
  final bool printBankDetails;
  final bool printUpiQr;
  final bool printDigitalSignature;

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
    this.termsAndConditions = '1. Goods once sold will not be taken back.\n2. Subject to local jurisdiction.',
    this.bankName = '',
    this.bankAccNo = '',
    this.bankIfsc = '',
    this.upiId = '',
    this.upiPayeeName = '',
    this.printBankDetails = false,
    this.printUpiQr = false,
    this.printDigitalSignature = false,
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
      termsAndConditions: json['terms_and_conditions'] ?? json['termsAndConditions'] ?? '1. Goods once sold will not be taken back.\n2. Subject to local jurisdiction.',
      bankName: json['bank_name'] ?? json['bankName'] ?? '',
      bankAccNo: json['bank_acc_no'] ?? json['bankAccNo'] ?? '',
      bankIfsc: json['bank_ifsc'] ?? json['bankIfsc'] ?? '',
      upiId: json['upi_id'] ?? json['upiId'] ?? '',
      upiPayeeName: json['upi_payee_name'] ?? json['upiPayeeName'] ?? '',
      printBankDetails: json['print_bank_details'] ?? json['printBankDetails'] ?? false,
      printUpiQr: json['print_upi_qr'] ?? json['printUpiQr'] ?? false,
      printDigitalSignature: json['print_digital_signature'] ?? json['printDigitalSignature'] ?? false,
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
      'terms_and_conditions': termsAndConditions,
      'bank_name': bankName,
      'bank_acc_no': bankAccNo,
      'bank_ifsc': bankIfsc,
      'upi_id': upiId,
      'upi_payee_name': upiPayeeName,
      'print_bank_details': printBankDetails,
      'print_upi_qr': printUpiQr,
      'print_digital_signature': printDigitalSignature,
    };
  }
}
