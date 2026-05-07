class StockInModel {
  final int inwardsNo;
  final DateTime date;
  final String grnNo;
  final String billNo;
  final String supplier;
  final String supplierBill;
  final String supplierGstin;
  final String supplierState;
  final String billStatus;
  final double paidAmount;
  final double outstandingAmount;
  final String itemName;
  final String brand;
  final String unit;
  final double rate;
  final double qty;
  final double gst;
  final double taxAmount;
  final double totalAfterTax;
  StockInModel({
    required this.inwardsNo,
    required this.date,
    required this.grnNo,
    required this.billNo,
    required this.supplier,
    required this.supplierBill,
    required this.supplierGstin,
    required this.supplierState,
    required this.billStatus,
    required this.paidAmount,
    required this.outstandingAmount,
    required this.itemName,
    required this.brand,
    required this.unit,
    required this.rate,
    required this.qty,
    required this.gst,
    required this.taxAmount,
    required this.totalAfterTax,
  });

  factory StockInModel.fromJson(Map<String, dynamic> json) {
    return StockInModel(
      inwardsNo: json['inwards_no'],
      date: DateTime.parse(json['date']),
      grnNo: (json['grn_no'] ?? '').toString(),
      billNo: (json['bill_no'] ?? '').toString(),
      supplier: json['supplier'] ?? '',
      supplierBill: json['supplier_bill'] ?? '',
      supplierGstin: json['supplier_gstin'] ?? '',
      supplierState: json['supplier_state'] ?? '',
      billStatus: json['bill_status'] ?? '',
      paidAmount: double.tryParse((json['paid_amount'] ?? 0).toString()) ?? 0,
      outstandingAmount:
          double.tryParse((json['outstanding_amount'] ?? 0).toString()) ?? 0,
      itemName: json['item_name'] ?? '',
      brand: json['brand'] ?? '',
      unit: json['unit'] ?? '',
      rate: double.tryParse((json['rate'] ?? 0).toString()) ?? 0,
      qty: double.tryParse((json['qty'] ?? 0).toString()) ?? 0,
      gst: double.tryParse((json['gst'] ?? 0).toString()) ?? 0,
      taxAmount: double.tryParse((json['tax_amount'] ?? 0).toString()) ?? 0,
      totalAfterTax:
          double.tryParse((json['total_after_tax'] ?? 0).toString()) ?? 0,
    );
  }

  double get amount => rate * qty;
  double get gstAmount => amount * gst / 100;
  double get netAmount =>
      totalAfterTax == 0 ? amount + gstAmount : totalAfterTax;
}
