class ReceiveItemModel {
  final String code;
  final String name;
  final String brand;
  final String unit;
  final int qty;
  final double rate;
  final double tax;
  final DateTime expiryDate;

  ReceiveItemModel({
    required this.code,
    required this.name,
    required this.brand,
    required this.unit,
    required this.qty,
    required this.rate,
    required this.tax,
    required this.expiryDate,
  });

  Map<String, dynamic> toJson() => {
        "code": code,
        "name": name,
        "brand": brand,
        "unit": unit,
        "qty": qty,
        "rate": rate,
        "tax": tax,
        "expiry_date": expiryDate.toIso8601String(),
      };
}
