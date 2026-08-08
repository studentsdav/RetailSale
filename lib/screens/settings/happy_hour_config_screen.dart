import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/theme/app_theme.dart';

class HappyHourConfigScreen extends StatefulWidget {
  const HappyHourConfigScreen({super.key});

  @override
  State<HappyHourConfigScreen> createState() => _HappyHourConfigScreenState();
}

class _HappyHourConfigScreenState extends State<HappyHourConfigScreen> {
  List<dynamic> _rules = [];
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
      final rulesRes = await ApiClient.get('/api/sales/happy-hours');
      final itemsRes = await ApiClient.get(ApiEndpoints.items);

      setState(() {
        _rules = rulesRes['data'] ?? [];
        _products = itemsRes['data'] ?? [];
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading configurations: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteRule(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Configuration'),
        content: const Text('Are you sure you want to delete this Happy Hour configuration?'),
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
      await ApiClient.delete('/api/sales/happy-hours/$id');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuration deleted successfully')),
      );
      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting configuration: $e')),
      );
    }
  }

  void _showAddEditDialog([Map<String, dynamic>? rule]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AddEditHappyHourDialog(
        rule: rule,
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
        title: const Text('Happy Hour Configurations'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: TapRegion(
              child: FilledButton.icon(
                onPressed: () => _showAddEditDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add Configuration'),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _rules.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.alarm_off, size: 64, color: theme.colorScheme.outline),
                      const SizedBox(height: 16),
                      Text(
                        'No Happy Hour configurations set yet.',
                        style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.outline),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: _rules.length,
                  itemBuilder: (context, index) {
                    final r = _rules[index];
                    final applyAll = r['apply_to_all_happy_hour_items'] == true;
                    final parentName = r['parent_item'] != null
                        ? '${r['parent_item']['item_name']} (${r['parent_item']['item_code']})'
                        : 'N/A';
                    final freeItemName = r['free_item'] != null
                        ? '${r['free_item']['item_name']} (${r['free_item']['item_code']})'
                        : 'Same item';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12.0),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: r['is_active'] == true ? Colors.green.shade200 : Colors.grey.shade300,
                          width: 1.5,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time_filled,
                                      color: r['is_active'] == true ? Colors.green : Colors.grey,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${r['start_time']} - ${r['end_time']}',
                                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      onPressed: () => _showAddEditDialog(r),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _deleteRule(r['id']),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            _infoRow('Weekdays', r['days_of_week'] ?? 'All days'),
                            _infoRow('Scheme Style', '${r['buy_qty']} + ${r['free_qty']} Free'),
                            Builder(
                              builder: (context) {
                                final happyHourProducts = _products.where((p) => p['is_happy_hour'] == true || p['is_happy_hour'] == 1).toList();
                                final happyHourNames = happyHourProducts.map((p) => p['item_name']?.toString() ?? '').where((name) => name.isNotEmpty).join(', ');
                                final targetItemsStr = applyAll
                                    ? 'All Happy Hour Items${happyHourNames.isNotEmpty ? " ($happyHourNames)" : " (No items currently marked)"}'
                                    : 'Individual Item: $parentName';
                                return _infoRow('Target Items', targetItemsStr);
                              }
                            ),
                            _infoRow('Gifted Item', freeItemName),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  r['is_active'] == true ? 'Active' : 'Inactive',
                                  style: TextStyle(
                                    color: r['is_active'] == true ? Colors.green : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Switch(
                                  value: r['is_active'] == true,
                                  onChanged: (val) async {
                                    try {
                                      await ApiClient.put('/api/sales/happy-hours/${r['id']}', {'is_active': val});
                                      _loadData();
                                    } catch (_) {}
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddEditHappyHourDialog extends StatefulWidget {
  final Map<String, dynamic>? rule;
  final List<dynamic> products;
  final VoidCallback onSave;

  const _AddEditHappyHourDialog({
    this.rule,
    required this.products,
    required this.onSave,
  });

  @override
  State<_AddEditHappyHourDialog> createState() => _AddEditHappyHourDialogState();
}

class _AddEditHappyHourDialogState extends State<_AddEditHappyHourDialog> {
  final _formKey = GlobalKey<FormState>();
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  final TextEditingController _buyQtyCtrl = TextEditingController(text: '2');
  final TextEditingController _freeQtyCtrl = TextEditingController(text: '1');
  bool _applyAll = true;
  int? _parentItemId;
  int? _freeItemId;
  bool _isActive = true;

  final List<String> _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final List<String> _selectedDays = [];

  @override
  void initState() {
    super.initState();
    if (widget.rule != null) {
      final r = widget.rule!;
      _startTime = _parseTime(r['start_time']);
      _endTime = _parseTime(r['end_time']);
      _buyQtyCtrl.text = r['buy_qty'].toString();
      _freeQtyCtrl.text = r['free_qty'].toString();
      _applyAll = r['apply_to_all_happy_hour_items'] == true;
      _parentItemId = r['parent_item_id'];
      _freeItemId = r['free_item_id'];
      _isActive = r['is_active'] == true;

      if (r['days_of_week'] != null && r['days_of_week'].toString().isNotEmpty) {
        _selectedDays.addAll(r['days_of_week'].toString().split(',').map((s) => s.trim()));
      }
    } else {
      _selectedDays.addAll(_weekdays);
    }
  }

  TimeOfDay? _parseTime(String? timeStr) {
    if (timeStr == null || !timeStr.contains(':')) return null;
    final parts = timeStr.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return '';
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _selectStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? const TimeOfDay(hour: 12, minute: 0),
    );
    if (picked != null) {
      setState(() => _startTime = picked);
    }
  }

  Future<void> _selectEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? const TimeOfDay(hour: 15, minute: 0),
    );
    if (picked != null) {
      setState(() => _endTime = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both start and end times')),
      );
      return;
    }

    final payload = {
      'start_time': _formatTime(_startTime),
      'end_time': _formatTime(_endTime),
      'days_of_week': _selectedDays.join(','),
      'buy_qty': double.parse(_buyQtyCtrl.text),
      'free_qty': double.parse(_freeQtyCtrl.text),
      'apply_to_all_happy_hour_items': _applyAll,
      'parent_item_id': _applyAll ? null : _parentItemId,
      'free_item_id': _freeItemId,
      'is_active': _isActive,
    };

    try {
      if (widget.rule != null) {
        await ApiClient.put('/api/sales/happy-hours/${widget.rule!['id']}', payload);
      } else {
        await ApiClient.post('/api/sales/happy-hours', payload);
      }
      widget.onSave();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving configuration: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.rule != null;

    return AlertDialog(
      title: Text(isEdit ? 'Edit Configuration' : 'Add Configuration'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Timing picks
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _selectStartTime,
                        icon: const Icon(Icons.login),
                        label: Text(_startTime == null ? 'Start Time' : 'Starts: ${_formatTime(_startTime)}'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _selectEndTime,
                        icon: const Icon(Icons.logout),
                        label: Text(_endTime == null ? 'End Time' : 'Ends: ${_formatTime(_endTime)}'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Buy & Free Qty
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _buyQtyCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Buy Quantity'),
                        validator: (val) => val == null || double.tryParse(val) == null ? 'Invalid' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _freeQtyCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Free Quantity'),
                        validator: (val) => val == null || double.tryParse(val) == null ? 'Invalid' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Weekdays multi select
                const Text('Allowed Weekdays', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _weekdays.map((day) {
                    final isSelected = _selectedDays.contains(day);
                    return FilterChip(
                      label: Text(day),
                      selected: isSelected,
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            _selectedDays.add(day);
                          } else {
                            _selectedDays.remove(day);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Toggle Apply to all
                SwitchListTile(
                  title: const Text('Apply to all marked Happy Hour items'),
                  value: _applyAll,
                  onChanged: (val) => setState(() => _applyAll = val),
                ),

                if (_applyAll) ...[
                  const SizedBox(height: 8),
                  Builder(
                    builder: (context) {
                      final happyHourProducts = widget.products.where((p) => p['is_happy_hour'] == true || p['is_happy_hour'] == 1).toList();
                      final happyHourNames = happyHourProducts.map((p) => p['item_name']?.toString() ?? '').where((name) => name.isNotEmpty).join(', ');
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          happyHourNames.isNotEmpty
                              ? 'Currently active items: $happyHourNames'
                              : 'No items are currently marked as Happy Hour items in the Item Master.',
                          style: TextStyle(
                            color: happyHourNames.isNotEmpty ? Colors.blue.shade700 : Colors.red.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }
                  ),
                ],

                if (!_applyAll) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    value: _parentItemId,
                    decoration: const InputDecoration(labelText: 'Trigger Item'),
                    items: widget.products.map<DropdownMenuItem<int>>((item) {
                      return DropdownMenuItem<int>(
                        value: item['id'],
                        child: Text('${item['item_name']} (${item['item_code']})'),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _parentItemId = val),
                    validator: (val) => val == null && !_applyAll ? 'Item is required' : null,
                  ),
                ],

                const SizedBox(height: 8),
                DropdownButtonFormField<int?>(
                  value: _freeItemId,
                  decoration: const InputDecoration(labelText: 'Gifted Free Item (Optional)'),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Same item as trigger'),
                    ),
                    ...widget.products.map<DropdownMenuItem<int?>>((item) {
                      return DropdownMenuItem<int?>(
                        value: item['id'],
                        child: Text('${item['item_name']} (${item['item_code']})'),
                      );
                    }),
                  ],
                  onChanged: (val) => setState(() => _freeItemId = val),
                ),

                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Is Configuration Active'),
                  value: _isActive,
                  onChanged: (val) => setState(() => _isActive = val),
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
