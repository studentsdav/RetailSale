class DamageItem {
  final int? itemId;
  final String itemCode;
  final String itemName;
  final String unit;
  final int qty;
  final double rate;
  final String remarks;

  DamageItem({
    this.itemId,
    required this.itemCode,
    required this.itemName,
    required this.unit,
    required this.qty,
    required this.rate,
    required this.remarks,
  });

  double get amount => qty * rate;

  Map<String, dynamic> toJson() {
    return {
      'item_id': itemId,
      'item_code': itemCode,
      'item_name': itemName,
      'unit': unit,
      'qty': qty,
      'rate': rate,
      'remarks': remarks,
    };
  }
}
