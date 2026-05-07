class CashLedgerEntry {
  final DateTime txnDate;
  final String transactionType;
  final String referenceNo;
  final String partyName;
  final String paymentMethod;
  final double amountIn;
  final double amountOut;
  final double balance;
  final String notes;

  CashLedgerEntry({
    required this.txnDate,
    required this.transactionType,
    required this.referenceNo,
    required this.partyName,
    required this.paymentMethod,
    required this.amountIn,
    required this.amountOut,
    required this.balance,
    required this.notes,
  });

  factory CashLedgerEntry.fromJson(Map<String, dynamic> json) {
    return CashLedgerEntry(
      txnDate: DateTime.parse(json['txn_date']),
      transactionType: (json['transaction_type'] ?? '').toString(),
      referenceNo: (json['reference_no'] ?? '').toString(),
      partyName: (json['party_name'] ?? '').toString(),
      paymentMethod: (json['payment_method'] ?? '').toString(),
      amountIn: double.tryParse((json['amount_in'] ?? 0).toString()) ?? 0,
      amountOut: double.tryParse((json['amount_out'] ?? 0).toString()) ?? 0,
      balance: double.tryParse((json['balance'] ?? 0).toString()) ?? 0,
      notes: (json['notes'] ?? '').toString(),
    );
  }
}
