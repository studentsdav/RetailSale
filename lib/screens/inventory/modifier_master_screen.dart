import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/currency/currency_service.dart';
import '../../models/inventory/tax_group_model.dart';

class ModifierMasterScreen extends StatefulWidget {
  const ModifierMasterScreen({super.key});

  @override
  State<ModifierMasterScreen> createState() => _ModifierMasterScreenState();
}

class _ModifierMasterScreenState extends State<ModifierMasterScreen> {
  bool _loading = false;
  List<Map<String, dynamic>> _modifiers = [];
  List<Map<String, dynamic>> _items = [];
  List<TaxGroup> _taxGroups = [];
  String _selectedItemFilter = 'ALL';

  final _searchCtrl = TextEditingController();
  static const Color primaryColor = Color(0xFF0B5CAD);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final itemsFuture = ApiClient.get(ApiEndpoints.items);
      final modifiersFuture = ApiClient.get(ApiEndpoints.itemModifiers);
      final taxGroupsFuture = ApiClient.get(ApiEndpoints.taxGroups);

      final results = await Future.wait([itemsFuture, modifiersFuture, taxGroupsFuture]);
      final itemsRes = results[0];
      final modifiersRes = results[1];
      final taxGroupsRes = results[2];

      if (itemsRes['success'] == true) {
        _items = List<Map<String, dynamic>>.from(itemsRes['data'] ?? []);
      }
      if (modifiersRes['success'] == true) {
        _modifiers = List<Map<String, dynamic>>.from(modifiersRes['data'] ?? []);
      }
      if (taxGroupsRes['success'] == true && taxGroupsRes['data'] != null) {
        final raw = taxGroupsRes['data'] as List;
        _taxGroups = raw.map((e) => TaxGroup.fromJson(Map<String, dynamic>.from(e))).toList();
      }
    } catch (e) {
      debugPrint('Error loading modifiers: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load modifiers: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredModifiers {
    final query = _searchCtrl.text.trim().toLowerCase();
    return _modifiers.where((m) {
      final matchItem = _selectedItemFilter == 'ALL' ||
          m['item_master_id']?.toString() == _selectedItemFilter;
      final name = (m['modifier_name'] ?? '').toString().toLowerCase();
      final itemName = (m['item_name'] ?? '').toString().toLowerCase();
      final matchSearch = query.isEmpty || name.contains(query) || itemName.contains(query);
      return matchItem && matchSearch;
    }).toList();
  }

  void _showAddEditDialog([Map<String, dynamic>? modifier]) {
    final isEditing = modifier != null;
    final nameCtrl = TextEditingController(text: modifier?['modifier_name'] ?? '');
    final priceVal = double.tryParse(modifier?['price']?.toString() ?? '0.00') ?? 0.0;
    final priceCtrl = TextEditingController(text: priceVal.toStringAsFixed(2));
    int selectedItemId = int.tryParse(modifier?['item_master_id']?.toString() ?? '0') ?? 0;
    
    // Tax & Inventory State
    double? selectedTaxPercent = modifier?['tax_percent'] != null
        ? double.tryParse(modifier!['tax_percent'].toString())
        : null;

    int selectedInventoryItemId = int.tryParse(modifier?['inventory_item_id']?.toString() ?? '0') ?? 0;
    final deductVal = double.tryParse(modifier?['deduct_qty']?.toString() ?? '1.00') ?? 1.0;
    final deductQtyCtrl = TextEditingController(text: deductVal.toStringAsFixed(2));
    bool isActive = modifier?['is_active'] == true || modifier?['is_active'] == null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final Map<String, dynamic> currentItem = _items.firstWhere(
            (it) => it['id'] == selectedItemId,
            orElse: () => {},
          );
          final double itemTaxRate = double.tryParse(currentItem['tax_percent']?.toString() ?? '0') ?? 0.0;
          final String currentItemName = currentItem['item_name'] ?? '';

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.tune, color: primaryColor),
                const SizedBox(width: 8),
                Text(
                  isEditing ? 'Edit Modifier / Add-on' : 'Add Modifier / Add-on',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: primaryColor, fontSize: 18),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 500,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Modifier Name
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Modifier Name *',
                        hintText: 'e.g. Extra Cheese, Extra Spicy, Takeaway Box',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.label_outline),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Applicable Menu Item Selector (Searchable DropdownSearch for 5000+ items)
                    DropdownSearch<Map<String, dynamic>>(
                      selectedItem: selectedItemId == 0
                          ? const {'id': 0, 'item_name': 'All Items / Global Modifier', 'item_code': 'GLOBAL', 'tax_percent': 0.0}
                          : currentItem,
                      items: (filter, infiniteScrollProps) {
                        final List<Map<String, dynamic>> all = [
                          const {'id': 0, 'item_name': 'All Items / Global Modifier', 'item_code': 'GLOBAL', 'tax_percent': 0.0},
                          ..._items,
                        ];
                        final f = filter.trim().toLowerCase();
                        if (f.isEmpty) return all;
                        return all.where((it) {
                          final name = (it['item_name'] ?? '').toString().toLowerCase();
                          final code = (it['item_code'] ?? '').toString().toLowerCase();
                          final barcode = (it['barcode'] ?? '').toString().toLowerCase();
                          return name.contains(f) || code.contains(f) || barcode.contains(f);
                        }).toList();
                      },
                      itemAsString: (item) {
                        if (item['id'] == 0) return 'All Items / Global Modifier';
                        final name = item['item_name'] ?? '';
                        final code = item['item_code'] ?? '';
                        final tax = double.tryParse(item['tax_percent']?.toString() ?? '0') ?? 0.0;
                        return code.isNotEmpty && code != '-'
                            ? '$name ($code) - [Tax: ${tax.toStringAsFixed(0)}%]'
                            : '$name - [Tax: ${tax.toStringAsFixed(0)}%]';
                      },
                      compareFn: (a, b) =>
                          (int.tryParse(a['id']?.toString() ?? '0') ?? 0) ==
                          (int.tryParse(b['id']?.toString() ?? '0') ?? 0),
                      popupProps: const PopupProps.menu(
                        showSearchBox: true,
                        searchFieldProps: TextFieldProps(
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: 'Type to search 5000+ items (Name / Code / Barcode)...',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                        ),
                      ),
                      decoratorProps: const DropDownDecoratorProps(
                        decoration: InputDecoration(
                          labelText: 'Applicable Menu Item (Searchable)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.restaurant_menu),
                        ),
                      ),
                      onChanged: (val) {
                        if (val != null) {
                          setDlgState(() {
                            selectedItemId = int.tryParse(val['id']?.toString() ?? '0') ?? 0;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Price & Tax Settings Row
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: TextField(
                            controller: priceCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Price Add-on',
                              hintText: '0.00',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.attach_money),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: DropdownButtonFormField<double?>(
                            initialValue: selectedTaxPercent,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Tax Pickup / Rate',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.receipt_long),
                            ),
                            items: [
                              DropdownMenuItem<double?>(
                                value: null,
                                child: Text(
                                  selectedItemId > 0
                                      ? 'Inherit Item Tax (${itemTaxRate.toStringAsFixed(0)}%)'
                                      : 'Inherit Item Tax (Auto)',
                                  style: const TextStyle(fontWeight: FontWeight.w600, color: primaryColor),
                                ),
                              ),
                              const DropdownMenuItem<double?>(
                                value: 0.0,
                                child: Text('0% (Exempt)'),
                              ),
                              if (_taxGroups.isNotEmpty)
                                ..._taxGroups.map((g) => DropdownMenuItem<double?>(
                                      value: g.totalRate,
                                      child: Text('${g.groupName} (${g.totalRate.toStringAsFixed(0)}%)'),
                                    ))
                              else ...const [
                                DropdownMenuItem<double?>(value: 5.0, child: Text('GST 5%')),
                                DropdownMenuItem<double?>(value: 12.0, child: Text('GST 12%')),
                                DropdownMenuItem<double?>(value: 18.0, child: Text('GST 18%')),
                                DropdownMenuItem<double?>(value: 28.0, child: Text('GST 28%')),
                              ],
                            ],
                            onChanged: (val) => setDlgState(() => selectedTaxPercent = val),
                          ),
                        ),
                      ],
                    ),

                    // Tax Auto-Pickup Information Badge
                    if (selectedTaxPercent == null && selectedItemId > 0 && currentItemName.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_outline, size: 14, color: Colors.green.shade800),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Auto-picked ${itemTaxRate.toStringAsFixed(2)}% Tax from "$currentItemName"',
                                style: TextStyle(fontSize: 11, color: Colors.green.shade900, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Inventory Deduction Section
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 18, color: primaryColor),
                              SizedBox(width: 6),
                              Text(
                                'Inventory Stock Deduction (Optional)',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryColor),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Select raw material or packaging item to auto-deduct when ordered:',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 8),
                          DropdownSearch<Map<String, dynamic>>(
                            selectedItem: selectedInventoryItemId == 0
                                ? const {'id': 0, 'item_name': 'None (No Stock Deduction / Kitchen Note)', 'unit': ''}
                                : (_items.firstWhere(
                                    (it) => it['id'] == selectedInventoryItemId,
                                    orElse: () => {'id': 0, 'item_name': 'None (No Stock Deduction)', 'unit': ''},
                                  )),
                            items: (filter, infiniteScrollProps) {
                              final List<Map<String, dynamic>> all = [
                                const {'id': 0, 'item_name': 'None (No Stock Deduction / Kitchen Note)', 'unit': ''},
                                ..._items,
                              ];
                              final f = filter.trim().toLowerCase();
                              if (f.isEmpty) return all;
                              return all.where((it) {
                                final name = (it['item_name'] ?? '').toString().toLowerCase();
                                final code = (it['item_code'] ?? '').toString().toLowerCase();
                                return name.contains(f) || code.contains(f);
                              }).toList();
                            },
                            itemAsString: (item) {
                              if (item['id'] == 0) return 'None (No Stock Deduction / Kitchen Note)';
                              final name = item['item_name'] ?? '';
                              final unit = item['unit'] ?? 'PCS';
                              final code = item['item_code'] ?? '';
                              return code.isNotEmpty && code != '-' ? '$name ($code) [$unit]' : '$name [$unit]';
                            },
                            compareFn: (a, b) =>
                                (int.tryParse(a['id']?.toString() ?? '0') ?? 0) ==
                                (int.tryParse(b['id']?.toString() ?? '0') ?? 0),
                            popupProps: const PopupProps.menu(
                              showSearchBox: true,
                              searchFieldProps: TextFieldProps(
                                autofocus: true,
                                decoration: InputDecoration(
                                  hintText: 'Search raw stock item to deduct...',
                                  prefixIcon: Icon(Icons.search),
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                              ),
                            ),
                            decoratorProps: const DropDownDecoratorProps(
                              decoration: InputDecoration(
                                labelText: 'Deduct From Raw Stock Item (Searchable)',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                prefixIcon: Icon(Icons.inventory_2_outlined),
                              ),
                            ),
                            onChanged: (val) {
                              if (val != null) {
                                setDlgState(() {
                                  selectedInventoryItemId = int.tryParse(val['id']?.toString() ?? '0') ?? 0;
                                });
                              }
                            },
                          ),
                          if (selectedInventoryItemId > 0) ...[
                            const SizedBox(height: 8),
                            TextField(
                              controller: deductQtyCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Quantity to Deduct per Portion',
                                hintText: 'e.g. 1.0, 0.05, 2.0',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                prefixIcon: Icon(Icons.remove_circle_outline, color: Colors.red),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Is Active', style: TextStyle(fontWeight: FontWeight.w600)),
                      value: isActive,
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: Colors.green,
                      onChanged: (val) => setDlgState(() => isActive = val),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                  final deductQty = selectedInventoryItemId > 0 ? (double.tryParse(deductQtyCtrl.text.trim()) ?? 1.0) : 0.0;

                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter modifier name')),
                    );
                    return;
                  }

                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(ctx);
                  setState(() => _loading = true);

                  try {
                    final payload = {
                      'modifier_name': name,
                      'price': price,
                      'tax_percent': selectedTaxPercent,
                      'inventory_item_id': selectedInventoryItemId,
                      'deduct_qty': deductQty,
                      'item_master_id': selectedItemId,
                      'is_active': isActive,
                    };

                    if (isEditing) {
                      await ApiClient.put('${ApiEndpoints.itemModifiers}/${modifier['id']}', payload);
                    } else {
                      await ApiClient.post(ApiEndpoints.itemModifiers, payload);
                    }

                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(isEditing ? 'Modifier updated' : 'Modifier created'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      _loadData();
                    }
                  } catch (e) {
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _loading = false);
                  }
                },
                child: const Text('Save Modifier', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteModifier(Map<String, dynamic> modifier) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Modifier'),
        content: Text('Are you sure you want to delete "${modifier['modifier_name']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      await ApiClient.delete('${ApiEndpoints.itemModifiers}/${modifier['id']}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Modifier deleted successfully'), backgroundColor: Colors.green),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredModifiers;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu Item Modifiers & Add-ons'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading && _modifiers.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Filter bar
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.grey.shade100,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _searchCtrl,
                          decoration: InputDecoration(
                            hintText: 'Search modifier or item...',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          onChanged: (v) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey.shade400),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedItemFilter,
                              isExpanded: true,
                              items: [
                                const DropdownMenuItem(value: 'ALL', child: Text('Filter: All Items')),
                                const DropdownMenuItem(value: '0', child: Text('Global Modifiers Only')),
                                ..._items.map((it) => DropdownMenuItem(
                                      value: it['id'].toString(),
                                      child: Text('Item: ${it['item_name']}', overflow: TextOverflow.ellipsis),
                                    )),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedItemFilter = val);
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Modifiers List
                Expanded(
                  child: list.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.extension_off_outlined, size: 64, color: Colors.grey),
                              const SizedBox(height: 12),
                              const Text('No item modifiers or add-ons found.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
                                onPressed: () => _showAddEditDialog(),
                                icon: const Icon(Icons.add),
                                label: const Text('Create First Modifier'),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: list.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, idx) {
                            final m = list[idx];
                            final double price = double.tryParse(m['price']?.toString() ?? '0') ?? 0.0;
                            final double? taxPercent = m['tax_percent'] != null ? double.tryParse(m['tax_percent'].toString()) : null;
                            final int invItemId = int.tryParse(m['inventory_item_id']?.toString() ?? '0') ?? 0;
                            final double deductQty = double.tryParse(m['deduct_qty']?.toString() ?? '0') ?? 0.0;
                            final String invItemName = m['inventory_item_name'] ?? '';
                            final String invItemUnit = m['inventory_item_unit'] ?? 'Units';
                            final bool isActive = m['is_active'] == true || m['is_active'] == null;
                            final String itemName = m['item_name'] ?? 'All Items';

                            return Card(
                              elevation: 0.5,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: isActive ? Colors.blue.shade50 : Colors.grey.shade200,
                                      child: Icon(
                                        Icons.tune,
                                        color: isActive ? primaryColor : Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(m['modifier_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                              const SizedBox(width: 8),
                                              if (price > 0)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green.shade100,
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    '+${CurrencyService.format(price)}',
                                                    style: TextStyle(color: Colors.green.shade900, fontSize: 11, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.indigo.shade50,
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: Colors.indigo.shade200),
                                                ),
                                                child: Text(
                                                  taxPercent != null ? 'Tax: ${taxPercent.toStringAsFixed(0)}%' : 'Tax: Inherit (Item Tax)',
                                                  style: TextStyle(color: Colors.indigo.shade800, fontSize: 10, fontWeight: FontWeight.w600),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 4,
                                            children: [
                                              Text(
                                                'Applies To: $itemName',
                                                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                                              ),
                                              if (invItemId > 0 && invItemName.isNotEmpty)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: Colors.amber.shade100,
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.inventory_2, size: 12, color: Colors.amber.shade900),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Deducts $deductQty $invItemUnit $invItemName',
                                                        style: TextStyle(color: Colors.amber.shade900, fontSize: 11, fontWeight: FontWeight.bold),
                                                      ),
                                                    ],
                                                  ),
                                                )
                                              else
                                                Text(
                                                  '• No Stock Deduction',
                                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      tooltip: 'Edit',
                                      onPressed: () => _showAddEditDialog(m),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      tooltip: 'Delete',
                                      onPressed: () => _deleteModifier(m),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryColor,
        onPressed: () => _showAddEditDialog(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Modifier / Add-on', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
