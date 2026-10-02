import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/currency/currency_service.dart';

class ModifierMasterScreen extends StatefulWidget {
  const ModifierMasterScreen({super.key});

  @override
  State<ModifierMasterScreen> createState() => _ModifierMasterScreenState();
}

class _ModifierMasterScreenState extends State<ModifierMasterScreen> {
  bool _loading = false;
  List<Map<String, dynamic>> _modifiers = [];
  List<Map<String, dynamic>> _items = [];
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

      final results = await Future.wait([itemsFuture, modifiersFuture]);
      final itemsRes = results[0];
      final modifiersRes = results[1];

      if (itemsRes['success'] == true) {
        _items = List<Map<String, dynamic>>.from(itemsRes['data'] ?? []);
      }
      if (modifiersRes['success'] == true) {
        _modifiers = List<Map<String, dynamic>>.from(modifiersRes['data'] ?? []);
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
    final priceCtrl = TextEditingController(
      text: (modifier?['price'] as num?)?.toDouble().toStringAsFixed(2) ?? '0.00',
    );
    int selectedItemId = modifier?['item_master_id'] is int
        ? modifier!['item_master_id']
        : int.tryParse(modifier?['item_master_id']?.toString() ?? '0') ?? 0;
    bool isActive = modifier?['is_active'] ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: Text(
            isEditing ? 'Edit Modifier / Add-on' : 'Add Modifier / Add-on',
            style: const TextStyle(fontWeight: FontWeight.bold, color: primaryColor),
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Modifier Name *',
                      hintText: 'e.g. Extra Cheese, Extra Spicy, Takeaway Box',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Price Add-on Amount',
                      hintText: '0.00 (or additional surcharge)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    initialValue: selectedItemId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Applicable Menu Item',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int>(
                        value: 0,
                        child: Text('All Items / Global Modifier', style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor)),
                      ),
                      ..._items.map((item) {
                        final id = item['id'] as int? ?? 0;
                        final name = item['item_name'] ?? '';
                        return DropdownMenuItem<int>(
                          value: id,
                          child: Text(name, overflow: TextOverflow.ellipsis),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      if (val != null) setDlgState(() => selectedItemId = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Is Active'),
                    value: isActive,
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
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
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
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
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
                            final double price = (m['price'] as num?)?.toDouble() ?? 0.0;
                            final bool isActive = m['is_active'] ?? true;
                            final String itemName = m['item_name'] ?? 'All Items';

                            return Card(
                              elevation: 0.5,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isActive ? Colors.blue.shade50 : Colors.grey.shade200,
                                  child: Icon(
                                    Icons.tune,
                                    color: isActive ? primaryColor : Colors.grey,
                                  ),
                                ),
                                title: Row(
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
                                  ],
                                ),
                                subtitle: Text(
                                  'Applies To: $itemName',
                                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
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
