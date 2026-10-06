import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/endpoints.dart';
import '../../core/config/app_config.dart';

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
  // Session & Auth state
  bool _loading = true;
  String? _errorMessage;
  Map<String, dynamic>? _restaurantData;
  Map<String, dynamic>? _tableData;
  List<dynamic> _categories = [];
  List<dynamic> _allItems = [];
  List<dynamic> _activeOrders = [];

  // Customer Profile
  Map<String, dynamic>? _customerProfile;
  bool _isLoggedIn = false;

  // Cart state: Map<itemId, {item, qty, note, modifiers}>
  final Map<int, Map<String, dynamic>> _cart = {};

  // Filters & Search
  String _selectedCategory = 'ALL';
  String _dietaryFilter = 'ALL'; // 'ALL', 'VEG', 'NON_VEG', 'EGG'
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
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.toLowerCase().trim());
    });
    _initializeDiningSession();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _specialInstructionsCtrl.dispose();
    super.dispose();
  }

  Future<void> _initializeDiningSession() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      // 1. Check local customer session
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

  Future<void> _fetchTableDiningCatalog() async {
    final serverBase = AppConfig.baseUrl;
    final baseUrl = serverBase.isNotEmpty ? serverBase : 'http://localhost:5000';
    
    final targetOutlet = widget.outletId ?? '1';
    final targetTable = widget.tableId ?? '1';

    final uri = Uri.parse('$baseUrl${ApiEndpoints.publicDiningTableInfo}?outlet_id=$targetOutlet&table_id=$targetTable');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['success'] == true && json['data'] != null) {
        final data = json['data'];
        setState(() {
          _restaurantData = data['restaurant'];
          _tableData = data['table'];
          _categories = data['categories'] ?? [];
          _allItems = data['items'] ?? [];
          _activeOrders = data['active_orders'] ?? [];
          _loading = false;
        });

        // If not logged in, prompt login modal after render
        if (!_isLoggedIn) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showAuthModal(context);
          });
        }
        return;
      }
    }

    throw Exception('Unable to load dining menu from restaurant server.');
  }

  // --- AUTHENTICATION & EMAIL OTP MODAL ---

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
          Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Welcome, ${profile['customer_name'] ?? 'Guest'}! Menu is ready.'),
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
    });
    _showAuthModal(context);
  }

  // --- CART OPERATIONS ---

  void _addItemToCart(dynamic item) {
    final itemId = item['id'] as int;
    setState(() {
      if (_cart.containsKey(itemId)) {
        _cart[itemId]!['qty'] = (_cart[itemId]!['qty'] as int) + 1;
      } else {
        _cart[itemId] = {
          'item': item,
          'qty': 1,
          'note': '',
          'price': double.tryParse(item['selling_price']?.toString() ?? '0') ?? 0.0,
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

  int _getItemCartQty(int itemId) {
    return _cart[itemId]?['qty'] as int? ?? 0;
  }

  double _getCartSubtotal() {
    double sum = 0.0;
    _cart.forEach((_, val) {
      final qty = val['qty'] as int;
      final price = val['price'] as double;
      sum += (qty * price);
    });
    return sum;
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

    try {
      final res = await http.post(
        Uri.parse('$baseUrl${ApiEndpoints.publicDiningCallWaiter}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'outlet_id': widget.outletId ?? '1',
          'table_id': widget.tableId ?? '1',
          'request_type': requestType,
          'customer_name': _customerProfile?['customer_name'] ?? 'Guest',
        }),
      );

      final json = jsonDecode(res.body);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(json['message'] ?? 'Waiter notified!'),
            backgroundColor: primaryOrange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to call waiter: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- PLACE ORDER (KOT DISPATCH) ---

  Future<void> _submitOrderToKitchen() async {
    if (_cart.isEmpty) return;
    if (!_isLoggedIn) {
      _showAuthModal(context);
      return;
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
        'special_note': v['note'],
        'kitchen_station_id': it['kitchen_station_id'],
      };
    }).toList();

    try {
      final res = await http.post(
        Uri.parse('$baseUrl${ApiEndpoints.publicDiningPlaceOrder}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'outlet_id': widget.outletId ?? '1',
          'table_id': widget.tableId ?? '1',
          'customer_id': _customerProfile?['id'],
          'customer_name': _customerProfile?['customer_name'],
          'customer_phone': _customerProfile?['customer_phone'],
          'customer_email': _customerProfile?['customer_email'],
          'items': orderItems,
          'special_instructions': _specialInstructionsCtrl.text.trim(),
          'payment_method': _paymentMethod,
        }),
      );

      final json = jsonDecode(res.body);
      if (json['success'] == true) {
        final orderData = json['data'];
        setState(() {
          _cart.clear();
          _specialInstructionsCtrl.clear();
          _submittingOrder = false;
        });

        // Close bottom sheet if open
        if (Navigator.canPop(context)) Navigator.pop(context);

        // Show Order Placed Dialog
        _showOrderSuccessDialog(orderData);

        // Refresh orders list
        _fetchTableDiningCatalog();
      } else {
        throw Exception(json['message'] ?? json['error'] ?? 'Order failed');
      }
    } catch (e) {
      setState(() => _submittingOrder = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showOrderSuccessDialog(Map<String, dynamic> orderData) {
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
              'KOT #${orderData['kot_no'] ?? ''} • Table ${orderData['table_name'] ?? ''}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: primaryOrange),
            ),
            const SizedBox(height: 4),
            Text(
              'Assigned Waiter: ${orderData['waiter_name']?.isNotEmpty == true ? orderData['waiter_name'] : "Server on Duty"}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                orderData['payment_method'] == 'ONLINE'
                    ? 'Payment Status: PAID ONLINE'
                    : 'Payment Status: Pay at Table / Settle with Waiter',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: darkBg),
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

    final currency = _restaurantData?['currency'] ?? '₹';
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

                // 2. QUICK WAITER ASSIST BUTTONS
                SliverToBoxAdapter(
                  child: _buildWaiterQuickActions(),
                ),

                // 3. SEARCH & DIETARY FILTER
                SliverToBoxAdapter(
                  child: _buildSearchAndFilters(),
                ),

                // 4. CATEGORY PILLS BAR
                SliverToBoxAdapter(
                  child: _buildCategoryPills(),
                ),

                // 5. FOOD CATALOG LIST
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
              ],
            ),

            // FLOATING BOTTOM CART BAR
            if (_cart.isNotEmpty)
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

  // --- HEADER & BANNER ---

  Widget _buildRestaurantHeader() {
    final resName = _restaurantData?['property_name'] ?? 'Grand Restaurant';
    final tableName = _tableData?['table_name'] ?? '1';
    final floorName = _tableData?['floor_name'] ?? '';
    final areaName = _tableData?['area_name'] ?? '';
    final customerName = _customerProfile?['customer_name'] ?? 'Guest';

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

              // Table Locked Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: primaryOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: primaryOrange.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.table_restaurant, size: 16, color: primaryOrange),
                    const SizedBox(width: 4),
                    Text(
                      'Table $tableName',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryOrange),
                    ),
                  ],
                ),
              ),
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

  Widget _buildWaiterQuickActions() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _quickActionBtn('Call Server', Icons.person_search_outlined, () => _callWaiter('CALL_WAITER')),
          const SizedBox(width: 8, height: 24, child: VerticalDivider(color: Color(0xFFE2E8F0))),
          _quickActionBtn('Water', Icons.water_drop_outlined, () => _callWaiter('WATER')),
          const SizedBox(width: 8, height: 24, child: VerticalDivider(color: Color(0xFFE2E8F0))),
          _quickActionBtn('Request Bill', Icons.receipt_long_outlined, () => _callWaiter('BILL')),
          if (_activeOrders.isNotEmpty) ...[
            const SizedBox(width: 8, height: 24, child: VerticalDivider(color: Color(0xFFE2E8F0))),
            _quickActionBtn('Orders (${_activeOrders.length})', Icons.timelapse_outlined, _showOrdersModal),
          ],
        ],
      ),
    );
  }

  Widget _quickActionBtn(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF0F172A)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
        ],
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
      selectedColor: color.withOpacity(0.15),
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
      final name = (it['item_name'] ?? '').toString().toLowerCase();
      final desc = (it['description'] ?? '').toString().toLowerCase();
      final category = (it['item_group'] ?? '').toString();
      final foodType = (it['food_type'] ?? '').toString().toUpperCase();

      // Search Query
      if (_searchQuery.isNotEmpty && !name.contains(_searchQuery) && !desc.contains(_searchQuery)) {
        return false;
      }

      // Category Filter
      if (_selectedCategory != 'ALL' && category != _selectedCategory) {
        return false;
      }

      // Dietary Filter
      if (_dietaryFilter == 'VEG' && !foodType.contains('VEG')) return false;
      if (_dietaryFilter == 'NON_VEG' && !foodType.contains('NON')) return false;

      return true;
    }).toList();
  }

  // --- ITEM CARD (SWIGGY/ZOMATO STYLE) ---

  Widget _buildFoodItemCard(dynamic item, String currency) {
    final itemId = item['id'] as int;
    final name = item['item_name'] ?? '';
    final desc = item['description'] ?? '';
    final price = double.tryParse(item['selling_price']?.toString() ?? '0') ?? 0.0;
    final foodType = (item['food_type'] ?? 'VEG').toString().toUpperCase();
    final isVeg = !foodType.contains('NON');
    final isRecommended = item['is_recommended'] == true;
    final qty = _getItemCartQty(itemId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
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
                // Veg / Non-Veg Icon & Bestseller tag
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        border: Border.all(color: isVeg ? pureVegGreen : nonVegRed, width: 1.5),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isVeg ? pureVegGreen : nonVegRed,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    if (isRecommended) ...[
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
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: darkBg),
                ),
                const SizedBox(height: 4),

                // Price
                Text(
                  '$currency${price.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: darkBg),
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

          // Right: Add Button / Stepper
          Column(
            children: [
              if (qty == 0)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: primaryOrange,
                    elevation: 1,
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  ),
                  onPressed: () => _addItemToCart(item),
                  child: const Text('ADD +', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                )
              else
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
              color: primaryOrange.withOpacity(0.4),
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
    final currency = _restaurantData?['currency'] ?? '₹';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final subtotal = _getCartSubtotal();
            final tax = subtotal * 0.05; // 5% GST estimate
            final grandTotal = subtotal + tax;

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
                          final qty = v['qty'] as int;
                          final price = v['price'] as double;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['item_name'],
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: darkBg),
                                      ),
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
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: darkBg),
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

                        // Payment Mode Selector
                        const Text('Payment Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: darkBg)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _paymentChoiceTile(
                                title: 'Pay at Table',
                                subtitle: 'Cash / Card to Waiter',
                                icon: Icons.handshake_outlined,
                                value: 'PAY_LATER',
                                setSheetState: setSheetState,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _paymentChoiceTile(
                                title: 'Pay Online',
                                subtitle: 'UPI / Card Instantly',
                                icon: Icons.qr_code_scanner,
                                value: 'ONLINE',
                                setSheetState: setSheetState,
                              ),
                            ),
                          ],
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
                              _billRow('Item Subtotal', '$currency${subtotal.toStringAsFixed(2)}'),
                              const SizedBox(height: 4),
                              _billRow('Estimated Taxes (GST 5%)', '$currency${tax.toStringAsFixed(2)}'),
                              const Divider(height: 12),
                              _billRow('Grand Total', '$currency${grandTotal.toStringAsFixed(2)}', isBold: true),
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
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _submittingOrder ? null : _submitOrderToKitchen,
                        child: _submittingOrder
                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Send Order to Kitchen', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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

  Widget _paymentChoiceTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required String value,
    required StateSetter setSheetState,
  }) {
    final isSelected = _paymentMethod == value;
    return InkWell(
      onTap: () {
        setSheetState(() => _paymentMethod = value);
        setState(() => _paymentMethod = value);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? primaryOrange.withOpacity(0.08) : Colors.white,
          border: Border.all(
            color: isSelected ? primaryOrange : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: isSelected ? primaryOrange : const Color(0xFF64748B)),
                const Spacer(),
                if (isSelected) const Icon(Icons.check_circle, size: 14, color: primaryOrange),
              ],
            ),
            const SizedBox(height: 6),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isSelected ? primaryOrange : darkBg)),
            Text(subtitle, style: const TextStyle(fontSize: 9, color: Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }

  Widget _billRow(String title, String val, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(fontSize: isBold ? 13 : 11, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: darkBg)),
        Text(val, style: TextStyle(fontSize: isBold ? 14 : 11, fontWeight: isBold ? FontWeight.w900 : FontWeight.w600, color: darkBg)),
      ],
    );
  }

  // --- ACTIVE ORDERS TRACKER MODAL ---

  void _showOrdersModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Table ${_tableData?['table_name']} Active Orders', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: darkBg)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _activeOrders.isEmpty
                  ? const Center(child: Text('No active orders on this table yet.', style: TextStyle(color: Colors.grey)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _activeOrders.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, idx) {
                        final kot = _activeOrders[idx];
                        final items = kot['items'] as List<dynamic>? ?? [];

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('KOT #${kot['kot_no']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryOrange)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(4)),
                                    child: Text(kot['status'] ?? 'In Kitchen', style: const TextStyle(color: Color(0xFFB45309), fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ...items.map((it) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('${it['qty']}x ${it['item_name']}', style: const TextStyle(fontSize: 12, color: darkBg)),
                                        Text(it['status'] ?? 'New', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                      ],
                                    ),
                                  )),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- CUSTOMER AUTH MODAL (EMAIL OTP & PROFILE) ---

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
  int _step = 1; // 1: Email, 2: OTP, 3: Register Profile
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _otpCtrl = TextEditingController();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Please enter a valid email address');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
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
        }),
      );

      final json = jsonDecode(res.body);
      if (json['success'] == true) {
        setState(() {
          _step = 2;
          _loading = false;
        });
      } else {
        throw Exception(json['message'] ?? 'Failed to send OTP');
      }
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length < 6) {
      setState(() => _error = 'Please enter complete 6-digit code');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final serverBase = AppConfig.baseUrl;
    final baseUrl = serverBase.isNotEmpty ? serverBase : 'http://localhost:5000';

    try {
      final res = await http.post(
        Uri.parse('$baseUrl${ApiEndpoints.publicDiningVerifyOtp}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailCtrl.text.trim(),
          'otp': otp,
          'outlet_id': widget.outletId,
        }),
      );

      final json = jsonDecode(res.body);
      if (json['success'] == true) {
        if (json['is_registered'] == true && json['customer'] != null) {
          widget.onLoginSuccess(json['customer']);
        } else {
          // New customer needs profile registration
          setState(() {
            _step = 3;
            _loading = false;
          });
        }
      } else {
        throw Exception(json['message'] ?? 'Invalid code');
      }
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _registerProfile() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      setState(() => _error = 'Name and Mobile Number are required');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final serverBase = AppConfig.baseUrl;
    final baseUrl = serverBase.isNotEmpty ? serverBase : 'http://localhost:5000';

    try {
      final res = await http.post(
        Uri.parse('$baseUrl${ApiEndpoints.publicDiningRegisterProfile}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'phone': phone,
          'email': _emailCtrl.text.trim(),
          'address': _addressCtrl.text.trim(),
          'outlet_id': widget.outletId,
        }),
      );

      final json = jsonDecode(res.body);
      if (json['success'] == true && json['customer'] != null) {
        widget.onLoginSuccess(json['customer']);
      } else {
        throw Exception(json['message'] ?? 'Registration failed');
      }
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE23744).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.restaurant_menu, color: Color(0xFFE23744), size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.restaurantName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Text('Self-Ordering Table Dining', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Color(0xFFB91C1C), size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12))),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (_step == 1) ...[
            const Text('Enter your email to view menu & order', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            const Text('We will send a 6-digit code to verify your table session.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            const SizedBox(height: 12),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email Address',
                hintText: 'alex@example.com',
                prefixIcon: const Icon(Icons.email_outlined, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE23744),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _loading ? null : _requestOtp,
                child: _loading
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Send Verification Code', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ] else if (_step == 2) ...[
            Text('Verify Code sent to ${_emailCtrl.text}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            const Text('Enter the 6-digit code received in your email inbox.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            const SizedBox(height: 12),
            TextField(
              controller: _otpCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 8),
              decoration: InputDecoration(
                counterText: '',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE23744),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _loading ? null : _verifyOtp,
                child: _loading
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Verify & Continue', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            Center(
              child: TextButton(
                onPressed: () => setState(() => _step = 1),
                child: const Text('Change Email', style: TextStyle(fontSize: 12)),
              ),
            ),
          ] else if (_step == 3) ...[
            const Text('Quick Registration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            const Text('Please complete your details once for order updates and loyalty rewards.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: 'Full Name *',
                prefixIcon: const Icon(Icons.person_outline, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Mobile Number *',
                prefixIcon: const Icon(Icons.phone_outlined, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _addressCtrl,
              decoration: InputDecoration(
                labelText: 'Address (Optional)',
                prefixIcon: const Icon(Icons.location_on_outlined, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE23744),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _loading ? null : _registerProfile,
                child: _loading
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Complete Profile & Order', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
