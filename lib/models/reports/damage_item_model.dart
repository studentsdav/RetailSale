class DamageItem {
  final DateTime date;
  final String item;
  final String brand;
  final String category;
  final double qty;
  final double rate;
  final String reason;
  final String user;

  DamageItem({
    required this.date,
    required this.item,
    required this.brand,
    required this.category,
    required this.qty,
    required this.rate,
    required this.reason,
    required this.user,
  });

  factory DamageItem.fromJson(Map<String, dynamic> json) {
    return DamageItem(
      date: DateTime.parse(json['date']),
      item: json['item'] ?? '',
      brand: json['brand'] ?? '',
      category: json['category'] ?? '',
      qty: double.parse((json['qty'].toString())),
      rate: (double.parse(json['rate']) ?? 0).toDouble(),
      reason: json['reason'] ?? '',
      user: json['user'] ?? '',
    );
  }

  double get amount => qty * rate;
}

class CategoryDamage {
  final String category;
  final double value;
  CategoryDamage(this.category, this.value);
}

class DailyDamage {
  final String day;
  final double value;
  DailyDamage(this.day, this.value);
}
