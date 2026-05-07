import '../inventory/return_item_model.dart';

class ReturnReport {
  final int id;
  final String returnNo;
  final DateTime returnDate;
  final String? issueNo;
  final double totalQty;
  final double totalAmount;
  final List<ReturnItemReport> items;

  ReturnReport({
    required this.id,
    required this.returnNo,
    required this.returnDate,
    required this.issueNo,
    required this.totalQty,
    required this.totalAmount,
    required this.items,
  });

  factory ReturnReport.fromJson(Map<String, dynamic> json) {
    return ReturnReport(
      id: json['id'],
      returnNo: json['return_no'] ?? '',
      returnDate: DateTime.parse(json['return_date']),
      issueNo: json['issue_no'],
      totalQty: double.tryParse(json['total_qty'].toString()) ?? 0,
      totalAmount: double.tryParse(json['total_amount'].toString()) ?? 0,
      items: (json['items'] as List)
          .map((e) => ReturnItemReport.fromJson(e))
          .toList(),
    );
  }
}
// return report//
