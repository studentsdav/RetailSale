class MarketplaceVendor {
  final String id;
  final String vendorCode;
  final String businessName;
  final String tradeName;
  final String logoUrl;
  final String bannerUrl;
  final String address;
  final String city;
  final String state;
  final String pinCode;
  final String phone;
  final String email;
  final String gstin;
  final String fssai;
  final double rating;
  final int totalReviews;
  final bool isVerified;
  final bool isB2BSupplier;
  final bool isB2CRetailer;
  final double minOrderAmount;
  final String deliveryEstimate;
  final List<String> categories;
  final String openingTime;
  final String closingTime;
  final bool isOpen;

  MarketplaceVendor({
    required this.id,
    required this.vendorCode,
    required this.businessName,
    required this.tradeName,
    this.logoUrl = '',
    this.bannerUrl = '',
    required this.address,
    required this.city,
    this.state = '',
    this.pinCode = '',
    required this.phone,
    this.email = '',
    this.gstin = '',
    this.fssai = '',
    this.rating = 4.8,
    this.totalReviews = 120,
    this.isVerified = true,
    this.isB2BSupplier = true,
    this.isB2CRetailer = true,
    this.minOrderAmount = 500.0,
    this.deliveryEstimate = 'Same Day Delivery',
    this.categories = const [],
    this.openingTime = '08:00 AM',
    this.closingTime = '09:00 PM',
    this.isOpen = true,
  });

  factory MarketplaceVendor.fromJson(Map<String, dynamic> json) {
    return MarketplaceVendor(
      id: json['id']?.toString() ?? '',
      vendorCode: json['vendor_code'] ?? json['outlet_code'] ?? json['id']?.toString() ?? '',
      businessName: json['business_name'] ?? json['property_name'] ?? 'Vendor Outlet',
      tradeName: json['trade_name'] ?? json['legal_name'] ?? '',
      logoUrl: json['logo_url'] ?? json['logo_path'] ?? '',
      bannerUrl: json['banner_url'] ?? '',
      address: json['address'] ?? '',
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      pinCode: json['pin_code'] ?? '',
      phone: json['phone'] ?? json['mobile'] ?? '',
      email: json['email'] ?? '',
      gstin: json['gstin'] ?? json['gst_no'] ?? '',
      fssai: json['fssai'] ?? json['fssai_no'] ?? '',
      rating: double.tryParse(json['rating']?.toString() ?? '') ?? 4.8,
      totalReviews: int.tryParse(json['total_reviews']?.toString() ?? '') ?? 42,
      isVerified: json['is_verified'] == true || json['is_verified'] == 1,
      isB2BSupplier: json['is_b2b_supplier'] ?? true,
      isB2CRetailer: json['is_b2c_retailer'] ?? true,
      minOrderAmount: double.tryParse(json['min_order_amount']?.toString() ?? '') ?? 500.0,
      deliveryEstimate: json['delivery_estimate'] ?? '24-48 hrs Delivery',
      categories: (json['categories'] as List?)?.map((e) => e.toString()).toList() ?? ['General', 'Groceries'],
      openingTime: json['opening_time'] ?? '08:00 AM',
      closingTime: json['closing_time'] ?? '09:00 PM',
      isOpen: json['is_open'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'vendor_code': vendorCode,
    'business_name': businessName,
    'trade_name': tradeName,
    'logo_url': logoUrl,
    'banner_url': bannerUrl,
    'address': address,
    'city': city,
    'state': state,
    'pin_code': pinCode,
    'phone': phone,
    'email': email,
    'gstin': gstin,
    'fssai': fssai,
    'rating': rating,
    'total_reviews': totalReviews,
    'is_verified': isVerified,
    'is_b2b_supplier': isB2BSupplier,
    'is_b2c_retailer': isB2CRetailer,
    'min_order_amount': minOrderAmount,
    'delivery_estimate': deliveryEstimate,
    'categories': categories,
    'opening_time': openingTime,
    'closing_time': closingTime,
    'is_open': isOpen,
  };
}

class MarketplaceCatalogItem {
  final int id;
  final String itemCode;
  final String itemName;
  final String brand;
  final String unit;
  final String category;
  final double b2bPrice;
  final double retailPrice;
  final double mrp;
  final int minOrderQtyB2B;
  final double taxPercent;
  final String imagePath;
  final double stockAvailable;
  final String vendorId;

  MarketplaceCatalogItem({
    required this.id,
    required this.itemCode,
    required this.itemName,
    required this.brand,
    required this.unit,
    required this.category,
    required this.b2bPrice,
    required this.retailPrice,
    required this.mrp,
    this.minOrderQtyB2B = 1,
    this.taxPercent = 0.0,
    this.imagePath = '',
    this.stockAvailable = 100.0,
    required this.vendorId,
  });

  factory MarketplaceCatalogItem.fromJson(Map<String, dynamic> json, {String vendorId = ''}) {
    final retail = double.tryParse(json['retail_sale_price']?.toString() ?? json['retail_price']?.toString() ?? '') ?? 0.0;
    final b2b = double.tryParse(json['b2b_price']?.toString() ?? json['b2b_rate']?.toString() ?? json['rate']?.toString() ?? '') ?? (retail > 0 ? (retail * 0.85) : 0.0);
    final mrpVal = double.tryParse(json['mrp']?.toString() ?? '') ?? (retail > 0 ? retail : b2b * 1.2);

    return MarketplaceCatalogItem(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      itemCode: json['item_code'] ?? '',
      itemName: json['item_name'] ?? '',
      brand: json['brand'] ?? '',
      unit: json['unit'] ?? 'PCS',
      category: json['item_group'] ?? json['category'] ?? 'General',
      b2bPrice: b2b > 0 ? b2b : retail,
      retailPrice: retail > 0 ? retail : b2b,
      mrp: mrpVal,
      minOrderQtyB2B: int.tryParse(json['min_order_qty_b2b']?.toString() ?? '') ?? 1,
      taxPercent: double.tryParse(json['tax_percent']?.toString() ?? '') ?? 0.0,
      imagePath: json['image_path'] ?? '',
      stockAvailable: double.tryParse(json['stock_qty']?.toString() ?? json['opening_balance']?.toString() ?? '') ?? 99.0,
      vendorId: vendorId.isNotEmpty ? vendorId : (json['vendor_id']?.toString() ?? ''),
    );
  }
}

class MarketplaceCartItem {
  final MarketplaceCatalogItem catalogItem;
  int quantity;
  final bool isB2B;

  MarketplaceCartItem({
    required this.catalogItem,
    required this.quantity,
    this.isB2B = true,
  });

  double get unitPrice => isB2B ? catalogItem.b2bPrice : catalogItem.retailPrice;
  double get lineTotal => unitPrice * quantity;
  double get taxAmount => lineTotal * (catalogItem.taxPercent / 100);
  double get grandTotal => lineTotal + taxAmount;
}
