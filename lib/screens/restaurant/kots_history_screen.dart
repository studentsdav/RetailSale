import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../../core/api/api_client.dart';
import '../../controllers/restaurant/restaurant_controller.dart';
import '../../controllers/settings/system_settings_controller.dart';

class KotsHistoryScreen extends StatefulWidget {
  const KotsHistoryScreen({super.key});

  @override
  State<KotsHistoryScreen> createState() => _KotsHistoryScreenState();
}

class _KotsHistoryScreenState extends State<KotsHistoryScreen> {
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 2));
  DateTime _toDate = DateTime.now();
  String _searchQuery = '';
  String _selectedStatus = 'All';
  String _selectedType = 'All';
  bool _loading = false;
  List<dynamic> _kots = [];
  Map<String, dynamic>? _selectedKot;
  final settingsCtrl = SystemSettingsController();

  final TextEditingController _searchCtrl = TextEditingController();

  final List<String> _statuses = ['All', 'Closed', 'Completed', 'Billed', 'Cancelled', 'Rejected', 'Preparing', 'Ready', 'Served'];
  final List<String> _types = ['All', 'Dine In', 'Takeaway', 'NC Order'];

  @override
  void initState() {
    super.initState();
    settingsCtrl.load().then((_) {
      if (mounted) setState(() {});
    });
    _loadHistoryKots();
  }

  String _displayName(Map<String, dynamic> item) {
    final String name = item['item_name'] ?? '';
    final bool showBrand = settingsCtrl.settings?.showBrandName ?? true;
    if (!showBrand) return name;

    if (item['item'] != null && item['item']['brand'] != null) {
      final String brand = item['item']['brand'].toString().trim();
      if (brand.isNotEmpty) {
        return '$brand - $name';
      }
    }
    return name;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHistoryKots() async {
    setState(() => _loading = true);
    try {
      final String fromStr = DateFormat('yyyy-MM-dd').format(_fromDate);
      final String toStr = DateFormat('yyyy-MM-dd').format(_toDate.add(const Duration(days: 1)));
      
      final res = await ApiClient.get(
        '/api/restaurant/kots?from_date=$fromStr&to_date=$toStr'
      );
      if (res['success'] == true) {
        setState(() {
          _kots = res['data'] ?? [];
          if (_selectedKot != null) {
            // Refresh selection
            final refreshed = _kots.firstWhere(
              (k) => k['id'] == _selectedKot!['id'],
              orElse: () => null,
            );
            _selectedKot = refreshed;
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading KOT history: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<dynamic> _getFilteredKots() {
    return _kots.where((kot) {
      final String kotNo = (kot['kot_number'] ?? kot['kot_no'] ?? '#KOT-${kot['id']}').toString().toLowerCase();
      final String status = (kot['status'] ?? 'Pending').toString().toLowerCase();
      final String serviceType = (kot['service_type'] ?? 'Dine In').toString().toLowerCase();

      final matchesSearch = _searchQuery.isEmpty || kotNo.contains(_searchQuery.toLowerCase());
      final matchesStatus = _selectedStatus == 'All' || status == _selectedStatus.toLowerCase();
      
      bool matchesType = true;
      if (_selectedType != 'All') {
        if (_selectedType == 'NC Order') {
          matchesType = serviceType.contains('nc');
        } else if (_selectedType == 'Takeaway') {
          matchesType = serviceType.contains('takeaway') || serviceType.contains('packing') || kot['table_id'] == null;
        } else {
          matchesType = serviceType == _selectedType.toLowerCase();
        }
      }

      return matchesSearch && matchesStatus && matchesType;
    }).toList();
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom ? _fromDate : _toDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _fromDate = picked;
      } else {
        _toDate = picked;
      }
    });
    _loadHistoryKots();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final filtered = _getFilteredKots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Past KOTs / Completed Orders list'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistoryKots,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Panel Header
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Row(
              children: [
                // Date Pickers
                OutlinedButton.icon(
                  icon: const Icon(Icons.date_range, size: 16),
                  label: Text('From: ${DateFormat('dd MMM yy').format(_fromDate)}'),
                  onPressed: () => _pickDate(isFrom: true),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.date_range, size: 16),
                  label: Text('To: ${DateFormat('dd MMM yy').format(_toDate)}'),
                  onPressed: () => _pickDate(isFrom: false),
                ),
                const SizedBox(width: 14),
                // Search field
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search KOT No...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                const SizedBox(width: 12),
                // Status Dropdown
                DropdownButton<String>(
                  value: _selectedStatus,
                  items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (val) => setState(() => _selectedStatus = val ?? 'All'),
                ),
                const SizedBox(width: 12),
                // Type Dropdown
                DropdownButton<String>(
                  value: _selectedType,
                  items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (val) => setState(() => _selectedType = val ?? 'All'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Split Pane Layout
          Expanded(
            child: Row(
              children: [
                // Left master list
                Expanded(
                  flex: 2,
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : (filtered.isEmpty
                          ? const Center(child: Text('No orders found matching filters.'))
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, idx) {
                                final kot = filtered[idx];
                                final isSelected = _selectedKot?['id'] == kot['id'];
                                final String kotNo = kot['kot_number'] ?? kot['kot_no'] ?? '#KOT-${kot['id']}';
                                final String table = kot['table']?['table_name'] ?? 'Takeaway';
                                final String serviceType = kot['service_type'] ?? 'Dine In';
                                final String status = kot['status'] ?? 'Pending';
                                final String dateStr = kot['created_time'] != null
                                    ? DateFormat('dd MMM, hh:mm a').format(DateTime.parse(kot['created_time']))
                                    : '';

                                return ListTile(
                                  selected: isSelected,
                                  selectedTileColor: Colors.blue.shade50,
                                  title: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(kotNo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                                      Text(status.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                             color: (status.toLowerCase() == 'cancelled' || status.toLowerCase() == 'rejected')
                                                 ? Colors.red
                                                 : (status.toLowerCase() == 'closed' ? Colors.grey : Colors.green.shade700),
                                          )),
                                    ],
                                  ),
                                  subtitle: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Table: $table • $serviceType', style: const TextStyle(fontSize: 12)),
                                      Text(dateStr, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    ],
                                  ),
                                  onTap: () => setState(() => _selectedKot = kot),
                                );
                              },
                            )),
                ),
                const VerticalDivider(width: 1),
                // Right detail view
                Expanded(
                  flex: 3,
                  child: _selectedKot == null
                      ? const Center(child: Text('Select an order to view detail & reprint ticket'))
                      : _buildDetailPanel(colorScheme),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailPanel(ColorScheme colorScheme) {
    final kot = _selectedKot!;
    final String kotNo = kot['kot_number'] ?? kot['kot_no'] ?? '#KOT-${kot['id']}';
    final String status = kot['status'] ?? 'Pending';
    final String table = kot['table']?['table_name'] ?? 'Takeaway';
    final String waiter = kot['waiter']?['employee_name'] ?? 'N/A';
    final String rawCaptain = kot['captain']?['employee_name'] ?? '';
    final String captain = (rawCaptain.isEmpty || rawCaptain.toLowerCase().contains('dummy')) ? 'N/A' : rawCaptain;
    final String remarks = kot['remarks'] ?? '';
    final String created = kot['created_time'] != null
        ? DateFormat('dd-MMM-yyyy, hh:mm a').format(DateTime.parse(kot['created_time']))
        : '';
    final items = kot['items'] as List? ?? [];

    return Container(
      color: const Color(0xFFF8FAFD),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(kotNo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Dispatched on $created', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.print, size: 18),
                label: const Text('Reprint KOT Ticket', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => _printKot(kot),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 10),
          // Meta details
          Row(
            children: [
              Expanded(child: _buildMetaRow('Table / Order', table)),
              Expanded(child: _buildMetaRow('Waiter / Captain', '$waiter / $captain')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildMetaRow('Status', status.toUpperCase())),
              Expanded(child: _buildMetaRow('Remarks', remarks.isEmpty ? 'None' : remarks)),
            ],
          ),
          const SizedBox(height: 20),
          if (status.toUpperCase() == 'CANCELLED' || status.toUpperCase() == 'REJECTED') ...[
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                '${status.toUpperCase()}: ${remarks.isEmpty ? "No reason provided" : remarks}',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade900, fontSize: 13),
              ),
            ),
          ],
          const Text('Order Items List', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Expanded(
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.grey.shade300, width: 0.5),
              ),
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, idx) {
                  final item = items[idx];
                   final isCancelled = item['status'] == 'Cancelled' || item['status'] == 'Rejected';
                  final double quantity = double.tryParse(item['quantity']?.toString() ?? item['qty']?.toString() ?? '1') ?? 1.0;
                  final String qtyStr = (quantity % 1 == 0) ? quantity.toInt().toString() : quantity.toStringAsFixed(1);
                  final String itemLoc = (item['location'] ?? item['station_name'] ?? 'Kitchen').toString();

                  return Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isCancelled ? Colors.red.shade50 : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${qtyStr}x',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isCancelled ? Colors.red.shade900 : Colors.blue.shade900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _displayName(item),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                decoration: isCancelled ? TextDecoration.lineThrough : null,
                                color: isCancelled ? Colors.red : null,
                              ),
                            ),
                            if (item['item_remark'] != null && item['item_remark'].toString().isNotEmpty)
                              Text('Note: ${item['item_remark']}', style: const TextStyle(fontSize: 11, color: Colors.orange, fontStyle: FontStyle.italic)),
                             if (isCancelled && item['cancel_reason'] != null && item['cancel_reason'].toString().isNotEmpty)
                               Text(
                                 '${item['status'] == 'Rejected' ? 'Rejection' : 'Cancellation'} Reason: ${item['cancel_reason']}',
                                 style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic),
                               ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.grey.shade300, width: 0.5),
                        ),
                        child: Text(
                          itemLoc,
                          style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  Future<void> _printKot(Map<String, dynamic> kot) async {
    final items = kot['items'] as List? ?? [];
    if (items.isEmpty) return;

    try {
      final restCtrl = Provider.of<RestaurantController>(context, listen: false);
      final kitchenStations = restCtrl.kitchenStations;
      final printers = restCtrl.printers;

      // Split items by station location
      final Map<String, List<dynamic>> locationGroups = {};
      for (final item in items) {
        final String loc = (item['location'] ?? item['station_name'] ?? 'Kitchen').toString().trim();
        final String key = loc.isEmpty ? 'Kitchen' : loc;
        locationGroups.putIfAbsent(key, () => []).add(item);
      }

      // Reprint station KOTs
      for (final locationName in locationGroups.keys) {
        final List<dynamic> stationItems = locationGroups[locationName]!;
        
        final station = kitchenStations.firstWhere(
          (s) => (s['station_name'] ?? '').toString().toLowerCase() == locationName.toLowerCase(),
          orElse: () => null,
        );
        
        String printerName = '';
        if (station != null && station['printer_id'] != null) {
          final pConfig = printers.firstWhere(
            (p) => p['id'] == station['printer_id'],
            orElse: () => null,
          );
          if (pConfig != null) {
            printerName = pConfig['printer_name'] ?? '';
          }
        }

        final pdfBytes = await _generateKotPdfForPrint(kot, stationItems, locationName);
        
        if (printerName.isNotEmpty) {
          final systemPrinters = await Printing.listPrinters();
          Printer? targetPrinter;
          try {
            targetPrinter = systemPrinters.firstWhere(
              (p) => p.name.toLowerCase() == printerName.toLowerCase(),
            );
          } catch (_) {
            targetPrinter = null;
          }
          if (targetPrinter != null) {
            await Printing.directPrintPdf(
              printer: targetPrinter,
              name: kot['kot_number'] ?? 'KOT_${kot['id']}',
              onLayout: (_) async => pdfBytes,
            );
            continue;
          }
        }

        // Fallback to preview print dialog
        await Printing.layoutPdf(
          name: kot['kot_number'] ?? 'KOT_${kot['id']}',
          onLayout: (_) async => pdfBytes,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error reprinting KOT: $e')),
      );
    }
  }

  Future<Uint8List> _generateKotPdfForPrint(Map<String, dynamic> kot, List<dynamic> items, String locationName) async {
    final pdf = pw.Document();
    
    final String tableName = kot['table']?['table_name'] ?? 'Takeaway';
    final int guestCount = kot['guest_count'] ?? 1;
    final String nowStr = DateTime.now().toString().substring(0, 16);
    final String kotNo = kot['kot_number'] ?? kot['kot_no'] ?? '#KOT-${kot['id']}';
    
    double totalQty = 0;
    for (final item in items) {
      totalQty += double.tryParse(item['quantity']?.toString() ?? item['qty']?.toString() ?? '0') ?? 0.0;
    }
    
    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 4 * PdfPageFormat.mm),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Center(
                child: pw.Text(
                  'KITCHEN ORDER TICKET',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  '*** REPRINT K O T ($locationName) ***',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TABLE: $tableName', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                  pw.Text('GUESTS: $guestCount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('KOT: $kotNo', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                ],
              ),
              pw.Text('Print Time: $nowStr', style: const pw.TextStyle(fontSize: 9)),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
              pw.Row(
                children: [
                  pw.SizedBox(width: 32, child: pw.Text('QTY', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                  pw.Expanded(child: pw.Text('ITEM DESCRIPTION', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                ],
              ),
              pw.Divider(thickness: 0.5),
              ...items.map((item) {
                final double q = double.tryParse(item['quantity']?.toString() ?? item['qty']?.toString() ?? '0') ?? 0.0;
                final String qtyStr = (q % 1 == 0) ? q.toInt().toString() : q.toStringAsFixed(1);
                final String displayName = _displayName(item);
                final String remark = (item['item_remark'] ?? item['notes'] ?? '').toString();
                
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 3),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.SizedBox(
                            width: 32,
                            child: pw.Text(
                              '[ $qtyStr ]',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
                            ),
                          ),
                          pw.Expanded(
                            child: pw.Text(
                              displayName,
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      if (remark.isNotEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(left: 32, top: 1),
                          child: pw.Text('* Note: $remark', style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic)),
                        ),
                    ],
                  ),
                );
              }),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total Qty:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  pw.Text((totalQty % 1 == 0) ? totalQty.toInt().toString() : totalQty.toStringAsFixed(1),
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                ],
              ),
              pw.SizedBox(height: 10),
            ],
          );
        },
      ),
    );
    return pdf.save();
  }
}
