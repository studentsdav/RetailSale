import 'tax_breakdown_model.dart';
import 'tax_group_model.dart';

class BillingCharge {
  final String name;
  final String code;
  final double amount;
  final String calculationType;
  final double calculationValue;
  final bool taxable;
  final bool autoApply;
  final bool isEnabled;
  final String taxType;
  final double taxPercent;
  final String? taxGroupId;
  final TaxGroup? taxGroup;
  final List<TaxBreakdown> taxBreakup;

  const BillingCharge({
    required this.name,
    required this.code,
    required this.amount,
    this.calculationType = 'AMOUNT',
    double? calculationValue,
    required this.taxable,
    required this.autoApply,
    required this.isEnabled,
    required this.taxType,
    required this.taxPercent,
    this.taxGroupId,
    this.taxGroup,
    this.taxBreakup = const [],
  }) : calculationValue = calculationValue ?? amount;

  factory BillingCharge.fromJson(Map<String, dynamic> json) {
    TaxGroup? parsedTaxGroup;
    if (json['tax_group'] != null && json['tax_group'] is Map) {
      parsedTaxGroup = TaxGroup.fromJson(Map<String, dynamic>.from(json['tax_group']));
    }

    final rawBreakup = json['tax_breakup'] as List?;
    final parsedBreakup = rawBreakup != null
        ? rawBreakup.map((e) => TaxBreakdown.fromJson(Map<String, dynamic>.from(e))).toList()
        : const <TaxBreakdown>[];

    return BillingCharge(
      name: json['name'] ?? '',
      code: json['code'] ?? (json['name'] ?? '').toString().toUpperCase().replaceAll(' ', '_'),
      amount: double.tryParse(json['amount'].toString()) ?? 0,
      calculationType: (json['calculation_type'] ?? json['calculationType'] ?? 'AMOUNT')
          .toString()
          .toUpperCase(),
      calculationValue: double.tryParse(
            (json['calculation_value'] ?? json['calculationValue'] ?? json['amount']).toString(),
          ) ??
          0,
      taxable: json['taxable'] ?? false,
      autoApply: json['auto_apply'] ?? json['autoApply'] ?? false,
      isEnabled: json['is_enabled'] ?? json['isEnabled'] ?? true,
      taxType: json['tax_type'] ?? json['taxType'] ?? 'GST',
      taxPercent: double.tryParse(
            (json['tax_percent'] ?? json['taxPercent']).toString(),
          ) ??
          0,
      taxGroupId: json['tax_group_id']?.toString() ?? json['taxGroupId']?.toString(),
      taxGroup: parsedTaxGroup,
      taxBreakup: parsedBreakup,
    );
  }

  BillingCharge copyWith({
    String? name,
    String? code,
    double? amount,
    String? calculationType,
    double? calculationValue,
    bool? taxable,
    bool? autoApply,
    bool? isEnabled,
    String? taxType,
    double? taxPercent,
    String? taxGroupId,
    TaxGroup? taxGroup,
    List<TaxBreakdown>? taxBreakup,
  }) {
    return BillingCharge(
      name: name ?? this.name,
      code: code ?? this.code,
      amount: amount ?? this.amount,
      calculationType: calculationType ?? this.calculationType,
      calculationValue: calculationValue ?? this.calculationValue,
      taxable: taxable ?? this.taxable,
      autoApply: autoApply ?? this.autoApply,
      isEnabled: isEnabled ?? this.isEnabled,
      taxType: taxType ?? this.taxType,
      taxPercent: taxPercent ?? this.taxPercent,
      taxGroupId: taxGroupId ?? this.taxGroupId,
      taxGroup: taxGroup ?? this.taxGroup,
      taxBreakup: taxBreakup ?? this.taxBreakup,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'code': code,
      'amount': amount,
      'calculation_type': calculationType,
      'calculation_value': calculationValue,
      'taxable': taxable,
      'auto_apply': autoApply,
      'is_enabled': isEnabled,
      'tax_type': taxType,
      'tax_percent': taxPercent,
      if (taxGroupId != null) 'tax_group_id': taxGroupId,
      if (taxGroup != null) 'tax_group': taxGroup!.toJson(),
      if (taxBreakup.isNotEmpty) 'tax_breakup': taxBreakup.map((t) => t.toJson()).toList(),
    };
  }

  double effectiveAmount(double baseAmount) {
    if (calculationType == 'PERCENT') {
      return (baseAmount * calculationValue) / 100;
    }
    return amount;
  }
}
