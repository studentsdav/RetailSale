import 'attribute_model.dart';
import 'tax_group_model.dart';

class Item {
  final int id;
  final String itemCode;
  final String itemName;
  final String hsnSacCode;
  final String itemGroup;
  final String subCategory;
  final String brand;
  final String unit;
  final String barcode;
  final String imagePath;
  final String location;
  final double rate;
  final double retailSalePrice;
  final String taxType;
  final double taxPercent;
  final String? taxGroupId;
  final TaxGroup? taxGroup;
  final bool discountApplicable;
  final bool schemeApplicable;
  final double openingBalance;
  final double packQty;
  final String looseItemCode;
  final int minLevel;
  final int maxLevel;
  final bool stockable;
  final bool isSaleable;
  final bool isModifier;
  final String foodType; // 'VEG', 'NON_VEG', 'EGG', 'VEGAN', 'OTHER'
  final String? applicableItemIds;
  final int? deductRawItemId;
  final double deductQty;
  final bool isTaxInclusive;
  final bool isHappyHour;
  final double mrp;
  final int? productTemplateId;
  final List<AttributeValue> attributeValues;
  final bool isListedOnMarketplace;
  final bool isB2BEnabled;
  final bool isB2CEnabled;
  final double b2bPrice;
  final double b2cPrice;
  final int minOrderQtyB2B;

  bool get isVeg => foodType == 'VEG' || foodType == 'VEGAN';
  bool get isNonVeg => foodType == 'NON_VEG';
  bool get hasEgg => foodType == 'EGG';

