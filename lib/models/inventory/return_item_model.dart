class ReturnItem {
  final int issueItemId;
  final int itemId;
  int qty;
  double rate;

  ReturnItem({
    required this.issueItemId,
    required this.itemId,
    required this.qty,
    required this.rate,
  });

  Map<String, dynamic> toJson() {
    return {
      'issue_item_id': issueItemId,
      'item_id': itemId,
      'qty': qty,
      'rate': rate,
    };
  }
}

class ReturnItemReport {
  final String itemName;
  final double qty;
  final double rate;
  final double amount;

  ReturnItemReport({
    required this.itemName,
    required this.qty,
    required this.rate,
    required this.amount,
  });

  factory ReturnItemReport.fromJson(Map<String, dynamic> json) {
    return ReturnItemReport(
      itemName: json['item_name'] ?? '',
      qty: double.tryParse(json['qty'].toString()) ?? 0,
      rate: double.tryParse(json['rate'].toString()) ?? 0,
      amount: double.tryParse(json['amount'].toString()) ?? 0,
    );
  }
}
