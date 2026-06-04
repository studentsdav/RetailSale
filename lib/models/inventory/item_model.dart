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
  final double rate;
  final double retailSalePrice;
  final String taxType;
  final double taxPercent;
  final bool discountApplicable;
  final bool schemeApplicable;
  final double openingBalance;
  final double packQty;
  final String looseItemCode;
  final int minLevel;
  final int maxLevel;
  final bool stockable;

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
    required this.rate,
    required this.retailSalePrice,
    required this.taxType,
    required this.taxPercent,
    required this.discountApplicable,
    required this.schemeApplicable,
    required this.openingBalance,
    required this.packQty,
    required this.looseItemCode,
    required this.minLevel,
    required this.maxLevel,
    required this.stockable,
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      id: json['id'],
      itemCode: json['item_code'],
      itemName: json['item_name'],
      hsnSacCode: json['hsn_sac_code'] ?? json['hsn_code'] ?? json['hsn'] ?? '',
      itemGroup: json['item_group'],
      subCategory: json['sub_category'],
      brand: json['brand'],
      unit: json['unit'],
      barcode: json['barcode'] ?? '',
      imagePath: json['image_path'] ?? '',
      rate: double.tryParse(json['rate'].toString()) ?? 0.0,
      retailSalePrice:
          double.tryParse(json['retail_sale_price'].toString()) ?? 0.0,
      taxType: json['tax_type'] ?? 'GST',
      taxPercent: double.tryParse(json['tax_percent'].toString()) ?? 0.0,
      discountApplicable: json['discount_applicable'] ?? true,
      schemeApplicable: json['scheme_applicable'] ?? true,
      openingBalance: double.tryParse(json['opening_balance'].toString()) ?? 0,
      packQty: double.tryParse(json['pack_qty'].toString()) ?? 0,
      looseItemCode: json['loose_item_code'] ?? '',
      minLevel: json['min_level'] ?? 0,
      maxLevel: json['max_level'] ?? 0,
      stockable: json['stockable'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'item_code': itemCode,
      'item_name': itemName,
      'hsn_sac_code': hsnSacCode,
      'item_group': itemGroup,
      'sub_category': subCategory,
      'brand': brand,
      'unit': unit,
      'barcode': barcode,
      'image_path': imagePath,
      'rate': rate,
      'retail_sale_price': retailSalePrice,
      'tax_type': taxType,
      'tax_percent': taxPercent,
      'discount_applicable': discountApplicable,
      'scheme_applicable': schemeApplicable,
      'opening_balance': openingBalance,
      'pack_qty': packQty,
      'loose_item_code': looseItemCode,
      'min_level': minLevel,
      'max_level': maxLevel,
      'stockable': stockable,
    };
  }
}
