class StockItem {
  final String name;
  final String category;
  final String unit;
  final double qty;
  final double reorder;
  final double rate;

  StockItem({
    required this.name,
    required this.category,
    required this.unit,
    required this.qty,
    required this.reorder,
    required this.rate,
  });

  factory StockItem.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic value) =>
        double.tryParse((value ?? 0).toString()) ?? 0;

    return StockItem(
      name: json['name'] ?? '',
      category: json['category'] ?? '',
      unit: json['unit'] ?? '',
      qty: toDouble(json['qty']),
      reorder: toDouble(json['reorder']),
      rate: toDouble(json['rate']),
    );
  }

  double get value => qty * rate;
  bool get isLow => qty <= reorder;
  double get shortfall => isLow ? (reorder - qty) : 0;
  String get stockStatus {
    if (reorder <= 0) return 'NO_MIN';
    if (qty <= reorder) return 'REORDER';
    if (qty <= reorder * 1.25) return 'LOW_BUFFER';
    return 'HEALTHY';
  }
}

class CategoryStock {
  final String category;
  final double value;

  CategoryStock(this.category, this.value);
}
