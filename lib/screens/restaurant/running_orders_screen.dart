import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import 'kot_builder_screen.dart';

class RunningOrdersScreen extends StatefulWidget {
  final int tableId;
  final String tableName;

  const RunningOrdersScreen({
    super.key,
    required this.tableId,
    required this.tableName,
  });

  @override
  State<RunningOrdersScreen> createState() => _RunningOrdersScreenState();
}

class _RunningOrdersScreenState extends State<RunningOrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> activeKotsList = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchTableKots();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchTableKots() async {
    setState(() => isLoading = true);
    try {
      final res = await ApiClient.get('/api/restaurant/kots?table_id=${widget.tableId}&active_only=true');
      if (res['success'] == true) {
        setState(() {
          activeKotsList = res['data'] ?? [];
        });
      }
    } catch (e) {
      debugPrint('Error loading table active orders: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<bool> _showPinOverrideDialog() async {
    String enteredPin = '';
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.security, color: Colors.orange),
              SizedBox(width: 8),
              Text('Supervisor Override'),
            ],
          ),
          content: TextField(
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Enter Supervisor PIN',
              hintText: 'xxxx',
              border: OutlineInputBorder(),
            ),
            onChanged: (val) => enteredPin = val,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (enteredPin == '1234' || enteredPin == '4321' || enteredPin == '9999') {
                  Navigator.pop(context, true);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid Security PIN! Access Denied.')),
                  );
                }
              },
              child: const Text('Authorize'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Future<void> _cancelKotItem(int itemId, String itemName) async {
    final authorized = await _showPinOverrideDialog();
    if (!authorized) return;

    String reason = 'Removed by Waiter';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel "$itemName"?'),
        content: TextField(
          decoration: const InputDecoration(
            labelText: 'Cancellation Reason',
            hintText: 'Customer changed mind, out of stock, etc.',
            border: OutlineInputBorder(),
          ),
          onChanged: (val) => reason = val,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Go Back')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Confirm Cancel'),
          )
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final res = await ApiClient.put('/api/restaurant/kots/items/$itemId/status', {
          'status': 'Cancelled',
          'cancel_reason': reason,
        });
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cancelled "$itemName" successfully.')),
          );
          _fetchTableKots();
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _cancelEntireKot(int kotId, String kotNo) async {
    final authorized = await _showPinOverrideDialog();
    if (!authorized) return;

    String reason = 'Cancelled by Manager';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel KOT $kotNo?'),
        content: TextField(
          decoration: const InputDecoration(
            labelText: 'Cancellation Reason',
            border: OutlineInputBorder(),
          ),
          onChanged: (val) => reason = val,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Go Back')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancel KOT'),
          )
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final res = await ApiClient.put('/api/restaurant/kots/$kotId/status', {
          'status': 'Cancelled',
          'remarks': reason,
        });
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cancelled KOT $kotNo successfully.')),
          );
          _fetchTableKots();
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Running Orders - Table ${widget.tableName}'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchTableKots,
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.receipt), text: 'KOT Wise Tickets'),
            Tab(icon: Icon(Icons.dashboard_customize), text: 'Consolidated Items View'),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : activeKotsList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.restaurant_menu_outlined, size: 64, color: colorScheme.outlineVariant),
                      const SizedBox(height: 16),
                      Text(
                        'No running orders on Table ${widget.tableName}',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.outline),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildKotWiseTab(colorScheme),
                    _buildConsolidatedTab(colorScheme),
                  ],
                ),
    );
  }

  Widget _buildKotWiseTab(ColorScheme scheme) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: activeKotsList.length,
      itemBuilder: (context, index) {
        final kot = activeKotsList[index];
        final items = kot['items'] as List? ?? [];
        final dateCreated = DateTime.tryParse(kot['created_time'] ?? '') ?? DateTime.now();
        final minutesElapsed = DateTime.now().difference(dateCreated).inMinutes;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: scheme.outlineVariant, width: 0.8),
          ),
          elevation: 1,
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                color: scheme.surfaceVariant,
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('KOT: ${kot['kot_no']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(
                          'Waiter: ${kot['waiter']?['employee_name'] ?? 'N/A'} | ordered $minutesElapsed min ago',
                          style: TextStyle(fontSize: 12, color: scheme.outline),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          kot['status'] ?? 'New',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: kot['status'] == 'Preparing'
                                ? Colors.blue.shade800
                                : (kot['status'] == 'Ready' ? Colors.green.shade800 : scheme.onSurface),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (kot['status'] != 'Cancelled') ...[
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent, size: 20),
                            tooltip: 'Edit Order Items',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => KotBuilderScreen(
                                    table: {
                                      'id': widget.tableId,
                                      'table_name': widget.tableName,
                                    },
                                    prefilledItems: items,
                                    editKotId: kot['id'],
                                  ),
                                ),
                              ).then((_) => _fetchTableKots());
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_forever, color: Colors.redAccent, size: 20),
                            tooltip: 'Cancel Entire KOT',
                            onPressed: () => _cancelEntireKot(kot['id'], kot['kot_no']),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Items List
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: scheme.outlineVariant),
                itemBuilder: (context, idx) {
                  final item = items[idx];
                  final isCancelled = item['status'] == 'Cancelled';
                  final hasRemark = item['item_remark'] != null && item['item_remark'].toString().trim().isNotEmpty;

                  final double q = double.tryParse(item['qty'].toString()) ?? 0.0;
                  final String qtyStr = (q % 1 == 0) ? q.toInt().toString() : q.toStringAsFixed(1);

                  return ListTile(
                    dense: true,
                    title: Text(
                      item['item_name'] ?? '',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        decoration: isCancelled ? TextDecoration.lineThrough : null,
                        color: isCancelled ? Colors.grey : scheme.onSurface,
                      ),
                    ),
                    subtitle: hasRemark
                        ? Text(
                            'Remark: ${item['item_remark']}',
                            style: const TextStyle(color: Colors.orangeAccent, fontSize: 11),
                          )
                        : null,
                    leading: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isCancelled ? Colors.grey.shade300 : scheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$qtyStr x',
                        style: TextStyle(
                          color: isCancelled ? Colors.grey : scheme.onSecondaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item['status'] ?? 'Ordered',
                          style: TextStyle(
                            fontSize: 12,
                            color: isCancelled
                                ? Colors.red.shade700
                                : (item['status'] == 'Ready' ? Colors.green.shade800 : scheme.outline),
                          ),
                        ),
                        if (!isCancelled) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.cancel_outlined, color: Colors.red, size: 18),
                            onPressed: () => _cancelKotItem(item['id'], item['item_name']),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryTab(ColorScheme scheme) {
    return _buildConsolidatedTab(scheme);
  }

  Widget _buildConsolidatedTab(ColorScheme scheme) {
    final Map<String, Map<String, double>> summary = {};
    for (final kot in activeKotsList) {
      final items = kot['items'] as List? ?? [];
      for (final item in items) {
        final name = item['item_name'] ?? 'Unknown Item';
        final isCancelled = item['status'] == 'Cancelled';
        final double q = double.tryParse(item['qty'].toString()) ?? 0.0;

        if (!summary.containsKey(name)) {
          summary[name] = {'active': 0.0, 'cancelled': 0.0};
        }

        if (isCancelled) {
          summary[name]!['cancelled'] = summary[name]!['cancelled']! + q;
        } else {
          summary[name]!['active'] = summary[name]!['active']! + q;
        }
      }
    }

    final keys = summary.keys.toList();

    return Card(
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant, width: 0.8),
      ),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: scheme.surfaceVariant,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Dish Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Row(
                  children: [
                    SizedBox(width: 80, child: Text('Running', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                    SizedBox(width: 80, child: Text('Cancelled', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: keys.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: scheme.outlineVariant),
              itemBuilder: (context, index) {
                final name = keys[index];
                final activeVal = summary[name]!['active']!;
                final cancelVal = summary[name]!['cancelled']!;

                final String activeStr = (activeVal % 1 == 0) ? activeVal.toInt().toString() : activeVal.toStringAsFixed(1);
                final String cancelStr = (cancelVal % 1 == 0) ? cancelVal.toInt().toString() : cancelVal.toStringAsFixed(1);

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                      Row(
                        children: [
                          SizedBox(
                            width: 80,
                            child: Text(
                              activeStr,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: activeVal > 0 ? Colors.green.shade800 : Colors.grey,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 80,
                            child: Text(
                              cancelStr,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: cancelVal > 0 ? Colors.red.shade800 : Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
