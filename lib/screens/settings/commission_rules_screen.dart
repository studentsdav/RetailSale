import 'package:flutter/material.dart';
import '../../controllers/sales/sales_controller.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';

class CommissionRulesScreen extends StatefulWidget {
  const CommissionRulesScreen({super.key});

  @override
  State<CommissionRulesScreen> createState() => _CommissionRulesScreenState();
}

class _CommissionRulesScreenState extends State<CommissionRulesScreen> {
  final SalesController _salesCtrl = SalesController();
  bool _isLoading = false;

  List<Map<String, dynamic>> _rules = [];
  List<Map<String, dynamic>> _platforms = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _products = [];

  String? _selectedPlatformFilter;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      // Load Platforms
      final sources = await _salesCtrl.listSaleSources();
      _platforms = sources.where((e) => e['is_active'] == true).toList();
      if (_platforms.isNotEmpty) {
        _selectedPlatformFilter = _platforms.first['name'].toString();
      }

      // Load Categories (Item Groups)
      final groupsRes = await ApiClient.get('/api/inventory/groups');
      _categories = (groupsRes['data'] as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      // Load Products
      final itemsRes = await ApiClient.get(ApiEndpoints.items);
      _products = (itemsRes['data'] as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      await _loadRules();
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadRules() async {
    int? platformId;
    if (_selectedPlatformFilter != null) {
      final plat = _platforms.firstWhere(
        (p) => p['name'] == _selectedPlatformFilter,
        orElse: () => const {},
      );
      platformId = plat['id'];
    }

    if (platformId == null) return;

    try {
      final rulesList = await _salesCtrl.listCommissionRules(platformId: platformId);
      setState(() {
        _rules = rulesList;
      });
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg.replaceFirst('Exception: ', '')),
        backgroundColor: Colors.red.shade800,
      ),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  void _showFormulaGuide(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue.shade600, size: 24),
            const SizedBox(width: 8),
            const Text('Commission Formula Guide'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How Platform Commission is Calculated:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 15, color: Colors.black, height: 1.4),
                  children: [
                    TextSpan(
                      text: '[ (Rate × Percentage%)',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                    ),
                    const TextSpan(text: ' + '),
                    TextSpan(
                      text: 'Fixed Fee ]',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade700),
                    ),
                    const TextSpan(text: ' × '),
                    TextSpan(
                      text: 'Quantity',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Example Walkthrough:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            _buildStepRow('1. Percentage Part', 'Rate (₹60) × 18% = ₹10.80', Colors.blue.shade700),
            _buildStepRow('2. Add Fixed Fee', '₹10.80 + ₹200.00 = ₹210.80', Colors.orange.shade700),
            _buildStepRow('3. Quantity Multiply', '₹210.80 × 2 units = ₹421.60', Colors.green.shade700),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 4),
            const Text(
              'Scope Hierarchy Level:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 4),
            const Text(
              '• Product specific rules override Category specific rules, which override Platform Defaults.\n• Overlapping rules are resolved by highest priority value first.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildStepRow(String title, String formula, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• $title: ', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          Expanded(
            child: Text(
              formula,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleRuleActive(Map<String, dynamic> rule, bool val) async {
    try {
      await _salesCtrl.updateCommissionRule(rule['id'], {'is_active': val});
      _showSuccess('Rule status updated');
      _loadRules();
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _deleteRule(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Commission Rule'),
        content: const Text('Are you sure you want to delete this commission rule? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
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
      await _salesCtrl.deleteCommissionRule(id);
      _showSuccess('Rule deleted successfully');
      _loadRules();
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _showAddEditRuleDialog({Map<String, dynamic>? rule}) async {
    final isEdit = rule != null;
    int? selectedPlatformId;
    if (isEdit) {
      selectedPlatformId = rule['platform_id'];
    } else if (_selectedPlatformFilter != null) {
      final plat = _platforms.firstWhere(
        (p) => p['name'] == _selectedPlatformFilter,
        orElse: () => const {},
      );
      selectedPlatformId = plat['id'];
    }

    String ruleTargetType = 'PLATFORM'; // 'PLATFORM', 'CATEGORY', 'PRODUCT'
    int? selectedCategoryId;
    int? selectedProductId;

    if (isEdit) {
      if (rule['product_id'] != null) {
        ruleTargetType = 'PRODUCT';
        selectedProductId = rule['product_id'];
      } else if (rule['category_id'] != null) {
        ruleTargetType = 'CATEGORY';
        selectedCategoryId = rule['category_id'];
      }
    }

    final minPriceCtrl = TextEditingController(text: isEdit ? rule['min_price'].toString() : '0.00');
    final maxPriceCtrl = TextEditingController(text: isEdit ? rule['max_price'].toString() : '9999999.00');
    final percentageCtrl = TextEditingController(text: isEdit ? rule['percentage_fee'].toString() : '0.00');
    final fixedCtrl = TextEditingController(text: isEdit ? rule['fixed_fee'].toString() : '0.00');
    final priorityCtrl = TextEditingController(text: isEdit ? rule['priority'].toString() : '0');
    bool isActive = isEdit ? (rule['is_active'] == true) : true;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEdit ? 'Edit Commission Rule' : 'Add Commission Rule'),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Platform select
                      DropdownButtonFormField<int>(
                        value: selectedPlatformId,
                        decoration: const InputDecoration(labelText: 'Platform / Sales Source'),
                        items: _platforms.map((p) {
                          return DropdownMenuItem<int>(
                            value: p['id'],
                            child: Text(p['name'].toString()),
                          );
                        }).toList(),
                        onChanged: isEdit ? null : (val) {
                          setDialogState(() {
                            selectedPlatformId = val;
                          });
                        },
                      ),
                      const SizedBox(height: 12),

                      // Target Type Select
                       Row(
                        children: [
                          const Text(
                            'Rule Scope / Level',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                          ),
                          const SizedBox(width: 6),
                          Tooltip(
                            triggerMode: TooltipTriggerMode.tap,
                            message: 'Define the target specificity:\n'
                                '• Platform: Applies to all platform orders.\n'
                                '• Category: Applies to a specific item category.\n'
                                '• Product: Applies only to a specific item.\n\n'
                                'Product rules override category rules, which override platform defaults.',
                            child: Icon(Icons.info_outline, color: Colors.grey.shade600, size: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment<String>(value: 'PLATFORM', label: Text('Platform')),
                          ButtonSegment<String>(value: 'CATEGORY', label: Text('Category')),
                          ButtonSegment<String>(value: 'PRODUCT', label: Text('Product')),
                        ],
                        selected: {ruleTargetType},
                        onSelectionChanged: (val) {
                          setDialogState(() {
                            ruleTargetType = val.first;
                          });
                        },
                      ),
                      const SizedBox(height: 12),

                      // Category Select if scope = CATEGORY
                      if (ruleTargetType == 'CATEGORY') ...[
                        DropdownButtonFormField<int>(
                          value: selectedCategoryId,
                          decoration: const InputDecoration(labelText: 'Product Category'),
                          items: _categories.map((c) {
                            return DropdownMenuItem<int>(
                              value: c['id'],
                              child: Text(c['group_name'].toString()),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setDialogState(() {
                              selectedCategoryId = val;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Product Select if scope = PRODUCT
                      if (ruleTargetType == 'PRODUCT') ...[
                        DropdownButtonFormField<int>(
                          value: selectedProductId,
                          decoration: const InputDecoration(labelText: 'Product / Item'),
                          items: _products.map((p) {
                            return DropdownMenuItem<int>(
                              value: p['id'],
                              child: Text('[${p['item_code']}] ${p['item_name']}'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setDialogState(() {
                              selectedProductId = val;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Price slabs row
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: minPriceCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'Min Price (₹)', hintText: '0.00'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: maxPriceCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'Max Price (₹)', hintText: '9999999.00'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Percentage & Fixed fee
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: percentageCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Percentage Fee (%)', 
                                hintText: '0.00',
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.help_outline, size: 18),
                                  onPressed: () => _showFormulaGuide(context),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: fixedCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Fixed Flat Fee (₹)', 
                                hintText: '0.00',
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.help_outline, size: 18),
                                  onPressed: () => _showFormulaGuide(context),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Priority and active toggle
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: priorityCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Evaluation Priority', 
                                hintText: '0',
                                suffixIcon: Tooltip(
                                  triggerMode: TooltipTriggerMode.tap,
                                  message: 'Higher priority values resolve first in case of overlapping price slabs or target scopes.',
                                  child: const Icon(Icons.info_outline, size: 18),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Row(
                            children: [
                              const Text('Active'),
                              Switch(
                                value: isActive,
                                onChanged: (val) {
                                  setDialogState(() {
                                    isActive = val;
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () async {
                    if (selectedPlatformId == null) {
                      _showError('Please select a platform');
                      return;
                    }
                    if (ruleTargetType == 'CATEGORY' && selectedCategoryId == null) {
                      _showError('Please select a category');
                      return;
                    }
                    if (ruleTargetType == 'PRODUCT' && selectedProductId == null) {
                      _showError('Please select a product');
                      return;
                    }

                    final payload = {
                      'platform_id': selectedPlatformId,
                      'category_id': ruleTargetType == 'CATEGORY' ? selectedCategoryId : null,
                      'product_id': ruleTargetType == 'PRODUCT' ? selectedProductId : null,
                      'min_price': double.tryParse(minPriceCtrl.text) ?? 0.0,
                      'max_price': double.tryParse(maxPriceCtrl.text) ?? 9999999.0,
                      'percentage_fee': double.tryParse(percentageCtrl.text) ?? 0.0,
                      'fixed_fee': double.tryParse(fixedCtrl.text) ?? 0.0,
                      'priority': int.tryParse(priorityCtrl.text) ?? 0,
                      'is_active': isActive
                    };

                    try {
                      if (isEdit) {
                        await _salesCtrl.updateCommissionRule(rule['id'], payload);
                      } else {
                        await _salesCtrl.createCommissionRule(payload);
                      }
                      if (context.mounted) Navigator.pop(context);
                      _showSuccess(isEdit ? 'Rule updated successfully' : 'Rule added successfully');
                      _loadRules();
                    } catch (e) {
                      _showError(e.toString());
                    }
                  },
                  child: const Text('Save'),
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
        title: const Text('Platform Commission Rule Engine'),
        actions: [
          IconButton(
            tooltip: 'Reload Rules',
            onPressed: _loadRules,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hierarchy visual explainer card
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.info_outline, color: Color(0xFF2563EB), size: 24),
                              SizedBox(width: 8),
                              Text(
                                'How the Waterfall Rule Engine Evaluates Commissions:',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _infoChip('1. Product Rule', 'Evaluated first. Match on product ID + price slab.', Colors.blue),
                              const Icon(Icons.chevron_right, color: Colors.grey),
                              _infoChip('2. Category Rule', 'Match on product category + price slab.', Colors.orange),
                              const Icon(Icons.chevron_right, color: Colors.grey),
                              _infoChip('3. Platform Default', 'Fallback rule with lowest specificity.', Colors.green),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Filter Row
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Platform / Channel: ',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 200,
                              child: DropdownButtonFormField<String>(
                                value: _selectedPlatformFilter,
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  border: OutlineInputBorder(),
                                ),
                                items: _platforms.map((p) {
                                  return DropdownMenuItem<String>(
                                    value: p['name'].toString(),
                                    child: Text(p['name'].toString()),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedPlatformFilter = val;
                                  });
                                  _loadRules();
                                },
                              ),
                            ),
                          ],
                        ),
                        FilledButton.icon(
                          onPressed: () => _showAddEditRuleDialog(),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add Commission Rule'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Rules Ledger Table
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Commission Rules Ledger',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _showFormulaGuide(context),
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: Icon(Icons.info_outline, color: Colors.blue.shade600, size: 20),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text('Rules will resolve from top to bottom based on specificity and priority levels.', style: TextStyle(color: Color(0xFF64748B))),
                        const SizedBox(height: 16),
                        _rules.isEmpty
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(40),
                                  child: Text('No custom commission rules configured for this platform.'),
                                ),
                              )
                            : SizedBox(
                                width: double.infinity,
                                child: Scrollbar(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                                      columns: const [
                                        DataColumn(label: Text('Scope / Target')),
                                        DataColumn(label: Text('Price Slab')),
                                        DataColumn(label: Text('Commission %')),
                                        DataColumn(label: Text('Fixed Fee')),
                                        DataColumn(label: Text('Priority')),
                                        DataColumn(label: Text('Status')),
                                        DataColumn(label: Text('Actions')),
                                      ],
                                      rows: _rules.map((rule) {
                                        String targetScope = 'Platform Default';
                                        Color scopeColor = Colors.green;
                                        if (rule['product'] != null) {
                                          targetScope = 'Product: [${rule['product']['item_code']}] ${rule['product']['item_name']}';
                                          scopeColor = Colors.blue;
                                        } else if (rule['category'] != null) {
                                          targetScope = 'Category: ${rule['category']['group_name']}';
                                          scopeColor = Colors.orange;
                                        }

                                        return DataRow(
                                          cells: [
                                            DataCell(Chip(
                                              label: Text(targetScope),
                                              backgroundColor: scopeColor.withOpacity(0.1),
                                              labelStyle: TextStyle(color: scopeColor, fontWeight: FontWeight.bold, fontSize: 12),
                                              side: BorderSide.none,
                                            )),
                                            DataCell(Text('₹${rule['min_price']} - ₹${rule['max_price']}')),
                                            DataCell(Text('${rule['percentage_fee']}%')),
                                            DataCell(Text('₹${rule['fixed_fee']}')),
                                            DataCell(Text('${rule['priority']}')),
                                            DataCell(Switch(
                                              value: rule['is_active'] == true,
                                              onChanged: (val) => _toggleRuleActive(rule, val),
                                            )),
                                            DataCell(Row(
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.edit_rounded, color: Colors.blue),
                                                  onPressed: () => _showAddEditRuleDialog(rule: rule),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.delete_rounded, color: Colors.red),
                                                  onPressed: () => _deleteRule(rule['id']),
                                                ),
                                              ],
                                            )),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _infoChip(String label, String tooltip, Color color) {
    return Expanded(
      child: Tooltip(
        message: tooltip,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 2),
              Text(tooltip, style: const TextStyle(fontSize: 11, color: Colors.black54), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}
