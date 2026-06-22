import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';

class SubmittedStatusScreen extends StatefulWidget {
  const SubmittedStatusScreen({super.key});

  @override
  State<SubmittedStatusScreen> createState() => _SubmittedStatusScreenState();
}

class _SubmittedStatusScreenState extends State<SubmittedStatusScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _requests = [];
  List<dynamic> _damages = [];
  bool _loading = false;
  String _selectedRequestFilter = 'PENDING';
  String _selectedDamageFilter = 'PENDING';

  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 90));
  DateTime _toDate = DateTime.now().add(const Duration(days: 1));

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadData();
      }
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
    });

    final fromStr = DateFormat('yyyy-MM-dd').format(_fromDate);
    final toStr = DateFormat('yyyy-MM-dd').format(_toDate);

    try {
      if (_tabController.index == 0) {
        final res = await ApiClient.get(
          '${ApiEndpoints.requestReport}?from_date=$fromStr&to_date=$toStr',
        );
        if (!mounted) return;
        setState(() {
          _requests = res['data'] ?? [];
        });
      } else {
        final res = await ApiClient.get(
          '${ApiEndpoints.damagesumReport}?from_date=$fromStr&to_date=$toStr',
        );
        if (!mounted) return;
        setState(() {
          _damages = res['data'] ?? [];
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading status: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Submissions Status',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Choose Date Range',
            icon: const Icon(Icons.date_range),
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 30)),
              );
              if (picked != null) {
                setState(() {
                  _fromDate = picked.start;
                  _toDate = picked.end;
                });
                _loadData();
              }
            },
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'My Requests'),
            Tab(text: 'My Damages'),
          ],
        ),
      ),
      body: Container(
        color: Colors.grey.shade50,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.white,
              child: Row(
                children: [
                  const Text(
                    'Filter Status: ',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildFilterChips(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildRequestTab(),
                        _buildDamageTab(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final currentTab = _tabController.index;
    final activeFilter = currentTab == 0 ? _selectedRequestFilter : _selectedDamageFilter;

    return Wrap(
      spacing: 8,
      children: ['PENDING', 'APPROVED', 'REJECTED'].map((filter) {
        final isSelected = activeFilter == filter;
        Color selectedColor = Colors.blue.shade100;
        Color labelColor = Colors.blue.shade900;

        if (filter == 'APPROVED') {
          selectedColor = Colors.green.shade100;
          labelColor = Colors.green.shade900;
        } else if (filter == 'REJECTED') {
          selectedColor = Colors.red.shade100;
          labelColor = Colors.red.shade900;
        }

        return ChoiceChip(
          label: Text(
            filter,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isSelected ? labelColor : Colors.grey.shade700,
            ),
          ),
          selected: isSelected,
          selectedColor: selectedColor,
          backgroundColor: Colors.grey.shade200,
          onSelected: (selected) {
            if (selected) {
              setState(() {
                if (currentTab == 0) {
                  _selectedRequestFilter = filter;
                } else {
                  _selectedDamageFilter = filter;
                }
              });
            }
          },
        );
      }).toList(),
    );
  }

  Widget _buildRequestTab() {
    final filtered = _requests
        .where((e) => (e['approval_status'] ?? 'PENDING') == _selectedRequestFilter)
        .toList();

    if (filtered.isEmpty) {
      return _buildEmptyState(
        Icons.playlist_add_check_circle_outlined,
        'No requests in status $_selectedRequestFilter',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final req = filtered[index];
        final itemsList = req['items'] as List? ?? [];
        final dateParsed = req['request_date'] != null
            ? DateFormat('dd-MMM-yyyy').format(DateTime.parse(req['request_date']))
            : '-';

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ExpansionTile(
            clipBehavior: Clip.antiAlias,
            shape: const RoundedRectangleBorder(side: BorderSide.none),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Req #${req['request_no']}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                _buildStatusBadge(req['approval_status']),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(Icons.business, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(req['department'] ?? 'No Dept'),
                  const SizedBox(width: 14),
                  Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(dateParsed),
                ],
              ),
            ),
            children: [
              Container(
                color: Colors.grey.shade50,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Requested Items:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    _buildItemsTable(itemsList),
                    if (req['rejection_reason'] != null &&
                        req['rejection_reason'].toString().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.error_outline, size: 18, color: Colors.red.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Rejection Reason:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red.shade900,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    req['rejection_reason'],
                                    style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDamageTab() {
    final filtered = _damages
        .where((e) => (e['approval_status'] ?? 'PENDING') == _selectedDamageFilter)
        .toList();

    if (filtered.isEmpty) {
      return _buildEmptyState(
        Icons.warning_amber_rounded,
        'No damages in status $_selectedDamageFilter',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final dmg = filtered[index];
        final itemsList = dmg['items'] as List? ?? [];
        final dateParsed = dmg['damage_date'] != null
            ? DateFormat('dd-MMM-yyyy').format(DateTime.parse(dmg['damage_date']))
            : '-';
        final totalValue = NumberFormat.currency(symbol: 'Rs. ').format(
          double.tryParse(dmg['total_value']?.toString() ?? '') ?? 0.0,
        );

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ExpansionTile(
            clipBehavior: Clip.antiAlias,
            shape: const RoundedRectangleBorder(side: BorderSide.none),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Damage #${dmg['damage_no']}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                _buildStatusBadge(dmg['approval_status']),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(Icons.monetization_on_outlined, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(totalValue, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 14),
                  Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(dateParsed),
                ],
              ),
            ),
            children: [
              Container(
                color: Colors.grey.shade50,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Damaged Items & Details:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    _buildItemsTable(itemsList, showValue: true),
                    if (dmg['rejection_reason'] != null &&
                        dmg['rejection_reason'].toString().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.error_outline, size: 18, color: Colors.red.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Rejection Reason:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red.shade900,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    dmg['rejection_reason'],
                                    style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildItemsTable(List items, {bool showValue = false}) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('No items found in this document.', style: TextStyle(fontStyle: FontStyle.italic)),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(3),
          1: FlexColumnWidth(1),
          2: FlexColumnWidth(1.2),
          3: FlexColumnWidth(1.5),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
            ),
            children: [
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('Item Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(showValue ? 'Rate' : 'Unit', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(showValue ? 'Value' : 'Remarks', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right),
              ),
            ],
          ),
          ...items.map((i) {
            final qty = double.tryParse(i['qty']?.toString() ?? '') ?? 0.0;
            final remarks = i['remarks'] ?? i['remarks_desc'] ?? '-';
            final rate = double.tryParse(i['rate']?.toString() ?? '') ?? 0.0;
            final unit = i['unit'] ?? i['item_master']?['unit'] ?? '-';
            final amount = double.tryParse(i['amount']?.toString() ?? '') ?? (qty * rate);

            final rateFmt = NumberFormat.currency(symbol: 'Rs.').format(rate);
            final amountFmt = NumberFormat.currency(symbol: 'Rs.').format(amount);

            return TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(i['item_name'] ?? i['item_master']?['item_name'] ?? '-', style: const TextStyle(fontSize: 12)),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text('$qty', style: const TextStyle(fontSize: 12), textAlign: TextAlign.right),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(showValue ? rateFmt : '$unit', style: const TextStyle(fontSize: 12), textAlign: TextAlign.right),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(showValue ? amountFmt : '$remarks', style: const TextStyle(fontSize: 12), textAlign: TextAlign.right),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String? status) {
    final s = (status ?? 'PENDING').toUpperCase();
    Color bg = Colors.grey.shade200;
    Color fg = Colors.grey.shade700;

    if (s == 'APPROVED') {
      bg = Colors.green.shade50;
      fg = Colors.green.shade700;
    } else if (s == 'REJECTED') {
      bg = Colors.red.shade50;
      fg = Colors.red.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withAlpha(77)),
      ),
      child: Text(
        s,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
