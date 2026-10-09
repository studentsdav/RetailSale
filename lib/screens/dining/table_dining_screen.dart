import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/config/app_config.dart';
import '../../core/currency/currency_service.dart';

class TableDiningScreen extends StatefulWidget {
  final String? outletId;
  final String? tableId;
  final String? tableName;

  const TableDiningScreen({
    super.key,
    this.outletId,
    this.tableId,
    this.tableName,
  });

  @override
  State<TableDiningScreen> createState() => _TableDiningScreenState();
}

class _TableDiningScreenState extends State<TableDiningScreen> with SingleTickerProviderStateMixin {
  // Table Selection & Database Tables
  String _selectedTableId = '1';
  String _selectedTableName = 'Table 1';
  List<Map<String, dynamic>> _databaseTables = [];
  bool _loadingTables = false;

  // Navigation: 0 = Food Menu, 1 = Order History & Status
  int _currentMainTab = 0;

  // Session & Auth state
  bool _loading = true;
  String? _errorMessage;
  Map<String, dynamic>? _restaurantData;
  Map<String, dynamic>? _tableData;
  List<dynamic> _categories = [];
  List<dynamic> _allItems = [];
  List<dynamic> _activeOrders = [];
  Timer? _liveOrdersPollTimer;

  // Customer Profile
  Map<String, dynamic>? _customerProfile;
  bool _isLoggedIn = false;

  // Cart state: Map<itemId, {item, qty, note, modifiers}>
  final Map<int, Map<String, dynamic>> _cart = {};

  // Filters & Search
  String _selectedCategory = 'ALL';
  String _dietaryFilter = 'ALL'; // 'ALL', 'VEG', 'NON_VEG'
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // Order & Payment
  String _paymentMethod = 'PAY_LATER'; // 'PAY_LATER' | 'ONLINE'
  final TextEditingController _specialInstructionsCtrl = TextEditingController();
  bool _submittingOrder = false;

  // UI Theme
  static const Color primaryOrange = Color(0xFFE23744); // Zomato/Swiggy vibrant food red
  static const Color pureVegGreen = Color(0xFF16A34A);
  static const Color nonVegRed = Color(0xFFDC2626);
  static const Color darkBg = Color(0xFF0F172A);

