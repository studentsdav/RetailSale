import 'package:flutter/material.dart';
import '../../controllers/inventory/stock_transfer_controller.dart';

class TransferProgressDashboardScreen extends StatefulWidget {
  const TransferProgressDashboardScreen({super.key});

  @override
  State<TransferProgressDashboardScreen> createState() => _TransferProgressDashboardScreenState();
}

class _TransferProgressDashboardScreenState extends State<TransferProgressDashboardScreen> with SingleTickerProviderStateMixin {
  final StockTransferController _transferCtrl = StockTransferController();
  late TabController _tabController;

  bool _isLoadingOverall = true;
  Map<String, dynamic>? _overallData;

  bool _isLoadingIndividual = false;
  Map<String, dynamic>? _individualData;
  int? _selectedOutletId;
  List<dynamic> _allOutlets = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadOverallData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOverallData() async {
    setState(() => _isLoadingOverall = true);
    final data = await _transferCtrl.fetchOverallProgress();
    if (mounted) {
      setState(() {
        _overallData = data;
        _isLoadingOverall = false;
        if (data != null && data['outlets_progress'] != null) {
          _allOutlets = data['outlets_progress'];
          if (_allOutlets.isNotEmpty) {
            final exists = _allOutlets.any((o) => o['outlet_id'] == _selectedOutletId);
            if (!exists || _selectedOutletId == null) {
              _selectedOutletId = _allOutlets.first['outlet_id'];
            }
            _loadIndividualData(_selectedOutletId!);
          }
        }
      });
    }
  }

  Future<void> _loadIndividualData(int outletId) async {
    setState(() => _isLoadingIndividual = true);
    final data = await _transferCtrl.fetchIndividualOutletProgress(outletId);
    if (mounted) {
      setState(() {
        _individualData = data;
        _isLoadingIndividual = false;
      });
    }
  }

