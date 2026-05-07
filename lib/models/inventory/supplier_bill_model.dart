enum PaymentStatus { PAID, UNPAID, PARTIAL }

class SupplierBill {
  final int id;
  final String supplier;
  final String billNo;
  final DateTime billDate;
  final double billAmount;
  final double paidAmount;
  final PaymentStatus status;

  SupplierBill({
    required this.id,
    required this.supplier,
    required this.billNo,
    required this.billDate,
    required this.billAmount,
    required this.paidAmount,
    required this.status,
  });

  factory SupplierBill.fromJson(Map<String, dynamic> json) {
    return SupplierBill(
      id: json['id'],
      supplier: json['supplier']?['supplier_name'] ?? '',
      billNo: json['bill_no'],
      billDate: DateTime.parse(json['bill_date']),
      billAmount: (double.parse(json['bill_amount']) ?? 0).toDouble(),
      paidAmount: (double.parse(json['paid_amount']) ?? 0).toDouble(),
      status: PaymentStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => PaymentStatus.UNPAID,
      ),
    );
  }

  double get balance => billAmount - paidAmount;
}
