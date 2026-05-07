class TaxBreakdown {
  final String code;
  final String label;
  final String taxType;
  final double rate;
  final double taxableAmount;
  final double taxAmount;

  const TaxBreakdown({
    required this.code,
    required this.label,
    required this.taxType,
    required this.rate,
    required this.taxableAmount,
    required this.taxAmount,
  });

  factory TaxBreakdown.fromJson(Map<String, dynamic> json) {
    return TaxBreakdown(
      code: json['code'] ?? '',
      label: json['label'] ?? '',
      taxType: json['tax_type'] ?? json['taxType'] ?? 'GST',
      rate: double.tryParse(json['rate'].toString()) ?? 0,
      taxableAmount:
          double.tryParse((json['taxable_amount'] ?? json['taxableAmount']).toString()) ?? 0,
      taxAmount:
          double.tryParse((json['tax_amount'] ?? json['taxAmount']).toString()) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'label': label,
      'tax_type': taxType,
      'rate': rate,
      'taxable_amount': taxableAmount,
      'tax_amount': taxAmount,
    };
  }
}
