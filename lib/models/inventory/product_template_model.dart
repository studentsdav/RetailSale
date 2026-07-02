import 'item_model.dart';

class ProductTemplate {
  final int id;
  final String name;
  final String itemGroup;
  final String subCategory;
  final String brand;
  final String hsnSacCode;
  final String taxType;
  final double taxPercent;
  final bool discountApplicable;
  final bool schemeApplicable;
  final bool isActive;
  final List<Item> variants;

  ProductTemplate({
    required this.id,
    required this.name,
    required this.itemGroup,
    required this.subCategory,
    this.brand = '',
    this.hsnSacCode = '',
    this.taxType = 'GST',
    this.taxPercent = 0.0,
    this.discountApplicable = true,
    this.schemeApplicable = true,
    this.isActive = true,
    this.variants = const [],
  });

  factory ProductTemplate.fromJson(Map<String, dynamic> json) {
    var rawVariants = json['variants'] as List?;
    List<Item> vars = rawVariants != null
        ? rawVariants.map((e) => Item.fromJson(e)).toList()
        : [];

    return ProductTemplate(
      id: json['id'],
      name: json['name'],
      itemGroup: json['item_group'] ?? '',
      subCategory: json['sub_category'] ?? '',
      brand: json['brand'] ?? '',
      hsnSacCode: json['hsn_sac_code'] ?? '',
      taxType: json['tax_type'] ?? 'GST',
      taxPercent: double.tryParse(json['tax_percent'].toString()) ?? 0.0,
      discountApplicable: json['discount_applicable'] ?? true,
      schemeApplicable: json['scheme_applicable'] ?? true,
      isActive: json['is_active'] ?? true,
      variants: vars,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'item_group': itemGroup,
      'sub_category': subCategory,
      'brand': brand,
      'hsn_sac_code': hsnSacCode,
      'tax_type': taxType,
      'tax_percent': taxPercent,
      'discount_applicable': discountApplicable,
      'scheme_applicable': schemeApplicable,
      'is_active': isActive,
      'variants': variants.map((e) => e.toJson()).toList(),
    };
  }
}
