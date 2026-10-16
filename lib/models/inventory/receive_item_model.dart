class ReceiveItem {
  final String itemId;
  final String code;
  final String name;
  final String brand;
  final String unit;
  final double qty;
  final double rate;
  final double saleRate;
  final double tax;
  final DateTime? expiryDate;
  final String? department;
  final String remarks;
  String lineStatus;
  final bool isTaxInclusive;
  final bool isSaleTaxInclusive;
  final String inclusiveScope;
  final double? originalRate;

  ReceiveItem({
    required this.itemId,
    required this.code,
    required this.name,
    required this.brand,
    required this.unit,
    required this.qty,
    required this.rate,
    required this.saleRate,
    required this.tax,
    this.expiryDate,
    required this.department,
    this.remarks = '',
    this.lineStatus = 'CLOSED',
    this.isTaxInclusive = false,
    this.isSaleTaxInclusive = false,
    this.inclusiveScope = 'NONE',
    this.originalRate,
  });

  double get amount => double.parse((qty * rate).toStringAsFixed(2));
  double get gst => double.parse((amount * tax / 100).toStringAsFixed(2));
  double get totalAfterTax => double.parse((amount + gst).toStringAsFixed(2));

  Map<String, dynamic> toJson() => {
        'item_id': itemId,
        'code': code,
        'name': name,
        'brand': brand,
        'unit': unit,
        'qty': qty,
        'rate': rate,
        'original_rate': originalRate ?? rate,
        'is_tax_inclusive': isTaxInclusive,
        'is_sale_tax_inclusive': isSaleTaxInclusive,
        'inclusive_scope': inclusiveScope,
        'tax': tax,
        'sale_rate': saleRate,
        'expiry_date': expiryDate?.toIso8601String(),
        'department': department,
        'remarks': remarks,
        'line_status': lineStatus
      };
}

