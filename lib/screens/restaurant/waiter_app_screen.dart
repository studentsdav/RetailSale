import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../controllers/restaurant/restaurant_controller.dart';
import '../../core/api/api_client.dart';
import '../../core/currency/currency_service.dart';
import '../../core/printing/pdf_preview_dialog.dart';
import '../../core/auth/token_storage.dart';
import 'kot_builder_screen.dart';

class WaiterAppScreen extends StatefulWidget {
  const WaiterAppScreen({super.key});

  @override
  State<WaiterAppScreen> createState() => _WaiterAppScreenState();
}

class _WaiterAppScreenState extends State<WaiterAppScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = false;
  Timer? _pollingTimer;

  int? _selectedFloorId;
  String _currentUser = 'Waiter';

  List<dynamic> _runningKots = [];
  List<dynamic> _settledBills = [];
  final _searchBillCtrl = TextEditingController();

  static const Color primaryTeal = Color(0xFF0D9488);
  static const Color darkSlate = Color(0xFF0F172A);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUser();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctrl = context.read<RestaurantController>();
      ctrl.loadFloors();
      ctrl.loadDiningAreas();
      ctrl.loadTables();
      _fetchOrders();
    });

    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _fetchOrders(silent: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _tabController.dispose();
    _searchBillCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final user = await TokenStorage.getUser();
    if (mounted && user != null) {
      setState(() {
        _currentUser = user['name'] ?? user['username'] ?? 'Waiter';
      });
    }
  }

  Future<void> _fetchOrders({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final runningFuture = ApiClient.get('/api/restaurant/kots?active_only=true');
      final settledFuture = ApiClient.get('/api/sales/reprint-bills?limit=50');

      final results = await Future.wait([runningFuture, settledFuture]);
      final runningRes = results[0];
      final settledRes = results[1];

      if (mounted) {
        setState(() {
          if (runningRes['success'] == true) {
            _runningKots = runningRes['data'] ?? [];
          }
          if (settledRes['success'] == true) {
            _settledBills = settledRes['data'] ?? [];
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching waiter orders: $e');
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  void _openTableOrder(Map<String, dynamic> table) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => KotBuilderScreen(table: table, isFreshOrder: table['status'] == 'Available'),
      ),
    ).then((_) {
      if (mounted) {
        context.read<RestaurantController>().loadTables();
        _fetchOrders();
      }
    });
  }

  Future<void> _printProformaBill(Map<String, dynamic> kot) async {
    final pdf = pw.Document();
    final items = kot['items'] as List? ?? [];
    double total = 0;
    for (final item in items) {
      final double qty = double.tryParse(item['qty']?.toString() ?? '1') ?? 1;
      final double rate = double.tryParse(item['rate']?.toString() ?? '0') ?? 0;
      total += qty * rate;
    }

    final tableName = kot['table']?['table_name'] ?? 'Table';
    final kotNo = kot['kot_no'] ?? '#KOT';

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 4 * PdfPageFormat.mm),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text('PRO-FORMA BILL / ESTIMATE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
              pw.Text('Table: $tableName • $kotNo', style: const pw.TextStyle(fontSize: 11)),
              pw.Text('Waiter: $_currentUser', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('Date: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 9)),
              pw.Divider(thickness: 0.5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Item', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  pw.Text('Qty x Rate', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                ],
              ),
              pw.Divider(thickness: 0.5),
              ...items.map((it) {
                final double q = double.tryParse(it['qty']?.toString() ?? '1') ?? 1;
                final double r = double.tryParse(it['rate']?.toString() ?? '0') ?? 0;
                final double itemTotal = q * r;
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(child: pw.Text(it['item_name'] ?? '', style: const pw.TextStyle(fontSize: 10))),
                      pw.Text('$q x ${r.toStringAsFixed(2)}  ', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text(itemTotal.toStringAsFixed(2), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    ],
                  ),
                );
              }),
              pw.Divider(thickness: 0.8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL DUE:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                  pw.Text(CurrencyService.format(total), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Text('Thank You! Please proceed to Cashier.', style: const pw.TextStyle(fontSize: 9)),
            ],
          );
        },
      ),
    );

    showPdfPreviewDialog(
      context: context,
      name: 'Bill_Estimate_$tableName',
      pageFormat: const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 4 * PdfPageFormat.mm),
      buildPdf: (format) => pdf.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.room_service_outlined, size: 24),
            const SizedBox(width: 8),
            const Text('Waiter Floor Terminal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.badge_outlined, size: 14, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(_currentUser, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: primaryTeal,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            const Tab(icon: Icon(Icons.table_restaurant), text: 'Floor Tables'),
            Tab(
              icon: const Icon(Icons.pending_actions),
              text: 'Running Orders (${_runningKots.length})',
            ),
            const Tab(icon: Icon(Icons.check_circle_outline), text: 'Settled Bills'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Orders',
            onPressed: () {
              context.read<RestaurantController>().loadTables();
              _fetchOrders();
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFloorTablesTab(),
          _buildRunningOrdersTab(),
          _buildSettledBillsTab(),
        ],
      ),
    );
  }

  Widget _buildFloorTablesTab() {
    final restCtrl = context.watch<RestaurantController>();
    final floors = restCtrl.floors;
    var tables = restCtrl.tables;

    if (_selectedFloorId != null) {
      tables = tables.where((t) => t['floor_id'] == _selectedFloorId).toList();
    }

    return Column(
      children: [
        // Floor selector bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: Colors.grey.shade100,
          child: Row(
            children: [
              FilterChip(
                label: const Text('All Floors'),
                selected: _selectedFloorId == null,
                selectedColor: Colors.teal.shade100,
                onSelected: (_) => setState(() => _selectedFloorId = null),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: floors.map((f) {
                      final isSelected = _selectedFloorId == f['id'];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(f['name']),
                          selected: isSelected,
                          selectedColor: Colors.teal.shade100,
                          onSelected: (_) => setState(() => _selectedFloorId = f['id']),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Tables Grid
        Expanded(
          child: tables.isEmpty
              ? const Center(child: Text('No tables found for this floor.'))
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 180,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.95,
                  ),
                  itemCount: tables.length,
                  itemBuilder: (context, index) {
                    final table = tables[index];
                    final String status = table['status'] ?? 'Available';
                    final String tableName = table['table_name'] ?? 'T-${table['id']}';
                    final int capacity = table['capacity'] ?? 4;
                    final waiterName = table['waiter']?['employee_name'] ?? table['waiter_name'];

                    Color statusColor = Colors.green;
                    if (status == 'Occupied') statusColor = Colors.red.shade600;
                    if (status == 'Billed') statusColor = Colors.amber.shade700;
                    if (status == 'Reserved') statusColor = Colors.purple.shade600;

                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: statusColor, width: 2),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _openTableOrder(table),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Icon(Icons.chair, size: 16, color: Colors.grey.shade600),
                                  Text('$capacity Seats', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                ],
                              ),
                              Column(
                                children: [
                                  Text(
                                    tableName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: darkSlate),
                                    textAlign: TextAlign.center,
                                  ),
                                  if (waiterName != null && waiterName.toString().isNotEmpty)
                                    Text(
                                      waiterName,
                                      style: TextStyle(fontSize: 11, color: Colors.teal.shade800, fontWeight: FontWeight.w600),
                                    ),
                                ],
                              ),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRunningOrdersTab() {
    if (_loading && _runningKots.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_runningKots.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.teal.shade200),
            const SizedBox(height: 12),
            const Text('No running unsettled orders on floor.', style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _runningKots.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, idx) {
        final kot = _runningKots[idx];
        final tableName = kot['table']?['table_name'] ?? 'Table';
        final items = kot['items'] as List? ?? [];
        final kotNo = kot['kot_no'] ?? '#KOT-${kot['id']}';
        final timeStr = kot['created_at'] != null
            ? DateFormat('HH:mm').format(DateTime.parse(kot['created_at']).toLocal())
            : '';

        double totalAmount = 0;
        for (final item in items) {
          final double q = double.tryParse(item['qty']?.toString() ?? '1') ?? 1;
          final double r = double.tryParse(item['rate']?.toString() ?? '0') ?? 0;
          totalAmount += q * r;
        }

        return Card(
          elevation: 1.5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: Colors.amber.shade100,
              child: const Icon(Icons.restaurant, color: Colors.orange),
            ),
            title: Row(
              children: [
                Text('Table: $tableName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(width: 8),
                Text('($kotNo)', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const Spacer(),
                Text(
                  CurrencyService.format(totalAmount),
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade800, fontSize: 15),
                ),
              ],
            ),
            subtitle: Text('Items: ${items.length}  •  Placed: $timeStr'),
            children: [
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    ...items.map((it) {
                      final double q = double.tryParse(it['qty']?.toString() ?? '1') ?? 1;
                      final double r = double.tryParse(it['rate']?.toString() ?? '0') ?? 0;
                      final mods = it['modifier_details'] as List? ?? [];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Text('${q.toInt()}x', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(it['item_name'] ?? '', style: const TextStyle(fontSize: 13)),
                                  if (mods.isNotEmpty)
                                    Text('Mods: ${mods.join(", ")}', style: const TextStyle(fontSize: 11, color: Colors.teal)),
                                ],
                              ),
                            ),
                            Text(CurrencyService.format(q * r), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(foregroundColor: primaryTeal),
                          onPressed: () => _printProformaBill(kot),
                          icon: const Icon(Icons.receipt_long, size: 16),
                          label: const Text('Print Pro-forma Bill'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: primaryTeal, foregroundColor: Colors.white),
                          onPressed: () {
                            if (kot['table'] != null) {
                              _openTableOrder(kot['table']);
                            }
                          },
                          icon: const Icon(Icons.add_shopping_cart, size: 16),
                          label: const Text('Add Items / Modify'),
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
  }

  Widget _buildSettledBillsTab() {
    if (_settledBills.isEmpty) {
      return const Center(child: Text('No settled bills loaded.'));
    }

    final query = _searchBillCtrl.text.trim().toLowerCase();
    final filtered = _settledBills.where((b) {
      final billNo = (b['bill_no'] ?? '').toString().toLowerCase();
      final table = (b['table_name'] ?? '').toString().toLowerCase();
      final cashier = (b['created_by'] ?? b['cashier_name'] ?? '').toString().toLowerCase();
      return query.isEmpty || billNo.contains(query) || table.contains(query) || cashier.contains(query);
    }).toList();

    return Column(
      children: [
        // Search bar
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.grey.shade100,
          child: TextField(
            controller: _searchBillCtrl,
            decoration: InputDecoration(
              hintText: 'Search Settled Bill / Table / Cashier...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),

        // Bills List
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('No matching settled bills.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, idx) {
                    final b = filtered[idx];
                    final double netAmount = (b['net_amount'] as num?)?.toDouble() ?? 0.0;
                    final String billNo = b['bill_no'] ?? '#BILL';
                    final String payMode = b['pay_mode'] ?? b['payment_mode'] ?? 'CASH';
                    final String dateStr = b['bill_date'] ?? b['created_at'] ?? '';
                    final String table = b['table_name'] ?? '-';
                    final String cashier = b['created_by'] ?? b['cashier_name'] ?? 'Cashier';

                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE6F4EA),
                        child: Icon(Icons.check_circle, color: Colors.green),
                      ),
                      title: Row(
                        children: [
                          Text(billNo, style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          if (table != '-')
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                              child: Text('Table: $table', style: TextStyle(fontSize: 11, color: Colors.blue.shade900)),
                            ),
                          const Spacer(),
                          Text(
                            CurrencyService.format(netAmount),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        'Paid via: $payMode • Cashier: $cashier • ${dateStr.split("T").first}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
