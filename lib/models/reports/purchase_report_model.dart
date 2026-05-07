class PurchaseOrderReport {
  final String poNo;
  final String supplierName;
  final String status;
  final double totalAmount;
  final DateTime poDate;

  PurchaseOrderReport({
    required this.poNo,
    required this.supplierName,
    required this.status,
    required this.totalAmount,
    required this.poDate,
  });

  factory PurchaseOrderReport.fromJson(Map<String, dynamic> json) {
    return PurchaseOrderReport(
      poNo: json['po_no'] ?? '',
      supplierName: json['supplier_name'] ?? '',
      status: json['status'] ?? '',
      totalAmount: double.tryParse(json['total_amount'].toString()) ?? 0,
      poDate: DateTime.parse(json['po_date']),
    );
  }
}
