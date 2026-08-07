import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../controllers/restaurant/restaurant_controller.dart';
import '../../core/api/api_client.dart';
import '../inventory/salescreen.dart';
import 'kot_builder_screen.dart';
import 'running_orders_screen.dart';

class CaptainDashboardScreen extends StatefulWidget {
  const CaptainDashboardScreen({super.key});

  @override
  State<CaptainDashboardScreen> createState() => _CaptainDashboardScreenState();
}

class _CaptainDashboardScreenState extends State<CaptainDashboardScreen> {
  int? selectedFloorId;
  Map<String, dynamic>? selectedTable;
  Map<int, List<dynamic>> activeKotItemsByTable = {};
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctrl = Provider.of<RestaurantController>(context, listen: false);
      ctrl.loadFloors().then((_) {
        if (ctrl.floors.isNotEmpty) {
          setState(() {
            selectedFloorId = ctrl.floors[0]['id'];
          });
        }
      });
      _refreshData();
    });

    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _refreshData();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _refreshData() {
    if (!mounted) return;
    context.read<RestaurantController>().loadTables();
    _fetchActiveKots();
  }

  Future<void> _fetchActiveKots() async {
    try {
      final res = await ApiClient.get('/api/restaurant/kots?active_only=true');
      if (res['success'] == true) {
        final List kots = res['data'] ?? [];
        final Map<int, List<dynamic>> tempMap = {};
        for (final kot in kots) {
          final tableId = kot['table_id'];
          if (tableId == null) continue;
          final items = kot['items'] as List? ?? [];
          if (!tempMap.containsKey(tableId)) {
            tempMap[tableId] = [];
          }
          for (final item in items) {
            if (item['status'] != 'Cancelled') {
              tempMap[tableId]!.add(item);
            }
          }
        }
        if (mounted) {
          setState(() {
            activeKotItemsByTable = tempMap;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading active KOTs for dashboard: $e');
    }
  }

  LinearGradient _getTableGradient(String status) {
    switch (status) {
      case 'Available':
        return LinearGradient(
          colors: [Colors.teal.shade400, Colors.teal.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'Occupied':
        return LinearGradient(
          colors: [Colors.pink.shade400, Colors.orange.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'Reserved':
        return LinearGradient(
          colors: [Colors.lightBlue.shade400, Colors.indigo.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'Billing':
        return LinearGradient(
          colors: [Colors.amber.shade400, Colors.orange.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'Cleaning':
        return LinearGradient(
          colors: [Colors.deepOrange.shade300, Colors.deepOrange.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      default:
        return LinearGradient(
          colors: [Colors.grey.shade400, Colors.grey.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<RestaurantController>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final filteredTables = ctrl.tables.where((t) => t['floor_id'] == selectedFloorId).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Captain Console / Order Desk'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ctrl.loadTables();
              ctrl.loadFloors();
              _fetchActiveKots();
            },
          )
        ],
      ),
      body: Row(
        children: [
          // Sidebar with Floor selections
          Container(
            width: 180,
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: colorScheme.outlineVariant)),
            ),
            child: ListView.builder(
              itemCount: ctrl.floors.length,
              itemBuilder: (context, index) {
                final floor = ctrl.floors[index];
                final isSelected = floor['id'] == selectedFloorId;
                return ListTile(
                  title: Text(floor['name'] ?? ''),
                  selected: isSelected,
                  selectedTileColor: colorScheme.primaryContainer,
                  onTap: () {
                    setState(() {
                      selectedFloorId = floor['id'];
                    });
                  },
                );
              },
            ),
          ),
          // Main table grid
          Expanded(
            child: ctrl.tables.isEmpty
                ? const Center(child: Text('No tables configured. Please add tables in setup.'))
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final cols = (constraints.maxWidth / 220).floor().clamp(2, 8);
                      return GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.8,
                        ),
                        itemCount: filteredTables.length,
                        itemBuilder: (context, index) {
                          final table = filteredTables[index];
                          final gradient = _getTableGradient(table['status']);
                          final runningItems = activeKotItemsByTable[table['id']] ?? [];

                          return InkWell(
                            onTap: () => _handleTableTap(context, table, ctrl),
                            child: Card(
                              elevation: 4,
                              clipBehavior: Clip.antiAlias,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: gradient,
                                ),
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Icon(Icons.table_restaurant, color: Colors.white, size: 28),
                                        if (table['current_guest_count'] > 0)
                                          Row(
                                            children: [
                                              const Icon(Icons.people, color: Colors.white70, size: 14),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${table['current_guest_count']}',
                                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      table['table_name'] ?? '',
                                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      table['status'] ?? '',
                                      style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                                    ),
                                    if (runningItems.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      const Divider(color: Colors.white24, height: 1),
                                      const SizedBox(height: 6),
                                      Expanded(
                                        child: ListView.builder(
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          itemCount: runningItems.length.clamp(0, 3),
                                          itemBuilder: (context, idx) {
                                            final item = runningItems[idx];
                                            final double q = double.tryParse(item['qty']?.toString() ?? '0') ?? 0.0;
                                            final String qtyStr = (q % 1 == 0) ? q.toInt().toString() : q.toStringAsFixed(1);
                                            return Text(
                                              '$qtyStr x ${item['item_name']}',
                                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                              overflow: TextOverflow.ellipsis,
                                            );
                                          },
                                        ),
                                      ),
                                      if (runningItems.length > 3)
                                        Text(
                                          '+${runningItems.length - 3} more items',
                                          style: const TextStyle(color: Colors.white70, fontSize: 9, fontStyle: FontStyle.italic),
                                        ),
                                    ] else
                                      const Spacer(),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          )
        ],
      ),
    );
  }

  void _handleTableTap(BuildContext context, Map<String, dynamic> table, RestaurantController ctrl) {
    if (table['status'] == 'Available') {
      _showOpenTableDialog(context, table, ctrl);
    } else {
      _showTableOptionsDialog(context, table, ctrl);
    }
  }

  void _showOpenTableDialog(BuildContext context, Map<String, dynamic> table, RestaurantController ctrl) {
    final guestsCtrl = TextEditingController(text: '2');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Open ${table['table_name']}'),
          content: TextField(
            controller: guestsCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Number of Guests'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final guests = int.tryParse(guestsCtrl.text) ?? 2;
                await ctrl.updateTableStatus(table['id'], 'Occupied', guestCount: guests);
                Navigator.pop(context);
                _openOrderSheet(table);
              },
              child: const Text('Start Order / Occupy'),
            )
          ],
        );
      },
    );
  }

  void _showTableOptionsDialog(BuildContext context, Map<String, dynamic> table, RestaurantController ctrl) {
    showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: Text('Table: ${table['table_name']} (${table['status']})'),
          children: [
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                _openOrderSheet(table);
              },
              child: const ListTile(
                leading: Icon(Icons.add_shopping_cart, color: Colors.blue),
                title: Text('Add Items / Edit KOT'),
              ),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RunningOrdersScreen(
                      tableId: table['id'],
                      tableName: table['table_name'] ?? '',
                    ),
                  ),
                ).then((_) => _refreshData());
              },
              child: const ListTile(
                leading: Icon(Icons.restaurant_menu, color: Colors.deepOrange),
                title: Text('View Running Orders'),
              ),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                _showBillingCheckoutDialog(context, table, ctrl);
              },
              child: const ListTile(
                leading: Icon(Icons.receipt_long, color: Colors.teal),
                title: Text('Print Bill & Settle'),
              ),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                _showTransferDialog(context, table, ctrl);
              },
              child: const ListTile(
                leading: Icon(Icons.swap_horiz, color: Colors.purple),
                title: Text('Transfer Table'),
              ),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                _showMergeDialog(context, table, ctrl);
              },
              child: const ListTile(
                leading: Icon(Icons.merge, color: Colors.orange),
                title: Text('Merge / Combine Tables'),
              ),
            ),
            SimpleDialogOption(
              onPressed: () async {
                await ctrl.updateTableStatus(table['id'], 'Available', guestCount: 0);
                Navigator.pop(context);
              },
              child: const ListTile(
                leading: Icon(Icons.check_circle, color: Colors.green),
                title: Text('Set Available / Clean Table'),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showTransferDialog(BuildContext context, Map<String, dynamic> sourceTable, RestaurantController ctrl) {
    int? selectedTargetTable;
    final availableTables = ctrl.tables.where((t) => t['status'] == 'Available' && t['id'] != sourceTable['id']).toList();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Transfer ${sourceTable['table_name']} to...'),
              content: DropdownButtonFormField<int>(
                value: selectedTargetTable,
                decoration: const InputDecoration(labelText: 'Select vacant table'),
                items: availableTables.map<DropdownMenuItem<int>>((t) {
                  return DropdownMenuItem<int>(value: t['id'], child: Text(t['table_name']));
                }).toList(),
                onChanged: (val) => setState(() => selectedTargetTable = val),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedTargetTable == null) return;
                    await ctrl.transferTable(sourceTable['id'], selectedTargetTable!);
                    Navigator.pop(context);
                  },
                  child: const Text('Transfer'),
                )
              ],
            );
          },
        );
      },
    );
  }

  void _showMergeDialog(BuildContext context, Map<String, dynamic> mainTable, RestaurantController ctrl) {
    int? selectedMergeTable;
    final occupiedTables = ctrl.tables.where((t) => t['status'] == 'Occupied' && t['id'] != mainTable['id']).toList();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Merge Table with ${mainTable['table_name']}'),
              content: DropdownButtonFormField<int>(
                value: selectedMergeTable,
                decoration: const InputDecoration(labelText: 'Choose table to merge from'),
                items: occupiedTables.map<DropdownMenuItem<int>>((t) {
                  return DropdownMenuItem<int>(value: t['id'], child: Text(t['table_name']));
                }).toList(),
                onChanged: (val) => setState(() => selectedMergeTable = val),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedMergeTable == null) return;
                    await ctrl.mergeTables(mainTable['id'], selectedMergeTable!);
                    Navigator.pop(context);
                  },
                  child: const Text('Merge'),
                )
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showBillingCheckoutDialog(BuildContext context, Map<String, dynamic> table, RestaurantController ctrl) async {
    // Show a loading dialog first
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Fetch active KOTs for this table
      final res = await ApiClient.get('/api/restaurant/kots?table_id=${table['id']}&active_only=true');
      Navigator.pop(context); // Pop loading indicator

      if (res['success'] == true) {
        final List kots = res['data'] ?? [];
        if (kots.isEmpty) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('No active KOTs'),
              content: const Text('There are no active orders placed on this table to bill.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
              ],
            ),
          );
          return;
        }

        // Group same items and sum quantities
        final Map<int, Map<String, dynamic>> grouped = {};
        for (final kot in kots) {
          final List items = kot['items'] ?? [];
          for (final item in items) {
            final int itemId = item['item_id'];
            final double qty = double.tryParse(item['qty'].toString()) ?? 1.0;
            final double rate = double.tryParse(item['rate']?.toString() ?? '') ?? 
                              double.tryParse(item['item_rate']?.toString() ?? '') ?? 0.0;

            if (grouped.containsKey(itemId)) {
              grouped[itemId]!['qty'] = grouped[itemId]!['qty'] + qty;
            } else {
              grouped[itemId] = {
                'item_id': itemId,
                'item_name': item['item_name'],
                'qty': qty,
                'rate': rate,
              };
            }
          }
        }

        final consolidatedItems = grouped.values.toList();

        // Redirect to main Retail POS checkout screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SaleScreen(
              preloadedTableId: table['id'],
              preloadedItems: consolidatedItems,
            ),
          ),
        ).then((_) {
          // Refresh table status on return
          ctrl.loadTables();
        });
      } else {
        throw Exception('Failed to load active orders');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading orders: $e')),
      );
    }
  }

  void _openOrderSheet(Map<String, dynamic> table) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => KotBuilderScreen(table: table)),
    );
  }
}
