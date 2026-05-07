class IssueItem {
  final int itemId;
  final String itemCode;
  final String itemName;
  final String unit;
  final double qty;
  final double rate;
  final double tax;
  final String type;
  String lineStatus;

  IssueItem({
    required this.itemId,
    required this.itemCode,
    required this.itemName,
    required this.unit,
    required this.qty,
    required this.rate,
    required this.tax,
    required this.type,
    this.lineStatus = 'CLOSED',
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
      'tax': tax,
      'type': type,
      'line_status': lineStatus,
    };
  }
}
