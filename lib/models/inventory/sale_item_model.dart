import 'tax_breakdown_model.dart';

class SaleItem {
  final int itemId;
  final String itemCode;
  final String itemName;
  final String hsnSacCode;
  final String barcode;
  final String unit;
  final double qty;
  final double originalQty;
  final double rate;
  final double referenceRate;
  final String taxType;
  final double taxPercent;
  final bool discountApplicable;
  final bool schemeApplicable;
  final bool isSchemeFree;
  final bool isAdvanceFree;
  final int? appliedSchemeId;
  final double lineDiscount;
  final double taxableAmount;
  final double taxAmount;
  final double lineTotal;
  final List<TaxBreakdown> taxBreakup;

  SaleItem({
    required this.itemId,
    required this.itemCode,
    required this.itemName,
    this.hsnSacCode = '',
    required this.barcode,
    required this.unit,
    required this.qty,
    double? originalQty,
    required this.rate,
    double? referenceRate,
    this.taxType = 'GST',
    this.taxPercent = 0,
    this.discountApplicable = true,
    this.schemeApplicable = true,
    this.isSchemeFree = false,
    this.isAdvanceFree = false,
    this.appliedSchemeId,
    this.lineDiscount = 0,
    double? taxableAmount,
    this.taxAmount = 0,
    double? lineTotal,
    this.taxBreakup = const [],
  })  : originalQty = originalQty ?? qty,
        referenceRate = referenceRate ?? rate,
        taxableAmount = taxableAmount ?? ((qty * rate) - lineDiscount),
        lineTotal = lineTotal ??
            ((taxableAmount ?? ((qty * rate) - lineDiscount)) + taxAmount);

  double get amount => qty * rate;
  double get netAmount => lineTotal;

  SaleItem copyWith({
    double? qty,
    double? originalQty,
    double? rate,
    double? referenceRate,
    String? hsnSacCode,
    String? taxType,
    double? taxPercent,
    bool? discountApplicable,
    bool? schemeApplicable,
    bool? isSchemeFree,
    bool? isAdvanceFree,
    int? appliedSchemeId,
    double? lineDiscount,
    double? taxableAmount,
    double? taxAmount,
    double? lineTotal,
    List<TaxBreakdown>? taxBreakup,
  }) {
    return SaleItem(
      itemId: itemId,
      itemCode: itemCode,
      itemName: itemName,
      hsnSacCode: hsnSacCode ?? this.hsnSacCode,
      barcode: barcode,
      unit: unit,
      qty: qty ?? this.qty,
      originalQty: originalQty ?? this.originalQty,
      rate: rate ?? this.rate,
      referenceRate: referenceRate ?? this.referenceRate,
      taxType: taxType ?? this.taxType,
      taxPercent: taxPercent ?? this.taxPercent,
      discountApplicable: discountApplicable ?? this.discountApplicable,
      schemeApplicable: schemeApplicable ?? this.schemeApplicable,
      isSchemeFree: isSchemeFree ?? this.isSchemeFree,
      isAdvanceFree: isAdvanceFree ?? this.isAdvanceFree,
      appliedSchemeId: appliedSchemeId ?? this.appliedSchemeId,
      lineDiscount: lineDiscount ?? this.lineDiscount,
      taxableAmount: taxableAmount ?? this.taxableAmount,
      taxAmount: taxAmount ?? this.taxAmount,
      lineTotal: lineTotal ?? this.lineTotal,
      taxBreakup: taxBreakup ?? this.taxBreakup,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'item_id': itemId,
      'item_code': itemCode,
      'item_name': itemName,
      'hsn_sac_code': hsnSacCode,
      'barcode': barcode,
      'unit': unit,
      'qty': qty,
      'original_qty': originalQty,
      'rate': rate,
      'reference_rate': referenceRate,
      'tax_type': taxType,
      'tax_percent': taxPercent,
      'discount_applicable': discountApplicable,
      'scheme_applicable': schemeApplicable,
      'is_scheme_free': isSchemeFree,
      'is_advance_free': isAdvanceFree,
      'applied_scheme_id': appliedSchemeId,
      'line_discount': lineDiscount,
      'taxable_amount': taxableAmount,
      'tax_amount': taxAmount,
      'line_total': lineTotal,
      'tax_breakup': taxBreakup.map((entry) => entry.toJson()).toList(),
      'amount': amount,
      'net_amount': netAmount,
    };
  }

  factory SaleItem.fromJson(Map<String, dynamic> json) {
    double parseNum(dynamic value) =>
        double.tryParse(value?.toString() ?? '') ?? 0;

    return SaleItem(
      itemId: json['item_id'] ?? 0,
      itemCode: json['item_code'] ?? '',
      itemName: json['item_name'] ?? '',
      hsnSacCode: json['hsn_sac_code'] ?? '',
      barcode: json['barcode'] ?? '',
      unit: json['unit'] ?? '',
      qty: parseNum(json['qty']),
      originalQty: parseNum(json['original_qty'] ?? json['qty']),
      rate: parseNum(json['rate']),
      referenceRate: parseNum(
        json['reference_rate'] ??
            json['original_rate'] ??
            json['scheme_free_reference_rate'] ??
            json['_scheme_source_rate'] ??
            json['item_rate'] ??
            (json['item'] is Map
                ? (json['item']['retail_sale_price'] ?? json['item']['rate'])
                : null) ??
            json['rate'],
      ),
      taxType: json['tax_type'] ??
          (json['item'] is Map ? json['item']['tax_type'] : null) ??
          'GST',
      taxPercent: parseNum(
        json['tax_percent'] ??
            (json['item'] is Map ? json['item']['tax_percent'] : null),
      ),
      discountApplicable: json['discount_applicable'] ?? true,
      schemeApplicable: json['scheme_applicable'] ?? true,
      isSchemeFree: json['is_scheme_free'] ?? false,
      isAdvanceFree: json['is_advance_free'] ?? false,
      appliedSchemeId: json['applied_scheme_id'],
      lineDiscount: parseNum(json['line_discount']),
      taxableAmount: parseNum(json['taxable_amount']),
      taxAmount: parseNum(json['tax_amount']),
      lineTotal: parseNum(json['line_total']),
      taxBreakup: (json['tax_breakup'] as List? ?? const [])
          .map((entry) =>
              TaxBreakdown.fromJson(Map<String, dynamic>.from(entry)))
          .toList(),
    );
  }
}
