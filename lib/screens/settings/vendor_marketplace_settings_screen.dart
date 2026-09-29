import 'package:flutter/material.dart';
import '../../controllers/inventory/item_controller.dart';
import '../../controllers/settings/property_info_controller.dart';
import '../../core/currency/currency_service.dart';
import '../../core/settings/local_preferences.dart';
import '../../models/inventory/item_model.dart';

class VendorMarketplaceSettingsScreen extends StatelessWidget {
  const VendorMarketplaceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendor & Marketplace Setup'),
      ),
      body: const VendorMarketplaceSettingsView(),
    );
  }
}

class VendorMarketplaceSettingsView extends StatefulWidget {
  const VendorMarketplaceSettingsView({super.key});

  @override
  State<VendorMarketplaceSettingsView> createState() =>
      _VendorMarketplaceSettingsViewState();
}

class _VendorMarketplaceSettingsViewState
    extends State<VendorMarketplaceSettingsView> {
  final PropertyInfoController _propertyCtrl = PropertyInfoController();
  final ItemController _itemCtrl = ItemController();

  bool _isVendorEnabled = true;
  bool _listAllItems = true;
  bool _isB2BEnabled = true;
  bool _isB2CEnabled = true;

  final TextEditingController _minOrderCtrl = TextEditingController(text: '1000');
  final TextEditingController _deliverySlaCtrl =
      TextEditingController(text: 'Same Day Dispatch (Order before 2 PM)');
  final TextEditingController _searchCtrl = TextEditingController();

  List<Item> _items = [];
  String _searchQuery = '';
  bool _isLoading = false;
  bool _isSaving = false;

  // Local modifications map: itemId -> {b2b_price: double, b2c_price: double, moq: int, is_listed: bool}
  final Map<int, Map<String, dynamic>> _itemOverrides = {};

  // Controllers cache for inline editable table fields
  final Map<int, TextEditingController> _b2cControllers = {};
  final Map<int, TextEditingController> _b2bControllers = {};
  final Map<int, TextEditingController> _moqControllers = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    for (var c in _b2cControllers.values) {
      c.dispose();
    }
    for (var c in _b2bControllers.values) {
      c.dispose();
    }
    for (var c in _moqControllers.values) {
      c.dispose();
    }
    _minOrderCtrl.dispose();
    _deliverySlaCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await _propertyCtrl.load();
      await _itemCtrl.load();

      // Load saved vendor config
      final savedConfig = await LocalPreferences.getMarketplaceVendorConfig();
      _isVendorEnabled = savedConfig['is_vendor_enabled'] ?? true;
      _minOrderCtrl.text = (savedConfig['min_order_value'] ?? 1000.0).toString();
      _deliverySlaCtrl.text = savedConfig['delivery_sla'] ?? 'Same Day Dispatch (Order before 2 PM)';
      _isB2BEnabled = savedConfig['is_b2b_enabled'] ?? true;
      _isB2CEnabled = savedConfig['is_b2c_enabled'] ?? true;
      _listAllItems = savedConfig['list_all_items'] ?? true;

      // Load saved item overrides
      final savedOverrides = await LocalPreferences.getMarketplaceItemOverrides();
      savedOverrides.forEach((key, val) {
        final id = int.tryParse(key.toString());
        if (id != null && val is Map) {
          _itemOverrides[id] = Map<String, dynamic>.from(val);
        }
      });

      _items = _itemCtrl.list;

      // Initialize controllers for each item
      for (var it in _items) {
        final override = _itemOverrides[it.id] ?? {};
        final double b2c = double.tryParse(override['b2c_price']?.toString() ?? '') ??
            (it.retailSalePrice > 0 ? it.retailSalePrice : it.mrp);
        final double b2b = double.tryParse(override['b2b_price']?.toString() ?? '') ??
            (it.rate > 0 ? it.rate : (b2c > 0 ? (b2c * 0.85) : 0.0));
        final int moq = int.tryParse(override['moq']?.toString() ?? '') ??
            (it.minOrderQtyB2B > 0 ? it.minOrderQtyB2B : 1);

        _b2cControllers[it.id] = TextEditingController(text: b2c > 0 ? b2c.toStringAsFixed(2) : '0.00');
        _b2bControllers[it.id] = TextEditingController(text: b2b > 0 ? b2b.toStringAsFixed(2) : '0.00');
        _moqControllers[it.id] = TextEditingController(text: moq.toString());
      }
    } catch (e) {
      debugPrint('Error loading vendor marketplace settings: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyBulkWholesaleDiscount(double discountPercentage) {
    setState(() {
      for (var it in _items) {
        final double b2c = double.tryParse(_b2cControllers[it.id]?.text ?? '') ?? it.retailSalePrice;
        final double newB2B = b2c * (1 - (discountPercentage / 100));
        _b2bControllers[it.id]?.text = newB2B.toStringAsFixed(2);
        _itemOverrides[it.id] = {
          ...(_itemOverrides[it.id] ?? {}),
          'b2b_price': newB2B,
          'b2c_price': b2c,
        };
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Applied ${discountPercentage.toInt()}% wholesale discount across all products.'),
      ),
    );
  }

  void _setAllVisibility(bool isVisible) {
    setState(() {
      for (var it in _items) {
        _itemOverrides[it.id] = {
          ...(_itemOverrides[it.id] ?? {}),
          'is_listed': isVisible,
        };
      }
    });
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      // 1. Sync current controller text values into overrides map
      for (var it in _items) {
        final b2c = double.tryParse(_b2cControllers[it.id]?.text ?? '') ?? it.retailSalePrice;
        final b2b = double.tryParse(_b2bControllers[it.id]?.text ?? '') ?? (b2c * 0.85);
        final moq = int.tryParse(_moqControllers[it.id]?.text ?? '') ?? 1;
        final currentOverride = _itemOverrides[it.id] ?? {};
        final isListed = currentOverride['is_listed'] ?? (_listAllItems ? true : false);

        _itemOverrides[it.id] = {
          'b2c_price': b2c,
          'b2b_price': b2b,
          'moq': moq,
          'is_listed': isListed,
          'item_code': it.itemCode,
          'item_name': it.itemName,
        };
      }

      // 2. Save Vendor Config
      final vendorConfig = {
        'is_vendor_enabled': _isVendorEnabled,
        'min_order_value': double.tryParse(_minOrderCtrl.text) ?? 1000.0,
        'delivery_sla': _deliverySlaCtrl.text.trim(),
        'is_b2b_enabled': _isB2BEnabled,
        'is_b2c_enabled': _isB2CEnabled,
        'list_all_items': _listAllItems,
      };
      await LocalPreferences.setMarketplaceVendorConfig(vendorConfig);

      // 3. Save Item Overrides separately from Item Master
      final Map<String, dynamic> stringKeyedOverrides = {};
      _itemOverrides.forEach((k, v) => stringKeyedOverrides[k.toString()] = v);
      await LocalPreferences.setMarketplaceItemOverrides(stringKeyedOverrides);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF1B5E20),
            content: Text('Marketplace & Vendor rates saved successfully (stored separate from Item Master)!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text('Error saving rates: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final buyer = _propertyCtrl.data;

    final filteredItems = _items.where((it) {
      if (_searchQuery.isEmpty) return true;
      return it.itemName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          it.itemCode.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          it.brand.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar with Save Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Vendor Marketplace & Custom Rates',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Configure public listing, editable B2B wholesale prices, and B2C retail rates',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save_rounded, size: 18),
                label: Text(_isSaving ? 'Saving...' : 'Save Marketplace Rates',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                onPressed: _isSaving ? null : _saveSettings,
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Outlet Info Card
          if (buyer != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.storefront_rounded, color: Colors.blueAccent, size: 30),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Store: ${buyer.propertyName.isNotEmpty ? buyer.propertyName : buyer.legalName} (${buyer.city})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                        ),
                        Text(
                          'GSTIN: ${buyer.gstNo.isNotEmpty ? buyer.gstNo : "URP"} | Mobile: ${buyer.mobile} | Address: ${buyer.address}',
                          style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),

          // Main "Become Vendor" Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.hub_rounded, color: Colors.purple, size: 26),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Become a Marketplace Vendor / Wholesaler',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Allow other retailers, restaurants, and customers to purchase from your inventory',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Switch(
                        value: _isVendorEnabled,
                        activeThumbColor: Colors.purple,
                        onChanged: (val) => setState(() => _isVendorEnabled = val),
                      ),
                    ],
                  ),
                  if (_isVendorEnabled) ...[
                    const Divider(height: 28),
                    const Text(
                      'Storefront & Terms Configuration',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _minOrderCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Min Order Value (${CurrencyService.symbol})',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _deliverySlaCtrl,
                            decoration: InputDecoration(
                              labelText: 'Delivery SLA / Dispatch Terms',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Enable B2B Wholesale Channel',
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                            subtitle: const Text('Offer wholesale rates to restaurants & retailers',
                                style: TextStyle(fontSize: 11.5)),
                            value: _isB2BEnabled,
                            onChanged: (v) => setState(() => _isB2BEnabled = v ?? true),
                          ),
                        ),
                        Expanded(
                          child: CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Enable B2C Customer Channel',
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                            subtitle: const Text('Show products on Customer App at retail rates',
                                style: TextStyle(fontSize: 11.5)),
                            value: _isB2CEnabled,
                            onChanged: (v) => setState(() => _isB2CEnabled = v ?? true),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Inventory Scope & Bulk Rate Controls
          if (_isVendorEnabled) ...[
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Inventory Scope & Quick Rate Generators',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: const Icon(Icons.percent, size: 14),
                              label: const Text('Apply 15% B2B Discount', style: TextStyle(fontSize: 12)),
                              onPressed: () => _applyBulkWholesaleDiscount(15),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: const Icon(Icons.percent, size: 14),
                              label: const Text('Apply 10% B2B Discount', style: TextStyle(fontSize: 12)),
                              onPressed: () => _applyBulkWholesaleDiscount(10),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<bool>(
                            title: const Text('Publish All Inventory Items'),
                            subtitle: const Text('All products visible on marketplace by default'),
                            value: true,
                            groupValue: _listAllItems,
                            onChanged: (v) => setState(() => _listAllItems = v ?? true),
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<bool>(
                            title: const Text('Selected Items Only (Whitelist)'),
                            subtitle: const Text('Only items enabled in the table below are visible'),
                            value: false,
                            groupValue: _listAllItems,
                            onChanged: (v) => setState(() => _listAllItems = v ?? false),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Item Dual-Pricing & Visibility Table
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Item Dual-Pricing & Visibility Matrix',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Directly edit Retail (B2C) & Wholesale (B2B) rates below. Stored separately from Item Master.',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.check_box_outlined, size: 16),
                              label: const Text('Enable All', style: TextStyle(fontSize: 12)),
                              onPressed: () => _setAllVisibility(true),
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.disabled_by_default_outlined, size: 16),
                              label: const Text('Disable All', style: TextStyle(fontSize: 12)),
                              onPressed: () => _setAllVisibility(false),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 250,
                              child: TextField(
                                controller: _searchCtrl,
                                decoration: InputDecoration(
                                  hintText: 'Search items...',
                                  prefixIcon: const Icon(Icons.search, size: 18),
                                  contentPadding:
                                      const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onChanged: (val) => setState(() => _searchQuery = val),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Editable Data Table
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DataTable(
                        columnSpacing: 20,
                        dataRowMinHeight: 52,
                        dataRowMaxHeight: 58,
                        headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                        columns: const [
                          DataColumn(label: Text('Item Name & Code', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Brand / Unit', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Retail Price (B2C)', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Wholesale Rate (B2B)', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Min Order (MOQ)', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Public Listed', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: filteredItems.map((it) {
                          final override = _itemOverrides[it.id] ?? {};
                          final isListed = override['is_listed'] ?? (_listAllItems ? true : false);

                          final b2cCtrl = _b2cControllers[it.id] ??
                              TextEditingController(text: it.retailSalePrice.toStringAsFixed(2));
                          final b2bCtrl = _b2bControllers[it.id] ??
                              TextEditingController(text: (it.retailSalePrice * 0.85).toStringAsFixed(2));
                          final moqCtrl = _moqControllers[it.id] ??
                              TextEditingController(text: '1');

                          return DataRow(
                            cells: [
                              DataCell(
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(it.itemName,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                    Text(it.itemCode,
                                        style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                  ],
                                ),
                              ),
                              DataCell(Text('${it.brand} (${it.unit})', style: const TextStyle(fontSize: 12.5))),
                              // Editable Retail Price (B2C)
                              DataCell(
                                SizedBox(
                                  width: 120,
                                  child: TextFormField(
                                    controller: b2cCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                    decoration: InputDecoration(
                                      prefixText: '${CurrencyService.symbol} ',
                                      prefixStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                    ),
                                    onChanged: (val) {
                                      final parsed = double.tryParse(val);
                                      if (parsed != null) {
                                        _itemOverrides[it.id] = {
                                          ...(_itemOverrides[it.id] ?? {}),
                                          'b2c_price': parsed,
                                        };
                                      }
                                    },
                                  ),
                                ),
                              ),
                              // Editable Wholesale Rate (B2B)
                              DataCell(
                                SizedBox(
                                  width: 120,
                                  child: TextFormField(
                                    controller: b2bCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: const TextStyle(
                                        fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green),
                                    decoration: InputDecoration(
                                      prefixText: '${CurrencyService.symbol} ',
                                      prefixStyle: const TextStyle(fontSize: 12, color: Colors.green),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                    ),
                                    onChanged: (val) {
                                      final parsed = double.tryParse(val);
                                      if (parsed != null) {
                                        _itemOverrides[it.id] = {
                                          ...(_itemOverrides[it.id] ?? {}),
                                          'b2b_price': parsed,
                                        };
                                      }
                                    },
                                  ),
                                ),
                              ),
                              // Editable MOQ
                              DataCell(
                                SizedBox(
                                  width: 80,
                                  child: TextFormField(
                                    controller: moqCtrl,
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(fontSize: 13),
                                    decoration: InputDecoration(
                                      suffixText: 'units',
                                      suffixStyle: const TextStyle(fontSize: 10, color: Colors.grey),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                    ),
                                    onChanged: (val) {
                                      final parsed = int.tryParse(val);
                                      if (parsed != null) {
                                        _itemOverrides[it.id] = {
                                          ...(_itemOverrides[it.id] ?? {}),
                                          'moq': parsed,
                                        };
                                      }
                                    },
                                  ),
                                ),
                              ),
                              // Public Listed Switch
                              DataCell(
                                Switch(
                                  value: isListed,
                                  activeThumbColor: Colors.blueAccent,
                                  onChanged: (v) {
                                    setState(() {
                                      _itemOverrides[it.id] = {
                                        ...(_itemOverrides[it.id] ?? {}),
                                        'is_listed': v,
                                      };
                                    });
                                  },
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
