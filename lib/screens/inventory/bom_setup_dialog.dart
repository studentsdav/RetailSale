import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../../controllers/inventory/bom_controller.dart';
import '../../controllers/inventory/item_controller.dart';
import '../../models/inventory/item_model.dart';
import '../../models/inventory/bom_model.dart';

class BOMSetupDialog extends StatefulWidget {
  final Item parentItem;
  final ItemController itemCtrl;
  final VoidCallback? onCostUpdated;

  const BOMSetupDialog({
    super.key,
    required this.parentItem,
    required this.itemCtrl,
    this.onCostUpdated,
  });

  @override
  State<BOMSetupDialog> createState() => _BOMSetupDialogState();
}

class _BOMSetupDialogState extends State<BOMSetupDialog> {
  final List<BOMItem> _components = [];
  Item? _selectedComponent;
  final _qtyController = TextEditingController(text: '1');
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBOM();
    });
  }

  Future<void> _loadBOM() async {
    setState(() => _isLoading = true);
    final bomCtrl = Provider.of<BOMController>(context, listen: false);
    final bom = await bomCtrl.getBOM(widget.parentItem.id);
    if (bom != null) {
      setState(() {
        _components.clear();
        _components.addAll(bom.components);
      });
    }
    setState(() => _isLoading = false);
  }

  double get _compositeCost {
    double total = 0.0;
    for (var comp in _components) {
      total += comp.rate * comp.quantity;
    }
    return total;
  }

  void _addComponent() {
    if (_selectedComponent == null) return;
    
    final qty = double.tryParse(_qtyController.text.trim()) ?? 0.0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantity must be greater than 0')),
      );
      return;
    }

    if (_selectedComponent!.id == widget.parentItem.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An item cannot be a component of itself')),
      );
      return;
    }

    // Check if component already exists
    final existsIndex = _components.indexWhere((c) => c.componentItemId == _selectedComponent!.id);
    
    setState(() {
      final bomItem = BOMItem(
        componentItemId: _selectedComponent!.id,
        itemCode: _selectedComponent!.itemCode,
        itemName: _selectedComponent!.itemName,
        unit: _selectedComponent!.unit,
        rate: _selectedComponent!.rate,
        quantity: qty,
        cost: _selectedComponent!.rate * qty,
      );

      if (existsIndex >= 0) {
        _components[existsIndex] = bomItem;
      } else {
        _components.add(bomItem);
      }

      _selectedComponent = null;
      _qtyController.text = '1';
    });
  }

  Future<void> _saveBOM() async {
    setState(() => _isLoading = true);
    final bomCtrl = Provider.of<BOMController>(context, listen: false);

    final payload = _components.map((c) => {
      'component_item_id': c.componentItemId,
      'quantity': c.quantity,
    }).toList();

    final success = await bomCtrl.saveBOM(widget.parentItem.id, payload);
    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'BOM saved successfully!' : 'Failed to save BOM'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
      if (success) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _updateItemCost() async {
    setState(() => _isLoading = true);
    final bomCtrl = Provider.of<BOMController>(context, listen: false);
    final newCost = await bomCtrl.updateParentCost(widget.parentItem.id);
    setState(() => _isLoading = false);

    if (mounted) {
      if (newCost != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Updated item cost in master to Rs. ${newCost.toStringAsFixed(2)}'),
            backgroundColor: Colors.green,
          ),
        );
        if (widget.onCostUpdated != null) {
          widget.onCostUpdated!();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update cost. Please save the BOM first.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemCtrl = widget.itemCtrl;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.settings_input_component, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Bill of Materials (BOM) - ${widget.parentItem.itemName}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: _isLoading
          ? const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            )
          : SizedBox(
              width: 650,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Define the raw materials or components that make up this item:',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  
                  // Component selection row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        flex: 3,
                        child: DropdownSearch<Item>(
                          selectedItem: _selectedComponent,
                          items: (filter, scrollProps) {
                            return itemCtrl.list
                                .where((item) =>
                                    item.id != widget.parentItem.id &&
                                    (item.itemName.toLowerCase().contains(filter.toLowerCase()) ||
                                     item.itemCode.toLowerCase().contains(filter.toLowerCase())))
                                .toList();
                          },
                          itemAsString: (item) => '[${item.itemCode}] ${item.itemName} (Rs. ${item.rate.toStringAsFixed(2)})',
                          compareFn: (a, b) => a.id == b.id,
                          popupProps: const PopupProps.menu(
                            showSearchBox: true,
                            searchDelay: Duration(milliseconds: 200),
                          ),
                          decoratorProps: const DropDownDecoratorProps(
                            decoration: InputDecoration(
                              labelText: 'Select Component Item',
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _selectedComponent = val;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: TextField(
                          controller: _qtyController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Quantity',
                            suffixText: _selectedComponent?.unit ?? '',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _addComponent,
                        icon: const Icon(Icons.add),
                        label: const Text('Add'),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Components list table
                  const Text(
                    'Components List',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _components.isEmpty
                          ? const Center(child: Text('No components added yet.'))
                          : ListView.builder(
                              itemCount: _components.length,
                              itemBuilder: (context, idx) {
                                final comp = _components[idx];
                                return ListTile(
                                  dense: true,
                                  title: Text(comp.itemName),
                                  subtitle: Text('${comp.itemCode} | Cost: Rs. ${comp.rate.toStringAsFixed(2)} per ${comp.unit}'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${comp.quantity.toStringAsFixed(2)} ${comp.unit} = Rs. ${comp.cost.toStringAsFixed(2)}',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                        onPressed: () {
                                          setState(() {
                                            _components.removeAt(idx);
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Composite cost presentation banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Calculated Composite Cost:',
                          style: TextStyle(fontWeight: FontWeight.bold, color: blueVal),
                        ),
                        Text(
                          'Rs. ${_compositeCost.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: Colors.blue),
          onPressed: _components.isEmpty ? null : _updateItemCost,
          icon: const Icon(Icons.sync_alt),
          label: const Text('Update Cost in Master'),
        ),
        FilledButton.icon(
          onPressed: _saveBOM,
          icon: const Icon(Icons.save),
          label: const Text('Save BOM'),
        ),
      ],
    );
  }
}
const Color blueVal = Color(0xFF0D47A1);
