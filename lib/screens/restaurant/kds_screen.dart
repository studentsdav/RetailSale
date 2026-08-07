import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/restaurant/restaurant_controller.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../../core/api/endpoints.dart';
import '../../core/api/api_client.dart';

class KdsScreen extends StatefulWidget {
  const KdsScreen({super.key});

  @override
  State<KdsScreen> createState() => _KdsScreenState();
}

class _KdsScreenState extends State<KdsScreen> {
  List<dynamic> activeKotsList = [];
  bool isLoadingKots = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchKots();
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _fetchKots();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchKots() async {
    setState(() => isLoadingKots = true);
    try {
      final res = await ApiClient.get('/api/restaurant/kots?active_only=true');
      if (res['success'] == true) {
        setState(() {
          activeKotsList = res['data'] ?? [];
        });
      }
    } catch (e) {
      debugPrint('Error loading KDS orders: $e');
    } finally {
      setState(() => isLoadingKots = false);
    }
  }

  Future<void> _updateKotStatus(int id, String status) async {
    try {
      final res = await ApiClient.put('/api/restaurant/kots/$id/status', {'status': status});
      if (res['success'] == true) {
        _fetchKots();
      }
    } catch (e) {
      debugPrint('Error updating KOT: $e');
    }
  }

  String _formatQty(dynamic qty) {
    final double q = double.tryParse(qty?.toString() ?? '0') ?? 0.0;
    if (q % 1 == 0) {
      return q.toInt().toString();
    }
    return q.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kitchen Display System (KDS)'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchKots,
          )
        ],
      ),
      body: isLoadingKots
          ? const Center(child: CircularProgressIndicator())
          : activeKotsList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade600),
                      const SizedBox(height: 16),
                      Text(
                        'Kitchen Queue is Clear!',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.outline),
                      ),
                      const SizedBox(height: 8),
                      Text('No active orders right now.', style: TextStyle(color: colorScheme.outline)),
                    ],
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = (constraints.maxWidth / 320).floor().clamp(2, 6);
                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: activeKotsList.length,
                      itemBuilder: (context, index) {
                        final kot = activeKotsList[index];
                        final dateCreated = DateTime.tryParse(kot['created_time'] ?? '') ?? DateTime.now();
                        final durationDiff = DateTime.now().difference(dateCreated);
                        final minutesElapsed = durationDiff.inMinutes;



                        final bool isKotCancelled = kot['status'] == 'Cancelled';

                        Color headerColor = colorScheme.surfaceVariant;
                        Color borderColor = colorScheme.outlineVariant;
                        IconData statusIcon = Icons.info_outline;

                        if (isKotCancelled) {
                          headerColor = Colors.red.shade200;
                          borderColor = Colors.red.shade700;
                          statusIcon = Icons.cancel;
                        } else if (minutesElapsed > 15) {
                          headerColor = Colors.red.shade100;
                          borderColor = Colors.red.shade300;
                          statusIcon = Icons.warning_amber_rounded;
                        } else if (kot['status'] == 'Preparing') {
                          headerColor = Colors.blue.shade100;
                          borderColor = Colors.blue.shade300;
                          statusIcon = Icons.restaurant_menu;
                        } else if (kot['status'] == 'Ready') {
                          headerColor = Colors.green.shade100;
                          borderColor = Colors.green.shade300;
                          statusIcon = Icons.done_all;
                        }

                        return Card(
                          color: isKotCancelled ? Colors.red.shade50 : null,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: borderColor, width: isKotCancelled ? 3.0 : 1.5),
                          ),
                          elevation: 3,
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // KOT Header
                              Container(
                                color: headerColor,
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Icon(statusIcon, size: 20, color: isKotCancelled ? Colors.red.shade900 : colorScheme.onSurfaceVariant),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Table: ${kot['table']?['table_name'] ?? 'Takeaway'} ${isKotCancelled ? "(CANCELLED)" : ""}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: isKotCancelled ? Colors.red.shade900 : null,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isKotCancelled 
                                            ? Colors.red.shade700
                                            : (minutesElapsed > 15 ? Colors.red.shade800 : colorScheme.primary),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        isKotCancelled ? 'CANCELLED' : '${minutesElapsed}m ago',
                                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    )
                                  ],
                                ),
                              ),
                              
                              // KOT Metadata
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'KOT: ${kot['kot_no']}',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: colorScheme.outline),
                                    ),
                                    Text(
                                      'Waiter: ${kot['waiter']?['employee_name'] ?? 'N/A'}',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: colorScheme.outline),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 1),
                              
                              // Items List
                              Expanded(
                                child: ListView.separated(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: (kot['items'] as List?)?.length ?? 0,
                                  separatorBuilder: (_, __) => const Divider(),
                                  itemBuilder: (context, idx) {
                                    final item = kot['items'][idx];
                                    final hasRemark = item['item_remark'] != null && item['item_remark'].toString().trim().isNotEmpty;
                                    final isCancelled = item['status'] == 'Cancelled' || isKotCancelled;
                                    
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: isCancelled ? Colors.grey.shade300 : colorScheme.secondaryContainer,
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  _formatQty(item['qty']),
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                    color: isCancelled ? Colors.grey : colorScheme.onSecondaryContainer,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  item['item_name'] ?? '',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                    decoration: isCancelled ? TextDecoration.lineThrough : null,
                                                    color: isCancelled ? Colors.grey : colorScheme.onSurface,
                                                  ),
                                                ),
                                              ),
                                              if (!isCancelled)
                                                IconButton(
                                                  icon: const Icon(Icons.cancel_outlined, color: Colors.red, size: 18),
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(),
                                                  onPressed: () => _rejectKotItem(item['id']),
                                                ),
                                            ],
                                          ),
                                          if (hasRemark)
                                            Container(
                                              margin: const EdgeInsets.only(top: 8, left: 34),
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.amber.shade100,
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: Colors.amber.shade300, width: 0.8),
                                              ),
                                              child: Text(
                                                'Remarks: ${item['item_remark']}',
                                                style: TextStyle(
                                                  color: Colors.amber.shade900,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const Divider(height: 1),
                              
                              // KOT Action Footer
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: isKotCancelled
                                    ? Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'CANCELLED: ${kot['remarks'] ?? 'No reason'}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.red.shade800,
                                                fontSize: 12,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red.shade700,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                            ),
                                            icon: const Icon(Icons.done_all, size: 16),
                                            label: const Text('Dismiss Card'),
                                            onPressed: () => _updateKotStatus(kot['id'], 'Closed'),
                                          ),
                                        ],
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Status: ${kot['status']}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: kot['status'] == 'Preparing'
                                                  ? Colors.blue.shade800
                                                  : (kot['status'] == 'Ready' ? Colors.green.shade800 : colorScheme.onSurface),
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              TextButton.icon(
                                                icon: const Icon(Icons.cancel_presentation, color: Colors.red, size: 16),
                                                label: const Text('Reject', style: TextStyle(color: Colors.red, fontSize: 12)),
                                                onPressed: () => _rejectKotOrder(kot['id']),
                                              ),
                                              const SizedBox(width: 4),
                                              if (kot['status'] == 'New')
                                                ElevatedButton.icon(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.blue.shade700,
                                                    foregroundColor: Colors.white,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                  ),
                                                  icon: const Icon(Icons.check, size: 16),
                                                  label: const Text('Accept'),
                                                  onPressed: () => _updateKotStatus(kot['id'], 'Preparing'),
                                                )
                                              else if (kot['status'] == 'Preparing')
                                                ElevatedButton.icon(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.green.shade700,
                                                    foregroundColor: Colors.white,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                  ),
                                                  icon: const Icon(Icons.room_service, size: 16),
                                                  label: const Text('Ready'),
                                                  onPressed: () => _updateKotStatus(kot['id'], 'Ready'),
                                                )
                                              else if (kot['status'] == 'Ready')
                                                ElevatedButton.icon(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.teal.shade700,
                                                    foregroundColor: Colors.white,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                  ),
                                                  icon: const Icon(Icons.restaurant, size: 16),
                                                  label: const Text('Serve'),
                                                  onPressed: () => _updateKotStatus(kot['id'], 'Served'),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }

  Future<void> _rejectKotItem(int itemId) async {
    String reason = 'Not Available';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark Item Unavailable?'),
        content: TextField(
          decoration: const InputDecoration(
            labelText: 'Reason for unavailability',
            hintText: 'e.g. Ingredient Out of Stock',
          ),
          onChanged: (val) => reason = val,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Mark Unavailable'),
          )
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final res = await ApiClient.put('/api/restaurant/kots/items/$itemId/status', {
          'status': 'Cancelled',
          'cancel_reason': reason
        });
        if (res['success'] == true) {
          _fetchKots();
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _rejectKotOrder(int kotId) async {
    String reason = 'Rejected by Chef';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Entire KOT Order?'),
        content: TextField(
          decoration: const InputDecoration(
            labelText: 'Reason for rejection',
          ),
          onChanged: (val) => reason = val,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject Order'),
          )
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final res = await ApiClient.put('/api/restaurant/kots/$kotId/status', {
          'status': 'Cancelled',
          'remarks': reason
        });
        if (res['success'] == true) {
          _fetchKots();
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
