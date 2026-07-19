import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:intl/intl.dart';
import '../../controllers/inventory/bom_controller.dart';
import '../../controllers/inventory/item_controller.dart';
import '../../models/inventory/item_model.dart';
import '../../models/inventory/bom_model.dart';
import '../../core/api/api_client.dart';

class AssemblyScreen extends StatefulWidget {
  const AssemblyScreen({super.key});

  @override
  State<AssemblyScreen> createState() => _AssemblyScreenState();
}

class _AssemblyScreenState extends State<AssemblyScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ItemController _itemCtrl = ItemController();
  
  // Tab 1 state
  final _assemblyNoController = TextEditingController();
  DateTime _assemblyDate = DateTime.now();
  Item? _selectedParentItem;
  final _qtyController = TextEditingController(text: '1');
  final _notesController = TextEditingController();
  List<BOMItem> _bomComponents = [];
  Map<String, double> _componentStocks = {};
  bool _isBOMDetailsLoading = false;
  bool _isSaving = false;

  // Tab 2 state
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    _itemCtrl.load();
    _itemCtrl.addListener(_onItemCtrlChanged);
    
    _loadNextAssemblyNo();
    
    _tabController.addListener(() {
      if (_tabController.index == 1) {
        Provider.of<BOMController>(context, listen: false).loadAssemblies();
      }
    });
  }

  @override
  void dispose() {
    _itemCtrl.removeListener(_onItemCtrlChanged);
    _itemCtrl.dispose();
    _tabController.dispose();
    _assemblyNoController.dispose();
    _qtyController.dispose();
    _notesController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onItemCtrlChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadNextAssemblyNo() async {
    final bomCtrl = Provider.of<BOMController>(context, listen: false);
    final nextNo = await bomCtrl.getNextAssemblyNo();
    setState(() {
      _assemblyNoController.text = nextNo;
    });
  }

  Future<void> _onParentItemChanged(Item? val) async {
    setState(() {
      _selectedParentItem = val;
      _bomComponents = [];
      _componentStocks = {};
    });

    if (val == null) return;

    setState(() => _isBOMDetailsLoading = true);
    final bomCtrl = Provider.of<BOMController>(context, listen: false);
    final bom = await bomCtrl.getBOM(val.id);
    
    if (bom != null && bom.components.isNotEmpty) {
      setState(() {
        _bomComponents = bom.components;
      });

      // Fetch stock for each component item
      for (var comp in bom.components) {
        try {
          final res = await ApiClient.get('/api/inventory/issue/stock/${comp.itemCode}');
          if (res['success'] == true) {
            setState(() {
              _componentStocks[comp.itemCode] = double.tryParse(res['qty']?.toString() ?? '0.0') ?? 0.0;
            });
          }
        } catch (_) {}
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selected item has no BOM configured. Configure it in Item Master first.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
    setState(() => _isBOMDetailsLoading = false);
  }

  double get _unitCompositeCost {
    double total = 0.0;
    for (var comp in _bomComponents) {
      total += comp.rate * comp.quantity;
    }
    return total;
  }

  double get _totalAssemblyCost {
    final qty = double.tryParse(_qtyController.text.trim()) ?? 0.0;
    return _unitCompositeCost * qty;
  }

  Future<void> _submitAssembly() async {
    if (_selectedParentItem == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a finished product to assemble')),
      );
      return;
    }

    final qty = double.tryParse(_qtyController.text.trim()) ?? 0.0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantity must be greater than 0')),
      );
      return;
    }

    if (_bomComponents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selected item has no components in its BOM')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final bomCtrl = Provider.of<BOMController>(context, listen: false);
    
    try {
      final success = await bomCtrl.createAssembly(
        parentItemId: _selectedParentItem!.id,
        qty: qty,
        notes: _notesController.text.trim(),
        assemblyDate: DateFormat('yyyy-MM-dd').format(_assemblyDate),
      );

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Assembly created successfully!'), backgroundColor: Colors.green),
          );
        }
        // Reset state
        setState(() {
          _selectedParentItem = null;
          _bomComponents = [];
          _componentStocks = {};
          _qtyController.text = '1';
          _notesController.clear();
        });
        _loadNextAssemblyNo();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _showAssemblyDetails(AssemblyHeader item) async {
    final bomCtrl = Provider.of<BOMController>(context, listen: false);
    final details = await bomCtrl.getAssemblyDetails(item.id ?? 0);

    if (details == null) return;

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Assembly Details - ${details.assemblyNo}'),
            content: SizedBox(
              width: 550,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Finished Good: [${details.parentItemCode}] ${details.parentItemName}${details.parentBrand.isNotEmpty ? ' (${details.parentBrand})' : ''}'),
                  Text('Produced Qty: ${details.qty.toStringAsFixed(2)} ${details.parentUnit}'),
                  Text('Assembly Date: ${details.assemblyDate}'),
                  Text('Composite Cost per unit: Rs. ${details.compositeCost.toStringAsFixed(2)}'),
                  Text('Total Cost: Rs. ${details.totalCost.toStringAsFixed(2)}'),
                  if (details.notes.isNotEmpty) Text('Notes: ${details.notes}'),
                  const Divider(height: 20),
                  const Text('Components Consumed:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: details.items.length,
                      itemBuilder: (context, idx) {
                        final usage = details.items[idx];
                        return ListTile(
                          dense: true,
                          title: Text('${usage.componentItemName}${usage.componentBrand.isNotEmpty ? ' (${usage.componentBrand})' : ''}'),
                          subtitle: Text(usage.componentItemCode),
                          trailing: Text(
                            '${usage.qtyUsed.toStringAsFixed(2)} ${usage.componentUnit} @ Rs. ${usage.rate.toStringAsFixed(2)} = Rs. ${usage.totalCost.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Product Assembly'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.build), text: 'New Assembly'),
            Tab(icon: Icon(Icons.history), text: 'Assembly History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNewAssemblyTab(),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildNewAssemblyTab() {
    final itemCtrl = _itemCtrl;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header info card
          _card(
            title: 'Assembly Information',
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _assemblyNoController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Assembly No',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    readOnly: true,
                    controller: TextEditingController(
                      text: DateFormat('dd-MMM-yyyy').format(_assemblyDate),
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Assembly Date',
                      suffixIcon: Icon(Icons.calendar_today),
                      border: OutlineInputBorder(),
                    ),
                    onTap: () async {
                      final selected = await showDatePicker(
                        context: context,
                        initialDate: _assemblyDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (selected != null) {
                        setState(() {
                          _assemblyDate = selected;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Form selection card
          _card(
            title: 'Product Selection',
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      flex: 3,
                      child: DropdownSearch<Item>(
                        selectedItem: _selectedParentItem,
                        items: (filter, scrollProps) {
                          return itemCtrl.list
                              .where((item) =>
                                  item.itemName.toLowerCase().contains(filter.toLowerCase()) ||
                                  item.itemCode.toLowerCase().contains(filter.toLowerCase()))
                              .toList();
                        },
                        itemAsString: (item) => '[${item.itemCode}] ${item.itemName}${item.brand.isNotEmpty ? ' (${item.brand})' : ''}',
                        compareFn: (a, b) => a.id == b.id,
                        popupProps: const PopupProps.menu(showSearchBox: true),
                        decoratorProps: const DropDownDecoratorProps(
                          decoration: InputDecoration(
                            labelText: 'Finished Product (Parent Item)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        onChanged: _onParentItemChanged,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: _qtyController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Qty to Produce',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (val) {
                          setState(() {});
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes / Remarks',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Components requirements list card
          _card(
            title: 'BOM Component Stocks & Costs',
            child: _isBOMDetailsLoading
                ? const SizedBox(
                    height: 150,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _bomComponents.isEmpty
                    ? const SizedBox(
                        height: 100,
                        child: Center(child: Text('Select a finished product with a BOM to load details.')),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Table(
                            border: TableBorder.all(color: Colors.grey.shade300),
                            columnWidths: const {
                              0: FlexColumnWidth(1.2),
                              1: FlexColumnWidth(2.5),
                              2: FlexColumnWidth(1),
                              3: FlexColumnWidth(1),
                              4: FlexColumnWidth(1),
                              5: FlexColumnWidth(1),
                            },
                            children: [
                              TableRow(
                                decoration: BoxDecoration(color: Colors.grey.shade100),
                                children: const [
                                  Padding(padding: EdgeInsets.all(8), child: Text('Code', style: TextStyle(fontWeight: FontWeight.bold))),
                                  Padding(padding: EdgeInsets.all(8), child: Text('Component Item', style: TextStyle(fontWeight: FontWeight.bold))),
                                  Padding(padding: EdgeInsets.all(8), child: Text('Req Qty/Unit', style: TextStyle(fontWeight: FontWeight.bold))),
                                  Padding(padding: EdgeInsets.all(8), child: Text('Total Required', style: TextStyle(fontWeight: FontWeight.bold))),
                                  Padding(padding: EdgeInsets.all(8), child: Text('Current Stock', style: TextStyle(fontWeight: FontWeight.bold))),
                                  Padding(padding: EdgeInsets.all(8), child: Text('Cost Amount', style: TextStyle(fontWeight: FontWeight.bold))),
                                ],
                              ),
                              ..._bomComponents.map((comp) {
                                final qtyToProd = double.tryParse(_qtyController.text.trim()) ?? 0.0;
                                final totalReq = comp.quantity * qtyToProd;
                                final stock = _componentStocks[comp.itemCode] ?? 0.0;
                                final cost = comp.rate * totalReq;
                                final isStockShort = stock < totalReq;

                                return TableRow(
                                  children: [
                                    Padding(padding: const EdgeInsets.all(8), child: Text(comp.itemCode)),
                                    Padding(padding: const EdgeInsets.all(8), child: Text('${comp.itemName}${comp.brand.isNotEmpty ? ' (${comp.brand})' : ''}')),
                                    Padding(padding: const EdgeInsets.all(8), child: Text('${comp.quantity} ${comp.unit}')),
                                    Padding(padding: const EdgeInsets.all(8), child: Text('$totalReq ${comp.unit}')),
                                    Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Text(
                                        '$stock ${comp.unit}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isStockShort ? Colors.red : Colors.green,
                                        ),
                                      ),
                                    ),
                                    Padding(padding: const EdgeInsets.all(8), child: Text('Rs. ${cost.toStringAsFixed(2)}')),
                                  ],
                                );
                              }),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Composite Cost per Unit: Rs. ${_unitCompositeCost.toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Total Assembly Cost: Rs. ${_totalAssemblyCost.toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
          ),
          const SizedBox(height: 20),
          
          // Submit button
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
                onPressed: _isSaving || _bomComponents.isEmpty ? null : _submitAssembly,
                icon: _isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.build),
                label: Text(_isSaving ? 'Processing...' : 'Run Assembly / Production'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    final bomCtrl = Provider.of<BOMController>(context);

    if (bomCtrl.loading && bomCtrl.assemblyList.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredList = bomCtrl.assemblyList.where((asm) {
      if (_searchQuery.isEmpty) return true;
      return asm.assemblyNo.toLowerCase().contains(_searchQuery) ||
          asm.parentItemName.toLowerCase().contains(_searchQuery) ||
          asm.parentItemCode.toLowerCase().contains(_searchQuery);
    }).toList();

    return Column(
      children: [
        // 🔍 Search Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search by Assembly No or Finished Product Name/Code...',
                prefixIcon: Icon(Icons.search),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim().toLowerCase();
                });
              },
            ),
          ),
        ),

        Expanded(
          child: filteredList.isEmpty
              ? const Center(child: Text('No matching assembly entries found.'))
              : Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SizedBox(
                        height: constraints.maxHeight,
                        width: constraints.maxWidth,
                        child: Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minWidth: constraints.maxWidth,
                                  ),
                                  child: DataTable(
                                    headingRowColor: WidgetStateProperty.all(
                                        Theme.of(context).colorScheme.surfaceContainerHighest),
                                    columns: const [
                                      DataColumn(label: Text('Assembly No')),
                                      DataColumn(label: Text('Date')),
                                      DataColumn(label: Text('Finished Good')),
                                      DataColumn(label: Text('Produced Qty')),
                                      DataColumn(label: Text('Total Cost')),
                                      DataColumn(label: Text('Status')),
                                      DataColumn(label: Text('Action')),
                                    ],
                                    rows: filteredList.asMap().entries.map((entry) {
                                      final asm = entry.value;
                                      return DataRow(
                                        color: WidgetStateProperty.all(_rowColor(asm.status)),
                                        cells: [
                                          DataCell(Text(asm.assemblyNo)),
                                          DataCell(Text(_formatDate(asm.assemblyDate))),
                                          DataCell(Text('[${asm.parentItemCode}] ${asm.parentItemName}${asm.parentBrand.isNotEmpty ? ' (${asm.parentBrand})' : ''}')),
                                          DataCell(Text('${asm.qty.toStringAsFixed(2)} ${asm.parentUnit}')),
                                          DataCell(
                                            Text(
                                              'Rs. ${asm.totalCost.toStringAsFixed(2)}',
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          DataCell(_statusChip(asm.status)),
                                          DataCell(
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                OutlinedButton.icon(
                                                  onPressed: () => _showAssemblyDetails(asm),
                                                  icon: const Icon(Icons.visibility, size: 16),
                                                  label: const Text('View'),
                                                ),
                                                if (asm.status == 'RUNNING') ...[
                                                  const SizedBox(width: 8),
                                                  FilledButton.icon(
                                                    style: FilledButton.styleFrom(
                                                      backgroundColor: Colors.red.shade700,
                                                      foregroundColor: Colors.white,
                                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                                    ),
                                                    onPressed: () => _stopAssemblyRun(asm),
                                                    icon: const Icon(Icons.stop, size: 16),
                                                    label: const Text('Stop'),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Color _rowColor(String status) {
    if (status == 'RUNNING') {
      return Colors.green.withOpacity(.05);
    } else {
      return Colors.blueGrey.withOpacity(.05);
    }
  }

  Widget _statusChip(String status) {
    Color bg = Colors.grey.shade100;
    Color fg = Colors.grey.shade800;
    if (status == 'RUNNING') {
      bg = Colors.green.shade50;
      fg = Colors.green.shade700;
    } else if (status == 'STOPPED') {
      bg = Colors.blueGrey.shade50;
      fg = Colors.blueGrey.shade700;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withOpacity(0.3)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Future<void> _stopAssemblyRun(AssemblyHeader asm) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop Assembly Run'),
        content: Text('Are you sure you want to stop the assembly run #${asm.assemblyNo}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Stop Run'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final bomCtrl = Provider.of<BOMController>(context, listen: false);
      final success = await bomCtrl.stopAssembly(asm.id ?? 0);
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Assembly run stopped successfully!'), backgroundColor: Colors.green),
          );
        }
        bomCtrl.loadAssemblies();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to stop assembly run'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  String _formatDate(String dateStr) {
    try {
      final parsed = DateTime.tryParse(dateStr);
      if (parsed != null) {
        return DateFormat('dd-MMM-yyyy').format(parsed);
      }
    } catch (_) {}
    return dateStr;
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const Divider(height: 20),
          child,
        ],
      ),
    );
  }
}
