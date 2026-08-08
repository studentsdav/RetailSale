import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../utils/offline_database_helper.dart';

class KotBuilderScreen extends StatefulWidget {
  final Map<String, dynamic> table;
  final List<dynamic>? prefilledItems;
  final int? editKotId;

  const KotBuilderScreen({
    super.key,
    required this.table,
    this.prefilledItems,
    this.editKotId,
  });

  @override
  State<KotBuilderScreen> createState() => _KotBuilderScreenState();
}

class _KotBuilderScreenState extends State<KotBuilderScreen> {
  List<dynamic> allItems = [];
  List<dynamic> filteredItems = [];
  List<dynamic> _activeSchemes = [];
  List<String> categories = ['All'];
  String selectedCategory = 'All';
  String searchQuery = '';
  bool isLoadingItems = false;

  // Cart: Map of ItemID -> Map of Cart Item details
  final Map<int, Map<String, dynamic>> _cart = {};

  @override
  void initState() {
    super.initState();
    _fetchItems();
    _checkSyncQueue();
    _prefillCartIfAny();
  }

  void _prefillCartIfAny() {
    if (widget.prefilledItems != null) {
      for (final item in widget.prefilledItems!) {
        if (item['status'] == 'Cancelled') continue;
        final int itemId = item['item_id'];
        final double qty = double.tryParse(item['qty']?.toString() ?? '0') ?? 0.0;
        final double rate = double.tryParse(item['rate']?.toString() ?? '0') ?? 0.0;
        _cart[itemId] = {
          'item_id': itemId,
          'item_name': item['item_name'],
          'qty': qty,
          'item_remark': item['item_remark'] ?? '',
          'modifier_details': List<String>.from(item['modifier_details'] ?? []),
          'rate': rate,
        };
      }
    }
  }

  Future<void> _checkSyncQueue() async {
    await OfflineDatabaseHelper.instance.syncPendingKots();
  }

