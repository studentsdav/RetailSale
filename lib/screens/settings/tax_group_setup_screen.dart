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

  final List<Map<String, String>> _countryPresets = [
    {
      'country': 'India',
      'label': 'India (GST 0%, 5%, 12%, 18%, 28% + IGST 5%, 12%, 18%, 28%)',
      'icon': '🇮🇳'
    },
    {
      'country': 'USA',
      'label': 'USA (Zero 0%, Standard Sales Tax 6.25%, Retail 7.25%, Combined 8.25%)',
      'icon': '🇺🇸'
    },
    {
      'country': 'Kenya',
      'label': 'Kenya (Zero-Rated 0%, Standard VAT 16%, Hospitality VAT+CTL 18%, Fuel 8%)',
      'icon': '🇰🇪'
    },
    {
      'country': 'UK',
      'label': 'United Kingdom / England (Zero 0%, Reduced 5%, Standard VAT 20%)',
      'icon': '🇬🇧'
    },
    {
      'country': 'Germany',
      'label': 'Germany (Steuerfrei 0%, Ermäßigter 7%, MwSt 19%)',
      'icon': '🇩🇪'
    },
    {
      'country': 'Brazil',
      'label': 'Brazil (Isento 0%, ICMS 18%, ICMS+PIS+COFINS 27.25%)',
      'icon': '🇧🇷'
    },
    {
      'country': 'EU',
      'label': 'European Union (EU Zero 0%, Reduced 10%, Standard VAT 21%)',
      'icon': '🇪🇺'
    },
    {
      'country': 'Default',
      'label': 'Standard Generic (0%, 10%, 15%, 18%)',
      'icon': '🌐'
    },
  ];

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

  Future<void> _deleteGroup(TaxGroup group) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Delete Tax Group', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${group.groupName}"?\n\nIf any items in Item Master are linked to this tax group, deletion will be blocked.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final res = await ApiClient.delete('${ApiEndpoints.taxGroups}/${group.id}');
      if (res['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? 'Tax group deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
        await _loadTaxGroups();
      } else {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                  SizedBox(width: 8),
                  Text('Cannot Delete', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                ],
              ),
              content: Text(
                res['message'] ?? 'This tax group cannot be deleted because it is linked to items.',
                style: const TextStyle(fontSize: 14),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error deleting tax group: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting tax group: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showAutoSeedDialog() async {
    String selectedCountry = 'India';
    bool overwrite = false;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.public, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Auto-Configure Country Taxes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Automatically configure pre-built standard tax structures and sub-components for your outlet based on regional regulations:',
                      style: TextStyle(color: Colors.black87, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: selectedCountry,
                      decoration: InputDecoration(
                        labelText: 'Select Country / Tax Regime',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: _countryPresets.map((preset) {
                        return DropdownMenuItem<String>(
                          value: preset['country'],
                          child: Text('${preset['icon']} ${preset['label']}', style: const TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedCountry = val);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: overwrite,
                      activeColor: Colors.redAccent,
                      title: const Text('Replace existing tax groups for this outlet', style: TextStyle(fontSize: 13)),
                      subtitle: const Text(
                        'Unused tax groups will be replaced. Any tax groups currently linked to items in Item Master will be safely kept and not deleted.',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      onChanged: (v) => setDialogState(() => overwrite = v ?? false),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.flash_on),
                  label: const Text('Auto-Populate Taxes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _seedTaxes(selectedCountry, overwrite);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _seedTaxes(String country, bool overwrite) async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiClient.post('${ApiEndpoints.taxGroups}/seed-defaults', {
        'country': country,
        'overwrite': overwrite,
      });
      if (res['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? 'Taxes configured successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
        await _loadTaxGroups();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? 'Failed to configure taxes'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error seeding taxes: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error configuring taxes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
      components.add(_ComponentEditRow(
        codeCtrl: TextEditingController(text: 'TAX_1'),
        nameCtrl: TextEditingController(text: 'Tax Component 1'),
        rateCtrl: TextEditingController(text: '5.0'),
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
                          hintText: 'e.g. GST 18%, USA Sales Tax 8.25%, Kenya VAT 16%',
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
                                hintText: 'e.g. GST_18, SALES_TAX, VAT',
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
                              codeCtrl: TextEditingController(text: 'SUB_TAX'),
                              nameCtrl: TextEditingController(text: 'Sub Tax'),
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
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                      }
                      if (mounted) {
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
          TextButton.icon(
            icon: const Icon(Icons.public, color: Colors.blueAccent),
            label: const Text('Auto-Populate Taxes', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
            onPressed: _showAutoSeedDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadTaxGroups,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _taxGroups.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.account_balance_outlined, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          'No Tax Groups configured for this outlet yet.',
                          style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'You can automatically set up standard country taxes with sub-components, or create custom tax rates manually.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              icon: const Icon(Icons.public),
                              label: const Text('Auto-Configure Country Taxes'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: _showAutoSeedDialog,
                            ),
                            const SizedBox(width: 16),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.add),
                              label: const Text('Create Custom Tax Group'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                              onPressed: () => _openGroupDialog(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _taxGroups.length,
                  itemBuilder: (context, index) {
                    final group = _taxGroups[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 1.5,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                              tooltip: 'Edit Tax Group',
                              onPressed: () => _openGroupDialog(group),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              tooltip: 'Delete Tax Group',
                              onPressed: () => _deleteGroup(group),
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
