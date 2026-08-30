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
  bool _oneOptionMode = false;
  bool _showServedOrders = false;

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
        final List unbilled = raw.where((kot) {
          final bool isDismissed = kot['kds_dismissed'] == true || kot['kds_dismissed'] == 1;
          if (isDismissed) return false;

          final String status = (kot['status'] ?? '').toString().toUpperCase();
          final bool isBilled = kot['is_billed'] == true ||
              status == 'BILLED' ||
              status == 'COMPLETED' ||
              status == 'CLOSED' ||
              status == 'DISMISSED';
          if (isBilled) return false;

          if (!_showServedOrders && status == 'SERVED') {
            return false;
          }
          return true;
        }).toList();

        final Set<int> seenKotIds = {};
        final List uniqueKots = [];
        for (final kot in unbilled) {
          final int kId = int.tryParse((kot['id'] ?? 0).toString()) ?? 0;
          if (kId > 0 && seenKotIds.contains(kId)) continue;
          if (kId > 0) seenKotIds.add(kId);
          uniqueKots.add(kot);
        }

        setState(() {
          activeKotsList = uniqueKots;
        });
      }
    } catch (e) {
      debugPrint('Error loading KDS orders: $e');
    } finally {
      setState(() => isLoadingKots = false);
    }
  }

  Future<void> _updateKotStatus(int id, String status, {bool? kdsDismissed, String? location}) async {
    try {
      final payload = {
        'status': status,
        if (kdsDismissed != null) 'kds_dismissed': kdsDismissed,
        if (location != null && location.isNotEmpty && location != 'All') 'location': location,
      };
      final res = await ApiClient.put('/api/restaurant/kots/$id/status', payload);
      if (res['success'] == true) {
        _fetchKots();
      }
    } catch (e) {
      debugPrint('Error updating KOT: $e');
    }
  }

  Future<void> _toggleItemStatus(int itemId, String currentStatus) async {
    String nextStatus = 'Ready';
    final s = currentStatus.trim().toLowerCase();
    if (s == 'new' || s == 'pending' || s == 'preparing') {
      nextStatus = 'Ready';
    } else if (s == 'ready') {
      nextStatus = 'Served';
    } else if (s == 'served') {
      nextStatus = 'Preparing';
    }
    try {
      final res = await ApiClient.put('/api/restaurant/kots/items/$itemId/status', {
        'status': nextStatus,
      });
      if (res['success'] == true) {
        _fetchKots();
      }
    } catch (e) {
      debugPrint('Error toggling item status: $e');
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

  String _getItemLocation(dynamic item) {
    if (item is! Map) return 'Main Kitchen';
    String loc = (item['station']?['station_name'] ??
            item['station_name'] ??
            item['location'] ??
            item['item_location'] ??
            item['kitchen_location'] ??
            item['item']?['location'] ??
            (item['item'] is Map ? item['item']['location'] ?? item['item']['kitchen_location'] : null) ??
            '')
        .toString()
        .trim();

    if (loc.isEmpty) {
      loc = (item['item_group'] ??
              item['category'] ??
              item['item']?['item_group'] ??
              item['item']?['category'] ??
              (item['item'] is Map ? item['item']['item_group'] ?? item['item']['category'] : null) ??
              '')
          .toString()
          .trim();
    }

    return loc.isEmpty ? 'Main Kitchen' : loc;
  }

  String _getItemBrand(dynamic item) {
    if (item is! Map) return '';
    String brand = (item['brand'] ??
            item['brand_name'] ??
            item['item_brand'] ??
            item['item']?['brand'] ??
            (item['item'] is Map ? item['item']['brand'] : null) ??
            '')
        .toString()
        .trim();
    return brand;
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
        final loc = _getItemLocation(item);
        if (loc.isNotEmpty) locations.add(loc);
      }
    }

    // Filter KOTs by selected location chip
    final filteredKots = activeKotsList.where((kot) {
      if (selectedLocationFilter == 'All') return true;
      final items = (kot['items'] as List?) ?? [];
      return items.any((it) {
        final loc = _getItemLocation(it);
        final bool matchesLoc = loc.toLowerCase() == selectedLocationFilter.toLowerCase() ||
            loc.toLowerCase().contains(selectedLocationFilter.toLowerCase()) ||
            selectedLocationFilter.toLowerCase().contains(loc.toLowerCase());

        if (!matchesLoc) return false;

        if (!_showServedOrders) {
          final String itemSt = (it['status'] ?? 'New').toString().trim().toLowerCase();
          if (itemSt == 'served') return false;
        }

        return true;
      });
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kitchen Display System (KDS)'),
        elevation: 0,
        actions: [
          Tooltip(
            message: 'Show Served Orders: Keep served items visible in kitchen queue',
            child: Row(
              children: [
                const Text('Show Served', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                Switch(
                  value: _showServedOrders,
                  onChanged: (val) {
                    setState(() {
                      _showServedOrders = val;
                    });
                    _fetchKots();
                  },
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
          Tooltip(
            message: 'Direct Fast-Track Mode: Single-step status transitions for high-speed kitchen operations',
            child: Row(
              children: [
                const Text('Direct Serve Mode', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                Switch(
                  value: _oneOptionMode,
                  onChanged: (val) {
                    setState(() {
                      _oneOptionMode = val;
                    });
                  },
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
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
                                      final loc = _getItemLocation(it);
                                      return loc.toLowerCase() == selectedLocationFilter.toLowerCase() ||
                                          loc.toLowerCase().contains(selectedLocationFilter.toLowerCase()) ||
                                          selectedLocationFilter.toLowerCase().contains(loc.toLowerCase());
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
                                              onPressed: () => _cancelEntireKotDialog(kot['id'], kot['kot_no'] ?? kot['id'].toString()),
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
                                          Text('KOT: ${kot['kot_no'] ?? kot['id']}', style: TextStyle(color: colorScheme.outline, fontSize: 12, fontWeight: FontWeight.bold)),
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
                                          final String itemLoc = _getItemLocation(item);
                                          final String itemBrand = _getItemBrand(item);

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
                                                          child: Text.rich(
                                                            TextSpan(
                                                              text: item['item_name'] ?? '',
                                                              style: TextStyle(
                                                                fontWeight: FontWeight.w600,
                                                                fontSize: 14,
                                                                decoration: isCancelled ? TextDecoration.lineThrough : null,
                                                                color: isCancelled ? Colors.red : null,
                                                              ),
                                                              children: [
                                                                if (itemBrand.isNotEmpty)
                                                                  TextSpan(
                                                                    text: ' ($itemBrand)',
                                                                    style: TextStyle(
                                                                      fontWeight: FontWeight.bold,
                                                                      color: Colors.indigo.shade700,
                                                                      fontSize: 13,
                                                                      decoration: TextDecoration.none,
                                                                    ),
                                                                  ),
                                                              ],
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
                                              const SizedBox(width: 4),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.shade50,
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: Colors.blue.shade200, width: 0.5),
                                                ),
                                                child: Text(
                                                  itemLoc,
                                                  style: TextStyle(color: Colors.blue.shade800, fontSize: 9, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Builder(
                                                builder: (context) {
                                                  final String st = (item['status'] ?? 'New').toString().trim().toLowerCase();
                                                  final bool isItServed = st == 'served';
                                                  final bool isItReady = st == 'ready';
                                                  return InkWell(
                                                    onTap: isCancelled ? null : () => _toggleItemStatus(item['id'], st),
                                                    borderRadius: BorderRadius.circular(4),
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: isItServed
                                                            ? Colors.teal.shade50
                                                            : (isItReady ? Colors.green.shade50 : Colors.orange.shade50),
                                                        borderRadius: BorderRadius.circular(4),
                                                        border: Border.all(
                                                          color: isItServed
                                                              ? Colors.teal.shade300
                                                              : (isItReady ? Colors.green.shade300 : Colors.orange.shade300),
                                                          width: 0.8,
                                                        ),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                            isItServed ? Icons.check_circle : (isItReady ? Icons.task_alt : Icons.hourglass_top),
                                                            size: 10,
                                                            color: isItServed ? Colors.teal.shade800 : (isItReady ? Colors.green.shade800 : Colors.orange.shade800),
                                                          ),
                                                          const SizedBox(width: 2),
                                                          Text(
                                                            isItServed ? 'Served' : (isItReady ? 'Ready' : 'Pending'),
                                                            style: TextStyle(
                                                              color: isItServed ? Colors.teal.shade800 : (isItReady ? Colors.green.shade800 : Colors.orange.shade800),
                                                              fontSize: 9,
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ),
                                     // Action Bar
                                     Builder(
                                       builder: (context) {
                                         final String stationStatus = (() {
                                           if (displayItems.isEmpty) return 'New';
                                           final nonCancelled = displayItems.where((it) {
                                             final s = (it['status'] ?? '').toString().toLowerCase();
                                             return s != 'cancelled' && s != 'rejected';
                                           }).toList();
                                           if (nonCancelled.isEmpty) return 'Cancelled';

                                           final allServed = nonCancelled.every((it) => (it['status'] ?? '').toString().toLowerCase() == 'served');
                                           if (allServed) return 'Served';

                                           final allReadyOrServed = nonCancelled.every((it) {
                                             final s = (it['status'] ?? '').toString().toLowerCase();
                                             return s == 'ready' || s == 'served';
                                           });
                                           if (allReadyOrServed) return 'Ready';

                                           final anyPreparingOrReady = nonCancelled.any((it) {
                                             final s = (it['status'] ?? '').toString().toLowerCase();
                                             return s == 'preparing' || s == 'ready' || s == 'served';
                                           });
                                           if (anyPreparingOrReady) return 'Preparing';

                                           return 'New';
                                         })();

                                         final bool isServed = stationStatus == 'Served';
                                         final bool isKotCancelled = stationStatus == 'Cancelled';
                                         return Container(
                                           padding: const EdgeInsets.all(8),
                                           color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                                           child: Row(
                                             children: [
                                               if (isServed)
                                                 Expanded(
                                                   child: Container(
                                                     padding: const EdgeInsets.symmetric(vertical: 8),
                                                     decoration: BoxDecoration(
                                                       color: Colors.teal.shade50,
                                                       borderRadius: BorderRadius.circular(8),
                                                       border: Border.all(color: Colors.teal.shade200),
                                                     ),
                                                     child: Row(
                                                       mainAxisAlignment: MainAxisAlignment.center,
                                                       children: [
                                                         Icon(Icons.check_circle, size: 16, color: Colors.teal.shade700),
                                                         const SizedBox(width: 6),
                                                         Text(
                                                           'Status: Served',
                                                           style: TextStyle(
                                                             color: Colors.teal.shade800,
                                                             fontWeight: FontWeight.bold,
                                                             fontSize: 13,
                                                           ),
                                                         ),
                                                       ],
                                                     ),
                                                   ),
                                                 ),
                                               if (_oneOptionMode && !isKotCancelled && !isServed)
                                                 Expanded(
                                                   child: ElevatedButton.icon(
                                                     style: ElevatedButton.styleFrom(
                                                       backgroundColor: stationStatus == 'Ready' ? Colors.green.shade700 : Colors.orange.shade700,
                                                       foregroundColor: Colors.white,
                                                     ),
                                                     onPressed: () => _updateKotStatus(
                                                       kot['id'],
                                                       stationStatus == 'Ready' ? 'Served' : 'Ready',
                                                       location: selectedLocationFilter,
                                                     ),
                                                     icon: Icon(stationStatus == 'Ready' ? Icons.check_circle_outline : Icons.check, size: 16),
                                                     label: Text(stationStatus == 'Ready' ? 'Mark Served' : 'Mark Ready'),
                                                   ),
                                                 ),
                                               if (!_oneOptionMode && !isKotCancelled && !isServed && stationStatus != 'Preparing' && stationStatus != 'Ready')
                                                 Expanded(
                                                   child: ElevatedButton.icon(
                                                     style: ElevatedButton.styleFrom(
                                                       backgroundColor: Colors.blue.shade700,
                                                       foregroundColor: Colors.white,
                                                     ),
                                                     onPressed: () => _updateKotStatus(
                                                       kot['id'], 
                                                       'Preparing',
                                                       location: selectedLocationFilter,
                                                     ),
                                                     icon: const Icon(Icons.restaurant, size: 16),
                                                     label: const Text('Preparing'),
                                                   ),
                                                 ),
                                               if (!_oneOptionMode && !isKotCancelled && !isServed && stationStatus == 'Preparing')
                                                 Expanded(
                                                   child: ElevatedButton.icon(
                                                     style: ElevatedButton.styleFrom(
                                                       backgroundColor: Colors.orange.shade700,
                                                       foregroundColor: Colors.white,
                                                     ),
                                                     onPressed: () => _updateKotStatus(
                                                       kot['id'], 
                                                       'Ready',
                                                       location: selectedLocationFilter,
                                                     ),
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
                                                     onPressed: () => _updateKotStatus(
                                                       kot['id'], 
                                                       kot['status'], 
                                                       kdsDismissed: true,
                                                       location: selectedLocationFilter,
                                                     ),
                                                     icon: const Icon(Icons.clear_all, size: 16),
                                                     label: Text(kot['status'] == 'Rejected' ? 'Dismiss Rejected' : 'Dismiss Cancelled'),
                                                   ),
                                                 ),
                                               if (!_oneOptionMode && !isKotCancelled && !isServed && stationStatus == 'Ready')
                                                 Expanded(
                                                   child: ElevatedButton.icon(
                                                     style: ElevatedButton.styleFrom(
                                                       backgroundColor: Colors.green.shade700,
                                                       foregroundColor: Colors.white,
                                                     ),
                                                     onPressed: () => _updateKotStatus(
                                                       kot['id'], 
                                                       'Served',
                                                       location: selectedLocationFilter,
                                                     ),
                                                     icon: const Icon(Icons.check_circle_outline, size: 16),
                                                     label: const Text('Mark Served'),
                                                   ),
                                                 ),
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
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
