class PurchaseItem {
  final int itemId;
  final String itemCode;
  final String itemName;
  final String brand;
  final String unit;
  double qty;
  double rate;
  double tax;
  String department;
  String lineStatus;
  final bool isTaxInclusive;
  final double? originalRate;

  PurchaseItem({
    required this.itemId,
    required this.itemCode,
    required this.itemName,
    required this.brand,
    required this.unit,
    required this.qty,
    required this.rate,
    this.tax = 0,
    required this.department,
    this.lineStatus = 'OPEN',
    this.isTaxInclusive = false,
    this.originalRate,
  });

  double get amount => double.parse((qty * rate).toStringAsFixed(2));
  double get taxAmount => double.parse((amount * tax / 100).toStringAsFixed(2));
  double get totalAfterTax => double.parse((amount + taxAmount).toStringAsFixed(2));

  factory PurchaseItem.fromJson(Map<String, dynamic> json) {
    return PurchaseItem(
      itemId: json['item_id'],
      itemCode: json['item_code'] ?? '',
      itemName: json['item_name'] ?? '',
      brand: json['brand'] ?? '',
      unit: json['unit'] ?? '',
      qty: double.parse(json['qty'].toString()),
      rate: double.parse(json['rate'].toString()),
      tax: double.tryParse((json['tax'] ?? 0).toString()) ?? 0,
      department: json['department'] ?? '',
      lineStatus: (json['line_status'] ?? 'OPEN').toString(),
      isTaxInclusive: json['is_tax_inclusive'] == true || json['is_tax_inclusive'] == 1,
      originalRate: json['original_rate'] != null ? double.tryParse(json['original_rate'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'item_id': itemId,
        'item_code': itemCode,
        'item_name': itemName,
        'brand': brand,
        'unit': unit,
        'qty': qty,
        'rate': rate,
        'tax': tax,
        'department': department,
        'line_status': lineStatus,
        'is_tax_inclusive': isTaxInclusive,
        'original_rate': originalRate ?? rate,
      };
}

