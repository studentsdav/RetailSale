import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';

class BillValuePromoConfigScreen extends StatefulWidget {
  const BillValuePromoConfigScreen({super.key});

  @override
  State<BillValuePromoConfigScreen> createState() => _BillValuePromoConfigScreenState();
}

class _BillValuePromoConfigScreenState extends State<BillValuePromoConfigScreen> {
  List<dynamic> _promos = [];
  List<dynamic> _products = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final promosRes = await ApiClient.get('/api/sales/bill-value-promos');
      final itemsRes = await ApiClient.get(ApiEndpoints.items);

      setState(() {
        _promos = promosRes['data'] ?? [];
        _products = itemsRes['data'] ?? [];
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading promotions: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deletePromo(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Promotion'),
        content: const Text('Are you sure you want to delete this Bill Value Promotion?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ApiClient.delete('/api/sales/bill-value-promos/$id');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Promotion deleted successfully')),
      );
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting promotion: $e')),
      );
    }
  }

  void _showAddEditDialog([Map<String, dynamic>? promo]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AddEditPromoDialog(
        promo: promo,
        products: _products,
        onSave: () {
          Navigator.pop(ctx);
          _loadData();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill Value Promotions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _promos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.discount_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'No promotions configured yet.',
                        style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _promos.length,
                  itemBuilder: (context, index) {
                    final promo = _promos[index];
                    final targetItemName = promo['target_item']?['item_name'] ?? 'Unknown Item';
                    final targetItemCode = promo['target_item']?['item_code'] ?? '';
                    final isActive = promo['is_active'] == true;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        title: Text(
                          promo['name'] ?? '',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('• Min Bill Value: Rs. ${double.tryParse(promo['min_bill_amount'].toString())?.toStringAsFixed(2) ?? "0.00"}'),
                              const SizedBox(height: 2),
                              Text('• Reward Item: $targetItemName ${targetItemCode.isNotEmpty ? "($targetItemCode)" : ""}'),
                              const SizedBox(height: 2),
                              Text('• Discount: ${promo['discount_value']}% off'),
                            ],
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isActive ? Colors.green.shade50 : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isActive ? 'Active' : 'Inactive',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isActive ? Colors.green.shade700 : Colors.red.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _showAddEditDialog(promo),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deletePromo(promo['id']),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Promo Rule'),
      ),
    );
  }
}

class _AddEditPromoDialog extends StatefulWidget {
  final Map<String, dynamic>? promo;
  final List<dynamic> products;
  final VoidCallback onSave;

  const _AddEditPromoDialog({
    this.promo,
    required this.products,
    required this.onSave,
  });

  @override
  State<_AddEditPromoDialog> createState() => _AddEditPromoDialogState();
}

class _AddEditPromoDialogState extends State<_AddEditPromoDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _minBillAmountController = TextEditingController();
  final _discountValueController = TextEditingController(text: '100');

  int? _targetItemId;
  bool _isActive = true;
  String _selectedItemName = '';

  @override
  void initState() {
    super.initState();
    if (widget.promo != null) {
      _nameController.text = widget.promo!['name'] ?? '';
      _minBillAmountController.text = widget.promo!['min_bill_amount']?.toString() ?? '0';
      _discountValueController.text = widget.promo!['discount_value']?.toString() ?? '100';
      _targetItemId = widget.promo!['target_item_id'];
      _isActive = widget.promo!['is_active'] == true;

      final item = widget.products.firstWhere(
        (p) => p['id'] == _targetItemId,
        orElse: () => null,
      );
      if (item != null) {
        _selectedItemName = '${item['item_name']} (${item['item_code']})';
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _minBillAmountController.dispose();
    _discountValueController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_targetItemId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a target reward item')),
      );
      return;
    }

    final payload = {
      'name': _nameController.text.trim(),
      'min_bill_amount': double.tryParse(_minBillAmountController.text) ?? 0.0,
      'target_item_id': _targetItemId,
      'discount_value': double.tryParse(_discountValueController.text) ?? 100.0,
      'is_active': _isActive,
    };

    try {
      if (widget.promo == null) {
        await ApiClient.post('/api/sales/bill-value-promos', payload);
      } else {
        await ApiClient.put('/api/sales/bill-value-promos/${widget.promo!['id']}', payload);
      }
      widget.onSave();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving configuration: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.promo == null ? 'Add Promotion Rule' : 'Edit Promotion Rule'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 450,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Campaign / Rule Name',
                    hintText: 'e.g. Spend 200, Get Milk Free',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _minBillAmountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Minimum Bill Value (Rs.)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                Autocomplete<Map<String, dynamic>>(
                  initialValue: TextEditingValue(text: _selectedItemName),
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return const Iterable<Map<String, dynamic>>.empty();
                    }
                    return widget.products.where((item) {
                      final name = item['item_name']?.toString().toLowerCase() ?? '';
                      final code = item['item_code']?.toString().toLowerCase() ?? '';
                      final term = textEditingValue.text.toLowerCase();
                      return name.contains(term) || code.contains(term);
                    }).cast<Map<String, dynamic>>();
                  },
                  displayStringForOption: (option) => '${option['item_name']} (${option['item_code']})',
                  onSelected: (option) {
                    setState(() {
                      _targetItemId = option['id'];
                      _selectedItemName = '${option['item_name']} (${option['item_code']})';
                    });
                  },
                  fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
                    return TextFormField(
                      controller: textController,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        labelText: 'Target Reward Item',
                        hintText: 'Type to search item...',
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (_targetItemId == null) {
                          return 'Please select an item';
                        }
                        return null;
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _discountValueController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Discount Percentage (e.g. 100 for Free)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Required';
                    final parsed = double.tryParse(val);
                    if (parsed == null || parsed <= 0 || parsed > 100) {
                      return 'Must be between 1 and 100';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Is Active'),
                  value: _isActive,
                  onChanged: (val) => setState(() => _isActive = val),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
