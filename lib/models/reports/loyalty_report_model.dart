double _toDouble(dynamic value) => double.tryParse(value.toString()) ?? 0;

class LoyaltyMasterRow {
  final String customerKey;
  final String customerName;
  final String customerPhone;
  final String customerGstin;
  final double totalLifetimePurchase;
  final int totalPointsEarned;
  final int totalPointsRedeemed;
  final int pointsExpired;
  final int currentActiveBalance;

  const LoyaltyMasterRow({
    required this.customerKey,
    required this.customerName,
    required this.customerPhone,
    required this.customerGstin,
    required this.totalLifetimePurchase,
    required this.totalPointsEarned,
    required this.totalPointsRedeemed,
    required this.pointsExpired,
    required this.currentActiveBalance,
  });

  factory LoyaltyMasterRow.fromJson(Map<String, dynamic> json) {
    return LoyaltyMasterRow(
      customerKey: (json['customer_key'] ?? '').toString(),
      customerName: (json['customer_name'] ?? '').toString(),
      customerPhone: (json['customer_phone'] ?? '').toString(),
      customerGstin: (json['customer_gstin'] ?? '').toString(),
      totalLifetimePurchase: _toDouble(json['total_lifetime_purchase']),
      totalPointsEarned:
          int.tryParse((json['total_points_earned'] ?? 0).toString()) ?? 0,
      totalPointsRedeemed:
          int.tryParse((json['total_points_redeemed'] ?? 0).toString()) ?? 0,
      pointsExpired: int.tryParse((json['points_expired'] ?? 0).toString()) ?? 0,
      currentActiveBalance:
          int.tryParse((json['current_active_balance'] ?? 0).toString()) ?? 0,
    );
  }
}

class LoyaltyLedgerRow {
  final int id;
  final DateTime transactionDate;
  final String transactionType;
  final int pointsDelta;
  final int pointsBalanceAfter;
  final String billNumber;
  final int saleId;
  final String expiryDate;

  const LoyaltyLedgerRow({
    required this.id,
    required this.transactionDate,
    required this.transactionType,
    required this.pointsDelta,
    required this.pointsBalanceAfter,
    required this.billNumber,
    required this.saleId,
    required this.expiryDate,
  });

  factory LoyaltyLedgerRow.fromJson(Map<String, dynamic> json) {
    return LoyaltyLedgerRow(
      id: int.tryParse((json['id'] ?? 0).toString()) ?? 0,
      transactionDate:
          DateTime.tryParse((json['transaction_date'] ?? '').toString())
                  ?.toLocal() ??
              DateTime.now(),
      transactionType: (json['transaction_type'] ?? '').toString(),
      pointsDelta: int.tryParse((json['points_delta'] ?? 0).toString()) ?? 0,
      pointsBalanceAfter:
          int.tryParse((json['points_balance_after'] ?? 0).toString()) ?? 0,
      billNumber: (json['bill_number'] ?? '').toString(),
      saleId: int.tryParse((json['sale_id'] ?? 0).toString()) ?? 0,
      expiryDate: (json['expiry_date'] ?? '').toString(),
    );
  }
}
