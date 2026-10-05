import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/auth/token_storage.dart';
import '../../core/config/app_config.dart';
import '../../core/settings/local_preferences.dart';
import '../../models/common/property_info_model.dart';
import '../../models/inventory/marketplace_vendor_model.dart';
import '../../models/inventory/purchase_order_model.dart';
import '../../models/inventory/purchase_item_model.dart';
import '../purchase/purchase_order_controller.dart';
import '../inventory/supplier_controller.dart';
import '../../models/inventory/supplier_model.dart';
import '../settings/property_info_controller.dart';

class MarketplaceController extends ChangeNotifier {
  List<MarketplaceVendor> _vendors = [];
  List<MarketplaceVendor> get vendors => _vendors;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _selectedCity;
  String? get selectedCity => _selectedCity;

  final List<String> availableCities = [
    'New York',
    'Los Angeles',
    'Chicago',
    'Houston',
    'Miami',
    'Dallas',
    'Austin',
    'Seattle',
    'San Francisco',
    'Boston',
  ];

  void setCity(String city) {
    _selectedCity = city;
    notifyListeners();
  }

  /// Load real vendors & suppliers from database / API
  Future<void> fetchVendors({String? city, String? category, String? search}) async {
    _isLoading = true;
    notifyListeners();

    final targetCity = city ?? _selectedCity ?? 'New York';
    _selectedCity = targetCity;

    final List<MarketplaceVendor> publicVendors = [];

    // 1. Check if current outlet / business has enabled Public Marketplace Vendor presence
    try {
      final vendorConfig = await LocalPreferences.getMarketplaceVendorConfig();
      final isVendorEnabled = vendorConfig['is_vendor_enabled'] == true;

      if (isVendorEnabled) {
        final propCtrl = PropertyInfoController();
        await propCtrl.load();
        final p = propCtrl.data;

        if (p != null) {
          final outletCity = p.city.trim().isNotEmpty ? p.city.trim() : targetCity;
          final outletCode = AppConfig.outlets.isNotEmpty ? AppConfig.outlets.first : 'OUTLET-01';

          publicVendors.add(
            MarketplaceVendor(
              id: outletCode,
              vendorCode: outletCode,
              businessName: p.propertyName.isNotEmpty ? p.propertyName : p.legalName,
              tradeName: p.legalName.isNotEmpty ? p.legalName : p.propertyName,
              address: p.address.isNotEmpty ? p.address : 'Store Address',
              city: outletCity,
              state: p.state,
              phone: p.mobile,
              email: p.email,
              gstin: p.gstNo,
              isVerified: p.gstNo.trim().isNotEmpty,
              minOrderAmount: double.tryParse(vendorConfig['min_order_value']?.toString() ?? '') ?? 1000.0,
              deliveryEstimate: vendorConfig['delivery_sla'] ?? 'Same Day Dispatch',
              categories: ['Wholesale Supply', 'All Products'],
              isOpen: true,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking local vendor public status: $e');
    }

    // 2. Fetch public marketplace vendors from backend marketplace directory (only when online)
    if (!AppConfig.isLocalServer) {
      try {
        final queryParams = <String, String>{
          'city': targetCity,
        };
        if (category != null && category.isNotEmpty && category != 'All') {
          queryParams['category'] = category;
        }
        if (search != null && search.isNotEmpty) {
          queryParams['search'] = search;
        }

        final queryString = Uri(queryParameters: queryParams).query;
        final token = await TokenStorage.read();
        final url = Uri.parse('${AppConfig.baseUrl}/api/marketplace/vendors?$queryString');
        final response = await http.get(url, headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        }).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200 && response.body.isNotEmpty) {
          final res = jsonDecode(response.body);
          if (res['success'] == true && res['data'] != null && (res['data'] as List).isNotEmpty) {
            final remoteVendors = (res['data'] as List)
                .map((e) => MarketplaceVendor.fromJson(e))
                .toList();

            for (var rv in remoteVendors) {
              if (!publicVendors.any((v) => v.vendorCode == rv.vendorCode || (v.gstin.isNotEmpty && v.gstin == rv.gstin))) {
                publicVendors.add(rv);
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Remote marketplace vendors fetch note: $e');
      }
    }

    // Apply search filter if provided
    if (search != null && search.trim().isNotEmpty) {
      final q = search.trim().toLowerCase();
      _vendors = publicVendors.where((v) =>
          v.businessName.toLowerCase().contains(q) ||
          v.tradeName.toLowerCase().contains(q) ||
          v.gstin.toLowerCase().contains(q) ||
          v.address.toLowerCase().contains(q) ||
          v.phone.contains(q)).toList();
    } else {
      _vendors = publicVendors;
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Fetch catalog for a specific vendor
  Future<List<MarketplaceCatalogItem>> fetchVendorCatalog(
    MarketplaceVendor vendor, {
    bool isB2B = true,
  }) async {
    try {
      final token = await TokenStorage.read();
      final url = Uri.parse('${AppConfig.baseUrl}/api/marketplace/vendors/${vendor.id}/catalog?is_b2b=$isB2B');
      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final res = jsonDecode(response.body);
        if (res['success'] == true && res['data'] != null) {
          return (res['data'] as List)
              .map((e) => MarketplaceCatalogItem.fromJson(e, vendorId: vendor.id))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching vendor catalog: $e');
    }
    return [];
  }

  /// Places a B2B Order and AUTO-GENERATES a Purchase Order (PO) in Buyer POS
  Future<Map<String, dynamic>> placeB2BOrder({
    required MarketplaceVendor vendor,
    required List<MarketplaceCartItem> cartItems,
    required PropertyInfo buyerPropertyInfo,
    String remarks = '',
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Resolve or ensure Supplier exists locally for this vendor
      int supplierId = 1;
      try {
        final supplierCtrl = SupplierController();
        await supplierCtrl.load();
        final matched = supplierCtrl.list.where((s) =>
            s.supplierName.toLowerCase() == vendor.businessName.toLowerCase() ||
            s.supplierCode.toLowerCase() == vendor.vendorCode.toLowerCase() ||
            ((s.gstin ?? '').isNotEmpty && (s.gstin ?? '').toLowerCase() == vendor.gstin.toLowerCase())).firstOrNull;
        if (matched != null) {
          supplierId = matched.id;
        } else {
          try {
            final newSupplier = Supplier(
              id: 0,
              supplierCode: vendor.vendorCode.isNotEmpty ? vendor.vendorCode : 'MKT-VEN-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
              supplierName: vendor.businessName,
              address: vendor.address.isNotEmpty ? vendor.address : 'Marketplace Supplier',
              phone: vendor.phone,
              gstin: vendor.gstin.isNotEmpty ? vendor.gstin : null,
              isActive: true,
            );
            await supplierCtrl.create(newSupplier);
            await supplierCtrl.load();
            final created = supplierCtrl.list.where((s) =>
                s.supplierName.toLowerCase() == vendor.businessName.toLowerCase() ||
                s.supplierCode.toLowerCase() == vendor.vendorCode.toLowerCase()).firstOrNull;
            if (created != null) {
              supplierId = created.id;
            } else if (supplierCtrl.list.isNotEmpty) {
              supplierId = supplierCtrl.list.last.id;
            }
          } catch (e) {
            if (supplierCtrl.list.isNotEmpty) {
              supplierId = supplierCtrl.list.first.id;
            }
          }
        }
      } catch (_) {}

      // 2. Generate Next PO Number
      final now = DateTime.now();
      final poNumber = 'PO-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch.toString().substring(8)}';

      // 3. Build PurchaseOrder items from cart
      final poItems = cartItems.map((c) {
        return PurchaseItem(
          itemId: c.catalogItem.id,
          itemCode: c.catalogItem.itemCode,
          itemName: c.catalogItem.itemName,
          brand: c.catalogItem.brand,
          unit: c.catalogItem.unit,
          qty: c.quantity.toDouble(),
          rate: c.unitPrice,
          tax: c.catalogItem.taxPercent,
          department: 'GENERAL',
          lineStatus: 'OPEN',
        );
      }).toList();

      final purchaseOrder = PurchaseOrder(
        poNo: poNumber,
        manualNo: 'MKT-B2B-${vendor.vendorCode}',
        supplierId: supplierId,
        poDate: now,
        createdAt: now,
        items: poItems,
      );

      // 4. Create the Purchase Order in local POS backend
      final poCtrl = PurchaseOrderController();
      await poCtrl.create(purchaseOrder);

      // 5. Send order to Marketplace Vendor Backend
      final b2bOrderPayload = {
        'po_no': poNumber,
        'vendor_id': vendor.id,
        'buyer_name': buyerPropertyInfo.propertyName.isNotEmpty ? buyerPropertyInfo.propertyName : buyerPropertyInfo.legalName,
        'buyer_gstin': buyerPropertyInfo.gstNo,
        'buyer_phone': buyerPropertyInfo.mobile,
        'buyer_address': '${buyerPropertyInfo.address}, ${buyerPropertyInfo.city}, ${buyerPropertyInfo.state} - ${buyerPropertyInfo.pinCode}',
        'items': cartItems.map((c) => {
          'item_code': c.catalogItem.itemCode,
          'item_name': c.catalogItem.itemName,
          'qty': c.quantity,
          'b2b_rate': c.unitPrice,
          'tax_percent': c.catalogItem.taxPercent,
          'amount': c.grandTotal,
        }).toList(),
        'subtotal': cartItems.fold<double>(0, (sum, item) => sum + item.lineTotal),
        'total_tax': cartItems.fold<double>(0, (sum, item) => sum + item.taxAmount),
        'net_amount': cartItems.fold<double>(0, (sum, item) => sum + item.grandTotal),
        'remarks': remarks,
      };

      try {
        final token = await TokenStorage.read();
        final url = Uri.parse('${AppConfig.baseUrl}/api/marketplace/orders/b2b');
        await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: jsonEncode(b2bOrderPayload),
        ).timeout(const Duration(seconds: 4));
      } catch (e) {
        debugPrint('Marketplace vendor order dispatch logged: $e');
      }

      return {
        'success': true,
        'po_no': poNumber,
        'message': 'B2B Order successfully placed! Purchase Order $poNumber has been generated in your inventory. You can receive it in Goods Receiving.',
      };
    } catch (e) {
      debugPrint('Error placing B2B order: $e');
      return {
        'success': false,
        'message': 'Failed to place B2B order: $e',
      };
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