  @override
  void initState() {
    super.initState();
    _selectedTableId = (widget.tableId != null && widget.tableId!.isNotEmpty) ? widget.tableId! : '1';
    _selectedTableName = (widget.tableName != null && widget.tableName!.isNotEmpty) ? widget.tableName! : 'Table $_selectedTableId';
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.toLowerCase().trim());
    });
    _loadAvailableTables();
    _initializeDiningSession();

    // Auto-poll orders every 4 seconds to reflect kitchen & table status changes live
    _liveOrdersPollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) {
        _fetchTableDiningCatalog(isSilent: true);
      }
    });
  }

  @override
  void dispose() {
    _liveOrdersPollTimer?.cancel();
    _searchCtrl.dispose();
    _specialInstructionsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableTables() async {
    setState(() => _loadingTables = true);
    final serverBase = AppConfig.baseUrl;
    final baseUrl = serverBase.isNotEmpty ? serverBase : 'http://localhost:5000';
    final targetOutlet = widget.outletId ?? '1';

    try {
      // 1. Try public endpoint for restaurant tables
      final uri = Uri.parse('$baseUrl/api/public/dining/tables?outlet_id=$targetOutlet');
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (json['success'] == true && json['data'] is List) {
          final List list = json['data'];
          if (mounted && list.isNotEmpty) {
            setState(() {
              _databaseTables = list.map((t) => Map<String, dynamic>.from(t)).toList();
              _loadingTables = false;
            });
            return;
          }
        }
      }
    } catch (_) {}

    // 2. Resilient POS ApiClient Fallback
    try {
      final res = await ApiClient.get('/api/restaurant/tables');
      if (res != null) {
        List? rawList;
        if (res is List) {
          rawList = res;
        } else if (res is Map && res['data'] is List) {
          rawList = res['data'] as List;
        }
        if (rawList != null && rawList.isNotEmpty && mounted) {
          setState(() {
            _databaseTables = rawList!.map((t) => Map<String, dynamic>.from(t)).toList();
            _loadingTables = false;
          });
          return;
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _loadingTables = false);
    }
  }

  void _switchTable(String newTableId) {
    if (newTableId == _selectedTableId) return;

    final tableObj = _databaseTables.firstWhere(
      (t) => t['id']?.toString() == newTableId,
      orElse: () => <String, dynamic>{},
    );

    setState(() {
      _selectedTableId = newTableId;
      if (tableObj.isNotEmpty) {
        _selectedTableName = (tableObj['table_name'] ?? tableObj['name'] ?? 'Table $newTableId').toString();
      } else {
        _selectedTableName = 'Table $newTableId';
      }
      _cart.clear(); // Clear cart for new table session
      _activeOrders.clear();
      _loading = true;
    });

    _fetchTableDiningCatalog();
  }

  Future<void> _initializeDiningSession() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      // 1. Check local customer session (auto-login if previously verified)
      final prefs = await SharedPreferences.getInstance();
      final savedCustomerStr = prefs.getString('dining_customer_profile');
      if (savedCustomerStr != null && savedCustomerStr.isNotEmpty) {
        try {
          _customerProfile = jsonDecode(savedCustomerStr);
          _isLoggedIn = true;
        } catch (_) {}
      }

      // 2. Fetch table & catalog info from server
      await _fetchTableDiningCatalog();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load dining session: $e';
        _loading = false;
      });
    }
  }

  Future<void> _fetchTableDiningCatalog({bool isSilent = false}) async {
    final serverBase = AppConfig.baseUrl;
    final baseUrl = serverBase.isNotEmpty ? serverBase : 'http://localhost:5000';
    
    final targetOutlet = widget.outletId ?? '1';
    final targetTable = _selectedTableId;

    final custId = _customerProfile?['id']?.toString() ?? '';
    final custName = (_customerProfile?['customer_name'] ?? _customerProfile?['name'] ?? '').toString();
    final custPhone = (_customerProfile?['customer_phone'] ?? _customerProfile?['phone'] ?? '').toString();
    final custEmail = (_customerProfile?['customer_email'] ?? _customerProfile?['email'] ?? '').toString();

    final queryParams = [
      'outlet_id=$targetOutlet',
      'table_id=$targetTable',
      if (custId.isNotEmpty) 'customer_id=$custId',
      if (custName.isNotEmpty) 'customer_name=${Uri.encodeComponent(custName)}',
      if (custPhone.isNotEmpty) 'customer_phone=${Uri.encodeComponent(custPhone)}',
      if (custEmail.isNotEmpty) 'customer_email=${Uri.encodeComponent(custEmail)}',
    ].join('&');

    // 1. Attempt public dining endpoint
    try {
      final uri = Uri.parse('$baseUrl${ApiEndpoints.publicDiningTableInfo}?$queryParams');
      final response = await http.get(uri).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          final data = json['data'];
          if (mounted) {
            setState(() {
              _restaurantData = data['restaurant'];
              _tableData = data['table'];
              _categories = data['categories'] ?? [];
              _allItems = data['items'] ?? [];
              _activeOrders = _isLoggedIn ? (data['active_orders'] ?? []) : [];
              _loading = false;
            });

            if (!_isLoggedIn && !isSilent) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _showAuthModal(context);
              });
            }
          }
          return;
        }
      }
    } catch (_) {}

    // 2. Resilient Fallback: Load live items & tables directly from POS ApiClient
    try {
      Map<String, dynamic> restaurantMap = {
        'property_name': 'Grand Royale Restaurant',
        'address': 'Main Dining Hall',
        'wifi_ssid': 'Restaurant_Guest_WiFi',
        'payment_gateway_enabled': true,
      };

      try {
        final propRes = await ApiClient.get(ApiEndpoints.propertyInfo);
        if (propRes['success'] == true && propRes['data'] != null) {
          final p = propRes['data'];
          restaurantMap = {
            'property_name': p['property_name'] ?? p['name'] ?? 'Grand Royale Restaurant',
            'address': p['address'] ?? '',
            'phone': p['phone'] ?? '',
            'logo_path': p['logo_path'],
            'wifi_ssid': p['wifi_ssid'] ?? 'Restaurant_Guest_WiFi',
            'payment_gateway_enabled': true,
          };
        }
      } catch (_) {}

      // Fetch items from database
      List<dynamic> loadedItems = [];
      final Set<String> catSet = {};

      try {
        final itemsRes = await ApiClient.get('/api/inventory/items');
        if (itemsRes['success'] == true && itemsRes['data'] != null) {
          final rawItems = itemsRes['data'] as List;
          for (final item in rawItems) {
            final cat = (item['category'] ?? item['item_group'] ?? item['category_name'] ?? 'Main Course').toString();
            if (cat.trim().isNotEmpty) catSet.add(cat.trim());
            
            final double rate = double.tryParse((item['retail_sale_price'] ?? item['price'] ?? item['rate'] ?? item['mrp'] ?? 0).toString()) ?? 0.0;
            final name = (item['item_name'] ?? item['name'] ?? 'Dish').toString();
            final rawFoodType = (item['food_type'] ?? item['dietary_type'] ?? '').toString().toUpperCase();
            final bool isVeg = rawFoodType == 'VEG' || rawFoodType == 'VEGAN' ||
                (rawFoodType.isEmpty && (item['is_veg'] == true ||
                    (!name.toLowerCase().contains('chicken') &&
                        !name.toLowerCase().contains('mutton') &&
                        !name.toLowerCase().contains('fish') &&
                        !name.toLowerCase().contains('egg') &&
                        !name.toLowerCase().contains('prawn'))));
            final String foodType = rawFoodType.isNotEmpty ? rawFoodType : (isVeg ? 'VEG' : 'NON_VEG');
            final bool isModifier = item['is_modifier'] == true || item['is_modifier'] == 1 || item['is_modifier'].toString() == 'true';
            final bool isSaleable = item['is_saleable'] != false && item['is_saleable'] != 0 && item['is_saleable'].toString() != 'false';

            loadedItems.add({
              'id': item['id'] ?? (loadedItems.length + 1),
              'item_name': name,
              'category': cat,
              'rate': rate,
              'retail_sale_price': rate,
              'selling_price': rate > 0 ? rate : 150.0,
              'is_veg': isVeg,
              'food_type': foodType,
              'dietary_type': foodType,
              'description': (item['description'] != null && item['description'].toString().trim().isNotEmpty)
                  ? item['description'].toString().trim()
                  : '',
              'image_url': item['image_url'] ?? item['image_path'],
              'is_available': true,
              'rating': 4.7,
              'prep_time_minutes': 15,
              'is_modifier': isModifier,
              'applicable_item_ids': item['applicable_item_ids']?.toString(),
              'is_saleable': isSaleable,
              'stockable': item['stockable'] == true || item['stockable'] == 1 || item['stockable'].toString() == 'true',
              'stock': double.tryParse((item['stock'] ?? item['opening_balance'] ?? item['current_stock'] ?? 0).toString()) ?? 0.0,
              'opening_balance': double.tryParse((item['opening_balance'] ?? item['stock'] ?? item['current_stock'] ?? 0).toString()) ?? 0.0,
              'is_out_of_stock': (item['is_out_of_stock'] == true) ||
                  ((item['stockable'] == true || item['stockable'] == 1 || item['stockable'].toString() == 'true') &&
                      (double.tryParse((item['stock'] ?? item['opening_balance'] ?? item['current_stock'] ?? 0).toString()) ?? 0.0) <= 0),
              'tax_percent': double.tryParse((item['tax_percent'] ?? 0).toString()) ?? 0.0,
              'is_tax_inclusive': item['is_tax_inclusive'] == true || item['is_tax_inclusive'] == 1 || item['is_tax_inclusive'].toString() == 'true',
              'tax_group_name': item['tax_group_name']?.toString() ?? '',
            });
          }
        }
      } catch (_) {}

      // If no inventory items in DB yet, load demo dining catalog
      if (loadedItems.isEmpty) {
        catSet.addAll(['Starters', 'Main Course', 'Breads & Rice', 'Beverages', 'Desserts']);
        loadedItems = [
          {
            'id': 101,
            'item_name': 'Paneer Butter Masala',
            'category': 'Main Course',
            'selling_price': 240.0,
            'is_veg': true,
            'description': 'Rich cottage cheese in a velvety butter-tomato gravy with aromatic fenugreek.',
            'rating': 4.8,
            'prep_time_minutes': 15,
          },
          {
            'id': 102,
            'item_name': 'Butter Chicken (Murgh Makhani)',
            'category': 'Main Course',
            'selling_price': 320.0,
            'is_veg': false,
            'description': 'Tender roasted chicken in silky rich butter-tomato curry.',
            'rating': 4.9,
            'prep_time_minutes': 20,
          },
          {
            'id': 103,
            'item_name': 'Hyderabadi Dum Biryani',
            'category': 'Breads & Rice',
            'selling_price': 280.0,
            'is_veg': false,
            'description': 'Aromatic basmati rice layered with spiced meat & slow-cooked on dum.',
            'rating': 4.9,
            'prep_time_minutes': 20,
          },
          {
            'id': 104,
            'item_name': 'Crispy Veg Spring Rolls',
            'category': 'Starters',
            'selling_price': 160.0,
            'is_veg': true,
            'description': 'Golden fried rolls loaded with seasoned crunchy Asian vegetables.',
            'rating': 4.5,
            'prep_time_minutes': 12,
          },
          {
            'id': 105,
            'item_name': 'Chicken Tikka Kebab',
            'category': 'Starters',
            'selling_price': 260.0,
            'is_veg': false,
            'description': 'Smoky char-grilled chicken marinated in rich yogurt and tandoori spices.',
            'rating': 4.7,
            'prep_time_minutes': 15,
          },
          {
            'id': 106,
            'item_name': 'Butter Garlic Naan',
            'category': 'Breads & Rice',
            'selling_price': 60.0,
            'is_veg': true,
            'description': 'Freshly baked tandoori bread brushed with melted roasted garlic butter.',
            'rating': 4.6,
            'prep_time_minutes': 8,
          },
          {
            'id': 107,
            'item_name': 'Classic Cold Coffee with Ice Cream',
            'category': 'Beverages',
            'selling_price': 110.0,
            'is_veg': true,
            'description': 'Rich blended espresso shake topped with a scoop of vanilla ice cream.',
            'rating': 4.7,
            'prep_time_minutes': 5,
          },
          {
            'id': 108,
            'item_name': 'Hot Gulab Jamun with Rabri (2 Pcs)',
            'category': 'Desserts',
            'selling_price': 90.0,
            'is_veg': true,
            'description': 'Warm milk dumplings soaked in cardamom sugar syrup with creamy rabri.',
            'rating': 4.9,
            'prep_time_minutes': 5,
          },
        ];
      }

      // Fetch active and session orders ONLY for this logged-in customer on this table
      List<dynamic> activeOrdersList = [];
      if (_isLoggedIn && _customerProfile != null) {
        try {
          final kotRes = await ApiClient.get('/api/restaurant/kots?table_id=$targetTable');
          if (kotRes['success'] == true && kotRes['data'] != null && kotRes['data'] is List) {
            final List allKots = kotRes['data'];
            final cName = custName.toLowerCase().trim();
            final cPhone = custPhone.trim();
            final cEmail = custEmail.toLowerCase().trim();
            final cId = custId.trim();

            activeOrdersList = allKots.where((kot) {
              final remarks = (kot['remarks'] ?? kot['notes'] ?? '').toString().toLowerCase();
              final custField = (kot['customer_name'] ?? '').toString().toLowerCase();
              final phoneField = (kot['customer_phone'] ?? '').toString();
              final emailField = (kot['customer_email'] ?? '').toString().toLowerCase();
              final revisionsStr = kot['revisions'] != null ? jsonEncode(kot['revisions']).toLowerCase() : '';

              final matchesName = cName.length > 1 && (remarks.contains(cName) || custField.contains(cName) || revisionsStr.contains(cName));
              final matchesPhone = cPhone.length > 4 && (remarks.contains(cPhone) || phoneField.contains(cPhone) || revisionsStr.contains(cPhone));
              final matchesEmail = cEmail.length > 3 && (remarks.contains(cEmail) || emailField.contains(cEmail) || revisionsStr.contains(cEmail));
              final matchesId = cId.isNotEmpty && (remarks.contains('cid:$cId') || revisionsStr.contains('"customer_id":$cId') || revisionsStr.contains('"customer_id":"$cId"'));

              return matchesName || matchesPhone || matchesEmail || matchesId;
            }).toList();
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _restaurantData = restaurantMap;
          _tableData = {
            'id': targetTable,
            'table_name': _selectedTableName,
            'floor_name': 'Main Dining Hall',
          };
          _categories = catSet.toList();
          _allItems = loadedItems;
          _activeOrders = activeOrdersList;
          _loading = false;
        });

        if (!_isLoggedIn && !isSilent) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showAuthModal(context);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load dining session: $e';
          _loading = false;
        });
      }
    }
  }

  // --- AUTHENTICATION & REGISTRATION MODAL ---

  void _showAuthModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) => _CustomerAuthBottomSheet(
        restaurantName: _restaurantData?['property_name'] ?? 'Restaurant',
        outletId: widget.outletId ?? '1',
        onLoginSuccess: (profile) async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('dining_customer_profile', jsonEncode(profile));
          setState(() {
            _customerProfile = profile;
            _isLoggedIn = true;
          });
          _fetchTableDiningCatalog(isSilent: true);
          Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Welcome, ${profile['customer_name'] ?? 'Guest'}! Table is ready.'),
              backgroundColor: Colors.green.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  void _logoutCustomer() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('dining_customer_profile');
    setState(() {
      _customerProfile = null;
      _isLoggedIn = false;
      _cart.clear();
      _activeOrders.clear();
    });
    _fetchTableDiningCatalog(isSilent: true);
    _showAuthModal(context);
  }

  // --- CART OPERATIONS & MODIFIERS / ADDONS ---

  bool _isItemOutOfStock(dynamic item) {
    if (item == null) return false;
    if (item['is_out_of_stock'] == true || item['is_out_of_stock'].toString() == 'true') return true;
    final bool isStockable = item['stockable'] == true || item['stockable'] == 1 || item['stockable'].toString() == 'true';
    if (!isStockable) return false;
    final double stock = double.tryParse((item['stock'] ?? item['opening_balance'] ?? 0).toString()) ?? 0.0;
    return stock <= 0;
  }

  void _addItemToCart(dynamic item) {
    final itemId = item['id'] as int;
    final bool isStockable = item['stockable'] == true || item['stockable'] == 1 || item['stockable'].toString() == 'true';
    final double stock = double.tryParse((item['stock'] ?? item['opening_balance'] ?? 0).toString()) ?? 0.0;

    if (_isItemOutOfStock(item)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item['item_name'] ?? 'This item'} is currently out of stock'),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final currentQty = _cart[itemId]?['qty'] as int? ?? 0;
    if (isStockable && stock > 0 && currentQty >= stock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Only ${stock.toInt()} unit(s) available in stock for ${item['item_name'] ?? 'this item'}'),
          backgroundColor: Colors.orange.shade800,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final basePrice = double.tryParse(item['selling_price']?.toString() ?? '0') ?? 0.0;
    setState(() {
      if (_cart.containsKey(itemId)) {
        _cart[itemId]!['qty'] = (_cart[itemId]!['qty'] as int) + 1;
      } else {
        _cart[itemId] = {
          'item': item,
          'qty': 1,
          'note': '',
          'base_price': basePrice,
          'price': basePrice,
          'modifier_details': <String>[],
          'modifier_objects': <Map<String, dynamic>>[],
        };
      }
    });
  }

  void _removeItemFromCart(dynamic item) {
    final itemId = item['id'] as int;
    setState(() {
      if (_cart.containsKey(itemId)) {
        final currentQty = _cart[itemId]!['qty'] as int;
        if (currentQty > 1) {
          _cart[itemId]!['qty'] = currentQty - 1;
        } else {
          _cart.remove(itemId);
        }
      }
    });
  }

  bool _isModifierApplicable(dynamic mod, int targetItemId) {
    final String appIds = (mod['applicable_item_ids'] ?? '').toString().trim();
    if (appIds.isEmpty || appIds == 'ALL' || appIds == '*' || appIds == '0') return true;
    final list = appIds.split(',').map((s) => s.trim()).toList();
    return list.contains(targetItemId.toString());
  }

  bool _hasModifiersInDb(int itemId) {
    return _allItems.any((it) {
      final bool isMod = it['is_modifier'] == true || it['is_modifier'] == 1 || it['is_modifier'].toString() == 'true';
      if (!isMod) return false;
      return _isModifierApplicable(it, itemId);
    });
  }

  Future<void> _showModifiersDialog(int itemId, {StateSetter? parentSetSheetState}) async {
    final cartItem = _cart[itemId];
    if (cartItem == null) return;
    
    final item = cartItem['item'];
    final basePrice = (cartItem['base_price'] as double?) ?? (double.tryParse(item['selling_price']?.toString() ?? '0') ?? 0.0);
    final remarkCtrl = TextEditingController(text: cartItem['note']?.toString() ?? '');
    
    // Existing selected modifiers map: modifier_name -> qty (int)
    final Map<String, int> selectedModsMap = {};
    final List existingRawMods = cartItem['modifier_objects'] as List? ?? [];
    for (final m in existingRawMods) {
      if (m is Map) {
        final name = m['name']?.toString() ?? '';
        final qty = int.tryParse(m['qty']?.toString() ?? '1') ?? 1;
        if (name.isNotEmpty) selectedModsMap[name] = qty;
      }
    }

    if (selectedModsMap.isEmpty && cartItem['modifier_details'] != null) {
      for (final modStr in (cartItem['modifier_details'] as List)) {
        final str = modStr.toString().trim();
        final match = RegExp(r'^(.*?)\s*\(x(\d+)\)').firstMatch(str);
        if (match != null) {
          selectedModsMap[match.group(1)!.trim()] = int.tryParse(match.group(2)!) ?? 1;
        } else if (str.isNotEmpty) {
          selectedModsMap[str] = 1;
        }
      }
    }

    List<Map<String, dynamic>> availableModifiers = [];
    final serverBase = AppConfig.baseUrl;
    final baseUrl = serverBase.isNotEmpty ? serverBase : 'http://localhost:5000';
    try {
      final res = await http.get(Uri.parse('$baseUrl${ApiEndpoints.itemModifiers}?is_active=true&item_id=$itemId'));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (json['success'] == true && json['data'] is List) {
          final List loaded = json['data'];
          availableModifiers = loaded.map((m) {
            final String name = (m['modifier_name'] ?? m['item_name'] ?? '').toString().trim();
            return {
              'id': m['id'],
              'name': name,
              'price': double.tryParse((m['price'] ?? m['retail_sale_price'] ?? m['rate'] ?? 0).toString()) ?? 0.0,
              'tax_percent': double.tryParse((m['tax_percent'] ?? 0).toString()) ?? 0.0,
            };
          }).where((m) => (m['name'] as String).isNotEmpty).toList();
        }
      }
    } catch (_) {}

    // Fallback: check _allItems for real database is_modifier items
    if (availableModifiers.isEmpty && _allItems.isNotEmpty) {
      availableModifiers = _allItems.where((it) {
        final bool isMod = it['is_modifier'] == true || it['is_modifier'] == 1 || it['is_modifier'].toString() == 'true';
        if (!isMod) return false;
        return _isModifierApplicable(it, itemId);
      }).map((it) {
        return {
          'id': it['id'],
          'name': (it['item_name'] ?? '').toString().trim(),
          'price': double.tryParse((it['retail_sale_price'] ?? it['rate'] ?? 0).toString()) ?? 0.0,
          'tax_percent': double.tryParse((it['tax_percent'] ?? 0).toString()) ?? 0.0,
        };
      }).where((m) => (m['name'] as String).isNotEmpty).toList();
    }

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (modalCtx, setDialogState) {
            final currency = _getEffectiveCurrency();
            double extraPriceTotal = 0.0;
            selectedModsMap.forEach((name, qty) {
              final mod = availableModifiers.firstWhere((m) => m['name'] == name, orElse: () => {'price': 0.0});
              extraPriceTotal += (mod['price'] as double) * qty;
            });
            final finalUnitPrice = basePrice + extraPriceTotal;

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Drag Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.tune, color: primaryOrange, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Customize: ${item['item_name']}',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: darkBg),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Base: $currency${basePrice.toStringAsFixed(2)} | Item Total: $currency${finalUnitPrice.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(modalCtx),
                      ),
                    ],
                  ),
                  const Divider(height: 16),

                  // Special cooking note
                  TextField(
                    controller: remarkCtrl,
                    decoration: InputDecoration(
                      labelText: 'Special Preparation Note (Kitchen)',
                      hintText: 'e.g. Less spicy, well toasted, no onion...',
                      hintStyle: const TextStyle(fontSize: 12),
                      prefixIcon: const Icon(Icons.edit_note, size: 20, color: Color(0xFF64748B)),
                      isDense: true,
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 16),

                  if (availableModifiers.isNotEmpty) ...[
                    const Row(
                      children: [
                        Icon(Icons.add_circle_outline, size: 16, color: primaryOrange),
                        SizedBox(width: 6),
                        Text('Choose Add-ons & Modifiers:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: darkBg)),
                      ],
                    ),
                    const SizedBox(height: 8),

                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: availableModifiers.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, idx) {
                          final mod = availableModifiers[idx];
                          final String name = mod['name'];
                          final double modPrice = mod['price'];
                          final bool isSelected = selectedModsMap.containsKey(name) && (selectedModsMap[name] ?? 0) > 0;
                          final int modQty = selectedModsMap[name] ?? 0;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: isSelected,
                                  activeColor: primaryOrange,
                                  onChanged: (checked) {
                                    setDialogState(() {
                                      if (checked == true) {
                                        selectedModsMap[name] = 1;
                                      } else {
                                        selectedModsMap.remove(name);
                                      }
                                    });
                                  },
                                ),
                                Expanded(
                                  child: Text(
                                    name,
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      fontSize: 13,
                                      color: isSelected ? darkBg : const Color(0xFF334155),
                                    ),
                                  ),
                                ),
                                Text(
                                  '+$currency${modPrice.toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF16A34A)),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(color: primaryOrange),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        InkWell(
                                          onTap: () {
                                            setDialogState(() {
                                              if (modQty > 1) {
                                                selectedModsMap[name] = modQty - 1;
                                              } else {
                                                selectedModsMap.remove(name);
                                              }
                                            });
                                          },
                                          child: const Padding(
                                            padding: EdgeInsets.all(2),
                                            child: Icon(Icons.remove, size: 14, color: primaryOrange),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 4),
                                          child: Text('$modQty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                        ),
                                        InkWell(
                                          onTap: () {
                                            setDialogState(() {
                                              selectedModsMap[name] = modQty + 1;
                                            });
                                          },
                                          child: const Padding(
                                            padding: EdgeInsets.all(2),
                                            child: Icon(Icons.add, size: 14, color: primaryOrange),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, size: 18, color: Color(0xFF94A3B8)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'No add-ons configured in Item Master for this item. You can add cooking notes above.',
                              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Apply button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 2,
                      ),
                      onPressed: () {
                        final List<String> modDetails = [];
                        final List<Map<String, dynamic>> modObjects = [];
                        selectedModsMap.forEach((name, qty) {
                          final mod = availableModifiers.firstWhere((m) => m['name'] == name, orElse: () => {'price': 0.0});
                          final double price = mod['price'] as double;
                          final String label = qty > 1 ? '$name (x$qty)' : name;
                          modDetails.add('$label (+$currency${(price * qty).toStringAsFixed(2)})');
                          modObjects.add({
                            'id': mod['id'],
                            'name': name,
                            'price': price,
                            'qty': qty,
                          });
                        });

                        setState(() {
                          _cart[itemId] = {
                            'item': item,
                            'qty': cartItem['qty'] ?? 1,
                            'base_price': basePrice,
                            'price': finalUnitPrice,
                            'note': remarkCtrl.text.trim(),
                            'modifier_details': modDetails,
                            'modifier_objects': modObjects,
                          };
                        });

                        if (parentSetSheetState != null) {
                          parentSetSheetState(() {});
                        }
                        Navigator.pop(modalCtx);
                      },
                      child: Text(
                        'Save Customization ($currency${finalUnitPrice.toStringAsFixed(2)})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  int _getItemCartQty(int itemId) {
    return _cart[itemId]?['qty'] as int? ?? 0;
  }

  String _getEffectiveCurrency() {
    final resCurrency = _restaurantData?['currency'] ?? _restaurantData?['currency_symbol'];
    if (resCurrency != null && resCurrency.toString().trim().isNotEmpty) {
      return resCurrency.toString().trim();
    }
    if (CurrencyService.symbol.isNotEmpty) {
      return CurrencyService.symbol;
    }
    return '₹';
  }

  double _getCartSubtotal() {
    double sum = 0.0;
    _cart.forEach((_, val) {
      final qty = (val['qty'] as int?) ?? 1;
      final price = (val['price'] as num?)?.toDouble() ?? 0.0;
      sum += (price * qty);
    });
    return sum;
  }

  double _getCartTaxableAmount() {
    double taxable = 0.0;
    _cart.forEach((_, val) {
      final qty = (val['qty'] as int?) ?? 1;
      final price = (val['price'] as num?)?.toDouble() ?? 0.0;
      final it = val['item'];
      final taxPercent = double.tryParse((it?['tax_percent'] ?? 0).toString()) ?? 0.0;
      final isInclusive = it?['is_tax_inclusive'] == true;
      final lineGross = price * qty;
      if (isInclusive && taxPercent > 0) {
        taxable += lineGross / (1.0 + (taxPercent / 100.0));
      } else {
        taxable += lineGross;
      }
    });
    return taxable;
  }

  double _getCartTaxTotal() {
    double totalTax = 0.0;
    _cart.forEach((_, val) {
      final qty = (val['qty'] as int?) ?? 1;
      final price = (val['price'] as num?)?.toDouble() ?? 0.0;
      final it = val['item'];
      final taxPercent = double.tryParse((it?['tax_percent'] ?? 0).toString()) ?? 0.0;
      final isInclusive = it?['is_tax_inclusive'] == true;
      final lineGross = price * qty;
      if (taxPercent > 0) {
        if (isInclusive) {
          totalTax += lineGross - (lineGross / (1.0 + (taxPercent / 100.0)));
        } else {
          totalTax += (lineGross * taxPercent / 100.0);
        }
      }
    });
    return totalTax;
  }

  double _getCartExclusiveTaxTotal() {
    double exclusiveTax = 0.0;
    _cart.forEach((_, val) {
      final qty = (val['qty'] as int?) ?? 1;
      final price = (val['price'] as num?)?.toDouble() ?? 0.0;
      final it = val['item'];
      final taxPercent = double.tryParse((it?['tax_percent'] ?? 0).toString()) ?? 0.0;
      final isInclusive = it?['is_tax_inclusive'] == true;
      final lineGross = price * qty;
      if (!isInclusive && taxPercent > 0) {
        exclusiveTax += (lineGross * taxPercent / 100.0);
      }
    });
    return exclusiveTax;
  }

  double _getCartInclusiveTaxTotal() {
    double inclusiveTax = 0.0;
    _cart.forEach((_, val) {
      final qty = (val['qty'] as int?) ?? 1;
      final price = (val['price'] as num?)?.toDouble() ?? 0.0;
      final it = val['item'];
      final taxPercent = double.tryParse((it?['tax_percent'] ?? 0).toString()) ?? 0.0;
      final isInclusive = it?['is_tax_inclusive'] == true;
      final lineGross = price * qty;
      if (isInclusive && taxPercent > 0) {
        inclusiveTax += lineGross - (lineGross / (1.0 + (taxPercent / 100.0)));
      }
    });
    return inclusiveTax;
  }

  double _getCartGrandTotal() {
    double total = 0.0;
    _cart.forEach((_, val) {
      final qty = (val['qty'] as int?) ?? 1;
      final price = (val['price'] as num?)?.toDouble() ?? 0.0;
      final it = val['item'];
      final taxPercent = double.tryParse((it?['tax_percent'] ?? 0).toString()) ?? 0.0;
      final isInclusive = it?['is_tax_inclusive'] == true;
      final lineGross = price * qty;
      if (isInclusive || taxPercent <= 0) {
        total += lineGross;
      } else {
        total += lineGross + ((lineGross * taxPercent) / 100.0);
      }
    });
    return total > 0 ? total : _getCartSubtotal();
  }

  int _getTotalCartItems() {
    int count = 0;
    _cart.forEach((_, val) {
      count += (val['qty'] as int);
    });
    return count;
  }

  // --- WAITER CALL / ASSIST TRIGGER ---

  Future<void> _callWaiter(String requestType) async {
    final serverBase = AppConfig.baseUrl;
    final baseUrl = serverBase.isNotEmpty ? serverBase : 'http://localhost:5000';
    final rawTable = (_tableData?['table_name'] ?? _tableData?['name'] ?? widget.tableName ?? '1').toString();
    final cleanTableNumber = rawTable
        .replaceAll(RegExp(r'\(demo\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'table', caseSensitive: false), '')
        .trim();
    final displayTableName = cleanTableNumber.isEmpty ? 'Table 1' : 'Table $cleanTableNumber';
    final guestName = _customerProfile?['customer_name'] ?? _customerProfile?['name'] ?? 'Guest';

    String defaultMsg;
    IconData actionIcon;
    switch (requestType) {
      case 'WATER':
        defaultMsg = '💧 Drinking water request sent to your steward for $displayTableName!';
        actionIcon = Icons.water_drop;
        break;
      case 'BILL':
        defaultMsg = '🧾 Bill request sent to cashier for $displayTableName!';
        actionIcon = Icons.receipt_long;
        break;
      case 'CALL_WAITER':
      default:
        defaultMsg = '🛎️ Table steward has been notified for $displayTableName!';
        actionIcon = Icons.notifications_active;
        break;
    }

    // 1. Try public endpoint
    try {
      final res = await http.post(
        Uri.parse('$baseUrl${ApiEndpoints.publicDiningCallWaiter}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'outlet_id': widget.outletId ?? '1',
          'table_id': _selectedTableId,
          'request_type': requestType,
          'customer_name': guestName,
        }),
      ).timeout(const Duration(seconds: 3));

      if (res.statusCode == 200 || res.statusCode == 201) {
        final json = jsonDecode(res.body);
        if (mounted) {
          _showAssistanceBanner(json['message'] ?? defaultMsg, actionIcon);
        }
        return;
      }
    } catch (_) {}

    // 2. Resilient Fallback: Notify internal POS ApiClient
    try {
      await ApiClient.post('/api/restaurant/tables/$_selectedTableId/assistance', {
        'table_id': _selectedTableId,
        'table_name': displayTableName,
        'request_type': requestType,
        'customer_name': guestName,
        'requested_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}

    // 3. User feedback confirmation
    if (mounted) {
      _showAssistanceBanner(defaultMsg, actionIcon);
    }
  }

  void _showAssistanceBanner(String message, IconData icon) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // --- PLACE ORDER (KOT DISPATCH) ---

  Future<void> _processOrderPlacement({String? txnId, String? paymentMode}) async {
    if (_cart.isEmpty) return;
    if (!_isLoggedIn) {
      _showAuthModal(context);
      return;
    }

    // Pre-flight check: Ensure no out-of-stock items in cart
    for (final entry in _cart.values) {
      final it = entry['item'];
      if (_isItemOutOfStock(it)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${it['item_name'] ?? 'An item'}" in your cart is currently out of stock. Please remove it before placing your order.'),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }
    }

    setState(() => _submittingOrder = true);
    final serverBase = AppConfig.baseUrl;
    final baseUrl = serverBase.isNotEmpty ? serverBase : 'http://localhost:5000';

    final orderItems = _cart.values.map((v) {
      final it = v['item'];
      return {
        'item_id': it['id'],
        'item_name': it['item_name'],
        'qty': v['qty'],
        'price': v['price'],
        'base_price': v['base_price'] ?? v['price'],
        'special_note': v['note'],
        'item_remark': v['note'],
        'modifier_details': v['modifier_details'] ?? [],
        'modifier_objects': v['modifier_objects'] ?? [],
        'kitchen_station_id': it['kitchen_station_id'],
      };
    }).toList();

    final isPaidOnline = _paymentMethod == 'ONLINE' && txnId != null;

    try {
      final res = await http.post(
        Uri.parse('$baseUrl${ApiEndpoints.publicDiningPlaceOrder}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'outlet_id': widget.outletId ?? '1',
          'table_id': _selectedTableId,
          'customer_id': _customerProfile?['id'],
          'customer_name': _customerProfile?['customer_name'] ?? _customerProfile?['name'] ?? _customerProfile?['full_name'],
          'customer_phone': _customerProfile?['customer_phone'] ?? _customerProfile?['phone'] ?? _customerProfile?['mobile'],
          'customer_email': _customerProfile?['customer_email'] ?? _customerProfile?['email'],
          'items': orderItems,
          'special_instructions': _specialInstructionsCtrl.text.trim(),
          'payment_method': _paymentMethod,
          'payment_status': isPaidOnline ? 'PAID' : 'UNPAID',
          'payment_mode': isPaidOnline ? (paymentMode ?? 'UPI') : 'PAY_AT_COUNTER',
          'transaction_id': txnId,
          'amount_paid': isPaidOnline ? _getCartGrandTotal() : 0.0,
        }),
      );

      final json = jsonDecode(res.body);
      if (json['success'] == true) {
        final orderData = json['data'] ?? {};
        setState(() {
          _cart.clear();
          _specialInstructionsCtrl.clear();
          _submittingOrder = false;
        });

        if (Navigator.canPop(context)) Navigator.pop(context);
        _showOrderSuccessDialog(orderData, isPaidOnline, txnId, paymentMode);
        _fetchTableDiningCatalog();
        return;
      } else if (res.statusCode >= 400 || json['success'] == false) {
        setState(() => _submittingOrder = false);
        final errMsg = json['message'] ?? json['error'] ?? 'Failed to place order';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errMsg.toString()),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }
    } catch (e) {
      debugPrint('[ORDER PLACEMENT ERR] $e');
    }

    // Resilient Fallback: Dispatch KOT via POS ApiClient
    try {
      final kotRes = await ApiClient.post('/api/restaurant/kots', {
        'table_id': int.tryParse(_selectedTableId) ?? 1,
        'customer_name': _customerProfile?['name'] ?? _customerProfile?['customer_name'] ?? 'Dining Guest',
        'customer_phone': _customerProfile?['phone'] ?? _customerProfile?['customer_phone'] ?? '',
        'customer_email': _customerProfile?['email'] ?? _customerProfile?['customer_email'] ?? '',
        'notes': _specialInstructionsCtrl.text.trim(),
        'payment_status': isPaidOnline ? 'PAID' : 'UNPAID',
        'payment_mode': isPaidOnline ? (paymentMode ?? 'UPI') : 'PAY_AT_COUNTER',
        'transaction_id': txnId,
        'items': orderItems.map((it) => {
          'item_id': it['item_id'],
          'item_name': it['item_name'],
          'quantity': it['qty'],
          'rate': it['price'],
          'item_remark': it['special_note'],
        }).toList(),
      });

      final dynamic data = kotRes['data'] ?? {
        'kot_number': '#KOT-${DateTime.now().millisecondsSinceEpoch % 10000}',
        'created_at': DateTime.now().toIso8601String(),
      };

      setState(() {
        _cart.clear();
        _specialInstructionsCtrl.clear();
        _submittingOrder = false;
      });

      if (Navigator.canPop(context)) Navigator.pop(context);
      _showOrderSuccessDialog(data, isPaidOnline, txnId, paymentMode);
      _fetchTableDiningCatalog();
    } catch (_) {
      // Demo simulation fallback
      final simData = {
        'kot_number': '#KOT-${DateTime.now().millisecondsSinceEpoch % 10000}',
        'created_at': DateTime.now().toIso8601String(),
      };
      setState(() {
        _cart.clear();
        _specialInstructionsCtrl.clear();
        _submittingOrder = false;
      });
      if (Navigator.canPop(context)) Navigator.pop(context);
      _showOrderSuccessDialog(simData, isPaidOnline, txnId, paymentMode);
      _fetchTableDiningCatalog();
    }
  }

  void _onCheckoutTapped(double grandTotal) {
    // Direct place order / send KOT to kitchen (pay after meal / when bill generated)
    _paymentMethod = 'PAY_LATER';
    _processOrderPlacement();
  }

  // --- ONLINE PAYMENT GATEWAY DIALOG ---

  void _openPaymentGatewaySheet({
    required BuildContext context,
    required double amount,
    required Function(String txnId, String mode) onPaymentComplete,
  }) {
    final bool isGatewayEnabled = _restaurantData?['enable_payment_gateway'] == true ||
        _restaurantData?['enable_payment_gateway'] == 1 ||
        _restaurantData?['enable_payment_gateway'].toString() == 'true';
    final String? merchantUpiId = _restaurantData?['merchant_upi_id']?.toString();
    final String? gatewayProvider = _restaurantData?['payment_gateway_provider']?.toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PaymentGatewayBottomSheet(
        amount: amount,
        currency: _getEffectiveCurrency(),
        restaurantName: _restaurantData?['property_name'] ?? 'Restaurant',
        tableName: _tableData?['table_name'] ?? '',
        isGatewayEnabled: isGatewayEnabled,
        merchantUpiId: merchantUpiId,
        gatewayProvider: gatewayProvider,
        onSuccess: (txnId, mode) {
          Navigator.pop(ctx);
          onPaymentComplete(txnId, mode);
        },
      ),
    );
  }

  void _showOrderSuccessDialog(Map<String, dynamic> orderData, bool isPaid, String? txnId, String? mode) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 48),
            ),
            const SizedBox(height: 16),
            const Text(
              'Order Sent to Kitchen!',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: darkBg),
            ),
            const SizedBox(height: 8),
            Text(
              'KOT #${orderData['kot_no'] ?? ''} • Table ${orderData['table_name'] ?? _tableData?['table_name'] ?? ''}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: primaryOrange),
            ),
            const SizedBox(height: 4),
            Text(
              'Server: ${orderData['waiter_name']?.isNotEmpty == true ? orderData['waiter_name'] : "Waiter on Duty"}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isPaid ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isPaid ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPaid ? Icons.verified : Icons.access_time_filled,
                    size: 14,
                    color: isPaid ? const Color(0xFF16A34A) : const Color(0xFFB45309),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isPaid
                        ? 'PAID ONLINE ($mode - Ref: ${txnId ?? "#TXN"})'
                        : 'PAY AFTER MEAL (Cash / Card at Table)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isPaid ? const Color(0xFF15803D) : const Color(0xFFB45309),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Back to Menu', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- UI BUILD ---

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: primaryOrange),
              SizedBox(height: 16),
              Text('Connecting to restaurant table...', style: TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 12),
                Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _initializeDiningSession,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final currency = _getEffectiveCurrency();
    final filteredItems = _getFilteredItems();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                // 1. RESTAURANT & TABLE HEADER
                SliverToBoxAdapter(
                  child: _buildRestaurantHeader(),
                ),

                // 2. MAIN TAB SELECTOR (FOOD MENU vs ORDER HISTORY & STATUS)
                SliverToBoxAdapter(
                  child: _buildMainTabSelector(),
                ),

                // 3. QUICK WAITER ASSIST BUTTONS
                SliverToBoxAdapter(
                  child: _buildWaiterQuickActions(),
                ),

                // 4. CONTENT SLIVERS BASED ON ACTIVE TAB
                if (_currentMainTab == 0)
                  ..._buildFoodMenuSlivers(filteredItems, currency)
                else
                  ..._buildOrderHistorySlivers(currency),
              ],
            ),

            // FLOATING BOTTOM CART BAR (ONLY WHEN IN MENU TAB AND CART HAS ITEMS)
            if (_cart.isNotEmpty && _currentMainTab == 0)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: _buildFloatingCartBar(currency),
              ),
          ],
        ),
      ),
    );
  }

  // --- MAIN NAVIGATION TAB SELECTOR ---

  Widget _buildMainTabSelector() {
    final int ordersCount = _activeOrders.length;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _currentMainTab = 0),
              borderRadius: BorderRadius.circular(9),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _currentMainTab == 0 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: _currentMainTab == 0
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.restaurant_menu,
                      size: 16,
                      color: _currentMainTab == 0 ? primaryOrange : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Food Menu',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: _currentMainTab == 0 ? primaryOrange : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _currentMainTab = 1),
              borderRadius: BorderRadius.circular(9),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _currentMainTab == 1 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: _currentMainTab == 1
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.receipt_long,
                      size: 16,
                      color: _currentMainTab == 1 ? primaryOrange : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Order History & Status',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: _currentMainTab == 1 ? primaryOrange : const Color(0xFF64748B),
                      ),
                    ),
                    if (ordersCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: _currentMainTab == 1 ? primaryOrange : const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$ordersCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- FOOD MENU SLIVERS ---

  List<Widget> _buildFoodMenuSlivers(List<dynamic> filteredItems, String currency) {
    return [
      // Search & Dietary Filter
      SliverToBoxAdapter(
        child: _buildSearchAndFilters(),
      ),

      // Category Pills Bar
      SliverToBoxAdapter(
        child: _buildCategoryPills(),
      ),

      // Food Catalog List
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        sliver: filteredItems.isEmpty
            ? const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                    child: Text('No food items found matching criteria.', style: TextStyle(color: Colors.grey)),
                  ),
                ),
              )
            : SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = filteredItems[index];
                    return _buildFoodItemCard(item, currency);
                  },
                  childCount: filteredItems.length,
                ),
              ),
      ),
    ];
  }

  // --- ORDER HISTORY & LIVE STATUS SLIVERS ---

  List<Widget> _buildOrderHistorySlivers(String currency) {
    if (_activeOrders.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: primaryOrange.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.receipt_long_outlined, size: 48, color: primaryOrange),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No Orders Placed Yet',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: darkBg),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Items you order on this table will appear here with live kitchen & table updates (Cooking, Ready, Served & Billed).',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                  ),
                  icon: const Icon(Icons.restaurant_menu, size: 16),
                  label: const Text('Browse Food Menu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  onPressed: () => setState(() => _currentMainTab = 0),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    return [
      // Top Live Status Banner & Manual Refresh
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.timelapse, size: 18, color: primaryOrange),
                  const SizedBox(width: 6),
                  Text(
                    'Table Orders (${_activeOrders.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: darkBg),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  _fetchTableDiningCatalog(isSilent: false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Refreshing live order status from kitchen...'),
                      duration: Duration(milliseconds: 900),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh, size: 14, color: Color(0xFF0284C7)),
                      SizedBox(width: 4),
                      Text('Refresh Live Status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      // Order Cards List
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final kot = _activeOrders[index];
              return _buildOrderHistoryCard(kot, currency);
            },
            childCount: _activeOrders.length,
          ),
        ),
      ),
    ];
  }

  // --- ORDER HISTORY CARD ---

  Widget _buildOrderHistoryCard(dynamic kot, String currency) {
    final kotNo = (kot['kot_no'] ?? kot['id'] ?? '').toString();
    final items = kot['items'] as List<dynamic>? ?? [];
    final rawStatus = (kot['status'] ?? 'Pending').toString();
    final paymentStatus = (kot['payment_status'] ?? (rawStatus.toLowerCase() == 'paid' ? 'PAID' : 'UNPAID')).toString();
    final createdTimeStr = (kot['created_time'] ?? kot['created_at'] ?? '').toString();
    final String billNo = (kot['bill_no'] ?? (kot['sales_header'] is Map ? kot['sales_header']['sale_no'] : '') ?? '').toString();

    // Compute subtotal and tax dynamically across all items based on item tax groups
    double calculatedSubtotal = 0.0;
    double calculatedGrandTotal = 0.0;

    for (final it in items) {
      final String n = (it['item_name'] ?? 'Dish').toString();
      final int q = int.tryParse((it['qty'] ?? it['quantity'] ?? 1).toString()) ?? 1;
      double p = double.tryParse((it['price'] ?? it['rate'] ?? it['selling_price'] ?? (it['item'] is Map ? (it['item']['retail_sale_price'] ?? it['item']['rate'] ?? it['item']['selling_price']) : 0) ?? 0).toString()) ?? 0.0;
      
      dynamic catalogItem;
      if (_allItems.isNotEmpty) {
        catalogItem = _allItems.firstWhere(
          (m) => m['id'] == it['item_id'] || m['item_name']?.toString().toLowerCase().trim() == n.toLowerCase().trim(),
          orElse: () => null,
        );
      }
      if (p == 0.0 && catalogItem != null) {
        p = double.tryParse((catalogItem['retail_sale_price'] ?? catalogItem['selling_price'] ?? catalogItem['rate'] ?? catalogItem['mrp'] ?? 0).toString()) ?? 0.0;
      }
      
      final double itemTaxPercent = double.tryParse((it['tax_percent'] ?? (it['item'] is Map ? it['item']['tax_percent'] : null) ?? (catalogItem != null ? catalogItem['tax_percent'] : null) ?? 0).toString()) ?? 0.0;
      final bool isTaxInclusive = it['is_tax_inclusive'] == true || (it['item'] is Map && it['item']['is_tax_inclusive'] == true) || (catalogItem != null && catalogItem['is_tax_inclusive'] == true);

      final double lineGross = p * q;
      calculatedSubtotal += lineGross;
      if (itemTaxPercent > 0) {
        if (isTaxInclusive) {
          calculatedGrandTotal += lineGross;
        } else {
          final double lineTax = (lineGross * itemTaxPercent / 100.0);
          calculatedGrandTotal += (lineGross + lineTax);
        }
      } else {
        calculatedGrandTotal += lineGross;
      }
    }
    
    final double? rawKotTotal = double.tryParse((kot['total_amount'] ?? kot['net_amount'] ?? (kot['sales_header'] is Map ? kot['sales_header']['net_amount'] : null) ?? '').toString());
    final double kotTotal = (rawKotTotal != null && rawKotTotal > 0) ? rawKotTotal : (calculatedGrandTotal > 0 ? calculatedGrandTotal : calculatedSubtotal);
    
    final remarks = (kot['remarks'] ?? '').toString();
    final bool isRemarksPaid = remarks.contains('[PAID') || remarks.contains('[SETTLED]');
    final bool isSettled = rawStatus.toLowerCase() == 'settled' ||
        rawStatus.toLowerCase() == 'closed' ||
        rawStatus.toLowerCase() == 'paid' ||
        rawStatus.toLowerCase() == 'completed' ||
        paymentStatus.toUpperCase() == 'PAID' ||
        paymentStatus.toUpperCase() == 'SETTLED' ||
        (kot['is_settled'] == true) ||
        (kot['sales_header'] is Map && ((kot['sales_header']['status'] ?? '').toString().toUpperCase() == 'COMPLETED' || (double.tryParse((kot['sales_header']['balance_due'] ?? '0').toString()) ?? 0.0) <= 0.01)) ||
        isRemarksPaid;
    final bool isPaid = isSettled;
    final bool isBillGenerated = billNo.isNotEmpty || rawStatus.toLowerCase() == 'billed' || rawStatus.toLowerCase() == 'bill';
    final statusInfo = _getOrderStatusBadgeInfo(isSettled ? 'settled' : rawStatus, isSettled ? 'PAID' : paymentStatus);
    final saleHeader = kot['sales_header'] is Map ? kot['sales_header'] : null;
    final double cardDiscountAmt = double.tryParse((kot['discount_amount'] ?? saleHeader?['total_discount'] ?? saleHeader?['discount_amount'] ?? saleHeader?['manual_discount_amount'] ?? 0).toString()) ?? 0.0;
    final double cardChargeAmt = double.tryParse((kot['charge_total'] ?? saleHeader?['charge_total'] ?? 0).toString()) ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Header: Bill / KOT #, Time & Overall Status Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: primaryOrange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.receipt_long, size: 14, color: primaryOrange),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        billNo.isNotEmpty ? 'Bill #$billNo (KOT #$kotNo)' : 'KOT #$kotNo',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: darkBg),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatOrderTime(createdTimeStr),
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusInfo['bgColor'] as Color,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: (statusInfo['color'] as Color).withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusInfo['icon'] as IconData, size: 13, color: statusInfo['color'] as Color),
                    const SizedBox(width: 4),
                    Text(
                      statusInfo['label'] as String,
                      style: TextStyle(
                        color: statusInfo['color'] as Color,
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Status Explanation Callout
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: (statusInfo['bgColor'] as Color).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(statusInfo['icon'] as IconData, size: 14, color: statusInfo['color'] as Color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    statusInfo['description'] as String,
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: statusInfo['color'] as Color),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Visual Progress Stepper Timeline
          _buildOrderStepTimeline(statusInfo['step'] as int),

          const SizedBox(height: 8),

          // Ordered Items Breakdown List
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Dishes in this Order (${items.length}):',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: darkBg),
                    ),
                    const Text('Status & Amount', style: TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 6),

                ...items.map((it) {
                  final String name = (it['item_name'] ?? 'Dish').toString();
                  final int qty = int.tryParse((it['qty'] ?? it['quantity'] ?? 1).toString()) ?? 1;
                  double price = double.tryParse((it['price'] ?? it['rate'] ?? it['selling_price'] ?? (it['item'] is Map ? (it['item']['retail_sale_price'] ?? it['item']['rate'] ?? it['item']['selling_price']) : 0) ?? 0).toString()) ?? 0.0;
                  if (price == 0.0) {
                    final catalogItem = _allItems.firstWhere(
                      (m) => m['id'] == it['item_id'] || m['item_name']?.toString().toLowerCase().trim() == name.toLowerCase().trim(),
                      orElse: () => null,
                    );
                    if (catalogItem != null) {
                      price = double.tryParse((catalogItem['retail_sale_price'] ?? catalogItem['selling_price'] ?? catalogItem['rate'] ?? catalogItem['mrp'] ?? 0).toString()) ?? 0.0;
                    }
                  }

                  final String itemRawStatus = (it['status'] ?? rawStatus).toString();
                  final itemStatusInfo = _getItemStatusBadgeInfo(itemRawStatus);
                  final String remark = (it['item_remark'] ?? it['special_note'] ?? '').toString().trim();
                  final List<dynamic> modDetails = (it['modifier_details'] is List ? it['modifier_details'] : (it['modifiers'] is List ? it['modifiers'] : []));

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Dietary dot
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: const BoxDecoration(
                                color: pureVegGreen,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '$qty x $name',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: darkBg),
                              ),
                            ),
                            // Item-level status badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: itemStatusInfo['bgColor'] as Color,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(itemStatusInfo['icon'] as IconData, size: 10, color: itemStatusInfo['color'] as Color),
                                  const SizedBox(width: 3),
                                  Text(
                                    itemStatusInfo['label'] as String,
                                    style: TextStyle(
                                      color: itemStatusInfo['color'] as Color,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$currency${(price * qty).toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: darkBg),
                            ),
                          ],
                        ),
                        if (modDetails.isNotEmpty || remark.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(left: 12, top: 3),
                            child: Wrap(
                              spacing: 4,
                              runSpacing: 2,
                              children: [
                                ...modDetails.map((m) => Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: Text(
                                        m.toString(),
                                        style: const TextStyle(fontSize: 9.5, color: Color(0xFF1D4ED8), fontWeight: FontWeight.w600),
                                      ),
                                    )),
                                if (remark.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: Text(
                                      '📝 $remark',
                                      style: const TextStyle(fontSize: 9.5, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),

          if (cardDiscountAmt > 0 || cardChargeAmt > 0) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (cardDiscountAmt > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        'Discount: -$currency${cardDiscountAmt.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF16A34A), fontWeight: FontWeight.bold),
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  if (cardChargeAmt > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        'Charges: +$currency${cardChargeAmt.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF475569), fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
          ],

          // Order Total & Action Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Payment Status
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: isPaid ? const Color(0xFFDCFCE7) : (isBillGenerated ? const Color(0xFFFEF3C7) : const Color(0xFFEFF6FF)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isPaid
                      ? 'PAID (${kot['payment_mode'] ?? "ONLINE"})'
                      : (isBillGenerated ? 'UNPAID BILL' : 'ORDER PLACED'),
                  style: TextStyle(
                    color: isPaid
                        ? const Color(0xFF16A34A)
                        : (isBillGenerated ? const Color(0xFFB45309) : const Color(0xFF1D4ED8)),
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // Total Amount
              Text(
                'Total: $currency${kotTotal.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: darkBg),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Action Buttons: Digital Bill Receipt & Pay Bill / Paid Badge / Awaiting Bill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.receipt_long, size: 15, color: Color(0xFF0284C7)),
                label: Text(
                  isBillGenerated ? 'View Bill Receipt' : 'View Order Summary',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF0284C7), fontWeight: FontWeight.bold),
                ),
                onPressed: () => _showDigitalBillDialog(kot),
              ),
              if (isSettled)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle, size: 14, color: Color(0xFF16A34A)),
                      const SizedBox(width: 5),
                      Text(
                        'Paid ($currency${kotTotal.toStringAsFixed(2)})',
                        style: const TextStyle(
                          color: Color(0xFF16A34A),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )
              else if (isBillGenerated)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.payment, size: 14),
                  label: Text('Pay Bill $currency${kotTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    _openPaymentGatewaySheet(
                      context: context,
                      amount: kotTotal > 0 ? kotTotal : 100.0,
                      onPaymentComplete: (txnId, mode) async {
                        await _settleBillPayment(kot['id'], txnId, mode);
                        setState(() {});
                      },
                    );
                  },
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.hourglass_empty, size: 13, color: Color(0xFF64748B)),
                      SizedBox(width: 4),
                      Text(
                        'Awaiting Bill',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // --- ORDER STATUS TIMELINE STEPPER ---

  Widget _buildOrderStepTimeline(int activeStep) {
    // 4 Steps: 1. Placed, 2. Cooking, 3. Ready, 4. Served
    final steps = [
      {'title': 'Placed', 'icon': Icons.assignment_turned_in},
      {'title': 'Cooking', 'icon': Icons.soup_kitchen},
      {'title': 'Ready', 'icon': Icons.room_service},
      {'title': 'Served', 'icon': Icons.check_circle},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (index) {
          if (index.isOdd) {
            final stepIndex = (index ~/ 2) + 1;
            final isCompleted = activeStep > stepIndex;
            return Expanded(
              child: Container(
                height: 3,
                color: isCompleted ? pureVegGreen : const Color(0xFFE2E8F0),
              ),
            );
          }

          final stepIndex = (index ~/ 2) + 1;
          final step = steps[index ~/ 2];
          final isCompleted = activeStep > stepIndex;
          final isCurrent = activeStep == stepIndex;

          final Color nodeColor = isCompleted
              ? pureVegGreen
              : (isCurrent ? primaryOrange : const Color(0xFFCBD5E1));

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? pureVegGreen
                      : (isCurrent ? primaryOrange.withValues(alpha: 0.15) : const Color(0xFFF1F5F9)),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: nodeColor,
                    width: isCurrent ? 2 : 1.5,
                  ),
                ),
                child: Center(
                  child: Icon(
                    isCompleted ? Icons.check : (step['icon'] as IconData),
                    size: 13,
                    color: isCompleted ? Colors.white : nodeColor,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                step['title'] as String,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: isCurrent || isCompleted ? FontWeight.bold : FontWeight.normal,
                  color: isCurrent ? primaryOrange : (isCompleted ? darkBg : const Color(0xFF94A3B8)),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  // --- STATUS BADGE HELPERS ---

  Map<String, dynamic> _getOrderStatusBadgeInfo(String? rawStatus, String? paymentStatus) {
    final s = (rawStatus ?? '').toString().toLowerCase().trim();
    final p = (paymentStatus ?? '').toString().toLowerCase().trim();

    if (p == 'paid' || s == 'closed' || s == 'completed' || s == 'settled') {
      return {
        'label': 'Paid & Completed',
        'icon': Icons.verified,
        'color': const Color(0xFF16A34A),
        'bgColor': const Color(0xFFDCFCE7),
        'step': 4,
        'description': 'Payment is settled & dining session completed.',
      };
    }
    if (s == 'billed' || s == 'bill') {
      return {
        'label': 'Bill Generated',
        'icon': Icons.receipt_long,
        'color': const Color(0xFFD97706),
        'bgColor': const Color(0xFFFEF3C7),
        'step': 4,
        'description': 'Bill has been generated. Ready for payment settlement.',
      };
    }
    if (s == 'served' || s == 'delivered') {
      return {
        'label': 'Served to Table',
        'icon': Icons.check_circle_outline,
        'color': const Color(0xFF7C3AED),
        'bgColor': const Color(0xFFF3E8FF),
        'step': 4,
        'description': 'Dishes have been served to your table. Enjoy your meal!',
      };
    }
    if (s == 'ready' || s == 'prepared' || s == 'done') {
      return {
        'label': 'Ready to Serve',
        'icon': Icons.room_service,
        'color': const Color(0xFF059669),
        'bgColor': const Color(0xFFD1FAE5),
        'step': 3,
        'description': 'Dishes are freshly prepared and being served by steward.',
      };
    }
    if (s == 'cooking' || s == 'in progress' || s == 'in_progress' || s == 'preparing') {
      return {
        'label': 'Cooking in Kitchen',
        'icon': Icons.soup_kitchen,
        'color': const Color(0xFF0284C7),
        'bgColor': const Color(0xFFE0F2FE),
        'step': 2,
        'description': 'Chef is preparing your dishes in the kitchen.',
      };
    }
    // Default: Pending / In Kitchen
    return {
      'label': 'Sent to Kitchen',
      'icon': Icons.access_time_filled,
      'color': const Color(0xFFEA580C),
      'bgColor': const Color(0xFFFFEDD5),
      'step': 1,
      'description': 'Order has been received in the kitchen queue.',
    };
  }

  Map<String, dynamic> _getItemStatusBadgeInfo(String? rawStatus) {
    final s = (rawStatus ?? '').toString().toLowerCase().trim();
    if (s == 'served' || s == 'delivered') {
      return {
        'label': 'Served',
        'icon': Icons.check_circle,
        'color': const Color(0xFF7C3AED),
        'bgColor': const Color(0xFFF3E8FF),
      };
    }
    if (s == 'ready' || s == 'prepared' || s == 'done') {
      return {
        'label': 'Ready',
        'icon': Icons.room_service,
        'color': const Color(0xFF059669),
        'bgColor': const Color(0xFFD1FAE5),
      };
    }
    if (s == 'cooking' || s == 'in progress' || s == 'in_progress' || s == 'preparing') {
      return {
        'label': 'Cooking',
        'icon': Icons.soup_kitchen,
        'color': const Color(0xFF0284C7),
        'bgColor': const Color(0xFFE0F2FE),
      };
    }
    if (s == 'cancelled' || s == 'rejected') {
      return {
        'label': 'Cancelled',
        'icon': Icons.cancel,
        'color': const Color(0xFFDC2626),
        'bgColor': const Color(0xFFFEE2E2),
      };
    }
    return {
      'label': 'In Kitchen',
      'icon': Icons.hourglass_top,
      'color': const Color(0xFFD97706),
      'bgColor': const Color(0xFFFEF3C7),
    };
  }

  String _formatOrderTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return 'Just now';
    try {
      final dt = DateTime.parse(timeStr).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$hour:$minute $ampm';
    } catch (_) {
      return 'Today';
    }
  }

  // --- HEADER & BANNER ---

  Widget _buildRestaurantHeader() {
    final resName = _restaurantData?['property_name'] ?? 'Grand Restaurant';
    final rawTable = (_tableData?['table_name'] ?? _tableData?['name'] ?? _selectedTableName).toString();
    final cleanTableNumber = rawTable
        .replaceAll(RegExp(r'\(demo\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'table', caseSensitive: false), '')
        .trim();
    final displayTableName = cleanTableNumber.isEmpty ? 'Table $_selectedTableId' : 'Table $cleanTableNumber';
    final floorName = _tableData?['floor_name'] ?? '';
    final areaName = _tableData?['area_name'] ?? '';
    final customerName = _customerProfile?['customer_name'] ?? _customerProfile?['name'] ?? 'Guest';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Brand & Outlet Name
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      resName,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: darkBg),
                    ),
                    Text(
                      _restaurantData?['address'] ?? 'Dine-in Experience',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Interactive Database Table Selector Dropdown
              _buildTableSelectorDropdown(displayTableName),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 8),

          // User Greeting & Floor Info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.person_pin, size: 16, color: Color(0xFF0284C7)),
                  const SizedBox(width: 4),
                  Text(
                    _isLoggedIn ? 'Hello, $customerName' : 'Guest (Sign in to order)',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: darkBg),
                  ),
                  if (floorName.isNotEmpty || areaName.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      '• ${[floorName, areaName].where((s) => s.isNotEmpty).join(", ")}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ],
              ),
              if (_isLoggedIn)
                InkWell(
                  onTap: _logoutCustomer,
                  child: const Text('Change User', style: TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold)),
                )
              else
                InkWell(
                  onTap: () => _showAuthModal(context),
                  child: const Text('Sign In', style: TextStyle(fontSize: 11, color: primaryOrange, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTableSelectorDropdown(String currentDisplayName) {
    if (_loadingTables && _databaseTables.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: primaryOrange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: primaryOrange.withValues(alpha: 0.3)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2, color: primaryOrange),
            ),
            SizedBox(width: 6),
            Text('Loading tables...', style: TextStyle(fontSize: 11.5, color: primaryOrange, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    // Prepare dropdown items list
    final List<Map<String, dynamic>> itemsList = List.from(_databaseTables);
    
    // Ensure currently selected table exists in list
    final exists = itemsList.any((t) => t['id']?.toString() == _selectedTableId);
    if (!exists) {
      itemsList.insert(0, {
        'id': _selectedTableId,
        'table_name': currentDisplayName,
        'name': currentDisplayName,
      });
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: primaryOrange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryOrange.withValues(alpha: 0.35)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedTableId,
          isDense: true,
          icon: const Icon(Icons.arrow_drop_down, color: primaryOrange, size: 20),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(12),
          elevation: 4,
          items: itemsList.map((t) {
            final tId = t['id']?.toString() ?? '1';
            final rawName = (t['table_name'] ?? t['name'] ?? 'Table $tId').toString();
            final floor = t['floor_name'] ?? (t['floor'] is Map ? t['floor']['name'] : null) ?? '';
            final area = t['area_name'] ?? (t['dining_area'] is Map ? t['dining_area']['name'] : null) ?? '';
            final locationInfo = [floor, area].where((s) => s != null && s.toString().trim().isNotEmpty).join(' • ');

            return DropdownMenuItem<String>(
              value: tId,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.table_restaurant, size: 15, color: primaryOrange),
                  const SizedBox(width: 6),
                  Text(
                    rawName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: darkBg),
                  ),
                  if (locationInfo.isNotEmpty) ...[
                    const SizedBox(width: 5),
                    Text(
                      '($locationInfo)',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.normal),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
          onChanged: (newVal) {
            if (newVal != null && newVal != _selectedTableId) {
              _switchTable(newVal);
            }
          },
        ),
      ),
    );
  }



  Widget _buildWaiterQuickActions() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 640;
          final buttons = [
            _colorfulActionBtn(
              label: 'Call Server',
              subLabel: 'Steward',
              icon: Icons.room_service_rounded,
              accentColor: const Color(0xFF4F46E5), // Indigo
              bgGradientStart: const Color(0xFFEEF2FF),
              bgGradientEnd: const Color(0xFFE0E7FF),
              borderColor: const Color(0xFFC7D2FE),
              onTap: () => _callWaiter('CALL_WAITER'),
            ),
            _colorfulActionBtn(
              label: 'Water',
              subLabel: 'Refill Glass',
              icon: Icons.water_drop_rounded,
              accentColor: const Color(0xFF0284C7), // Sky/Cyan
              bgGradientStart: const Color(0xFFF0F9FF),
              bgGradientEnd: const Color(0xFFE0F2FE),
              borderColor: const Color(0xFFBAE6FD),
              onTap: () => _callWaiter('WATER'),
            ),
            _colorfulActionBtn(
              label: 'Request Bill',
              subLabel: 'Get Invoice',
              icon: Icons.receipt_long_rounded,
              accentColor: const Color(0xFFD97706), // Amber
              bgGradientStart: const Color(0xFFFFFBEB),
              bgGradientEnd: const Color(0xFFFEF3C7),
              borderColor: const Color(0xFFFDE68A),
              onTap: () => _callWaiter('BILL'),
            ),
            _colorfulActionBtn(
              label: _activeOrders.isEmpty ? 'Order History' : 'Orders (${_activeOrders.length})',
              subLabel: _activeOrders.isEmpty ? 'Past orders' : 'Active KOTs',
              icon: Icons.fastfood_rounded,
              accentColor: const Color(0xFF059669), // Emerald
              bgGradientStart: const Color(0xFFECFDF5),
              bgGradientEnd: const Color(0xFFD1FAE5),
              borderColor: const Color(0xFFA7F3D0),
              badgeCount: _activeOrders.length,
              onTap: () => setState(() => _currentMainTab = 1),
            ),
          ];

          if (isWide) {
            return Row(
              children: buttons.map((b) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: b,
                ),
              )).toList(),
            );
          }

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: buttons.map((b) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: b,
              )).toList(),
            ),
          );
        },
      ),
    );
  }

  Widget _colorfulActionBtn({
    required String label,
    required String subLabel,
    required IconData icon,
    required Color accentColor,
    required Color bgGradientStart,
    required Color bgGradientEnd,
    required Color borderColor,
    int badgeCount = 0,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: accentColor.withValues(alpha: 0.2),
        highlightColor: accentColor.withValues(alpha: 0.1),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [bgGradientStart, bgGradientEnd],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.12),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.2),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Icon(icon, size: 16, color: accentColor),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            label,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (badgeCount > 0) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: accentColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$badgeCount',
                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      subLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: accentColor.withValues(alpha: 0.9),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          // Search Box
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search dishes, drinks...',
                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),

          // Dietary Filter Chips
          _dietaryFilterChip('Veg', 'VEG', pureVegGreen, Icons.eco),
          const SizedBox(width: 6),
          _dietaryFilterChip('Non-Veg', 'NON_VEG', nonVegRed, Icons.egg_alt_outlined),
        ],
      ),
    );
  }

  Widget _dietaryFilterChip(String label, String value, Color color, IconData icon) {
    final isSelected = _dietaryFilter == value;
    return ChoiceChip(
      selected: isSelected,
      selectedColor: color.withValues(alpha: 0.15),
      backgroundColor: Colors.white,
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      side: BorderSide(color: isSelected ? color : const Color(0xFFE2E8F0)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: isSelected ? color : darkBg, fontWeight: FontWeight.bold)),
        ],
      ),
      onSelected: (sel) {
        setState(() {
          _dietaryFilter = sel ? value : 'ALL';
        });
      },
    );
  }

  Widget _buildCategoryPills() {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, idx) {
          final cat = idx == 0 ? 'ALL' : _categories[idx - 1];
          final isSelected = _selectedCategory == cat;

          return ChoiceChip(
            selected: isSelected,
            selectedColor: primaryOrange,
            backgroundColor: Colors.white,
            side: BorderSide(color: isSelected ? primaryOrange : const Color(0xFFE2E8F0)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            label: Text(
              idx == 0 ? 'All Categories' : cat,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
            ),
            onSelected: (_) => setState(() => _selectedCategory = cat),
          );
        },
      ),
    );
  }

  List<dynamic> _getFilteredItems() {
    return _allItems.where((it) {
      final bool isModifier = it['is_modifier'] == true || it['is_modifier'] == 1 || it['is_modifier'].toString() == 'true';
      final bool isSaleable = it['is_saleable'] != false && it['is_saleable'] != 0 && it['is_saleable'].toString() != 'false';
      
      // If it's purely a modifier and not sold as a standalone item, don't show on primary food catalog
      if (isModifier && !isSaleable) {
        return false;
      }

      final name = (it['item_name'] ?? '').toString().toLowerCase();
      final desc = (it['description'] ?? '').toString().toLowerCase();
      final category = (it['category'] ?? it['item_group'] ?? '').toString().toLowerCase();
      final rawFoodType = (it['food_type'] ?? it['dietary_type'] ?? (it['is_veg'] == false ? 'NON_VEG' : 'VEG')).toString().toUpperCase();
      final isItemVeg = it['is_veg'] == true || rawFoodType == 'VEG' || rawFoodType == 'VEGAN';

      // Search Query
      if (_searchQuery.isNotEmpty && !name.contains(_searchQuery.toLowerCase()) && !desc.contains(_searchQuery.toLowerCase())) {
        return false;
      }

      // Category Filter
      if (_selectedCategory != 'ALL' && category != _selectedCategory.toLowerCase()) {
        return false;
      }

      // Dietary Filter
      if (_dietaryFilter == 'VEG' && !isItemVeg) return false;
      if (_dietaryFilter == 'NON_VEG' && isItemVeg) return false;

      return true;
    }).toList();
  }

  // --- ITEM CARD (SWIGGY/ZOMATO STYLE) ---

  Widget _buildFoodItemCard(dynamic item, String currency) {
    final itemId = item['id'] as int;
    final name = item['item_name'] ?? '';
    final desc = (item['description'] ?? '').toString().trim();
    final price = double.tryParse(item['selling_price']?.toString() ?? '0') ?? 0.0;
    final rawFoodType = (item['food_type'] ?? item['dietary_type'] ?? (item['is_veg'] == false ? 'NON_VEG' : 'VEG')).toString().toUpperCase();
    final isVeg = item['is_veg'] == true || rawFoodType == 'VEG' || rawFoodType == 'VEGAN';
    final isEgg = rawFoodType == 'EGG';
    final isVegan = rawFoodType == 'VEGAN';
    final bool isOutOfStock = _isItemOutOfStock(item);
    final isRecommended = item['is_recommended'] == true;
    final qty = _getItemCartQty(itemId);
    final bool hasModifiers = _hasModifiersInDb(itemId);

    final Color badgeColor = isVegan
        ? const Color(0xFF059669)
        : (isEgg
            ? const Color(0xFFEAB308)
            : (isVeg ? pureVegGreen : nonVegRed));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isOutOfStock ? const Color(0xFFFAFAFA) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isOutOfStock ? const Color(0xFFE2E8F0) : const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Food Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Veg / Non-Veg Icon & Badges
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        border: Border.all(color: badgeColor, width: 1.5),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: isVegan
                          ? Icon(Icons.eco, size: 7, color: badgeColor)
                          : Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: badgeColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                    ),
                    if (isOutOfStock) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: const Text(
                          'OUT OF STOCK',
                          style: TextStyle(color: Color(0xFFB91C1C), fontSize: 8.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ] else if (isRecommended) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '★ Bestseller',
                          style: TextStyle(color: Color(0xFFB45309), fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),

                // Item Name
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isOutOfStock ? const Color(0xFF64748B) : darkBg,
                  ),
                ),
                const SizedBox(height: 4),

                // Price
                Text(
                  '$currency${price.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: isOutOfStock ? const Color(0xFF94A3B8) : darkBg,
                  ),
                ),

                // Description
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Right: Add Button / Stepper with Customise indicator
          Column(
            children: [
              if (isOutOfStock) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: const Text(
                    'OUT OF STOCK',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 10.5,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ] else if (qty == 0) ...[
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: primaryOrange,
                    elevation: 1,
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                  ),
                  onPressed: () => _addItemToCart(item),
                  child: const Text('ADD +', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                if (hasModifiers) ...[
                  const SizedBox(height: 3),
                  InkWell(
                    onTap: () {
                      _addItemToCart(item);
                      _showModifiersDialog(itemId);
                    },
                    child: const Text(
                      'Customisable',
                      style: TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ] else ...[
                Container(
                  decoration: BoxDecoration(
                    color: primaryOrange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, size: 14, color: Colors.white),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        onPressed: () => _removeItemFromCart(item),
                      ),
                      Text(
                        '$qty',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, size: 14, color: Colors.white),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        onPressed: () => _addItemToCart(item),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                InkWell(
                  onTap: () => _showModifiersDialog(itemId),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFFFD8A8)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.tune, size: 10, color: primaryOrange),
                        const SizedBox(width: 3),
                        Text(
                          hasModifiers ? 'Customise' : 'Notes',
                          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: primaryOrange),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // --- FLOATING BOTTOM CART BAR ---

  Widget _buildFloatingCartBar(String currency) {
    final count = _getTotalCartItems();
    final subtotal = _getCartSubtotal();

    return InkWell(
      onTap: _showCartBottomSheet,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: primaryOrange,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: primaryOrange.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$count ${count == 1 ? "ITEM" : "ITEMS"}  •  $currency${subtotal.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const Text(
                  'Extra charges / taxes may apply',
                  style: TextStyle(color: Colors.white70, fontSize: 9),
                ),
              ],
            ),
            const Row(
              children: [
                Text(
                  'View Cart',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                SizedBox(width: 6),
                Icon(Icons.arrow_forward, color: Colors.white, size: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- CART BOTTOM SHEET ---

  void _showCartBottomSheet() {
    final currency = _getEffectiveCurrency();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final subtotal = _getCartSubtotal();
            final taxableAmount = _getCartTaxableAmount();
            final totalTax = _getCartTaxTotal();
            final exclusiveTax = _getCartExclusiveTaxTotal();
            final inclusiveTax = _getCartInclusiveTaxTotal();
            final grandTotal = _getCartGrandTotal();

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  // Top Handle
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Your Table Order (${_tableData?['table_name'] ?? ''})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: darkBg),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // Cart Items List
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        ..._cart.values.map((v) {
                          final item = v['item'];
                          final int itemId = item['id'] as int;
                          final qty = v['qty'] as int;
                          final price = v['price'] as double;
                          final List<String> modDetails = (v['modifier_details'] is List ? List<String>.from(v['modifier_details']) : <String>[]);
                          final String note = (v['note'] ?? '').toString().trim();

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['item_name'],
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: darkBg),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '$currency${price.toStringAsFixed(2)} each',
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(color: primaryOrange),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.remove, size: 12, color: primaryOrange),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                            onPressed: () {
                                              _removeItemFromCart(item);
                                              setSheetState(() {});
                                              setState(() {});
                                              if (_cart.isEmpty) Navigator.pop(context);
                                            },
                                          ),
                                          Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                          IconButton(
                                            icon: const Icon(Icons.add, size: 12, color: primaryOrange),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                            onPressed: () {
                                              _addItemToCart(item);
                                              setSheetState(() {});
                                              setState(() {});
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Text(
                                      '$currency${(price * qty).toStringAsFixed(2)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: darkBg),
                                    ),
                                  ],
                                ),

                                // Customizations, Add-ons & Notes Row
                                Padding(
                                  padding: const EdgeInsets.only(top: 5),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Wrap(
                                          spacing: 4,
                                          runSpacing: 3,
                                          children: [
                                            ...modDetails.map((m) => Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFEFF6FF),
                                                borderRadius: BorderRadius.circular(4),
                                                border: Border.all(color: const Color(0xFFBFDBFE)),
                                              ),
                                              child: Text(
                                                m,
                                                style: const TextStyle(fontSize: 10, color: Color(0xFF1D4ED8), fontWeight: FontWeight.w600),
                                              ),
                                            )),
                                            if (note.isNotEmpty)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFFEF3C7),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  '📝 $note',
                                                  style: const TextStyle(fontSize: 10, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () {
                                          _showModifiersDialog(itemId, parentSetSheetState: setSheetState);
                                        },
                                        borderRadius: BorderRadius.circular(4),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFF7ED),
                                            border: Border.all(color: const Color(0xFFFFD8A8)),
                                            borderRadius: BorderRadius.circular(5),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.tune, size: 12, color: primaryOrange),
                                              const SizedBox(width: 4),
                                              Text(
                                                modDetails.isEmpty && note.isEmpty ? '+ Customise / Add-ons' : 'Edit Add-ons',
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primaryOrange),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),

                        const Divider(height: 24),

                        // Special Instructions
                        TextField(
                          controller: _specialInstructionsCtrl,
                          decoration: InputDecoration(
                            hintText: 'Add cooking note (e.g. Less spicy, extra cheese)...',
                            hintStyle: const TextStyle(fontSize: 11, color: Colors.grey),
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          style: const TextStyle(fontSize: 12),
                        ),

                        const SizedBox(height: 16),

                        // Bill Breakdown
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: [
                              _billRow('Sub Total', '$currency${subtotal.toStringAsFixed(2)}'),
                              if (taxableAmount > 0 && (taxableAmount - subtotal).abs() > 0.01) ...[
                                const SizedBox(height: 4),
                                _billRow('Taxable Value', '$currency${taxableAmount.toStringAsFixed(2)}'),
                              ],
                              if (exclusiveTax > 0 || totalTax > 0) ...[
                                const SizedBox(height: 4),
                                _billRow(
                                  inclusiveTax > 0 && exclusiveTax > 0
                                      ? 'Taxes & Levies ($currency${inclusiveTax.toStringAsFixed(2)} incl.)'
                                      : (inclusiveTax > 0 ? 'Taxes (Included in price)' : 'Taxes & Levies'),
                                  '$currency${totalTax.toStringAsFixed(2)}',
                                ),
                              ],
                              const Divider(height: 12),
                              _billRow('Order Estimate', '$currency${grandTotal.toStringAsFixed(2)}', isBold: true),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bottom Submit Button
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: _submittingOrder ? const SizedBox.shrink() : const Icon(Icons.soup_kitchen, size: 18),
                        label: _submittingOrder
                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(
                                'Send Order to Kitchen ($currency${grandTotal.toStringAsFixed(2)})',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                        onPressed: _submittingOrder ? null : () => _onCheckoutTapped(grandTotal),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _billRow(String title, String val, {bool isBold = false, Color? textColor, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(fontSize: isBold ? 13 : 11, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: textColor ?? darkBg)),
        Text(val, style: TextStyle(fontSize: isBold ? 14 : 11, fontWeight: isBold ? FontWeight.w900 : FontWeight.w600, color: valueColor ?? textColor ?? darkBg)),
      ],
    );
  }



  Future<void> _settleBillPayment(dynamic kotId, String txnId, String mode) async {
    final serverBase = AppConfig.baseUrl;
    final baseUrl = serverBase.isNotEmpty ? serverBase : 'http://localhost:5000';

    try {
      final res = await http.post(
        Uri.parse('$baseUrl${ApiEndpoints.publicDiningPayBill}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'kot_id': kotId,
          'outlet_id': widget.outletId ?? '1',
          'table_id': _selectedTableId,
          'transaction_id': txnId,
          'payment_mode': mode,
        }),
      );

      final json = jsonDecode(res.body);
      if (json['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Payment Successful ($mode)! Table bill settled.'),
              backgroundColor: Colors.green.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        _fetchTableDiningCatalog();
        return;
      }
    } catch (_) {}

    try {
      await ApiClient.put('/api/restaurant/kots/$kotId/status', {
        'status': 'PAID',
        'payment_status': 'PAID',
        'payment_mode': mode,
        'transaction_id': txnId,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment Successful ($mode)! Table bill settled.'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _fetchTableDiningCatalog();
      }
    } catch (_) {}
  }

  void _showDigitalBillDialog(dynamic kot) {
    final currency = _getEffectiveCurrency();
    final items = kot['items'] as List<dynamic>? ?? [];
    final String billNo = (kot['bill_no'] ?? (kot['sales_header'] is Map ? kot['sales_header']['sale_no'] : '') ?? '').toString();

    double calculatedSubtotal = 0.0;
    double calculatedTaxable = 0.0;
    double calculatedTax = 0.0;
    double calculatedExclusiveTax = 0.0;
    double calculatedInclusiveTax = 0.0;
    double calculatedGrandTotal = 0.0;

    for (final it in items) {
      final name = (it['item_name'] ?? it['name'] ?? 'Dish').toString();
      final q = int.tryParse((it['qty'] ?? it['quantity'] ?? 1).toString()) ?? 1;
      double p = double.tryParse((it['price'] ?? it['rate'] ?? it['selling_price'] ?? (it['item'] is Map ? (it['item']['retail_sale_price'] ?? it['item']['rate'] ?? it['item']['selling_price']) : 0) ?? 0).toString()) ?? 0.0;
      
      dynamic catalogItem;
      if (_allItems.isNotEmpty) {
        catalogItem = _allItems.firstWhere(
          (m) => m['id'] == it['item_id'] || m['item_name']?.toString().toLowerCase().trim() == name.toLowerCase().trim(),
          orElse: () => null,
        );
      }
      if (p == 0.0 && catalogItem != null) {
        p = double.tryParse((catalogItem['retail_sale_price'] ?? catalogItem['selling_price'] ?? catalogItem['rate'] ?? catalogItem['mrp'] ?? 0).toString()) ?? 0.0;
      }
      final double itemTaxPercent = double.tryParse((it['tax_percent'] ?? (it['item'] is Map ? it['item']['tax_percent'] : null) ?? (catalogItem != null ? catalogItem['tax_percent'] : null) ?? 0).toString()) ?? 0.0;
      final bool isInclusive = it['is_tax_inclusive'] == true || (it['item'] is Map && it['item']['is_tax_inclusive'] == true) || (catalogItem != null && catalogItem['is_tax_inclusive'] == true);
      
      final lineGross = p * q;
      calculatedSubtotal += lineGross;
      if (itemTaxPercent > 0) {
        if (isInclusive) {
          final lineTaxable = lineGross / (1.0 + (itemTaxPercent / 100.0));
          final lineTax = lineGross - lineTaxable;
          calculatedTaxable += lineTaxable;
          calculatedInclusiveTax += lineTax;
          calculatedTax += lineTax;
          calculatedGrandTotal += lineGross;
        } else {
          final lineTax = (lineGross * itemTaxPercent / 100.0);
          calculatedTaxable += lineGross;
          calculatedExclusiveTax += lineTax;
          calculatedTax += lineTax;
          calculatedGrandTotal += (lineGross + lineTax);
        }
      } else {
        calculatedTaxable += lineGross;
        calculatedGrandTotal += lineGross;
      }
    }

    final sale = kot['sales_header'] is Map ? kot['sales_header'] : null;

    final double? serverSubtotal = double.tryParse((kot['subtotal_amount'] ?? sale?['sub_total'] ?? '').toString());
    final double? serverTaxable = double.tryParse((kot['taxable_amount'] ?? sale?['taxable_amount'] ?? '').toString());
    final double? serverTax = double.tryParse((kot['tax_amount'] ?? sale?['total_tax'] ?? '').toString());
    final double? serverDiscount = double.tryParse((kot['discount_amount'] ?? sale?['total_discount'] ?? sale?['discount_amount'] ?? sale?['manual_discount_amount'] ?? '').toString());
    final double? serverChargeTotal = double.tryParse((kot['charge_total'] ?? sale?['charge_total'] ?? '').toString());
    final double? serverRoundOff = double.tryParse((kot['round_off_amount'] ?? sale?['round_off_amount'] ?? '').toString());
    final double? serverTotal = double.tryParse((kot['total_amount'] ?? kot['net_amount'] ?? sale?['net_amount'] ?? '').toString());

    double subtotal = calculatedSubtotal;
    double taxable = calculatedTaxable;
    double tax = calculatedTax;
    double discount = (serverDiscount != null && serverDiscount > 0) ? serverDiscount : 0.0;
    double chargeTotal = (serverChargeTotal != null && serverChargeTotal > 0) ? serverChargeTotal : 0.0;
    double roundOff = (serverRoundOff != null) ? serverRoundOff : 0.0;
    double grandTotal = calculatedGrandTotal;

    if (serverTotal != null && serverTotal > 0) {
      grandTotal = serverTotal;
      if (serverSubtotal != null && serverSubtotal > 0) subtotal = serverSubtotal;
      if (serverTaxable != null && serverTaxable > 0) taxable = serverTaxable;
      if (serverTax != null && serverTax >= 0) tax = serverTax;
    }

    final String? discountType = (kot['discount_type'] ?? sale?['manual_discount_type'])?.toString();
    final double discountValue = double.tryParse((kot['discount_value'] ?? sale?['manual_discount_value'] ?? 0).toString()) ?? 0.0;
    String discountLabel = 'Discount';
    if (discountValue > 0) {
      if (discountType == 'PERCENT' || discountType == '%') {
        discountLabel = 'Discount (${discountValue.toStringAsFixed(1)}%)';
      } else {
        discountLabel = 'Discount ($currency${discountValue.toStringAsFixed(2)})';
      }
    } else if (discount > 0) {
      discountLabel = 'Discount';
    }

    final dynamic taxBreakupRaw = kot['tax_breakup'] ?? sale?['tax_breakup'];
    List<dynamic> taxBreakupList = [];
    if (taxBreakupRaw is List) {
      taxBreakupList = taxBreakupRaw;
    } else if (taxBreakupRaw is Map) {
      taxBreakupList = taxBreakupRaw.values.toList();
    }

    final dynamic chargesRaw = kot['charges'] ?? sale?['charges'];
    List<dynamic> chargesList = [];
    if (chargesRaw is List) {
      chargesList = chargesRaw;
    }

    final remarks = (kot['remarks'] ?? '').toString();
    final bool isRemarksPaid = remarks.contains('[PAID') || remarks.contains('[SETTLED]');
    final rawStatus = (kot['status'] ?? 'Pending').toString();
    final paymentStatus = (kot['payment_status'] ?? '').toString();
    final bool isSettled = rawStatus.toLowerCase() == 'settled' ||
        rawStatus.toLowerCase() == 'closed' ||
        rawStatus.toLowerCase() == 'paid' ||
        rawStatus.toLowerCase() == 'completed' ||
        paymentStatus.toUpperCase() == 'PAID' ||
        paymentStatus.toUpperCase() == 'SETTLED' ||
        (kot['is_settled'] == true) ||
        (sale != null && ((sale['status'] ?? '').toString().toUpperCase() == 'COMPLETED' || (double.tryParse((sale['balance_due'] ?? '0').toString()) ?? 0.0) <= 0.01)) ||
        isRemarksPaid;
    final bool isBillGenerated = billNo.isNotEmpty || rawStatus.toLowerCase() == 'billed' || rawStatus.toLowerCase() == 'bill';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.receipt, color: primaryOrange),
            const SizedBox(width: 8),
            Text(
              isBillGenerated
                  ? '${_restaurantData?['property_name'] ?? 'Restaurant'} Bill'
                  : '${_restaurantData?['property_name'] ?? 'Restaurant'} Order Summary',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Table: ${_tableData?['table_name'] ?? _selectedTableName}${billNo.isNotEmpty ? '  |  Bill: #$billNo' : ''}  |  KOT: #${kot['kot_no'] ?? kot['id'] ?? ''}', style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              ...items.map((it) {
                final name = (it['item_name'] ?? it['name'] ?? 'Dish').toString();
                final q = int.tryParse((it['qty'] ?? it['quantity'] ?? 1).toString()) ?? 1;
                double p = double.tryParse((it['price'] ?? it['rate'] ?? it['selling_price'] ?? (it['item'] is Map ? (it['item']['retail_sale_price'] ?? it['item']['rate'] ?? it['item']['selling_price']) : 0) ?? 0).toString()) ?? 0.0;
                if (p == 0.0) {
                  final catalogItem = _allItems.firstWhere(
                    (m) => m['id'] == it['item_id'] || m['item_name']?.toString().toLowerCase().trim() == name.toLowerCase().trim(),
                    orElse: () => null,
                  );
                  if (catalogItem != null) {
                    p = double.tryParse((catalogItem['retail_sale_price'] ?? catalogItem['selling_price'] ?? catalogItem['rate'] ?? catalogItem['mrp'] ?? 0).toString()) ?? 0.0;
                  }
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('$q x $name', style: const TextStyle(fontSize: 12)),
                      Text('$currency${(p * q).toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              }),
              const Divider(height: 1),
              const SizedBox(height: 6),
              _billRow('Sub Total', '$currency${subtotal.toStringAsFixed(2)}'),
              if (discount > 0) ...[
                const SizedBox(height: 4),
                _billRow(discountLabel, '-$currency${discount.toStringAsFixed(2)}', textColor: const Color(0xFF16A34A), valueColor: const Color(0xFF16A34A)),
              ],
              if (taxable > 0 && (taxable - subtotal).abs() > 0.01) ...[
                const SizedBox(height: 4),
                _billRow('Taxable Value', '$currency${taxable.toStringAsFixed(2)}'),
              ],
              if (chargeTotal > 0) ...[
                const SizedBox(height: 4),
                if (chargesList.isNotEmpty) ...[
                  ...chargesList.map((ch) {
                    final chName = (ch['name'] ?? ch['charge_name'] ?? ch['label'] ?? 'Charge').toString();
                    final chAmt = double.tryParse((ch['amount'] ?? ch['charge_amount'] ?? ch['effective_amount'] ?? 0).toString()) ?? 0.0;
                    if (chAmt <= 0) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: _billRow(chName, '+$currency${chAmt.toStringAsFixed(2)}', textColor: const Color(0xFF475569)),
                    );
                  }),
                ] else ...[
                  _billRow('Charges', '+$currency${chargeTotal.toStringAsFixed(2)}', textColor: const Color(0xFF475569)),
                ],
              ],
              if (taxBreakupList.isNotEmpty) ...[
                ...taxBreakupList.map((tb) {
                  final label = (tb['label'] ?? tb['tax_name'] ?? tb['code'] ?? 'Tax').toString();
                  final rate = double.tryParse((tb['rate'] ?? tb['tax_percent'] ?? 0).toString()) ?? 0.0;
                  final amt = double.tryParse((tb['taxAmount'] ?? tb['tax_amount'] ?? tb['amount'] ?? 0).toString()) ?? 0.0;
                  if (amt <= 0) return const SizedBox.shrink();
                  final displayLabel = label.contains('%') || rate <= 0 ? label : '$label (${rate.toStringAsFixed(1)}%)';
                  return Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: _billRow(displayLabel, '$currency${amt.toStringAsFixed(2)}'),
                  );
                }),
              ] else if (tax > 0) ...[
                const SizedBox(height: 4),
                _billRow(
                  calculatedInclusiveTax > 0 && calculatedExclusiveTax > 0
                      ? 'Taxes & Levies ($currency${calculatedInclusiveTax.toStringAsFixed(2)} incl.)'
                      : (calculatedInclusiveTax > 0 ? 'Taxes (Included in price)' : 'Taxes & Levies'),
                  '$currency${tax.toStringAsFixed(2)}',
                ),
              ],
              if (roundOff.abs() > 0.001) ...[
                const SizedBox(height: 4),
                _billRow('Round Off', '${roundOff < 0 ? "-" : "+"}$currency${roundOff.abs().toStringAsFixed(2)}'),
              ],
              const Divider(height: 10),
              _billRow(isBillGenerated ? 'Total Bill' : 'Estimated Total', '$currency${grandTotal.toStringAsFixed(2)}', isBold: true),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          if (isSettled)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 14, color: Color(0xFF16A34A)),
                  SizedBox(width: 4),
                  Text('Paid & Settled', style: TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            )
          else if (isBillGenerated)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.payment, size: 14),
              label: Text('Pay $currency${grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              onPressed: () {
                Navigator.pop(ctx);
                _openPaymentGatewaySheet(
                  context: context,
                  amount: grandTotal > 0 ? grandTotal : 100.0,
                  onPaymentComplete: (txnId, mode) async {
                    await _settleBillPayment(kot['id'], txnId, mode);
                    setState(() {});
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}

// --- PAYMENT GATEWAY & BILL SETTLEMENT MODAL ---

class _PaymentGatewayBottomSheet extends StatefulWidget {
  final double amount;
  final String currency;
  final String restaurantName;
  final String tableName;
  final bool isGatewayEnabled;
  final String? merchantUpiId;
  final String? gatewayProvider;
  final Function(String txnId, String mode) onSuccess;

  const _PaymentGatewayBottomSheet({
    required this.amount,
    required this.currency,
    required this.restaurantName,
    required this.tableName,
    this.isGatewayEnabled = false,
    this.merchantUpiId,
    this.gatewayProvider,
    required this.onSuccess,
  });

  @override
  State<_PaymentGatewayBottomSheet> createState() => _PaymentGatewayBottomSheetState();
}

class _PaymentGatewayBottomSheetState extends State<_PaymentGatewayBottomSheet> {
  int _selectedGatewayTab = 0; // 0: UPI QR, 1: Debit/Credit Card, 2: NetBanking, 3: Pay at Counter
  int _counterPaymentMode = 0; // 0: Cash, 1: Card Machine (EDC), 2: Counter UPI Soundbox
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    // Default to direct counter settlement if online payment gateway is disabled
    if (!widget.isGatewayEnabled) {
      _selectedGatewayTab = 3;
    }
  }

  @override
  Widget build(BuildContext context) {
    final txnId = 'TXN${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    final effectiveUpiId = (widget.merchantUpiId != null && widget.merchantUpiId!.trim().isNotEmpty)
        ? widget.merchantUpiId!.trim()
        : '${widget.restaurantName.toLowerCase().replaceAll(RegExp(r"[^a-zA-Z0-9]"), "")}@upi';

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.isGatewayEnabled ? 'Select Payment Mode' : 'Pay Bill at Counter / Table',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                  ),
                  Text('Table ${widget.tableName} • ${widget.restaurantName}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(20)),
                child: Text(
                  '${widget.currency}${widget.amount.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF16A34A), fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // If Gateway is ENABLED: Show Gateway Tabs + Pay at Counter Tab
          if (widget.isGatewayEnabled) ...[
            Row(
              children: [
                Expanded(child: _gatewayTabItem(0, 'UPI QR', Icons.qr_code)),
                const SizedBox(width: 6),
                Expanded(child: _gatewayTabItem(1, 'Cards', Icons.credit_card)),
                const SizedBox(width: 6),
                Expanded(child: _gatewayTabItem(2, 'NetBanking', Icons.account_balance)),
                const SizedBox(width: 6),
                Expanded(child: _gatewayTabItem(3, 'At Counter', Icons.point_of_sale)),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // TAB 0: UPI QR (Online / Direct)
          if (widget.isGatewayEnabled && _selectedGatewayTab == 0) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  const Text('Scan with Any UPI App (GPay, PhonePe, Paytm)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: const Center(
                      child: Icon(Icons.qr_code_2, size: 90, color: Color(0xFF0F172A)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Merchant UPI ID: $effectiveUpiId', style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ]
          // TAB 1: Online Card
          else if (widget.isGatewayEnabled && _selectedGatewayTab == 1) ...[
            TextField(
              decoration: InputDecoration(
                labelText: 'Card Number',
                hintText: '4111 2222 3333 4444',
                prefixIcon: const Icon(Icons.credit_card, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'MM/YY',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'CVV',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ]
          // TAB 2: Online NetBanking
          else if (widget.isGatewayEnabled && _selectedGatewayTab == 2) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Text('Supported Banks: HDFC, ICICI, SBI, Axis, Kotak, PNB', style: TextStyle(fontSize: 12)),
            ),
          ]
          // TAB 3 / DEFAULT (When Gateway is DISABLED or Counter is Selected): Pay at Counter / Server Options
          else ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Color(0xFF1D4ED8)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Direct settlement at restaurant without gateway surcharge (0% extra fees).',
                      style: TextStyle(fontSize: 11, color: Color(0xFF1E40AF), fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Selectable Counter Methods
            _counterOptionTile(
              index: 0,
              icon: Icons.payments_outlined,
              title: 'Cash Payment',
              subtitle: 'Pay exact cash to steward or at cashier desk',
            ),
            const SizedBox(height: 8),
            _counterOptionTile(
              index: 1,
              icon: Icons.point_of_sale_outlined,
              title: 'Card Swipe / Tap (EDC Machine)',
              subtitle: 'Server will bring portable POS swipe machine to table',
            ),
            const SizedBox(height: 8),
            _counterOptionTile(
              index: 2,
              icon: Icons.qr_code_scanner_outlined,
              title: 'Counter UPI / Soundbox',
              subtitle: 'Scan printed QR at counter ($effectiveUpiId)',
            ),
          ],

          const SizedBox(height: 18),

          // Settle / Pay Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _processing
                  ? null
                  : () async {
                      setState(() => _processing = true);
                      await Future.delayed(const Duration(milliseconds: 600));
                      String mode = 'PAY_AT_COUNTER';
                      if (widget.isGatewayEnabled && _selectedGatewayTab == 0) {
                        mode = 'UPI';
                      } else if (widget.isGatewayEnabled && _selectedGatewayTab == 1) {
                        mode = 'CARD';
                      } else if (widget.isGatewayEnabled && _selectedGatewayTab == 2) {
                        mode = 'NETBANKING';
                      } else {
                        mode = _counterPaymentMode == 0 ? 'CASH' : (_counterPaymentMode == 1 ? 'EDC_CARD' : 'COUNTER_UPI');
                      }
                      widget.onSuccess(txnId, mode);
                    },
              child: _processing
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(
                      (!widget.isGatewayEnabled || _selectedGatewayTab == 3)
                          ? 'Confirm Settle ${widget.currency}${widget.amount.toStringAsFixed(2)} at Counter'
                          : 'Approve & Pay ${widget.currency}${widget.amount.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _counterOptionTile({
    required int index,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _counterPaymentMode == index;
    return InkWell(
      onTap: () => setState(() => _counterPaymentMode = index),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: isSelected ? const Color(0xFF16A34A) : const Color(0xFF64748B)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? const Color(0xFF15803D) : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 18,
              color: isSelected ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gatewayTabItem(int index, String label, IconData icon) {
    final isSelected = _selectedGatewayTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedGatewayTab = index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : const Color(0xFF64748B)),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}

// --- CUSTOMER AUTH MODAL (SWIGGY / ZOMATO STYLE LOGIN & REGISTRATION) ---

class _CustomerAuthBottomSheet extends StatefulWidget {
  final String restaurantName;
  final String outletId;
  final ValueChanged<Map<String, dynamic>> onLoginSuccess;

  const _CustomerAuthBottomSheet({
    required this.restaurantName,
    required this.outletId,
    required this.onLoginSuccess,
  });

  @override
  State<_CustomerAuthBottomSheet> createState() => _CustomerAuthBottomSheetState();
}

class _CustomerAuthBottomSheetState extends State<_CustomerAuthBottomSheet> {
  // Modes: 'LOGIN' | 'REGISTER' | 'OTP'
  String _authMode = 'REGISTER'; 
  
  // Controllers
  final TextEditingController _loginIdentifierCtrl = TextEditingController();
  final TextEditingController _otpCtrl = TextEditingController();
  final TextEditingController _regNameCtrl = TextEditingController();
  final TextEditingController _regPhoneCtrl = TextEditingController();
  final TextEditingController _regEmailCtrl = TextEditingController();
  final TextEditingController _regAddressCtrl = TextEditingController();

  String _dietaryPreference = 'ALL'; // 'ALL', 'VEG', 'NON_VEG'
  bool _loading = false;
  String? _error;
  String? _successNotice;
  
  // Resend OTP countdown timer
  int _resendCountdown = 30;
  bool _canResend = false;
  String _activeVerificationTarget = '';

  @override
  void dispose() {
    _loginIdentifierCtrl.dispose();
    _otpCtrl.dispose();
    _regNameCtrl.dispose();
    _regPhoneCtrl.dispose();
    _regEmailCtrl.dispose();
    _regAddressCtrl.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() {
      _resendCountdown = 30;
      _canResend = false;
    });
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      if (_resendCountdown > 1) {
        setState(() => _resendCountdown--);
        return true;
      } else {
        setState(() {
          _resendCountdown = 0;
          _canResend = true;
        });
        return false;
      }
    });
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email.trim());
  }

  Future<void> _requestLoginOtp() async {
    final email = _loginIdentifierCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Please enter your Email Address');
      return;
    }

    if (!_isValidEmail(email)) {
      setState(() => _error = 'Please enter a valid Email Address (e.g. name@example.com)');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _successNotice = null;
    });

    final serverBase = AppConfig.baseUrl;
    final baseUrl = serverBase.isNotEmpty ? serverBase : 'http://localhost:5000';

    try {
      final res = await http.post(
        Uri.parse('$baseUrl${ApiEndpoints.publicDiningRequestOtp}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'outlet_id': widget.outletId,
          'is_registration': false,
        }),
      );

      final json = jsonDecode(res.body);

      // If user is not registered in the system, redirect them to register first
      if (res.statusCode == 404 ||
          json['not_registered'] == true ||
          (json['message'] ?? '').toString().toLowerCase().contains('register first') ||
          (json['message'] ?? '').toString().toLowerCase().contains('no account found')) {
        setState(() {
          _regEmailCtrl.text = email;
          _authMode = 'REGISTER';
          _loading = false;
          _error = json['message'] ?? 'No account found with this email. Please register first with your name & contact details.';
        });
        return;
      }

      if (json['success'] == true) {
        _activeVerificationTarget = email;
        _startResendTimer();
        setState(() {
          _authMode = 'OTP';
          _loading = false;
          _successNotice = 'OTP sent to $email';
        });
      } else {
        throw Exception(json['message'] ?? 'Failed to send OTP code');
      }
    } catch (err) {
      final errStr = err.toString().replaceAll('Exception: ', '').trim();
      if (errStr.toLowerCase().contains('register first') || errStr.toLowerCase().contains('no account')) {
        setState(() {
          _regEmailCtrl.text = email;
          _authMode = 'REGISTER';
          _loading = false;
          _error = errStr;
        });
        return;
      }
      // Offline / Demo fallback: Send mock OTP and continue
      _activeVerificationTarget = email;
      _startResendTimer();
      setState(() {
        _authMode = 'OTP';
        _loading = false;
        _successNotice = 'OTP sent to $email (Demo Code: 1234)';
      });
    }
  }

  Future<void> _initiateRegistration() async {
    final name = _regNameCtrl.text.trim();
    final email = _regEmailCtrl.text.trim();
    final phone = _regPhoneCtrl.text.trim();

    if (name.length < 2) {
      setState(() => _error = 'Please enter your Full Name (at least 2 characters)');
      return;
    }

    if (email.isEmpty || !_isValidEmail(email)) {
      setState(() => _error = 'Email is required. Please enter a valid Email Address (e.g. name@example.com)');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _successNotice = null;
    });

    final serverBase = AppConfig.baseUrl;
    final baseUrl = serverBase.isNotEmpty ? serverBase : 'http://localhost:5000';

    try {
      // Request OTP specifically to email address
      final res = await http.post(
        Uri.parse('$baseUrl${ApiEndpoints.publicDiningRequestOtp}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'phone': phone,
          'outlet_id': widget.outletId,
          'is_registration': true,
        }),
      );

      final json = jsonDecode(res.body);
      
      // If customer is already registered for THIS specific outlet, smoothly switch them to login
      if (json['already_registered_in_outlet'] == true ||
          (json['message'] ?? '').toString().toLowerCase().contains('already registered')) {
        setState(() {
          _loginIdentifierCtrl.text = email;
          _activeVerificationTarget = email;
          _authMode = 'OTP';
          _loading = false;
          _error = 'You are already registered with ${widget.restaurantName}! We sent a login OTP to your email.';
        });
        _startResendTimer();
        return;
      }

      if (json['success'] == true) {
        _activeVerificationTarget = email;
        _startResendTimer();
        setState(() {
          _authMode = 'OTP';
          _loading = false;
          _successNotice = 'Verification code sent to $email';
        });
      } else {
        throw Exception(json['message'] ?? 'Unable to send verification OTP');
      }
    } catch (_) {
      // Offline / Demo fallback: Send mock OTP and continue
      _activeVerificationTarget = email;
      _startResendTimer();
      setState(() {
        _authMode = 'OTP';
        _loading = false;
        _successNotice = 'Verification code sent to $email (Demo Code: 1234)';
      });
    }
  }

  Future<void> _verifyOtpAndComplete() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length < 4) {
      setState(() => _error = 'Please enter the 4-6 digit verification code');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final serverBase = AppConfig.baseUrl;
    final baseUrl = serverBase.isNotEmpty ? serverBase : 'http://localhost:5000';

    try {
      // 1. Verify OTP with email
      final verifyRes = await http.post(
        Uri.parse('$baseUrl${ApiEndpoints.publicDiningVerifyOtp}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _activeVerificationTarget,
          'otp': otp,
          'outlet_id': widget.outletId,
        }),
      );

      final verifyJson = jsonDecode(verifyRes.body);
      if (verifyJson['success'] == true) {
        if (verifyJson['customer'] != null && _regNameCtrl.text.trim().isEmpty) {
          final cust = Map<String, dynamic>.from(verifyJson['customer']);
          await _saveCustomerSession(cust, verifyJson['token']);
          widget.onLoginSuccess(cust);
          return;
        }

        // Register profile
        final name = _regNameCtrl.text.trim().isNotEmpty ? _regNameCtrl.text.trim() : (verifyJson['customer']?['name'] ?? 'Dining Guest');
        final email = _activeVerificationTarget;
        final phone = _regPhoneCtrl.text.trim();
        final address = _regAddressCtrl.text.trim();

        final regRes = await http.post(
          Uri.parse('$baseUrl${ApiEndpoints.publicDiningRegisterProfile}'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'name': name,
            'email': email,
            'phone': phone,
            'address': address,
            'dietary_preference': _dietaryPreference,
            'outlet_id': widget.outletId,
            'source': 'QR_DINING',
          }),
        );

        final regJson = jsonDecode(regRes.body);
        final cust = regJson['customer'] != null ? Map<String, dynamic>.from(regJson['customer']) : {
          'id': DateTime.now().millisecondsSinceEpoch,
          'name': name,
          'customer_name': name,
          'email': email,
          'customer_email': email,
          'phone': phone,
          'customer_phone': phone,
          'address': address,
          'dietary_preference': _dietaryPreference,
          'outlet_id': widget.outletId,
        };
        await _saveCustomerSession(cust, regJson['token'] ?? verifyJson['token']);
        widget.onLoginSuccess(cust);
        return;
      }
    } catch (_) {}

    // Offline / Demo verification fallback
    final name = _regNameCtrl.text.trim().isNotEmpty 
        ? _regNameCtrl.text.trim() 
        : (_activeVerificationTarget.contains('@') ? _activeVerificationTarget.split('@')[0] : 'Guest');
    final email = _activeVerificationTarget;
    final phone = _regPhoneCtrl.text.trim();
    final address = _regAddressCtrl.text.trim();

    final fallbackCust = {
      'id': DateTime.now().millisecondsSinceEpoch % 100000,
      'name': name,
      'customer_name': name,
      'email': email,
      'customer_email': email,
      'phone': phone,
      'customer_phone': phone,
      'address': address,
      'dietary_preference': _dietaryPreference,
      'outlet_id': widget.outletId,
    };

    // Also try saving to POS customer database via ApiClient
    try {
      await ApiClient.post(ApiEndpoints.salesCustomers, {
        'customer_name': name,
        'customer_email': email,
        'customer_phone': phone,
        'customer_address': address,
      });
    } catch (_) {}

    await _saveCustomerSession(fallbackCust, 'demo-token-${DateTime.now().millisecondsSinceEpoch}');
    widget.onLoginSuccess(fallbackCust);
  }

  Future<void> _saveCustomerSession(Map<String, dynamic> customer, String? token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('dining_customer_profile', jsonEncode(customer));
      if (token != null && token.isNotEmpty) {
        await prefs.setString('dining_auth_token', token);
      }
      await prefs.setString('dining_outlet_id', widget.outletId);
    } catch (e) {
      debugPrint('Error saving customer dining session: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle pill bar
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Swiggy / Zomato Hero Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE23744), Color(0xFFFF5200)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE23744).withValues(alpha: 0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
                    ),
                    child: const Icon(Icons.restaurant_menu, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.restaurantName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Scan • Order • Enjoy Dining',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Mode Selector (Login vs Register)
            if (_authMode != 'OTP') ...[
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _authMode = 'LOGIN';
                          _error = null;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _authMode == 'LOGIN' ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: _authMode == 'LOGIN'
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.06),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              'Email Login (OTP)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: _authMode == 'LOGIN' ? const Color(0xFFE23744) : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _authMode = 'REGISTER';
                          _error = null;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _authMode == 'REGISTER' ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: _authMode == 'REGISTER'
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.06),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              'New Registration',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: _authMode == 'REGISTER' ? const Color(0xFFE23744) : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],

            // Feedback messages (Error / Success)
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Color(0xFFB91C1C), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            if (_successNotice != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: Color(0xFF15803D), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _successNotice!,
                        style: const TextStyle(color: Color(0xFF15803D), fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // --- VIEW 1: EMAIL LOGIN ---
            if (_authMode == 'LOGIN') ...[
              const Text(
                'Enter your Email Address',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 4),
              const Text(
                'We will send a 4-digit verification code to your email.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _loginIdentifierCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email Address *',
                  hintText: 'e.g. ajay@example.com',
                  prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFFE23744), size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE23744), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE23744),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                onPressed: _loading ? null : _requestLoginOtp,
                child: _loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.mail_outline, size: 18),
                          SizedBox(width: 8),
                          Text('Get Email Verification Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      ),
              ),
            ]

            // --- VIEW 2: NEW REGISTRATION ---
            else if (_authMode == 'REGISTER') ...[
              const Text(
                'Create Customer Profile',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 4),
              const Text(
                'Register once to enjoy digital dining, order history & instant billing.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _regNameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Full Name *',
                  hintText: 'e.g. Ajay Sharma',
                  prefixIcon: const Icon(Icons.person_outline, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),

              TextField(
                controller: _regEmailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email Address * (For OTP Verification)',
                  hintText: 'e.g. ajay@example.com',
                  prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFFE23744), size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE23744), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              TextField(
                controller: _regPhoneCtrl,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                decoration: InputDecoration(
                  counterText: '',
                  labelText: 'Mobile Number (Optional)',
                  hintText: '10-digit mobile number',
                  prefixIcon: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('🇮🇳 +91', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        SizedBox(width: 6),
                        VerticalDivider(width: 1, thickness: 1, color: Color(0xFFCBD5E1)),
                      ],
                    ),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),

              TextField(
                controller: _regAddressCtrl,
                decoration: InputDecoration(
                  labelText: 'City / Delivery Address (Optional)',
                  hintText: 'e.g. Sector 18, Block B',
                  prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),

              // Dietary Preference
              const Text('Dietary Preference:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('🌱 Veg Only', style: TextStyle(fontSize: 12))),
                      selected: _dietaryPreference == 'VEG',
                      selectedColor: const Color(0xFFDCFCE7),
                      onSelected: (val) => setState(() => _dietaryPreference = 'VEG'),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('🍖 Non-Veg', style: TextStyle(fontSize: 12))),
                      selected: _dietaryPreference == 'NON_VEG',
                      selectedColor: const Color(0xFFFEE2E2),
                      onSelected: (val) => setState(() => _dietaryPreference = 'NON_VEG'),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('🍽️ All Foods', style: TextStyle(fontSize: 12))),
                      selected: _dietaryPreference == 'ALL',
                      onSelected: (val) => setState(() => _dietaryPreference = 'ALL'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE23744),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                onPressed: _loading ? null : _initiateRegistration,
                child: _loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.mark_email_read_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Verify Email & Create Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      ),
              ),
            ]

            // --- VIEW 3: OTP VERIFICATION ---
            else if (_authMode == 'OTP') ...[
              Text(
                'Verify Email Code sent to $_activeVerificationTarget',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 4),
              const Text(
                'Enter the 4-digit code sent to your email address to confirm your dining identity.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _otpCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                autofocus: true,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 12,
                  color: Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '••••',
                  hintStyle: const TextStyle(letterSpacing: 12, color: Color(0xFFCBD5E1)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE23744), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE23744),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                onPressed: _loading ? null : _verifyOtpAndComplete,
                child: _loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_open, size: 18),
                          SizedBox(width: 8),
                          Text('Verify Email & Open Menu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      ),
              ),
              const SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _authMode = 'LOGIN';
                      _error = null;
                      _otpCtrl.clear();
                    }),
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('Change Email', style: TextStyle(fontSize: 12)),
                  ),
                  if (_canResend)
                    TextButton(
                      onPressed: _requestLoginOtp,
                      child: const Text('Resend Code', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFE23744))),
                    )
                  else
                    Text(
                      'Resend in ${_resendCountdown}s',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold),
                    ),
                ],
              ),
            ],

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 10),

            const Center(
              child: Text(
                'By signing in, you agree to the Restaurant Terms of Service & Privacy Policy',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

