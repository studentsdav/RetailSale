class RequestItem {
  String code;
  String name;
  String unit;
  double qty;
  double rate;
  String type;
  int itemid;
  String lineStatus;

  RequestItem({
    required this.code,
    required this.name,
    required this.unit,
    required this.qty,
    required this.rate,
    required this.type,
    required this.itemid,
    this.lineStatus = 'OPEN',
  });

  double get amount => qty * rate;
}

class RequestItemReport {
  final String itemName;
  final String brand;
  final double qty;
  final double rate;
  final double amount;

  RequestItemReport({
    required this.itemName,
    required this.brand,
    required this.qty,
    required this.rate,
    required this.amount,
  });

  factory RequestItemReport.fromJson(Map<String, dynamic> json) {
    return RequestItemReport(
      itemName: json['item_name'] ?? '',
      brand: json['brand'] ?? '',
      qty: double.parse(json['qty'].toString()),
      rate: double.parse(json['rate'].toString()),
      amount: double.parse(json['amount'].toString()),
    );
  }
}

class RequestItemnew {
  final int id;
  final int itemId;
  final String name;
  final String brand;
  final String unit;
  final double qty;
  final double rate;

  RequestItemnew({
    required this.id,
    required this.itemId,
    required this.name,
    required this.brand,
    required this.unit,
    required this.qty,
    required this.rate,
  });

  factory RequestItemnew.fromJson(Map<String, dynamic> json) {
    return RequestItemnew(
      id: json['id'],
      itemId: json['item_id'],
      name: json['item_master']?['item_name'] ?? '',
      brand: json['item_master']?['brand'] ?? '',
      unit: json['item_master']?['unit'] ?? '',
      qty: double.tryParse(json['qty'].toString()) ?? 0,
      rate: double.tryParse(json['rate'].toString()) ?? 0,
    );
  }
}