  Item({
    required this.id,
    required this.itemCode,
    required this.itemName,
    this.hsnSacCode = '',
    required this.itemGroup,
    required this.subCategory,
    required this.brand,
    required this.unit,
    required this.barcode,
    this.imagePath = '',
    this.location = '-',
    required this.rate,
    required this.retailSalePrice,
    required this.taxType,
    required this.taxPercent,
    this.taxGroupId,
    this.taxGroup,
    required this.discountApplicable,
    required this.schemeApplicable,
    required this.openingBalance,
    required this.packQty,
    required this.looseItemCode,
    required this.minLevel,
    required this.maxLevel,
    required this.stockable,
    required this.isSaleable,
    this.isModifier = false,
    this.foodType = 'VEG',
    this.applicableItemIds,
    this.deductRawItemId,
    this.deductQty = 0.0,
    this.isTaxInclusive = false,
    this.isHappyHour = false,
    this.mrp = 0.0,
    this.productTemplateId,
    this.attributeValues = const [],
    this.isListedOnMarketplace = false,
    this.isB2BEnabled = false,
    this.isB2CEnabled = true,
    this.b2bPrice = 0.0,
    this.b2cPrice = 0.0,
    this.minOrderQtyB2B = 1,
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    var rawValues = json['attribute_values'] as List?;
    List<AttributeValue> vals = rawValues != null
        ? rawValues.map((e) => AttributeValue.fromJson(e)).toList()
        : [];

    return Item(
      id: json['id'],
      itemCode: json['item_code'] ?? '',
      itemName: json['item_name'] ?? '',
      hsnSacCode: json['hsn_sac_code'] ?? json['hsn_code'] ?? json['hsn'] ?? '',
      itemGroup: json['item_group'] ?? '',
      subCategory: json['sub_category'] ?? '',
      brand: json['brand'] ?? '',
      unit: json['unit'] ?? '',
      barcode: json['barcode'] ?? '',
      imagePath: json['image_path'] ?? '',
      location: (json['location'] ?? json['kitchen_location'] ?? '-').toString().isEmpty
          ? '-'
          : (json['location'] ?? json['kitchen_location'] ?? '-').toString(),
      rate: double.tryParse(json['rate'].toString()) ?? 0.0,
      retailSalePrice:
          double.tryParse(json['retail_sale_price'].toString()) ?? 0.0,
      taxType: json['tax_type'] ?? 'GST',
      taxPercent: double.tryParse(json['tax_percent'].toString()) ?? 0.0,
      taxGroupId: json['tax_group_id']?.toString(),
      taxGroup: json['tax_group'] != null
          ? TaxGroup.fromJson(Map<String, dynamic>.from(json['tax_group']))
          : null,
      discountApplicable: json['discount_applicable'] ?? true,
      schemeApplicable: json['scheme_applicable'] ?? true,
      openingBalance: double.tryParse(json['opening_balance'].toString()) ?? 0,
      packQty: double.tryParse(json['pack_qty'].toString()) ?? 0,
      looseItemCode: json['loose_item_code'] ?? '',
      minLevel: json['min_level'] ?? 0,
      maxLevel: json['max_level'] ?? 0,
      stockable: json['stockable'] ?? true,
      isSaleable: json['is_saleable'] ?? true,
      isModifier: json['is_modifier'] == true || json['is_modifier'] == 1 || json['is_modifier'].toString() == 'true',
      foodType: (json['food_type'] ?? json['dietary_type'] ?? (json['is_veg'] == false ? 'NON_VEG' : (json['is_veg'] == true ? 'VEG' : 'VEG'))).toString().toUpperCase(),
      applicableItemIds: json['applicable_item_ids']?.toString(),
      deductRawItemId: json['deduct_raw_item_id'] != null ? int.tryParse(json['deduct_raw_item_id'].toString()) : null,
      deductQty: double.tryParse(json['deduct_qty']?.toString() ?? '0') ?? 0.0,
      isTaxInclusive: json['is_tax_inclusive'] == true || json['is_tax_inclusive'] == 1,
      isHappyHour: json['is_happy_hour'] == true || json['is_happy_hour'] == 1,
      mrp: double.tryParse(json['mrp']?.toString() ?? '') ?? 0.0,
      productTemplateId: json['product_template_id'],
      attributeValues: vals,
      isListedOnMarketplace: json['is_listed_on_marketplace'] == true || json['is_listed_on_marketplace'] == 1,
      isB2BEnabled: json['is_b2b_enabled'] == true || json['is_b2b_enabled'] == 1,
      isB2CEnabled: json['is_b2c_enabled'] ?? true,
      b2bPrice: double.tryParse(json['b2b_price']?.toString() ?? json['b2b_rate']?.toString() ?? '') ?? (double.tryParse(json['retail_sale_price']?.toString() ?? '') ?? 0.0),
      b2cPrice: double.tryParse(json['b2c_price']?.toString() ?? json['b2c_rate']?.toString() ?? '') ?? (double.tryParse(json['retail_sale_price']?.toString() ?? '') ?? 0.0),
      minOrderQtyB2B: int.tryParse(json['min_order_qty_b2b']?.toString() ?? '') ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'item_code': itemCode,
      'item_name': itemName,
      'hsn_sac_code': hsnSacCode,
      'item_group': itemGroup,
      'sub_category': subCategory,
      'brand': brand,
      'unit': unit,
      'barcode': barcode,
      'image_path': imagePath,
      'location': location,
      'rate': rate,
      'retail_sale_price': retailSalePrice,
      'tax_type': taxType,
      'tax_percent': taxPercent,
      'tax_group_id': taxGroupId,
      'discount_applicable': discountApplicable,
      'scheme_applicable': schemeApplicable,
      'opening_balance': openingBalance,
      'pack_qty': packQty,
      'loose_item_code': looseItemCode,
      'min_level': minLevel,
      'max_level': maxLevel,
      'stockable': stockable,
      'is_saleable': isSaleable,
      'is_modifier': isModifier,
      'food_type': foodType,
      'dietary_type': foodType,
      'is_veg': isVeg,
      'applicable_item_ids': applicableItemIds,
      'deduct_raw_item_id': deductRawItemId,
      'deduct_qty': deductQty,
      'is_tax_inclusive': isTaxInclusive,
      'is_happy_hour': isHappyHour,
      'mrp': mrp,
      'product_template_id': productTemplateId,
      'attribute_values': attributeValues.map((e) => e.toJson()).toList(),
      'is_listed_on_marketplace': isListedOnMarketplace,
      'is_b2b_enabled': isB2BEnabled,
      'is_b2c_enabled': isB2CEnabled,
      'b2b_price': b2bPrice,
      'b2c_price': b2cPrice,
      'min_order_qty_b2b': minOrderQtyB2B,
    };
  }
}
