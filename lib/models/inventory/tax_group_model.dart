class TaxGroupComponent {
  final String id;
  final String taxGroupId;
  final String componentCode;
  final String componentName;
  final double rate;
  final int calculationOrder;
  final String calculationType; // 'FLAT_PERCENT', 'COMPOUND_ON_SUBTOTAL', 'PERCENT_OF_TAX'
  final String? glAccountCode;

  const TaxGroupComponent({
    required this.id,
    required this.taxGroupId,
    required this.componentCode,
    required this.componentName,
    required this.rate,
    this.calculationOrder = 1,
    this.calculationType = 'FLAT_PERCENT',
    this.glAccountCode,
  });

  factory TaxGroupComponent.fromJson(Map<String, dynamic> json) {
    return TaxGroupComponent(
      id: (json['id'] ?? '').toString(),
      taxGroupId: (json['tax_group_id'] ?? json['taxGroupId'] ?? '').toString(),
      componentCode: (json['component_code'] ?? json['componentCode'] ?? 'TAX').toString(),
      componentName: (json['component_name'] ?? json['componentName'] ?? 'Tax').toString(),
      rate: double.tryParse((json['rate'] ?? 0).toString()) ?? 0.0,
      calculationOrder: int.tryParse((json['calculation_order'] ?? 1).toString()) ?? 1,
      calculationType: (json['calculation_type'] ?? 'FLAT_PERCENT').toString(),
      glAccountCode: json['gl_account_code']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tax_group_id': taxGroupId,
      'component_code': componentCode,
      'component_name': componentName,
      'rate': rate,
      'calculation_order': calculationOrder,
      'calculation_type': calculationType,
      'gl_account_code': glAccountCode,
    };
  }
}

class TaxGroup {
  final String id;
  final int outletId;
  final String groupName;
  final String? groupCode;
  final double totalRate;
  final bool isTaxInclusive;
  final bool isActive;
  final List<TaxGroupComponent> components;

  const TaxGroup({
    required this.id,
    required this.outletId,
    required this.groupName,
    this.groupCode,
    required this.totalRate,
    this.isTaxInclusive = false,
    this.isActive = true,
    this.components = const [],
  });

  factory TaxGroup.fromJson(Map<String, dynamic> json) {
    final rawComps = json['components'] as List?;
    final parsedComps = rawComps != null
        ? rawComps.map((e) => TaxGroupComponent.fromJson(Map<String, dynamic>.from(e))).toList()
        : <TaxGroupComponent>[];

    return TaxGroup(
      id: (json['id'] ?? '').toString(),
      outletId: int.tryParse((json['outlet_id'] ?? 0).toString()) ?? 0,
      groupName: (json['group_name'] ?? json['groupName'] ?? '').toString(),
      groupCode: json['group_code']?.toString(),
      totalRate: double.tryParse((json['total_rate'] ?? json['totalRate'] ?? 0).toString()) ?? 0.0,
      isTaxInclusive: json['is_tax_inclusive'] == true || json['is_tax_inclusive'] == 1,
      isActive: json['is_active'] ?? true,
      components: parsedComps,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'outlet_id': outletId,
      'group_name': groupName,
      'group_code': groupCode,
      'total_rate': totalRate,
      'is_tax_inclusive': isTaxInclusive,
      'is_active': isActive,
      'components': components.map((e) => e.toJson()).toList(),
    };
  }
}
