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
  String lineStatus;

  ReceiveItem(
      {required this.itemId,
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
      this.lineStatus = 'CLOSED'});

  double get amount => qty * rate;
  double get gst => amount * tax / 100;
  double get totalAfterTax => amount + gst;

  Map<String, dynamic> toJson() => {
        'item_id': itemId,
        'code': code,
        'name': name,
        'brand': brand,
        'unit': unit,
        'qty': qty,
        'rate': rate,
        'tax': tax,
        'sale_rate': rate,
        'expiry_date': expiryDate?.toIso8601String(),
        'department': department,
        'line_status': lineStatus
      };
}
