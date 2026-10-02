import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';

class StockTakingScreen extends StatefulWidget {
  const StockTakingScreen({super.key});

  @override
  State<StockTakingScreen> createState() => _StockTakingScreenState();
}

class _StockTakingScreenState extends State<StockTakingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = false;
  bool _saving = false;

  // Active Audit Data
  DateTime _auditDate = DateTime.now();
  String _selectedDepartment = 'ALL';
  List<String> _departments = ['ALL'];
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _allItems = [];
  List<Map<String, dynamic>> _filteredItems = [];
  bool _showVarianceOnly = false;

  // Historical Report Data
  List<Map<String, dynamic>> _reports = [];
  DateTimeRange _reportDateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );
  String _reportDepartment = 'ALL';
  bool _reportVarianceOnly = false;

  static const Color primaryColor = Color(0xFF0B5CAD);

  final List<String> _predefinedReasons = [
    'Physical Stock Count',
    'Damage / Spoilage',
    'Theft / Pilferage',
    'Unrecorded Sales / Usage',
    'Unrecorded Purchase / GRN',
    'Data Entry Correction',
    'Supplier Short Supply',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging && _tabController.index == 1) {
        _fetchReports();
      }
    });
    _fetchItems();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  Future<void> _fetchItems() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.get(ApiEndpoints.stockTakingItems);
      if (res['success'] == true) {
        final List list = res['data'] ?? [];
        final List depts = res['departments'] ?? [];
        setState(() {
          _departments = ['ALL', ...depts.map((d) => d.toString())];
          _allItems = list.map((item) {
            final double current = _toDouble(item['current_balance']);
            return {
              'id': item['id'],
              'item_code': item['item_code']?.toString() ?? '',
              'item_name': item['item_name']?.toString() ?? '',
              'unit': item['unit']?.toString() ?? 'PCS',
              'department': item['department']?.toString() ?? 'General',
              'rate': _toDouble(item['rate']),
              'current_balance': current,
              'counted_qty': current,
              'variance': 0.0,
              'reason': 'Physical Stock Count',
              'controller': TextEditingController(text: current.toStringAsFixed(2)),
            };
          }).toList();
          _applyFilters();
        });
      }
    } catch (e) {
      debugPrint('Error loading stock taking items: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load items: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    final query = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filteredItems = _allItems.where((item) {
        final matchDept = _selectedDepartment == 'ALL' || item['department'] == _selectedDepartment;
        final name = (item['item_name'] ?? '').toString().toLowerCase();
        final code = (item['item_code'] ?? '').toString().toLowerCase();
        final matchSearch = query.isEmpty || name.contains(query) || code.contains(query);
        final variance = _toDouble(item['variance']);
        final matchVariance = !_showVarianceOnly || variance.abs() > 0.001;
        return matchDept && matchSearch && matchVariance;
      }).toList();
    });
  }

  void _onCountChanged(Map<String, dynamic> item, String val) {
    final counted = double.tryParse(val.trim()) ?? _toDouble(item['current_balance']);
    final current = _toDouble(item['current_balance']);
    final variance = counted - current;
    setState(() {
      item['counted_qty'] = counted;
      item['variance'] = variance;
    });
  }

  Future<void> _saveAudit() async {
    final changedItems = _allItems.where((item) => _toDouble(item['variance']).abs() > 0.001).toList();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Stock Reconciliation'),
        content: Text(
          'Total Items in Audit: ${_allItems.length}\n'
          'Items with Variance: ${changedItems.length}\n\n'
          'Would you like to save this Physical Stock Take and auto-adjust the inventory ledger for variances?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm & Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _saving = true);
    try {
      final payload = {
        'audit_date': DateFormat('yyyy-MM-dd').format(_auditDate),
        'reconcile_ledger': true,
        'items': _allItems.map((item) => {
          'item_code': item['item_code'],
          'item_name': item['item_name'],
          'unit': item['unit'],
          'department': item['department'],
          'current_balance': item['current_balance'],
          'counted_qty': item['counted_qty'],
          'variance': item['variance'],
          'reason': item['reason'],
        }).toList(),
      };

      final res = await ApiClient.post(ApiEndpoints.stockTakingSave, payload);
      if (res['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? 'Stock taking audit recorded successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          _fetchItems();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Failed to save audit.'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving stock take: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _fetchReports() async {
    setState(() => _loading = true);
    try {
      final start = DateFormat('yyyy-MM-dd').format(_reportDateRange.start);
      final end = DateFormat('yyyy-MM-dd').format(_reportDateRange.end);
      final params = [
        'start_date=$start',
        'end_date=$end',
        if (_reportDepartment != 'ALL') 'department=$_reportDepartment',
        if (_reportVarianceOnly) 'variance_only=true',
      ];
      final url = '${ApiEndpoints.stockTakingReports}?${params.join('&')}';
      final res = await ApiClient.get(url);
      if (res['success'] == true) {
        setState(() {
          _reports = List<Map<String, dynamic>>.from(res['data'] ?? []);
        });
      }
    } catch (e) {
      debugPrint('Error fetching reports: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Taking & Physical Inventory Audit'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.fact_check_outlined), text: 'Physical Count Sheet'),
            Tab(icon: Icon(Icons.analytics_outlined), text: 'Stock Take Reports & History'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _tabController.index == 0 ? _fetchItems : _fetchReports,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAuditSheetTab(),
          _buildReportsTab(),
        ],
      ),
    );
  }

  Widget _buildAuditSheetTab() {
    if (_loading && _allItems.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final totalItems = _allItems.length;
    final varianceCount = _allItems.where((i) => (i['variance'] as double).abs() > 0.001).length;
    final inBalanceCount = totalItems - varianceCount;

    return Column(
      children: [
        // Top Filter & Config Bar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              // Date Picker
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _auditDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                  );
                  if (picked != null) setState(() => _auditDate = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today, size: 16, color: primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        'Audit Date: ${DateFormat('dd MMM yyyy').format(_auditDate)}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
              // Department Filter
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedDepartment,
                    hint: const Text('Department'),
                    items: _departments.map((d) => DropdownMenuItem(value: d, child: Text('Dept: $d'))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedDepartment = val);
                        _applyFilters();
                      }
                    },
                  ),
                ),
              ),
              // Search Field
              SizedBox(
                width: 220,
                height: 38,
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search Item / Barcode...',
                    hintStyle: const TextStyle(fontSize: 12),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.shade400)),
                  ),
                  onChanged: (_) => _applyFilters(),
                ),
              ),
              // Show Variance Only Toggle
              FilterChip(
                label: Text('Variances Only ($varianceCount)'),
                selected: _showVarianceOnly,
                selectedColor: Colors.amber.shade200,
                onSelected: (val) {
                  setState(() => _showVarianceOnly = val);
                  _applyFilters();
                },
              ),
              // Save / Reconcile Button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onPressed: _saving ? null : _saveAudit,
                icon: _saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_as),
                label: const Text('Save & Reconcile Stock', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),

        // Metrics Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.blue.shade50,
          child: Row(
            children: [
              Text('Total Catalog Items: $totalItems', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(width: 16),
              Text('In Balance: $inBalanceCount', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(width: 16),
              Text('Discrepancies / Variance: $varianceCount', style: TextStyle(color: varianceCount > 0 ? Colors.red.shade700 : Colors.grey, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
        ),

        // Table
        Expanded(
          child: _filteredItems.isEmpty
              ? const Center(child: Text('No items match current filters.'))
              : SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(Colors.grey.shade200),
                      columnSpacing: 20,
                      columns: const [
                        DataColumn(label: Text('Item Name', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Department', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Unit', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('System Balance', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Counted / In Hand', style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor))),
                        DataColumn(label: Text('Variance', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Reason / Remarks', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: _filteredItems.map((item) {
                        final double current = item['current_balance'] ?? 0.0;
                        final double variance = item['variance'] ?? 0.0;
                        final isShortage = variance < -0.001;
                        final isSurplus = variance > 0.001;

                        return DataRow(
                          color: WidgetStateProperty.resolveWith<Color?>((states) {
                            if (isShortage) return Colors.red.shade50;
                            if (isSurplus) return Colors.green.shade50;
                            return null;
                          }),
                          cells: [
                            DataCell(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(item['item_name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                                  Text(item['item_code'], style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                ],
                              ),
                            ),
                            DataCell(Text(item['department'] ?? 'General')),
                            DataCell(Text(item['unit'] ?? 'PCS')),
                            DataCell(
                              Text(
                                current.toStringAsFixed(2),
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 100,
                                height: 36,
                                child: TextField(
                                  controller: item['controller'],
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  textAlign: TextAlign.center,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  onChanged: (val) => _onCountChanged(item, val),
                                ),
                              ),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isShortage
                                      ? Colors.red.shade100
                                      : isSurplus
                                          ? Colors.green.shade100
                                          : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${variance > 0 ? '+' : ''}${variance.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isShortage
                                        ? Colors.red.shade900
                                        : isSurplus
                                            ? Colors.green.shade900
                                            : Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              DropdownButton<String>(
                                value: _predefinedReasons.contains(item['reason']) ? item['reason'] : _predefinedReasons.first,
                                underline: const SizedBox(),
                                items: _predefinedReasons.map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 12)))).toList(),
                                onChanged: (newVal) {
                                  if (newVal != null) {
                                    setState(() => item['reason'] = newVal);
                                  }
                                },
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildReportsTab() {
    return Column(
      children: [
        // Report Filters
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Date Range Picker
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black87),
                onPressed: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                    initialDateRange: _reportDateRange,
                  );
                  if (picked != null) {
                    setState(() => _reportDateRange = picked);
                    _fetchReports();
                  }
                },
                icon: const Icon(Icons.date_range, size: 16, color: primaryColor),
                label: Text(
                  '${DateFormat('dd MMM yyyy').format(_reportDateRange.start)} - ${DateFormat('dd MMM yyyy').format(_reportDateRange.end)}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              // Department Filter
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _reportDepartment,
                    items: _departments.map((d) => DropdownMenuItem(value: d, child: Text('Dept: $d'))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _reportDepartment = val);
                        _fetchReports();
                      }
                    },
                  ),
                ),
              ),
              // Filter Variance Only
              FilterChip(
                label: const Text('Variances Only'),
                selected: _reportVarianceOnly,
                selectedColor: Colors.amber.shade200,
                onSelected: (val) {
                  setState(() => _reportVarianceOnly = val);
                  _fetchReports();
                },
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
                onPressed: _fetchReports,
                icon: const Icon(Icons.search, size: 16),
                label: const Text('Generate Report'),
              ),
            ],
          ),
        ),

        // Reports Grid
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _reports.isEmpty
                  ? const Center(child: Text('No stock take audits found for selected range.'))
                  : SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(Colors.grey.shade200),
                          columns: const [
                            DataColumn(label: Text('Audit No / Date', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Item Name', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Department', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Unit', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('System Bal', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Counted', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Variance', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Reason', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Auditor', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: _reports.map((row) {
                            final variance = _toDouble(row['variance']);
                            final isShortage = variance < -0.001;
                            final isSurplus = variance > 0.001;

                            return DataRow(
                              color: WidgetStateProperty.resolveWith<Color?>((states) {
                                if (isShortage) return Colors.red.shade50;
                                if (isSurplus) return Colors.green.shade50;
                                return null;
                              }),
                              cells: [
                                DataCell(
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(row['audit_no'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                      Text(row['audit_date']?.toString().split('T')[0] ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                                DataCell(Text(row['item_name'] ?? '')),
                                DataCell(Text(row['department'] ?? 'General')),
                                DataCell(Text(row['unit'] ?? 'PCS')),
                                DataCell(Text(_toDouble(row['system_balance']).toStringAsFixed(2))),
                                DataCell(Text(_toDouble(row['counted_qty']).toStringAsFixed(2))),
                                DataCell(
                                  Text(
                                    '${variance > 0 ? '+' : ''}${variance.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isShortage
                                          ? Colors.red.shade900
                                          : isSurplus
                                              ? Colors.green.shade900
                                              : Colors.black87,
                                    ),
                                  ),
                                ),
                                DataCell(Text(row['reason'] ?? '')),
                                DataCell(Text(row['reconciled_by'] ?? 'Admin')),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
        ),
      ],
    );
  }
}
