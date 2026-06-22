import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../controllers/inventory/damage_controller.dart';
import '../../controllers/inventory/request_controller.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';

class ApprovalCenterScreen extends StatefulWidget {
  const ApprovalCenterScreen({super.key});

  @override
  State<ApprovalCenterScreen> createState() => _ApprovalCenterScreenState();
}

class _ApprovalCenterScreenState extends State<ApprovalCenterScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _requestCtrl = RequestController();
  final _damageCtrl = DamageController();

  List<dynamic> _requests = [];
  List<dynamic> _damages = [];
  bool _loading = false;
  String _selectedRequestFilter = 'PENDING';
  String _selectedDamageFilter = 'PENDING';

  // Date range for reports (defaulting to last 90 days to capture pending approvals)
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 90));
  DateTime _toDate = DateTime.now().add(const Duration(days: 1)); // Include today fully

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
          content: Text('Error loading approvals: $e'),
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

  Future<void> _approveRequest(int id) async {
    try {
      setState(() => _loading = true);
      await _requestCtrl.approve(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Material Request approved successfully'),
          backgroundColor: Colors.green,
        ),
      );
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red.shade600),
      );
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _rejectRequest(int id, String reason) async {
    try {
      setState(() => _loading = true);
      await _requestCtrl.reject(id, reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Material Request rejected successfully'),
          backgroundColor: Colors.orange,
        ),
      );
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red.shade600),
      );
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approveDamage(int id) async {
    try {
      setState(() => _loading = true);
      await _damageCtrl.approveDamage(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Damage Report approved and stock updated'),
          backgroundColor: Colors.green,
        ),
      );
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red.shade600),
      );
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _rejectDamage(int id, String reason) async {
    try {
      setState(() => _loading = true);
      await _damageCtrl.rejectDamage(id, reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Damage Report rejected successfully'),
          backgroundColor: Colors.orange,
        ),
      );
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red.shade600),
      );
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showRejectionDialog(int id, bool isRequest) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isRequest ? 'Reject Request' : 'Reject Damage'),
          content: TextField(
            controller: reasonCtrl,
            decoration: const InputDecoration(
              labelText: 'Cancellation/Rejection Reason',
              hintText: 'Enter reason here...',
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final reason = reasonCtrl.text.trim();
                if (reason.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Rejection reason is required')),
                  );
                  return;
                }
                Navigator.pop(context);
                if (isRequest) {
                  _rejectRequest(id, reason);
                } else {
                  _rejectDamage(id, reason);
                }
              },
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Approval Center',
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
            Tab(text: 'Material Requests'),
            Tab(text: 'Damage Reports'),
          ],
        ),
      ),
      body: Container(
        color: Colors.grey.shade50,
        child: Column(
          children: [
            // Filter Selector Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.white,
              child: Row(
                children: [
                  const Text(
                    'Status: ',
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
                        _buildRequestTab(scheme),
                        _buildDamageTab(scheme),
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

  Widget _buildRequestTab(ColorScheme scheme) {
    final filtered = _requests
        .where((e) => (e['approval_status'] ?? 'PENDING') == _selectedRequestFilter)
        .toList();

    if (filtered.isEmpty) {
      return _buildEmptyState(
        Icons.playlist_add_check_circle_outlined,
        'No material requests found in status $_selectedRequestFilter',
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
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.error_outline, size: 16, color: Colors.red.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Rejection Reason: ${req['rejection_reason']}',
                                style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (req['approval_status'] == 'PENDING') ...[
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red.shade700,
                              side: BorderSide(color: Colors.red.shade300),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            icon: const Icon(Icons.cancel_outlined, size: 18),
                            label: const Text('Reject'),
                            onPressed: () => _showRejectionDialog(req['id'], true),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            icon: const Icon(Icons.check_circle_outline, size: 18),
                            label: const Text('Approve'),
                            onPressed: () => _approveRequest(req['id']),
                          ),
                        ],
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

  Widget _buildDamageTab(ColorScheme scheme) {
    final filtered = _damages
        .where((e) => (e['approval_status'] ?? 'PENDING') == _selectedDamageFilter)
        .toList();

    if (filtered.isEmpty) {
      return _buildEmptyState(
        Icons.warning_amber_rounded,
        'No damage reports found in status $_selectedDamageFilter',
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
                      'Damaged Items & Values:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    _buildItemsTable(itemsList, showValue: true),
                    if (dmg['rejection_reason'] != null &&
                        dmg['rejection_reason'].toString().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.error_outline, size: 16, color: Colors.red.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Rejection Reason: ${dmg['rejection_reason']}',
                                style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (dmg['approval_status'] == 'PENDING') ...[
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red.shade700,
                              side: BorderSide(color: Colors.red.shade300),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            icon: const Icon(Icons.cancel_outlined, size: 18),
                            label: const Text('Reject'),
                            onPressed: () => _showRejectionDialog(dmg['id'], false),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            icon: const Icon(Icons.check_circle_outline, size: 18),
                            label: const Text('Approve'),
                            onPressed: () => _approveDamage(dmg['id']),
                          ),
                        ],
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