  Future<void> _receiveAndCompleteTransfer(dynamic rawTransferId, String transferNo) async {
    final int? transferId = rawTransferId is int ? rawTransferId : int.tryParse(rawTransferId?.toString() ?? '');
    if (transferId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid transfer record ID')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Complete Transfer $transferNo?'),
        content: const Text(
          'Confirming receipt will credit 100% of the dispatched stock directly into destination outlet stock ledger & item master catalog.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm Receive')),
        ],
      ),
    );

    if (confirm != true) return;

    final res = await _transferCtrl.receiveStock(transferId);
    if (mounted) {
      if (res != null && res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Stock transfer completed & credited!')),
        );
        _loadOverallData();
        if (_selectedOutletId != null) {
          _loadIndividualData(_selectedOutletId!);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res?['message'] ?? 'Failed to receive stock transfer')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Stock Transfer Progress Dashboard'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.analytics), text: 'Overall Progress (All Outlets)'),
            Tab(icon: Icon(Icons.store), text: 'Individual Outlet Progress'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverallProgressTab(),
          _buildIndividualProgressTab(),
        ],
      ),
    );
  }

  Widget _buildOverallProgressTab() {
    if (_isLoadingOverall) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_overallData == null) {
      return const Center(child: Text('Failed to load overall progress data.'));
    }

    final summary = _overallData!['overall_summary'] ?? {};
    final outletsProgress = (_overallData!['outlets_progress'] as List?) ?? [];
    final recentTransfers = (_overallData!['recent_transfers'] as List?) ?? [];

    return RefreshIndicator(
      onRefresh: _loadOverallData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Metrics Row
            LayoutBuilder(
              builder: (context, constraints) {
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _buildMetricCard('Total Dispatches', '${summary['total_dispatches'] ?? 0}', Icons.local_shipping, Colors.blue),
                    _buildMetricCard('In-Transit Transfers', '${summary['total_in_transit'] ?? 0}', Icons.sync, Colors.orange),
                    _buildMetricCard('Completed Transfers', '${summary['total_completed'] ?? 0}', Icons.check_circle, Colors.green),
                    _buildMetricCard('Total Qty Transferred', '${summary['total_qty_transferred'] ?? 0}', Icons.inventory_2, Colors.purple),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Outlets Table
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Outlets Stock Transfer Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Outlet Code')),
                          DataColumn(label: Text('Outlet Name')),
                          DataColumn(label: Text('Type')),
                          DataColumn(label: Text('Outgoing Count')),
                          DataColumn(label: Text('Dispatched Qty')),
                          DataColumn(label: Text('Incoming Count')),
                          DataColumn(label: Text('Received Qty')),
                          DataColumn(label: Text('In-Transit Qty')),
                        ],
                        rows: outletsProgress.map<DataRow>((outlet) {
                          return DataRow(
                            cells: [
                              DataCell(Text(outlet['outlet_code'] ?? '')),
                              DataCell(Text(outlet['outlet_name'] ?? '')),
                              DataCell(Text((outlet['is_master'] == true || outlet['is_master'] == 1 || outlet['is_master'] == '1' || outlet['outlet_role'] == 'MASTER' || outlet['parent_outlet_id'] == null) ? 'MASTER' : 'BRANCH')),
                              DataCell(Text('${outlet['outgoing_transfers_count']}')),
                              DataCell(Text('${outlet['dispatched_qty']}')),
                              DataCell(Text('${outlet['incoming_transfers_count']}')),
                              DataCell(Text('${outlet['received_qty']}')),
                              DataCell(Text('${outlet['in_transit_qty']}')),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Recent Transfers List
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Recent Inter-Outlet Stock Dispatches', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: recentTransfers.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, index) {
                        final t = recentTransfers[index];
                        final isCompleted = t['status'] == 'COMPLETED' || t['status'] == 'RECEIVED';
                        final itemStr = t['item_summary'] ?? (t['items'] != null && (t['items'] as List).isNotEmpty
                            ? (t['items'] as List).map((i) => '${i['item_name']} (x${i['transfer_qty']})').join(', ')
                            : 'Qty: ${t['total_qty']}');

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isCompleted ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                            child: Icon(isCompleted ? Icons.check : Icons.local_shipping, color: isCompleted ? Colors.green : Colors.orange),
                          ),
                          title: Text('${t['transfer_no']} — $itemStr', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Status: ${t['status']} | Total Qty: ${t['total_qty']} | Date: ${t['dispatch_date'] ?? ''}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('₹${t['total_amount']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              if (!isCompleted) ...[
                                const SizedBox(width: 12),
                                FilledButton.icon(
                                  onPressed: () => _receiveAndCompleteTransfer(t['id'], t['transfer_no']),
                                  icon: const Icon(Icons.check_circle_outline, size: 16),
                                  label: const Text('Complete Transfer'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndividualProgressTab() {
    final bool hasValidSelectedOutlet = _allOutlets.any((o) => o['outlet_id'] == _selectedOutletId);

    return Column(
      children: [
        // Top Filter Card
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.storefront, color: Colors.blue),
              const SizedBox(width: 12),
              const Text('Select Outlet:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: hasValidSelectedOutlet ? _selectedOutletId : null,
                  items: _allOutlets.map<DropdownMenuItem<int>>((outlet) {
                    return DropdownMenuItem<int>(
                      value: outlet['outlet_id'],
                      child: Text('${outlet['outlet_name']} (${outlet['outlet_code']})'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedOutletId = val);
                      _loadIndividualData(val);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Outlet Content
        Expanded(
          child: _isLoadingIndividual
              ? const Center(child: CircularProgressIndicator())
              : _individualData == null
                  ? const Center(child: Text('Select an outlet to view individual progress.'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Outlet Overview Banner
                          Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            color: const Color(0xFFEFF6FF),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  const CircleAvatar(
                                    radius: 28,
                                    backgroundColor: Colors.blue,
                                    child: Icon(Icons.business, color: Colors.white, size: 28),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _individualData!['outlet']['outlet_name'] ?? '',
                                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                        ),
                                        Text('Code: ${_individualData!['outlet']['outlet_code']} | Role: ${(_individualData!['outlet']['is_master'] == true || _individualData!['outlet']['is_master'] == 1 || _individualData!['outlet']['is_master'] == '1' || _individualData!['outlet']['outlet_role'] == 'MASTER' || _individualData!['outlet']['parent_outlet_id'] == null) ? 'MASTER' : 'BRANCH'}'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Individual Summary Cards
                          Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              _buildMetricCard('Dispatched Out Qty', '${_individualData!['summary']['total_dispatched_qty']}', Icons.upload, Colors.orange),
                              _buildMetricCard('Received In Qty', '${_individualData!['summary']['total_received_qty']}', Icons.download, Colors.green),
                              _buildMetricCard('In-Transit Incoming Qty', '${_individualData!['summary']['total_in_transit_qty']}', Icons.alt_route, Colors.purple),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Incoming Shipments Timeline
                          const Text('Incoming Stock Transfers to this Outlet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          _buildTransferList(_individualData!['incoming_transfers'] as List? ?? []),
                          const SizedBox(height: 24),

                          // Outgoing Shipments Timeline
                          const Text('Outgoing Stock Transfers from this Outlet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          _buildTransferList(_individualData!['outgoing_transfers'] as List? ?? []),
                        ],
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildTransferList(List<dynamic> transfers) {
    if (transfers.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: Text('No transfers found.')),
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: transfers.length,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (context, index) {
          final t = transfers[index];
          final isCompleted = t['status'] == 'COMPLETED' || t['status'] == 'RECEIVED';
          final itemStr = t['item_summary'] ?? (t['items'] != null && (t['items'] as List).isNotEmpty
              ? (t['items'] as List).map((i) => '${i['item_name']} (x${i['transfer_qty']})').join(', ')
              : 'Qty: ${t['total_qty']}');

          return ListTile(
            leading: Icon(isCompleted ? Icons.check_circle : Icons.schedule, color: isCompleted ? Colors.green : Colors.orange),
            title: Text('${t['transfer_no']} — $itemStr', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Status: ${t['status']} | Total Qty: ${t['total_qty']} | Date: ${t['dispatch_date'] ?? ''}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('₹${t['total_amount']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                if (!isCompleted) ...[
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () => _receiveAndCompleteTransfer(t['id'], t['transfer_no']),
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Complete Transfer'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