  Future<void> _fetchActiveKotItems() async {
    try {
      final res = await ApiClient.get('/api/restaurant/kots?table_id=${widget.table['id']}&active_only=true');
      if (res['success'] == true) {
        final List kots = res['data'] ?? [];
        setState(() {
          for (final kot in kots) {
            final List items = kot['items'] ?? [];
            for (final item in items) {
              final int itemId = item['item_id'];
              final double qty = double.tryParse(item['qty'].toString()) ?? 0.0;
              final double rate = double.tryParse(item['rate']?.toString() ?? '') ?? 0.0;
              final int kotItemId = item['id'];
              final isCancelled = item['status'] == 'Cancelled';

              if (isCancelled) continue; // Skip already cancelled items

              if (_cart.containsKey(itemId)) {
                _cart[itemId]!['qty'] = _cart[itemId]!['qty'] + qty;
                _cart[itemId]!['original_qty'] = _cart[itemId]!['original_qty'] + qty;
                (_cart[itemId]!['kot_item_ids'] as List<int>).add(kotItemId);
              } else {
                _cart[itemId] = {
                  'item_id': itemId,
                  'item_name': item['item_name'],
                  'qty': qty,
                  'original_qty': qty,
                  'kot_item_ids': <int>[kotItemId],
                  'item_remark': item['item_remark'] ?? '',
                  'modifier_details': List<String>.from(item['modifier_details'] ?? []),
                  'rate': rate,
                };
              }
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error preloading table KOTs: $e');
    }
  }

  Future<bool> _showPinOverrideDialog(BuildContext context) async {
    String enteredPin = '';
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.security, color: Colors.orange),
              SizedBox(width: 8),
              Text('Supervisor Override'),
            ],
          ),
          content: TextField(
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Enter Supervisor PIN',
              hintText: 'xxxx',
              border: OutlineInputBorder(),
            ),
            onChanged: (val) => enteredPin = val,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (enteredPin == '1234' || enteredPin == '4321' || enteredPin == '9999') {
                  Navigator.pop(context, true);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid Security PIN! Access Denied.')),
                  );
                }
              },
              child: const Text('Authorize'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Future<void> _fetchItems() async {
    setState(() => isLoadingItems = true);
    try {
      final res = await ApiClient.get(ApiEndpoints.items);
      final List data = res['data'] ?? [];

      List schemesList = [];
      try {
        final schemesRes = await ApiClient.get('/api/sales/schemes');
        schemesList = schemesRes['data'] ?? [];
      } catch (se) {
        debugPrint('Error fetching schemes for captain: $se');
      }

      final Set<String> cats = {'All'};
      for (final item in data) {
        final cat = item['category']?.toString() ?? item['item_group']?.toString();
        if (cat != null && cat.isNotEmpty) {
          cats.add(cat);
        }
      }

      setState(() {
        allItems = data;
        filteredItems = data;
        categories = cats.toList();
        _activeSchemes = schemesList;
      });
    } catch (e) {
      debugPrint('Error loading items: $e');
    } finally {
      setState(() => isLoadingItems = false);
    }
  }

  int _minutesFromHm(String hm) {
    final parts = hm.split(':');
    if (parts.length < 2) return 0;
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  Map<String, dynamic>? _getActivePromoForItem(Map<String, dynamic> item) {
    if (_activeSchemes.isEmpty) return null;
    final now = DateTime.now();
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final todayStr = weekdays[now.weekday - 1];
    final currentMinutes = TimeOfDay.fromDateTime(now).hour * 60 + TimeOfDay.fromDateTime(now).minute;

    for (final scheme in _activeSchemes) {
      final int? schemeItemId = scheme['item_id'] != null ? int.tryParse(scheme['item_id'].toString()) : null;
      final bool isActive = scheme['is_active'] == true || scheme['is_active'] == 1 || scheme['is_active'].toString() == 'true';
      if (schemeItemId == item['id'] && scheme['scheme_scope']?.toString().toUpperCase() == 'ITEM' && isActive) {
        if (scheme['days_of_week'] != null && scheme['days_of_week'].toString().trim().isNotEmpty) {
          final allowedDays = scheme['days_of_week'].toString().split(',').map((s) => s.trim().toLowerCase()).toList();
          if (!allowedDays.contains(todayStr.toLowerCase())) continue;
        }
        if (scheme['start_time'] != null && scheme['end_time'] != null &&
            scheme['start_time'].toString().trim().isNotEmpty && scheme['end_time'].toString().trim().isNotEmpty) {
          final start = _minutesFromHm(scheme['start_time'].toString());
          final end = _minutesFromHm(scheme['end_time'].toString());
          if (currentMinutes < start || currentMinutes > end) continue;
        }
        final String discountType = scheme['discount_type']?.toString().toUpperCase() ?? '';
        if (discountType == 'SPECIAL_PRICE' || discountType == 'AMOUNT_OFF') {
          return Map<String, dynamic>.from(scheme);
        }
      }
    }
    return null;
  }

  void _applyFilter() {
    setState(() {
      filteredItems = allItems.where((item) {
        final cat = item['category']?.toString() ?? item['item_group']?.toString() ?? 'General';
        final matchesCat = selectedCategory == 'All' || cat == selectedCategory;
        final matchesSearch = item['item_name'].toString().toLowerCase().contains(searchQuery.toLowerCase()) ||
            item['item_code'].toString().toLowerCase().contains(searchQuery.toLowerCase());
        return matchesCat && matchesSearch;
      }).toList();
    });
  }

  void _addToCart(Map<String, dynamic> item) {
    final bool isStockable = item['stockable'] == true || item['stockable'] == 1 || item['stockable'].toString() == 'true';
    final double stock = double.tryParse(item['opening_balance']?.toString() ?? '0') ?? 0.0;
    
    if (isStockable && stock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item['item_name']} is currently out of stock!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final itemId = item['id'];
    setState(() {
      if (_cart.containsKey(itemId)) {
        final double currentQty = double.tryParse(_cart[itemId]!['qty'].toString()) ?? 0.0;
        if (isStockable && currentQty >= stock) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cannot add more. Only ${stock.toInt()} units available in stock.'),
              backgroundColor: Colors.orangeAccent,
            ),
          );
          return;
        }
        _cart[itemId]!['qty'] = currentQty + 1;
      } else {
        final double rawRate = double.tryParse((item['retail_sale_price'] ?? item['rate'] ?? 0.0).toString()) ?? 0.0;
        final bool isInclusive = item['is_tax_inclusive'] == true || item['is_tax_inclusive'] == 1 || item['is_tax_inclusive'].toString() == 'true';
        final double taxPercent = double.tryParse(item['tax_percent']?.toString() ?? '0.0') ?? 0.0;
        final double cartRate = isInclusive ? double.parse((rawRate * (1 + taxPercent / 100)).toStringAsFixed(2)) : rawRate;

        _cart[itemId] = {
          'item_id': itemId,
          'item_name': item['item_name'],
          'qty': 1.0,
          'original_qty': 0.0,
          'kot_item_ids': <int>[],
          'item_remark': '',
          'modifier_details': <String>[],
          'rate': cartRate,
        };
      }
    });
  }

