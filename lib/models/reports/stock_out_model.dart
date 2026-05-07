class StockOutModel {
  final String itemName;
  final String brand;
  final String hsn;
  final String unit;
  final double rate;
  final double qty;
  final double gst;
  final double taxAmount;
  final double totalAfterTax;
  final String issuedTo;

  StockOutModel({
    required this.itemName,
    required this.brand,
    required this.hsn,
    required this.unit,
    required this.rate,
    required this.qty,
    required this.gst,
    required this.taxAmount,
    required this.totalAfterTax,
    required this.issuedTo,
  });
  factory StockOutModel.fromJson(Map<String, dynamic> json) {
    return StockOutModel(
      itemName: json['item_name'] ?? '',
      brand: json['brand'] ?? '',
      hsn: json['hsn_code'] ?? '',
      unit: json['unit'] ?? '',
      rate: (double.parse(json['rate']) ?? 0).toDouble(),
      qty: (double.parse(json['qty'])),
      gst: (double.parse(json['gst']) ?? 0).toDouble(),
      taxAmount: double.tryParse((json['tax_amount'] ?? 0).toString()) ?? 0,
      totalAfterTax:
          double.tryParse((json['total_after_tax'] ?? 0).toString()) ?? 0,
      issuedTo: json['issued_to'] ?? '',
    );
  }

  double get amount => rate * qty;
  double get gstAmount => amount * gst / 100;
  double get netAmount =>
      totalAfterTax == 0 ? amount + gstAmount : totalAfterTax;
}
