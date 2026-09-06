class SaleCustomer {
  final int id;
  final String customerName;
  final String customerPhone;
  final String customerAddress;
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
    this.customerGstin = '',
    this.schemeId,
    this.schemeName,
    this.outletId,
    this.outletName,
  });

  factory SaleCustomer.fromJson(Map<String, dynamic> json) {
    return SaleCustomer(
      id: json['id'] ?? 0,
      customerName: json['customer_name'] ?? '',
      customerPhone: json['customer_phone'] ?? '',
      customerAddress: json['customer_address'] ?? '',
      customerGstin: json['customer_gstin'] ?? '',
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
