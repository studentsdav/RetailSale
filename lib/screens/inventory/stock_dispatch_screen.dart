import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import '../../controllers/inventory/item_controller.dart';
import '../../controllers/inventory/stock_transfer_controller.dart';
import '../../models/inventory/item_model.dart';

class StockDispatchScreen extends StatefulWidget {
  const StockDispatchScreen({super.key});

  @override
  State<StockDispatchScreen> createState() => _StockDispatchScreenState();
}

class _StockDispatchScreenState extends State<StockDispatchScreen> {
  final StockTransferController _transferCtrl = StockTransferController();
  final ItemController _itemCtrl = ItemController();

  List<dynamic> _childOutlets = [];
  Map<String, dynamic>? _selectedOutlet;
  Map<String, dynamic>? _sourceOutlet;
  bool _isLoadingOutlets = true;
  bool _isDispatching = false;

  final List<Map<String, dynamic>> _selectedItems = [];
  final TextEditingController _notesCtrl = TextEditingController();

  Item? _currentItem;
  final TextEditingController _qtyCtrl = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    _loadOutlets();
    _itemCtrl.load();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOutlets() async {
    setState(() => _isLoadingOutlets = true);
    final hierarchy = await _transferCtrl.fetchHierarchy();
    if (mounted) {
      setState(() {
        _isLoadingOutlets = false;
        if (hierarchy != null) {
          _childOutlets = hierarchy['child_outlets'] ?? hierarchy['linked_child_outlets'] ?? [];
          _sourceOutlet = hierarchy['current_outlet'];
        }
      });
    }
  }

  void _addItem() {
    if (_currentItem == null) {
      _showMessage('Please select an item');
      return;
    }
    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0;
    if (qty <= 0) {
      _showMessage('Enter a valid transfer quantity');
      return;
    }

    setState(() {
      final nameWithBrand = _currentItem!.brand.trim().isNotEmpty
          ? '${_currentItem!.itemName} (${_currentItem!.brand.trim()})'
          : _currentItem!.itemName;

      _selectedItems.add({
        'item_id': _currentItem!.id,
        'item_code': _currentItem!.itemCode,
        'item_name': nameWithBrand,
        'transfer_qty': qty,
        'unit_cost': _currentItem!.rate,
      });
      _currentItem = null;
      _qtyCtrl.text = '1';
    });
  }

  void _removeItem(int index) {
    setState(() {
      _selectedItems.removeAt(index);
    });
  }

  Future<void> _submitDispatch() async {
    if (_selectedOutlet == null) {
      _showMessage('Please select a destination outlet');
      return;
    }
    if (_selectedItems.isEmpty) {
      _showMessage('Please add at least one item to dispatch');
      return;
    }

    setState(() => _isDispatching = true);

    final res = await _transferCtrl.dispatchStock(
      destinationOutletId: _selectedOutlet!['id'],
      items: _selectedItems,
      notes: _notesCtrl.text.trim(),
    );

    if (mounted) {
      setState(() => _isDispatching = false);
      if (res != null && res['success'] == true) {
        _showMessage(res['message'] ?? 'Stock dispatched successfully!');
        setState(() {
          _selectedItems.clear();
          _notesCtrl.clear();
          _selectedOutlet = null;
        });
      } else {
        _showMessage(res?['message'] ?? 'Failed to dispatch stock');
      }
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Dispatch Stock to Outlet'),
        centerTitle: true,
      ),
      body: _isLoadingOutlets
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card 1: Source & Destination Outlet Selection
                        Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '1. Select Source & Destination Outlets',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 16),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final isWide = constraints.maxWidth > 600;
                                    final sourceWidget = Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.grey.shade300),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.unarchive_outlined, color: Colors.orange),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Source Outlet (Debited)',
                                                  style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  _sourceOutlet != null
                                                      ? '${_sourceOutlet!['outlet_name']} (${_sourceOutlet!['outlet_code']})'
                                                      : 'Current Source Outlet',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );

                                    final destWidget = DropdownButtonFormField<Map<String, dynamic>>(
                                      initialValue: _selectedOutlet,
                                      decoration: const InputDecoration(
                                        labelText: 'Destination Child Outlet (Credited)',
                                        border: OutlineInputBorder(),
                                        prefixIcon: Icon(Icons.archive_outlined, color: Colors.green),
                                      ),
                                      items: _childOutlets.map<DropdownMenuItem<Map<String, dynamic>>>((outlet) {
                                        return DropdownMenuItem<Map<String, dynamic>>(
                                          value: outlet,
                                          child: Text('${outlet['outlet_name']} (${outlet['outlet_code']})'),
                                        );
                                      }).toList(),
                                      onChanged: (val) => setState(() => _selectedOutlet = val),
                                    );

                                    if (isWide) {
                                      return Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(child: sourceWidget),
                                          const SizedBox(width: 16),
                                          Expanded(child: destWidget),
                                        ],
                                      );
                                    } else {
                                      return Column(
                                        children: [
                                          sourceWidget,
                                          const SizedBox(height: 16),
                                          destWidget,
                                        ],
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Card 2: Add Items
                        Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '2. Select Items to Transfer',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 16),
                                AnimatedBuilder(
                                  animation: _itemCtrl,
                                  builder: (_, __) {
                                    return Wrap(
                                      spacing: 16,
                                      runSpacing: 16,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 360,
                                          child: DropdownSearch<Item>(
                                            items: (filter, scroll) => List<Item>.from(_itemCtrl.list),
                                            selectedItem: _currentItem,
                                            compareFn: (a, b) => a.id == b.id,
                                            itemAsString: (item) =>
                                                '${item.itemName}${item.brand.trim().isNotEmpty ? " (${item.brand.trim()})" : ""} (${item.itemCode})',
                                            popupProps: const PopupProps.menu(showSearchBox: true),
                                            decoratorProps: const DropDownDecoratorProps(
                                              decoration: InputDecoration(
                                                labelText: 'Search Item',
                                                border: OutlineInputBorder(),
                                              ),
                                            ),
                                            onChanged: (val) => setState(() => _currentItem = val),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 150,
                                          child: TextFormField(
                                            controller: _qtyCtrl,
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            decoration: const InputDecoration(
                                              labelText: 'Quantity (e.g. 100)',
                                              border: OutlineInputBorder(),
                                            ),
                                          ),
                                        ),
                                        FilledButton.icon(
                                          onPressed: _addItem,
                                          icon: const Icon(Icons.add),
                                          label: const Text('Add Item'),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 20),
                                if (_selectedItems.isNotEmpty) ...[
                                  const Text('Selected Items List:', style: TextStyle(fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 8),
                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: _selectedItems.length,
                                    itemBuilder: (context, index) {
                                      final item = _selectedItems[index];
                                      return ListTile(
                                        tileColor: const Color(0xFFF8FAFC),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        leading: const Icon(Icons.inventory),
                                        title: Text('${item['item_name']} (${item['item_code']})'),
                                        subtitle: Text('Transfer Qty: ${item['transfer_qty']} | Unit Rate: ₹${item['unit_cost']}'),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red),
                                          onPressed: () => _removeItem(index),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Card 3: Notes & Dispatch Button
                        Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextFormField(
                                  controller: _notesCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Transfer Remarks / Notes',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: FilledButton.icon(
                                    onPressed: _isDispatching ? null : _submitDispatch,
                                    icon: _isDispatching
                                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                        : const Icon(Icons.local_shipping),
                                    label: const Text('Dispatch Stock Now (Debits Source Outlet)'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
