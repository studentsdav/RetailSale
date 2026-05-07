class SaleScheme {
  final int id;
  final String schemeName;
  final String schemeType;
  final String schemeScope;
  final String discountType;
  final double discountValue;
  final String? startTime;
  final String? endTime;
  final double minQty;
  final double minAmount;
  final int? itemId;
  final double requiredDailyQty;
  final double freeQty;
  final int cycleDays;
  final bool requireNoGaps;
  final String repeatMode;
  final String applyTiming;
  final bool autoSelectOnCustomer;
  final int nextPurchaseValidDays;
  final bool isActive;
  final String usageType;
  final bool customerLinked;

  SaleScheme({
    required this.id,
    required this.schemeName,
    required this.schemeType,
    this.schemeScope = 'ORDER',
    required this.discountType,
    required this.discountValue,
    this.startTime,
    this.endTime,
    required this.minQty,
    required this.minAmount,
    this.itemId,
    this.requiredDailyQty = 0,
    this.freeQty = 0,
    this.cycleDays = 30,
    this.requireNoGaps = false,
    this.repeatMode = 'REPEAT',
    this.applyTiming = 'CURRENT_BILL',
    this.autoSelectOnCustomer = true,
    this.nextPurchaseValidDays = 7,
    required this.isActive,
    this.usageType = 'reusable',
    this.customerLinked = false,
  });

  factory SaleScheme.fromJson(Map<String, dynamic> json) {
    return SaleScheme(
      id: json['id'],
      schemeName: json['scheme_name'] ?? '',
      schemeType: json['scheme_type'] ?? 'TIME',
      schemeScope: json['scheme_scope'] ?? 'ORDER',
      discountType: json['discount_type'] ?? 'PERCENT',
      discountValue: double.tryParse(json['discount_value'].toString()) ?? 0,
      startTime: json['start_time'],
      endTime: json['end_time'],
      minQty: double.tryParse(json['min_qty'].toString()) ?? 0,
      minAmount: double.tryParse(json['min_amount'].toString()) ?? 0,
      itemId: json['item_id'],
      requiredDailyQty:
          double.tryParse(json['required_daily_qty'].toString()) ?? 0,
      freeQty: double.tryParse(json['free_qty'].toString()) ?? 0,
      cycleDays: int.tryParse(json['cycle_days'].toString()) ?? 30,
      requireNoGaps: json['require_no_gaps'] ?? false,
      repeatMode: (json['repeat_mode'] ?? 'REPEAT').toString(),
      applyTiming: (json['apply_timing'] ?? 'CURRENT_BILL').toString(),
      autoSelectOnCustomer: json['auto_select_on_customer'] ?? true,
      nextPurchaseValidDays:
          int.tryParse(json['next_purchase_valid_days'].toString()) ?? 7,
      isActive: json['is_active'] ?? true,
      usageType: (json['usage_type'] ??
              ((json['repeat_mode'] ?? '').toString().toUpperCase() == 'ONCE'
                  ? 'single_use'
                  : 'reusable'))
          .toString(),
      customerLinked: json['customer_linked'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'scheme_name': schemeName,
      'scheme_type': schemeType,
      'scheme_scope': schemeScope,
      'discount_type': discountType,
      'discount_value': discountValue,
      'start_time': startTime,
      'end_time': endTime,
      'min_qty': minQty,
      'min_amount': minAmount,
      'item_id': itemId,
      'required_daily_qty': requiredDailyQty,
      'free_qty': freeQty,
      'cycle_days': cycleDays,
      'require_no_gaps': requireNoGaps,
      'repeat_mode': repeatMode,
      'apply_timing': applyTiming,
      'auto_select_on_customer': autoSelectOnCustomer,
      'next_purchase_valid_days': nextPurchaseValidDays,
      'is_active': isActive,
      'usage_type': usageType,
      'customer_linked': customerLinked,
    };
  }
}
