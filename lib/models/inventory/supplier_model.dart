class Supplier {
  final int id;
  final String supplierCode;
  final String supplierName;
  final String address;
  final String phone;
  final String? state;
  final String? gstin;
  final String? taxCountryCode;
  Supplier({
    required this.id,
    required this.supplierCode,
    required this.supplierName,
    required this.address,
    required this.phone,
    this.state,
    this.gstin,
    this.taxCountryCode,
  });

  factory Supplier.fromJson(Map<String, dynamic> json) {
    return Supplier(
      id: json['id'],
      supplierCode: json['supplier_code'] ?? '',
      supplierName: json['supplier_name'] ?? '',
      address: json['address'] ?? '',
      phone: json['phone'] ?? '',
      state: json['state'],
      gstin: json['gstin'] ?? json['tax_id_number'],
      taxCountryCode: json['tax_country_code'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'supplier_code': supplierCode,
      'supplier_name': supplierName,
      'address': address,
      'phone': phone,
      'state': state,
      'gstin': gstin,
      'tax_id_number': gstin,
      'tax_country_code': taxCountryCode,
    };
  }
}