  void _removeFromCart(int itemId) {
    setState(() {
      if (_cart.containsKey(itemId)) {
        final double currentQty = double.tryParse(_cart[itemId]!['qty'].toString()) ?? 0.0;
        if (currentQty > 1) {
          _cart[itemId]!['qty'] = currentQty - 1;
        } else {
          _cart.remove(itemId);
        }
      }
    });
  }

  void _showModifiersDialog(int itemId) {
    final cartItem = _cart[itemId]!;
    final remarkCtrl = TextEditingController(text: cartItem['item_remark']);
    List<String> selectedMods = List<String>.from(cartItem['modifier_details']);

    final modifiersList = ['Extra Cheese', 'No Onion', 'Extra Spicy', 'Less Salt', 'Gluten Free'];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Modifiers: ${cartItem['item_name']}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: remarkCtrl,
                    decoration: const InputDecoration(labelText: 'Special Preparation Remarks'),
                  ),
                  const SizedBox(height: 15),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Add-on Modifiers:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 8,
                    children: modifiersList.map((mod) {
                      final hasMod = selectedMods.contains(mod);
                      return FilterChip(
                        label: Text(mod),
                        selected: hasMod,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              selectedMods.add(mod);
                            } else {
                              selectedMods.remove(mod);
                            }
                          });
                        },
                      );
                    }).toList(),
                  )
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () {
                    this.setState(() {
                      _cart[itemId]!['item_remark'] = remarkCtrl.text;
                      _cart[itemId]!['modifier_details'] = selectedMods;
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Apply Customizations'),
                )
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _dispatchKot() async {
    if (_cart.isEmpty) return;

    setState(() => isLoadingItems = true);

    try {
      if (widget.editKotId != null) {
        final modifyData = {
          'items': _cart.values.toList(),
          'modification_reason': 'Modified from running orders screen',
        };
        final res = await ApiClient.put('/api/restaurant/kots/${widget.editKotId}', modifyData);
        if (res['success'] == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('KOT successfully modified!')),
          );
          Navigator.pop(context);
        } else {
          throw Exception(res['message'] ?? 'Server rejected modification');
        }
      } else {
        final kotData = {
          'table_id': widget.table['id'],
          'service_type': 'Dine In',
          'waiter_id': widget.table['waiter_id'] ?? 1,
          'captain_id': widget.table['captain_id'] ?? 1,
          'remarks': 'App Order',
          'items': _cart.values.toList(),
        };
        final res = await ApiClient.post(ApiEndpoints.restaurantKots, kotData);
        if (res['success'] == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('KOT successfully sent to kitchen!')),
          );
          Navigator.pop(context);
        } else {
          throw Exception('Server rejected request');
        }
      }
    } catch (e) {
      if (widget.editKotId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to modify KOT: $e')),
        );
      } else {
        final kotData = {
          'table_id': widget.table['id'],
          'service_type': 'Dine In',
          'waiter_id': widget.table['waiter_id'] ?? 1,
          'captain_id': widget.table['captain_id'] ?? 1,
          'remarks': 'App Order',
          'items': _cart.values.toList(),
        };
        final localId = await OfflineDatabaseHelper.instance.cacheKot(kotData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Offline Mode: Order queued locally (ID: $localId). Will sync automatically when network restored.'),
              backgroundColor: Colors.orange.shade800,
            ),
          );
          Navigator.pop(context);
        }
      }
    } finally {
      setState(() => isLoadingItems = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('New KOT - Table ${widget.table['table_name']}'),
        elevation: 0,
      ),
      body: Row(
        children: [
          // 1. LEFT SIDEBAR: Categories Panel
          Container(
            width: 200,
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: colorScheme.outlineVariant, width: 0.8)),
              color: colorScheme.surfaceVariant.withOpacity(0.3),
            ),
            child: ListView.builder(
              itemCount: categories.length,
              itemBuilder: (context, idx) {
                final cat = categories[idx];
                final isSelected = selectedCategory == cat;
                return InkWell(
                  onTap: () {
                    setState(() {
                      selectedCategory = cat;
                      _applyFilter();
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      color: isSelected ? colorScheme.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      cat,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // 2. CENTER PANEL: Grid of menu items
          Expanded(
            child: Column(
              children: [
                // Top Search Bar
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search menu item name or code...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  searchQuery = '';
                                  _applyFilter();
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onChanged: (val) {
                      searchQuery = val;
                      _applyFilter();
                    },
                  ),
                ),
                
                // Item Grid View
                Expanded(
                  child: isLoadingItems
                      ? const Center(child: CircularProgressIndicator())
                      : filteredItems.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.restaurant_menu, size: 64, color: colorScheme.outline),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No items found',
                                    style: TextStyle(fontSize: 16, color: colorScheme.outline),
                                  ),
                                ],
                              ),
                            )
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                final gridWidth = constraints.maxWidth;
                                final crossAxisCount = (gridWidth / 220).floor().clamp(2, 6);
                                return GridView.builder(
                                  padding: const EdgeInsets.all(16),
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxisCount,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                    childAspectRatio: 0.72,
                                  ),
                                  itemCount: filteredItems.length,
                                  itemBuilder: (context, idx) {
                                    final item = filteredItems[idx];
                                    final bool isStockable = item['stockable'] == true ||
                                        item['stockable'] == 1 ||
                                        item['stockable'].toString() == 'true';
                                    final double stock = double.tryParse(item['opening_balance']?.toString() ?? '0') ?? 0.0;
                                    final bool isOutOfStock = isStockable && stock <= 0;

                                    final double rawRate = double.tryParse((item['retail_sale_price'] ?? item['rate'] ?? 0.0).toString()) ?? 0.0;
                                    final bool isInclusive = item['is_tax_inclusive'] == true || item['is_tax_inclusive'] == 1 || item['is_tax_inclusive'].toString() == 'true';
                                    final double taxPercent = double.tryParse(item['tax_percent']?.toString() ?? '0.0') ?? 0.0;
                                    final double rate = isInclusive ? double.parse((rawRate * (1 + taxPercent / 100)).toStringAsFixed(2)) : rawRate;
                                    final cartQty = _cart[item['id']]?['qty'] ?? 0.0;

                                    return Card(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 2,
                                      clipBehavior: Clip.antiAlias,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          // Product Image / Placeholders
                                          Expanded(
                                            child: Stack(
                                              fit: StackFit.expand,
                                              children: [
                                                Container(
                                                  color: colorScheme.surfaceVariant.withOpacity(0.5),
                                                  child: item['image_path'] != null && item['image_path'].toString().isNotEmpty
                                                      ? Image.network(
                                                          item['image_path'].toString(),
                                                          fit: BoxFit.cover,
                                                          errorBuilder: (_, __, ___) => Icon(
                                                            Icons.fastfood,
                                                            size: 40,
                                                            color: colorScheme.outline,
                                                          ),
                                                        )
                                                      : Icon(
                                                          Icons.fastfood,
                                                          size: 40,
                                                          color: colorScheme.outline,
                                                        ),
                                                ),
                                                if (isOutOfStock)
                                                  Container(
                                                    color: Colors.black.withOpacity(0.6),
                                                    child: const Center(
                                                      child: Card(
                                                        color: Colors.redAccent,
                                                        child: Padding(
                                                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                          child: Text(
                                                            'OUT OF STOCK',
                                                            style: TextStyle(
                                                              color: Colors.white,
                                                              fontWeight: FontWeight.bold,
                                                              fontSize: 10,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                else if (isStockable)
                                                  Positioned(
                                                    top: 8,
                                                    left: 8,
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: Colors.green.shade800,
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: Text(
                                                        'Stock: ${stock.toInt()}',
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                              ],
                                            ),
                                          ),
                                          
                                          // Product Details
                                          Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item['item_name'] ?? '',
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                                ),
                                                const SizedBox(height: 8),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    (() {
                                                      final promoScheme = _getActivePromoForItem(item);
                                                      double? promoPrice;
                                                      if (promoScheme != null) {
                                                        if (promoScheme['discount_type'] == 'SPECIAL_PRICE') {
                                                          double basePromo = double.tryParse(promoScheme['discount_value'].toString()) ?? rawRate;
                                                          promoPrice = isInclusive
                                                              ? double.parse((basePromo * (1 + taxPercent / 100)).toStringAsFixed(2))
                                                              : basePromo;
                                                        } else if (promoScheme['discount_type'] == 'AMOUNT_OFF') {
                                                          double baseOff = double.tryParse(promoScheme['discount_value'].toString()) ?? 0.0;
                                                          double off = isInclusive
                                                              ? double.parse((baseOff * (1 + taxPercent / 100)).toStringAsFixed(2))
                                                              : baseOff;
                                                          promoPrice = rate - off;
                                                        }
                                                      }

                                                      final hasPromo = promoPrice != null && promoPrice < rate;

                                                      return Wrap(
                                                        crossAxisAlignment: WrapCrossAlignment.center,
                                                        children: [
                                                          if (hasPromo) ...[
                                                            Text(
                                                              'Rs. ${rate.toStringAsFixed(2)}',
                                                              style: const TextStyle(
                                                                color: Colors.grey,
                                                                decoration: TextDecoration.lineThrough,
                                                                fontSize: 11.5,
                                                              ),
                                                            ),
                                                            const SizedBox(width: 4),
                                                            Text(
                                                              'Rs. ${promoPrice!.toStringAsFixed(2)}',
                                                              style: TextStyle(
                                                                color: colorScheme.primary,
                                                                fontWeight: FontWeight.bold,
                                                                fontSize: 14,
                                                              ),
                                                            ),
                                                          ] else ...[
                                                            Text(
                                                              'Rs. ${rate.toStringAsFixed(2)}',
                                                              style: TextStyle(
                                                                color: colorScheme.primary,
                                                                fontWeight: FontWeight.bold,
                                                                fontSize: 14,
                                                              ),
                                                            ),
                                                          ]
                                                        ],
                                                      );
                                                    })(),
                                                    
                                                    // Add / Quantity Selector Button (Blinkit style)
                                                    if (isOutOfStock)
                                                      const SizedBox(
                                                        height: 32,
                                                        child: Center(
                                                          child: Text(
                                                            'Unavailable',
                                                            style: TextStyle(color: Colors.red, fontSize: 12),
                                                          ),
                                                        ),
                                                      )
                                                    else if (cartQty > 0)
                                                      Container(
                                                        height: 32,
                                                        decoration: BoxDecoration(
                                                          border: Border.all(color: colorScheme.primary),
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            IconButton(
                                                              icon: const Icon(Icons.remove, size: 14),
                                                              padding: EdgeInsets.zero,
                                                              constraints: const BoxConstraints(),
                                                              onPressed: () => _removeFromCart(item['id']),
                                                            ),
                                                            Padding(
                                                              padding: const EdgeInsets.symmetric(horizontal: 8),
                                                              child: Text(
                                                                '${cartQty.toInt()}',
                                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                                              ),
                                                            ),
                                                            IconButton(
                                                              icon: const Icon(Icons.add, size: 14),
                                                              padding: EdgeInsets.zero,
                                                              constraints: const BoxConstraints(),
                                                              onPressed: () => _addToCart(item),
                                                            ),
                                                          ],
                                                        ),
                                                      )
                                                    else
                                                      SizedBox(
                                                        height: 32,
                                                        child: ElevatedButton(
                                                          style: ElevatedButton.styleFrom(
                                                            padding: const EdgeInsets.symmetric(horizontal: 16),
                                                            shape: RoundedRectangleBorder(
                                                              borderRadius: BorderRadius.circular(8),
                                                            ),
                                                          ),
                                                          onPressed: () => _addToCart(item),
                                                          child: const Text('ADD', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                                        ),
                                                      ),
                                                  ],
                                                )
                                              ],
                                            ),
                                          )
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                )
              ],
            ),
          ),
          
          // 3. RIGHT SIDEBAR: Shopping Cart Basket
          Container(
            width: 320,
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: colorScheme.outlineVariant, width: 0.8)),
              color: colorScheme.surface,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: colorScheme.primaryContainer.withOpacity(0.4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Order Basket',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colorScheme.onPrimaryContainer),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_cart.length} Items',
                          style: TextStyle(color: colorScheme.onPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      )
                    ],
                  ),
                ),
                Expanded(
                  child: _cart.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.shopping_basket_outlined, size: 48, color: colorScheme.outline),
                              const SizedBox(height: 8),
                              Text('Basket is empty', style: TextStyle(color: colorScheme.outline)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _cart.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, index) {
                            final key = _cart.keys.elementAt(index);
                            final item = _cart[key]!;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item['item_name'],
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline, size: 20),
                                          onPressed: () => _removeFromCart(key),
                                        ),
                                        Text('${item['qty'].toInt()}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        IconButton(
                                          icon: const Icon(Icons.add_circle_outline, size: 20),
                                          onPressed: () {
                                            // Validate stock logic in cart add
                                            final matching = allItems.firstWhere((it) => it['id'] == key, orElse: () => null);
                                            if (matching != null) {
                                              _addToCart(matching);
                                            } else {
                                              setState(() {
                                                item['qty'] = item['qty'] + 1;
                                              });
                                            }
                                          },
                                        ),
                                      ],
                                    )
                                  ],
                                ),
                                if (item['item_remark'].toString().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text('Remark: ${item['item_remark']}', style: const TextStyle(color: Colors.red, fontSize: 12)),
                                  ),
                                if (item['modifier_details'].isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text('Mods: ${item['modifier_details'].join(", ")}', style: const TextStyle(color: Colors.blue, fontSize: 12)),
                                  ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    icon: const Icon(Icons.tune, size: 14),
                                    label: const Text('Customize', style: TextStyle(fontSize: 12)),
                                    onPressed: () => _showModifiersDialog(key),
                                  ),
                                )
                              ],
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _cart.isEmpty ? null : _dispatchKot,
                    child: const Text('Send to Kitchen (KOT)', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
