class SaleCustomer {
  final int id;
  final String customerName;
  final String customerPhone;
  final String customerAddress;
  final String customerEmail;
  final String customerGstin;
  final int? schemeId;
  final String? schemeName;
  final int? outletId;
  final String? outletName;

  const SaleCustomer({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.customerAddress,
    this.customerEmail = '',
    this.customerGstin = '',
    this.schemeId,
    this.schemeName,
    this.outletId,
    this.outletName,
  });

  factory SaleCustomer.fromJson(Map<String, dynamic> json) {
    return SaleCustomer(
      id: json['id'] ?? 0,
      customerName: json['customer_name'] ?? json['name'] ?? '',
      customerPhone: json['customer_phone'] ?? json['phone'] ?? json['mobile'] ?? '',
      customerAddress: json['customer_address'] ?? json['address'] ?? '',
      customerEmail: json['customer_email'] ?? json['email'] ?? '',
      customerGstin: json['customer_gstin'] ?? json['gstin'] ?? '',
      schemeId: json['scheme_id'],
      schemeName: json['scheme_name'],
      outletId: json['outlet_id'],
      outletName: json['outlet_name'] ?? json['outlet']?['outlet_name'],
    );
  }

  String get displayLabel {
    final name = customerName.trim().isEmpty ? 'Walk-in Customer' : customerName;
    return '$customerPhone - $name';
  }
}
