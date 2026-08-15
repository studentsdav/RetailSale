import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
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
  String selectedLocationFilter = 'All';

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
        final List raw = res['data'] ?? [];
        // Filter out billed / completed / closed / served orders so only active unbilled KOTs show
        final List unbilled = raw.where((kot) {
          final String status = (kot['status'] ?? '').toString().toUpperCase();
          final bool isBilled = kot['is_billed'] == true ||
              status == 'BILLED' ||
              status == 'COMPLETED' ||
              status == 'CLOSED' ||
              status == 'SERVED' ||
              status == 'DISMISSED';
          return !isBilled;
        }).toList();

        setState(() {
          activeKotsList = unbilled;
        });
      }
    } catch (e) {
      debugPrint('Error loading KDS orders: $e');
    } finally {
      setState(() => isLoadingKots = false);
    }
  }

  Future<void> _updateKotStatus(int id, String status, {bool? kdsDismissed}) async {
    try {
      final payload = {
        'status': status,
        if (kdsDismissed != null) 'kds_dismissed': kdsDismissed,
      };
      final res = await ApiClient.put('/api/restaurant/kots/$id/status', payload);
      if (res['success'] == true) {
        _fetchKots();
      }
    } catch (e) {
      debugPrint('Error updating KOT: $e');
    }
  }

  Future<void> _cancelKotItemDialog(int itemId, String itemName) async {
    String reason = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reject "$itemName"?'),
        content: TextField(
          decoration: const InputDecoration(
            labelText: 'Reason for Rejection',
            border: OutlineInputBorder(),
          ),
          onChanged: (val) => reason = val,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Go Back')),
          ElevatedButton(
            onPressed: () {
              if (reason.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a rejection reason.')),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject Item'),
          )
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final res = await ApiClient.put('/api/restaurant/kots/items/$itemId/status', {
          'status': 'Rejected',
          'cancel_reason': reason,
        });
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Rejected "$itemName" successfully.')),
          );
          _fetchKots();
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _cancelEntireKotDialog(int kotId, String kotNo) async {
    String reason = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reject KOT $kotNo?'),
        content: TextField(
          decoration: const InputDecoration(
            labelText: 'Reason for Rejection',
            border: OutlineInputBorder(),
          ),
          onChanged: (val) => reason = val,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Go Back')),
          ElevatedButton(
            onPressed: () {
              if (reason.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a rejection reason.')),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject KOT'),
          )
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final res = await ApiClient.put('/api/restaurant/kots/$kotId/status', {
          'status': 'Rejected',
          'remarks': reason,
        });
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('KOT $kotNo has been rejected.')),
          );
          _fetchKots();
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
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

    // Collect all unique location/station names from KOT items
    final Set<String> locations = {'All'};
    for (final kot in activeKotsList) {
      final items = (kot['items'] as List?) ?? [];
      for (final item in items) {
        final loc = (item['location'] ?? item['station_name'] ?? item['kitchen_station'] ?? 'Kitchen').toString().trim();
        if (loc.isNotEmpty) locations.add(loc);
      }
    }

    // Filter KOTs by selected location chip
    final filteredKots = activeKotsList.where((kot) {
      if (selectedLocationFilter == 'All') return true;
      final items = (kot['items'] as List?) ?? [];
      return items.any((it) {
        final loc = (it['location'] ?? it['station_name'] ?? it['kitchen_station'] ?? 'Kitchen').toString().trim();
        return loc.toLowerCase() == selectedLocationFilter.toLowerCase();
      });
    }).toList();

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
      body: Column(
        children: [
          // ── Location Filter Chips Bar ────────────────────────────────────
          if (locations.length > 1)
            Container(
              height: 52,
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: locations.map((loc) {
                  final isSelected = loc.toLowerCase() == selectedLocationFilter.toLowerCase();
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        loc == 'All' ? 'All Stations' : loc,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.white : colorScheme.onSurface,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: colorScheme.primary,
                      onSelected: (_) {
                        setState(() => selectedLocationFilter = loc);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          Expanded(
            child: isLoadingKots
                ? const Center(child: CircularProgressIndicator())
                : filteredKots.isEmpty
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
                            Text('No active orders for $selectedLocationFilter right now.', style: TextStyle(color: colorScheme.outline)),
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
                            itemCount: filteredKots.length,
                            itemBuilder: (context, index) {
                              final kot = filteredKots[index];
                              final dateCreated = DateTime.tryParse(kot['created_time'] ?? '') ?? DateTime.now();
                              final durationDiff = DateTime.now().difference(dateCreated);
                              final minutesElapsed = durationDiff.inMinutes;

                              final bool isKotCancelled = kot['status'] == 'Cancelled' || kot['status'] == 'Rejected';

                              Color headerColor = colorScheme.surfaceContainerHighest;
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

                              final List allKotItems = (kot['items'] as List?) ?? [];
                              final List displayItems = selectedLocationFilter == 'All'
                                  ? allKotItems
                                  : allKotItems.where((it) {
                                      final loc = (it['location'] ?? it['station_name'] ?? it['kitchen_station'] ?? 'Kitchen').toString().trim();
                                      return loc.toLowerCase() == selectedLocationFilter.toLowerCase();
                                    }).toList();

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
                                                  '${(kot['kottype'] == 'nc' || (kot['service_type'] ?? '').toString().toLowerCase().contains('nc') || (kot['remarks'] ?? '').toString().toLowerCase().contains('nc')) ? "NC Order (No Charge)" : (kot['table'] != null ? "Table: ${kot['table']['table_name']}" : "Takeaway")} ${isKotCancelled ? "(CANCELLED/REJECTED)" : ""}',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                    color: isKotCancelled ? Colors.red.shade900 : null,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (!isKotCancelled && kot['status'] != 'Ready')
                                            IconButton(
                                              icon: const Icon(Icons.cancel_presentation, color: Colors.redAccent, size: 20),
                                              tooltip: 'Reject Complete Order',
                                              onPressed: () => _cancelEntireKotDialog(kot['id'], kot['kot_number'] ?? kot['id'].toString()),
                                            ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: minutesElapsed > 15 ? Colors.red : Colors.grey.shade800,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              '${minutesElapsed}m ago',
                                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                            ),
                                          )
                                        ],
                                      ),
                                    ),
                                    // Subheader Details
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('KOT: ${kot['kot_number'] ?? kot['id']}', style: TextStyle(color: colorScheme.outline, fontSize: 12, fontWeight: FontWeight.bold)),
                                          Text('Staff: ${kot['waiter_name'] ?? kot['created_by'] ?? 'Staff'}', style: TextStyle(color: colorScheme.outline, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    const Divider(height: 1),
                                    // Items List
                                    Expanded(
                                      child: ListView.separated(
                                        padding: const EdgeInsets.all(12),
                                        itemCount: displayItems.length,
                                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                                        itemBuilder: (context, iIdx) {
                                          final item = displayItems[iIdx];
                                          final isCancelled = item['status'] == 'Cancelled' || item['status'] == 'Rejected';
                                          final isNewItem = item['status'] == 'New';
                                          final String itemLoc = (item['location'] ?? item['station_name'] ?? 'Kitchen').toString();

                                          // Calculate quantity changes from revision logs
                                          String? qtyChangeMessage;
                                          final revisions = List.from(kot['revisions'] as List? ?? []);
                                          revisions.sort((a, b) {
                                            final int rA = int.tryParse(a['revision_no']?.toString() ?? '0') ?? 0;
                                            final int rB = int.tryParse(b['revision_no']?.toString() ?? '0') ?? 0;
                                            return rB.compareTo(rA);
                                          });
                                          for (final rev in revisions) {
                                            final Map<String, dynamic>? changes = rev['change_details'] is String
                                                ? jsonDecode(rev['change_details'])
                                                : rev['change_details'];
                                            if (changes != null && changes['updated'] is List) {
                                              final List updatedList = changes['updated'];
                                              final matchUpdate = updatedList.firstWhere(
                                                (u) => u['item_id'] == item['item_id'],
                                                orElse: () => null,
                                              );
                                              if (matchUpdate != null) {
                                                final double oldQty = double.tryParse(matchUpdate['old_qty']?.toString() ?? '0') ?? 0.0;
                                                final double newQty = double.tryParse(matchUpdate['new_qty']?.toString() ?? '0') ?? 0.0;
                                                if (newQty > oldQty) {
                                                  qtyChangeMessage = 'Qty Increased: ${oldQty.toInt()} ➔ ${newQty.toInt()}';
                                                } else if (newQty < oldQty) {
                                                  qtyChangeMessage = 'Qty Decreased: ${oldQty.toInt()} ➔ ${newQty.toInt()}';
                                                }
                                                break;
                                              }
                                            }
                                          }

                                          return Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: isCancelled ? Colors.red.shade100 : colorScheme.primaryContainer,
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  '${_formatQty(item['quantity'] ?? item['qty'])}x',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: isCancelled ? Colors.red.shade900 : colorScheme.onPrimaryContainer,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            item['item_name'] ?? '',
                                                            style: TextStyle(
                                                              fontWeight: FontWeight.w600,
                                                              fontSize: 14,
                                                              decoration: isCancelled ? TextDecoration.lineThrough : null,
                                                              color: isCancelled ? Colors.red : null,
                                                            ),
                                                          ),
                                                        ),
                                                        if (isNewItem)
                                                          Container(
                                                            margin: const EdgeInsets.only(left: 6),
                                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                                            decoration: BoxDecoration(
                                                              color: Colors.green.shade600,
                                                              borderRadius: BorderRadius.circular(4),
                                                            ),
                                                            child: const Text('NEW', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                                                          ),
                                                        if (isCancelled)
                                                          Container(
                                                            margin: const EdgeInsets.only(left: 6),
                                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                                            decoration: BoxDecoration(
                                                              color: Colors.red.shade600,
                                                              borderRadius: BorderRadius.circular(4),
                                                            ),
                                                            child: const Text('REJECTED', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                                                          ),
                                                      ],
                                                    ),
                                                    if (item['notes'] != null && item['notes'].toString().isNotEmpty)
                                                      Text(
                                                        'Note: ${item['notes']}',
                                                        style: const TextStyle(fontSize: 11, color: Colors.orange, fontStyle: FontStyle.italic),
                                                      ),
                                                    if (isCancelled && (item['cancel_reason'] ?? '').toString().isNotEmpty)
                                                      Text(
                                                        'Reason: ${item['cancel_reason']}',
                                                        style: TextStyle(color: Colors.red.shade800, fontSize: 10, fontStyle: FontStyle.italic),
                                                      ),
                                                    if (qtyChangeMessage != null)
                                                      Text(
                                                        qtyChangeMessage,
                                                        style: const TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              if (!isCancelled && kot['status'] != 'Ready')
                                                IconButton(
                                                  icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 18),
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(),
                                                  onPressed: () => _cancelKotItemDialog(item['id'], item['item_name']),
                                                ),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.shade50,
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: Colors.blue.shade200, width: 0.5),
                                                ),
                                                child: Text(
                                                  itemLoc,
                                                  style: TextStyle(color: Colors.blue.shade800, fontSize: 9.5, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ),
                                    // Action Bar
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                                      child: Row(
                                        children: [
                                          if (!isKotCancelled && kot['status'] != 'Preparing' && kot['status'] != 'Ready')
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.blue.shade700,
                                                  foregroundColor: Colors.white,
                                                ),
                                                onPressed: () => _updateKotStatus(kot['id'], 'Preparing'),
                                                icon: const Icon(Icons.restaurant, size: 16),
                                                label: const Text('Preparing'),
                                              ),
                                            ),
                                          if (!isKotCancelled && kot['status'] == 'Preparing')
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.orange.shade700,
                                                  foregroundColor: Colors.white,
                                                ),
                                                onPressed: () => _updateKotStatus(kot['id'], 'Ready'),
                                                icon: const Icon(Icons.check, size: 16),
                                                label: const Text('Mark Ready'),
                                              ),
                                            ),
                                          if (isKotCancelled)
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.grey.shade700,
                                                  foregroundColor: Colors.white,
                                                ),
                                                onPressed: () => _updateKotStatus(kot['id'], kot['status'], kdsDismissed: true),
                                                icon: const Icon(Icons.clear_all, size: 16),
                                                label: Text(kot['status'] == 'Rejected' ? 'Dismiss Rejected' : 'Dismiss Cancelled'),
                                              ),
                                            ),
                                          if (kot['status'] == 'Ready' && (kot['service_type'] ?? '').toString().toUpperCase().contains('NC'))
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.green.shade700,
                                                  foregroundColor: Colors.white,
                                                ),
                                                onPressed: () => _updateKotStatus(kot['id'], 'Served'),
                                                icon: const Icon(Icons.check_circle_outline, size: 16),
                                                label: const Text('Dismiss Order'),
                                              ),
                                            ),
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
