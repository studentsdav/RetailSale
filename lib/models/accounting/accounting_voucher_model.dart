class VoucherLineModel {
  final int? id;
  final int? voucherId;
  String lineType; // DEBIT or CREDIT
  int? accountId;
  String accountName;
  String accountType;
  double debitAmount;
  double creditAmount;
  String? particulars;

  VoucherLineModel({
    this.id,
    this.voucherId,
    required this.lineType,
    this.accountId,
    required this.accountName,
    this.accountType = 'GENERAL',
    required this.debitAmount,
    required this.creditAmount,
    this.particulars,
  });

  factory VoucherLineModel.fromJson(Map<String, dynamic> json) {
    return VoucherLineModel(
      id: json['id'] != null ? int.tryParse(json['id'].toString()) : null,
      voucherId: json['voucher_id'] != null
          ? int.tryParse(json['voucher_id'].toString())
          : null,
      lineType: json['line_type'] ?? 'DEBIT',
      accountId: json['account_id'] != null
          ? int.tryParse(json['account_id'].toString())
          : null,
      accountName: json['account_name'] ?? '',
      accountType: json['account_type'] ?? 'GENERAL',
      debitAmount:
          double.tryParse(json['debit_amount']?.toString() ?? '0') ?? 0.0,
      creditAmount:
          double.tryParse(json['credit_amount']?.toString() ?? '0') ?? 0.0,
      particulars: json['particulars'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (voucherId != null) 'voucher_id': voucherId,
      'line_type': lineType,
      'account_id': accountId,
      'account_name': accountName,
      'account_type': accountType,
      'debit_amount': debitAmount,
      'credit_amount': creditAmount,
      'particulars': particulars,
    };
  }
}

class AccountingVoucherModel {
  final int? id;
  final int? outletId;
  final String voucherNo;
  final String voucherType; // CONTRA, PAYMENT, RECEIPT, JOURNAL, SALES, PURCHASE
  final String voucherDate;
  final String paymentMode;
  final int? bankAccountId;
  final String? referenceNo;
  final String? narration;
  final double totalDebit;
  final double totalCredit;
  final String status;
  final List<VoucherLineModel> lines;

  AccountingVoucherModel({
    this.id,
    this.outletId,
    required this.voucherNo,
    required this.voucherType,
    required this.voucherDate,
    required this.paymentMode,
    this.bankAccountId,
    this.referenceNo,
    this.narration,
    required this.totalDebit,
    required this.totalCredit,
    this.status = 'POSTED',
    this.lines = const [],
  });

  factory AccountingVoucherModel.fromJson(Map<String, dynamic> json) {
    var rawLines = json['lines'] as List? ?? [];
    List<VoucherLineModel> parsedLines =
        rawLines.map((e) => VoucherLineModel.fromJson(e)).toList();

    return AccountingVoucherModel(
      id: json['id'] != null ? int.tryParse(json['id'].toString()) : null,
      outletId: json['outlet_id'] != null
          ? int.tryParse(json['outlet_id'].toString())
          : null,
      voucherNo: json['voucher_no'] ?? '',
      voucherType: json['voucher_type'] ?? 'JOURNAL',
      voucherDate: json['voucher_date'] ?? '',
      paymentMode: json['payment_mode'] ?? 'CASH',
      bankAccountId: json['bank_account_id'] != null
          ? int.tryParse(json['bank_account_id'].toString())
          : null,
      referenceNo: json['reference_no'],
      narration: json['narration'],
      totalDebit:
          double.tryParse(json['total_debit']?.toString() ?? '0') ?? 0.0,
      totalCredit:
          double.tryParse(json['total_credit']?.toString() ?? '0') ?? 0.0,
      status: json['status'] ?? 'POSTED',
      lines: parsedLines,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'voucher_no': voucherNo,
      'voucher_type': voucherType,
      'voucher_date': voucherDate,
      'payment_mode': paymentMode,
      'bank_account_id': bankAccountId,
      'reference_no': referenceNo,
      'narration': narration,
      'total_debit': totalDebit,
      'total_credit': totalCredit,
      'status': status,
      'lines': lines.map((e) => e.toJson()).toList(),
    };
  }
}
