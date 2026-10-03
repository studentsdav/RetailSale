import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../models/inventory/tax_group_model.dart';

class TaxGroupSetupScreen extends StatefulWidget {
  const TaxGroupSetupScreen({super.key});

  @override
  State<TaxGroupSetupScreen> createState() => _TaxGroupSetupScreenState();
}

class _TaxGroupSetupScreenState extends State<TaxGroupSetupScreen> {
  bool _isLoading = false;
  List<TaxGroup> _taxGroups = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _loadTaxGroups());
  }

  Future<void> _loadTaxGroups() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiClient.get(ApiEndpoints.taxGroups);
      if (res['success'] == true && res['data'] != null) {
        final raw = res['data'] as List;
        setState(() {
          _taxGroups = raw.map((e) => TaxGroup.fromJson(Map<String, dynamic>.from(e))).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading tax groups: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openGroupDialog([TaxGroup? group]) {
    final isEdit = group != null;
    final nameCtrl = TextEditingController(text: group?.groupName ?? '');
    final codeCtrl = TextEditingController(text: group?.groupCode ?? '');
    bool isInclusive = group?.isTaxInclusive ?? false;

    List<_ComponentEditRow> components = (group?.components ?? []).map((c) {
      return _ComponentEditRow(
        codeCtrl: TextEditingController(text: c.componentCode),
        nameCtrl: TextEditingController(text: c.componentName),
        rateCtrl: TextEditingController(text: c.rate.toString()),
        calcType: c.calculationType,
      );
    }).toList();

    if (components.isEmpty) {
      // Default initial component pre-added for quick setup
      components.add(_ComponentEditRow(
        codeCtrl: TextEditingController(text: 'STATE_TAX'),
        nameCtrl: TextEditingController(text: 'State Sales Tax'),
        rateCtrl: TextEditingController(text: '6.25'),
        calcType: 'FLAT_PERCENT',
      ));
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            double totalCalcRate = components.fold<double>(
              0.0,
              (sum, c) => sum + (double.tryParse(c.rateCtrl.text) ?? 0.0),
            );

            return AlertDialog(
              title: Text(isEdit ? 'Edit Tax Group' : 'Create New Tax Group'),
              content: SizedBox(
                width: 600,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Tax Group Name *',
                          hintText: 'e.g. USA Texas Retail Tax (8.25%) or Kenya Restaurant Tax',
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: codeCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Group Code (Printed on Bill)',
                                hintText: 'e.g. GST, VAT, SALES_TAX',
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Row(
                            children: [
                              Checkbox(
                                value: isInclusive,
                                onChanged: (v) => setDialogState(() => isInclusive = v ?? false),
                              ),
                              const Text('Tax Inclusive'),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Tax Components (Sub-Taxes)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          Text(
                            'Total Rate: ${totalCalcRate.toStringAsFixed(2)}%',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...components.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final row = entry.value;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: row.nameCtrl,
                                  decoration: const InputDecoration(labelText: 'Component Name'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: row.codeCtrl,
                                  decoration: const InputDecoration(labelText: 'Code'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 1,
                                child: TextField(
                                  controller: row.rateCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'Rate (%)'),
                                  onChanged: (_) => setDialogState(() {}),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () {
                                  if (components.length > 1) {
                                    setDialogState(() => components.removeAt(idx));
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add Component Sub-Tax'),
                        onPressed: () {
                          setDialogState(() {
                            components.add(_ComponentEditRow(
                              codeCtrl: TextEditingController(text: 'CITY_TAX'),
                              nameCtrl: TextEditingController(text: 'City Tax'),
                              rateCtrl: TextEditingController(text: '1.00'),
                              calcType: 'FLAT_PERCENT',
                            ));
                          });
                        },
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
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;

                    final compPayload = components.map((c) {
                      return {
                        'component_code': c.codeCtrl.text.trim(),
                        'component_name': c.nameCtrl.text.trim(),
                        'rate': double.tryParse(c.rateCtrl.text.trim()) ?? 0.0,
                        'calculation_type': c.calcType,
                      };
                    }).toList();

                    final payload = {
                      'group_name': nameCtrl.text.trim(),
                      'group_code': codeCtrl.text.trim(),
                      'is_tax_inclusive': isInclusive,
                      'components': compPayload,
                    };

                    try {
                      if (isEdit) {
                        await ApiClient.put('${ApiEndpoints.taxGroups}/${group.id}', payload);
                      } else {
                        await ApiClient.post(ApiEndpoints.taxGroups, payload);
                      }
                      if (mounted) {
                        Navigator.pop(ctx);
                        _loadTaxGroups();
                      }
                    } catch (e) {
                      debugPrint('Error saving tax group: $e');
                    }
                  },
                  child: const Text('Save Tax Group'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tax Groups & Components Master'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTaxGroups,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _taxGroups.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.account_balance_outlined, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'No Tax Groups configured yet.',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Create First Tax Group'),
                        onPressed: () => _openGroupDialog(),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _taxGroups.length,
                  itemBuilder: (context, index) {
                    final group = _taxGroups[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade100,
                          child: Text(
                            '${group.totalRate.toStringAsFixed(0)}%',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                          ),
                        ),
                        title: Text(
                          group.groupName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Code: ${(group.groupCode != null && group.groupCode!.trim().isNotEmpty) ? group.groupCode!.trim() : "Auto"} | Components: ${group.components.length} | ${group.isTaxInclusive ? "Inclusive" : "Exclusive"}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _openGroupDialog(group),
                            ),
                          ],
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Assigned Sub-Tax Components:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                ...group.components.map((c) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('• ${c.componentName} (${c.componentCode})'),
                                        Text(
                                          '${c.rate.toStringAsFixed(2)}%',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Create Tax Group'),
        onPressed: () => _openGroupDialog(),
      ),
    );
  }
}

class _ComponentEditRow {
  final TextEditingController codeCtrl;
  final TextEditingController nameCtrl;
  final TextEditingController rateCtrl;
  final String calcType;

  _ComponentEditRow({
    required this.codeCtrl,
    required this.nameCtrl,
    required this.rateCtrl,
    required this.calcType,
  });
}
