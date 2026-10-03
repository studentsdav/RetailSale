import 'dart:convert';
import 'tax_breakdown_model.dart';
import 'tax_group_model.dart';

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
  final String? taxGroupId;
  final TaxGroup? taxGroup;
  final bool discountApplicable;
  final bool schemeApplicable;
  final bool isSchemeFree;
  final bool isAdvanceFree;
  final int? appliedSchemeId;
  final int? appliedHappyHourId;
  final double lineDiscount;
  final double taxableAmount;
  final double taxAmount;
  final double lineTotal;
  final List<TaxBreakdown> taxBreakup;
  final String? brand;
  final bool isTaxInclusive;
  final double? originalRate;
  final double? schemeDiscountPerUnit;
  final double mrp;
  final String? location;
  final String? notes;
  final List<dynamic>? modifierDetails;
  final List<dynamic>? modifierObjects;
  final String? itemRemark;

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
    this.taxGroupId,
    this.taxGroup,
    this.discountApplicable = true,
    this.schemeApplicable = true,
    this.isSchemeFree = false,
    this.isAdvanceFree = false,
    this.appliedSchemeId,
    this.appliedHappyHourId,
    this.lineDiscount = 0,
    double? taxableAmount,
    this.taxAmount = 0,
    double? lineTotal,
    this.taxBreakup = const [],
    this.brand,
    this.isTaxInclusive = false,
    this.originalRate,
    this.schemeDiscountPerUnit,
    this.mrp = 0.0,
    this.location,
    this.notes,
    this.modifierDetails,
    this.modifierObjects,
    this.itemRemark,
  })  : originalQty = originalQty ?? qty,
        referenceRate = referenceRate ?? rate,
        taxableAmount = taxableAmount ??
            (isTaxInclusive && taxPercent > 0
                ? (((qty * rate) - lineDiscount) / (1 + taxPercent / 100))
                : ((qty * rate) - lineDiscount)),
        lineTotal = lineTotal ??
            (isTaxInclusive
                ? ((qty * rate) - lineDiscount)
                : ((taxableAmount ?? ((qty * rate) - lineDiscount)) + taxAmount));

  double get amount => qty * rate;
  double get netAmount {
    if (isSchemeFree || isAdvanceFree) {
      final baseRate = referenceRate > 0 ? referenceRate : (rate > 0 ? rate : (originalRate ?? 0.0));
      final val = baseRate * qty;
      if (val > 0) return val;
    }
    return lineTotal;
  }

  SaleItem copyWith({
    double? qty,
    double? originalQty,
    double? rate,
    double? referenceRate,
    String? hsnSacCode,
    String? taxType,
    double? taxPercent,
    String? taxGroupId,
    TaxGroup? taxGroup,
    bool? discountApplicable,
    bool? schemeApplicable,
    bool? isSchemeFree,
    bool? isAdvanceFree,
    int? appliedSchemeId,
    int? appliedHappyHourId,
    double? lineDiscount,
    double? taxableAmount,
    double? taxAmount,
    double? lineTotal,
    List<TaxBreakdown>? taxBreakup,
    String? brand,
    bool? isTaxInclusive,
    double? originalRate,
    double? schemeDiscountPerUnit,
    double? mrp,
    String? location,
    String? notes,
    List<dynamic>? modifierDetails,
    List<dynamic>? modifierObjects,
    String? itemRemark,
  }) {
    final resolvedRate = rate ?? this.rate;
    final resolvedQty = qty ?? this.qty;
    final bool rateOrQtyChanged = (rate != null && rate != this.rate) || (qty != null && qty != this.qty);

    return SaleItem(
      itemId: itemId,
      itemCode: itemCode,
      itemName: itemName,
      hsnSacCode: hsnSacCode ?? this.hsnSacCode,
      barcode: barcode,
      unit: unit,
      qty: resolvedQty,
      originalQty: originalQty ?? this.originalQty,
      rate: resolvedRate,
      referenceRate: referenceRate ?? this.referenceRate,
      taxType: taxType ?? this.taxType,
      taxPercent: taxPercent ?? this.taxPercent,
      taxGroupId: taxGroupId ?? this.taxGroupId,
      taxGroup: taxGroup ?? this.taxGroup,
      discountApplicable: discountApplicable ?? this.discountApplicable,
      schemeApplicable: schemeApplicable ?? this.schemeApplicable,
      isSchemeFree: isSchemeFree ?? this.isSchemeFree,
      isAdvanceFree: isAdvanceFree ?? this.isAdvanceFree,
      appliedSchemeId: appliedSchemeId ?? this.appliedSchemeId,
      appliedHappyHourId: appliedHappyHourId ?? this.appliedHappyHourId,
      lineDiscount: lineDiscount ?? this.lineDiscount,
      taxableAmount: taxableAmount ?? (rateOrQtyChanged ? null : this.taxableAmount),
      taxAmount: taxAmount ?? (rateOrQtyChanged ? 0 : this.taxAmount),
      lineTotal: lineTotal ?? (rateOrQtyChanged ? null : this.lineTotal),
      taxBreakup: taxBreakup ?? (rateOrQtyChanged ? const [] : this.taxBreakup),
      brand: brand ?? this.brand,
      isTaxInclusive: isTaxInclusive ?? this.isTaxInclusive,
      originalRate: originalRate ?? this.originalRate,
      schemeDiscountPerUnit: schemeDiscountPerUnit ?? this.schemeDiscountPerUnit,
      mrp: mrp ?? this.mrp,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      modifierDetails: modifierDetails ?? this.modifierDetails,
      modifierObjects: modifierObjects ?? this.modifierObjects,
      itemRemark: itemRemark ?? this.itemRemark,
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
      'tax_group_id': taxGroupId,
      'tax_group': taxGroup?.toJson(),
      'discount_applicable': discountApplicable,
      'scheme_applicable': schemeApplicable,
      'is_scheme_free': isSchemeFree,
      'is_advance_free': isAdvanceFree,
      'applied_scheme_id': appliedSchemeId,
      'applied_happy_hour_id': appliedHappyHourId,
      'line_discount': lineDiscount,
      'taxable_amount': taxableAmount,
      'tax_amount': taxAmount,
      'line_total': lineTotal,
      'tax_breakup': taxBreakup.map((entry) => entry.toJson()).toList(),
      'amount': amount,
      'net_amount': netAmount,
      'brand': brand,
      'is_tax_inclusive': isTaxInclusive,
      'original_rate': originalRate,
      'scheme_discount_per_unit': schemeDiscountPerUnit,
      'mrp': mrp,
      'location': location,
      'notes': notes,
      'modifier_details': modifierDetails,
      'modifier_objects': modifierObjects,
      'item_remark': itemRemark,
    };
  }

  factory SaleItem.fromJson(Map<String, dynamic> json) {
    double parseNum(dynamic value) =>
        double.tryParse(value?.toString() ?? '') ?? 0;

    TaxGroup? parsedTaxGroup;
    if (json['tax_group'] != null && json['tax_group'] is Map) {
      parsedTaxGroup = TaxGroup.fromJson(Map<String, dynamic>.from(json['tax_group']));
    } else if (json['item'] is Map && json['item']['tax_group'] != null && json['item']['tax_group'] is Map) {
      parsedTaxGroup = TaxGroup.fromJson(Map<String, dynamic>.from(json['item']['tax_group']));
    }

    return SaleItem(
      itemId: json['item_id'] ?? 0,
      itemCode: json['item_code'] ?? '',
      itemName: json['item_name'] ?? '',
      hsnSacCode: json['hsn_sac_code'] ?? json['hsn_code'] ?? json['hsn'] ?? '',
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
      taxGroupId: json['tax_group_id']?.toString() ??
          (json['item'] is Map ? json['item']['tax_group_id']?.toString() : null),
      taxGroup: parsedTaxGroup,
      discountApplicable: json['discount_applicable'] ?? true,
      schemeApplicable: json['scheme_applicable'] ?? true,
      isSchemeFree: json['is_scheme_free'] ?? false,
      isAdvanceFree: json['is_advance_free'] ?? false,
      appliedSchemeId: json['applied_scheme_id'],
      appliedHappyHourId: json['applied_happy_hour_id'],
      lineDiscount: parseNum(json['line_discount']),
      taxableAmount: json['taxable_amount'] != null ? parseNum(json['taxable_amount']) : null,
      taxAmount: parseNum(json['tax_amount']),
      lineTotal: json['line_total'] != null ? parseNum(json['line_total']) : null,
      taxBreakup: (json['tax_breakup'] as List? ?? const [])
          .map((entry) =>
              TaxBreakdown.fromJson(Map<String, dynamic>.from(entry)))
          .toList(),
      isTaxInclusive: json['is_tax_inclusive'] == true ||
          json['is_tax_inclusive'] == 1 ||
          json['is_tax_inclusive'] == '1' ||
          json['is_tax_inclusive'] == 'true' ||
          json['tax_type']?.toString().toUpperCase() == 'GST_INCLUSIVE' ||
          json['tax_type']?.toString().toUpperCase() == 'INCLUSIVE' ||
          (json['item'] is Map &&
              (json['item']['is_tax_inclusive'] == true ||
                  json['item']['is_tax_inclusive'] == 1 ||
                  json['item']['is_tax_inclusive'] == '1' ||
                  json['item']['is_tax_inclusive'] == 'true' ||
                  json['item']['tax_type']?.toString().toUpperCase() == 'GST_INCLUSIVE' ||
                  json['item']['tax_type']?.toString().toUpperCase() == 'INCLUSIVE')),
      originalRate: json['original_rate'] != null ? parseNum(json['original_rate']) : null,
      schemeDiscountPerUnit: json['scheme_discount_per_unit'] != null ? parseNum(json['scheme_discount_per_unit']) : null,
      mrp: json['mrp'] != null ? parseNum(json['mrp']) : (json['item'] is Map ? parseNum(json['item']['mrp']) : 0.0),
      location: json['location']?.toString() ?? (json['item'] is Map ? json['item']['location']?.toString() : null),
      notes: json['notes']?.toString() ?? json['remarks']?.toString() ?? json['item_notes']?.toString(),
      modifierDetails: (() {
        final raw = json['modifier_details'] ?? json['modifierDetails'] ?? json['modifiers'];
        if (raw is List) {
          return raw.map((e) {
            if (e is Map) {
              final name = (e['name'] ?? e['modifier_name'] ?? e['item_name'] ?? '').toString().trim();
              final qty = e['qty'] ?? e['quantity'] ?? 1;
              final price = double.tryParse(e['price']?.toString() ?? e['extra_price']?.toString() ?? '0') ?? 0.0;
              if (price > 0) return ' x @';
              return name;
            }
            return e.toString().trim();
          }).where((e) => e.isNotEmpty).toList();
        }
        if (raw is String && raw.trim().isNotEmpty) {
          final s = raw.trim();
          if (s.startsWith('[')) {
            try {
              final decoded = jsonDecode(s);
              if (decoded is List) {
                return decoded.map((e) {
                  if (e is Map) {
                    final name = (e['name'] ?? e['modifier_name'] ?? e['item_name'] ?? '').toString().trim();
                    final qty = e['qty'] ?? e['quantity'] ?? 1;
                    final price = double.tryParse(e['price']?.toString() ?? e['extra_price']?.toString() ?? '0') ?? 0.0;
                    if (price > 0) return ' x @';
                    return name;
                  }
                  return e.toString().trim();
                }).where((e) => e.isNotEmpty).toList();
              }
            } catch (_) {}
          }
          return [s];
        }
        return null;
      })(),
      modifierObjects: (() {
        final raw = json['modifier_objects'] ?? json['modifierObjects'] ?? json['raw_modifiers'];
        if (raw is List) return raw;
        if (raw is String && raw.trim().startsWith('[')) {
          try {
            final decoded = jsonDecode(raw);
            if (decoded is List) return decoded;
          } catch (_) {}
        }
        return null;
      })(),
      itemRemark: json['item_remark']?.toString() ?? json['itemRemark']?.toString(),
    );
  }
}
