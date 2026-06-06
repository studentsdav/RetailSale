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

class SupplierBillItemDetail {
  final String itemCode;
  final String itemName;
  final String unit;
  final double qty;
  final double rate;
  final double tax;
  final String remarks;

  const SupplierBillItemDetail({
    required this.itemCode,
    required this.itemName,
    required this.unit,
    required this.qty,
    required this.rate,
    required this.tax,
    required this.remarks,
  });

  factory SupplierBillItemDetail.fromJson(Map<String, dynamic> json) {
    double parseNum(dynamic value) =>
        double.tryParse(value?.toString() ?? '') ?? 0;

    return SupplierBillItemDetail(
      itemCode: (json['item_code'] ?? '').toString(),
      itemName: (json['item_name'] ?? '').toString(),
      unit: (json['unit'] ?? '').toString(),
      qty: parseNum(json['qty']),
      rate: parseNum(json['rate']),
      tax: parseNum(json['tax']),
      remarks: (json['remarks'] ?? '').toString(),
    );
  }
}

class SupplierBillDetail {
  final SupplierBill bill;
  final int? grnId;
  final int? supplierId;
  final String supplierAddress;
  final String supplierPhone;
  final String? grnNo;
  final DateTime? receiptDate;
  final List<SupplierBillItemDetail> items;

  const SupplierBillDetail({
    required this.bill,
    required this.grnId,
    required this.supplierId,
    required this.supplierAddress,
    required this.supplierPhone,
    required this.grnNo,
    required this.receiptDate,
    required this.items,
  });

  factory SupplierBillDetail.fromJson(Map<String, dynamic> json) {
    final billJson = Map<String, dynamic>.from(json['bill'] as Map);
    final grnJson = json['grn'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(json['grn'] as Map<String, dynamic>)
        : null;
    final supplierJson = billJson['supplier'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(billJson['supplier'] as Map<String, dynamic>)
        : const <String, dynamic>{};

    return SupplierBillDetail(
      bill: SupplierBill.fromJson(billJson),
      grnId: grnJson == null ? null : int.tryParse(grnJson['id']?.toString() ?? ''),
      supplierId: grnJson == null
          ? null
          : int.tryParse(grnJson['supplier_id']?.toString() ?? ''),
      supplierAddress: (supplierJson['address'] ?? '').toString(),
      supplierPhone: (supplierJson['phone'] ?? '').toString(),
      grnNo: grnJson == null ? null : grnJson['grn_no']?.toString(),
      receiptDate: grnJson == null || grnJson['receipt_date'] == null
          ? null
          : DateTime.tryParse(grnJson['receipt_date'].toString()),
      items: (json['items'] as List? ?? const [])
          .map((entry) =>
              SupplierBillItemDetail.fromJson(Map<String, dynamic>.from(entry)))
          .toList(),
    );
  }
}
