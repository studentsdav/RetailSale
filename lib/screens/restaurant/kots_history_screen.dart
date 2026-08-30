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
import '../../core/printing/device_printer_routing.dart';
import '../../core/settings/local_preferences.dart';

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

  List<dynamic> _masterItems = [];

  @override
  void initState() {
    super.initState();
    settingsCtrl.load().then((_) {
      if (mounted) setState(() {});
    });
    _loadMasterItems();
    _loadHistoryKots();
  }

  Future<void> _loadMasterItems() async {
    try {
      final res = await ApiClient.get('/api/inventory/items');
      if (res['success'] == true && res['data'] != null) {
        if (mounted) {
          setState(() {
            _masterItems = List<dynamic>.from(res['data']);
          });
        }
      }
    } catch (_) {}
  }

  String _getItemLocation(Map<String, dynamic> item) {
    String loc = (item['location'] ?? item['station_name'] ?? item['kitchen_location'] ?? '').toString().trim();
    if (loc.isNotEmpty && loc.toLowerCase() != 'null') return loc;

    if (item['item'] != null && item['item'] is Map) {
      final itemMap = item['item'] as Map;
      loc = (itemMap['location'] ?? itemMap['station_name'] ?? itemMap['kitchen_location'] ?? '').toString().trim();
      if (loc.isNotEmpty && loc.toLowerCase() != 'null') return loc;
    }

    final int itemId = int.tryParse((item['item_id'] ?? item['id'] ?? 0).toString()) ?? 0;
    final String itemName = (item['item_name'] ?? item['name'] ?? '').toString().trim().toLowerCase();

    dynamic master;
    if (itemId > 0 && _masterItems.isNotEmpty) {
      try {
        master = _masterItems.firstWhere((i) => (i is Map ? i['id'] : i.id) == itemId);
      } catch (_) {}
    }
    if (master == null && itemName.isNotEmpty && _masterItems.isNotEmpty) {
      try {
        master = _masterItems.firstWhere((i) => ((i is Map ? i['item_name'] ?? i['itemName'] : i.itemName) ?? '').toString().trim().toLowerCase() == itemName);
      } catch (_) {}
    }

    if (master != null) {
      loc = (master is Map ? (master['location'] ?? master['station_name'] ?? master['kitchen_location'] ?? '') : (master.location ?? '')).toString().trim();
      if (loc.isNotEmpty && loc.toLowerCase() != 'null') return loc;
    }

    return 'Kitchen';
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

  String _formatDisplayStatus(String? rawStatus) {
    final s = (rawStatus ?? '').toString().trim();
    final lower = s.toLowerCase();
    if (lower == 'p' || lower == 'pending' || lower.isEmpty) return 'PENDING';
    if (lower == 'billed') return 'BILLED';
    if (lower == 'nc cleared' || lower == 'nc_cleared') return 'NC CLEARED';
    if (lower == 'closed') return 'CLOSED';
    if (lower == 'cancelled') return 'CANCELLED';
    if (lower == 'rejected') return 'REJECTED';
    return s.toUpperCase();
  }

  String _getDisplayTableName(Map<String, dynamic> kot) {
    final String kottypeLower = (kot['kottype'] ?? '').toString().toLowerCase().trim();
    final String serviceTypeLower = (kot['service_type'] ?? '').toString().toLowerCase().trim();
    final String remarksLower = (kot['remarks'] ?? '').toString().toLowerCase().trim();

    final bool isNc = kottypeLower == 'nc' || serviceTypeLower.contains('nc') || remarksLower.contains('nc');
    if (isNc) {
      return 'NC Order';
    }

    if (kot['table'] != null && kot['table']['table_name'] != null && kot['table']['table_name'].toString().trim().isNotEmpty) {
      return kot['table']['table_name'].toString();
    }

    if (kottypeLower == 'packing' || serviceTypeLower.contains('packing') || serviceTypeLower.contains('takeaway')) {
      return 'Takeaway';
    }

    return 'Takeaway';
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
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
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
                  SizedBox(
                    width: 180,
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
                                final String table = _getDisplayTableName(kot);
                                final String serviceType = kot['service_type'] ?? 'Dine In';
                                final String rawStatus = kot['status'] ?? 'Pending';
                                final String displayStatus = _formatDisplayStatus(rawStatus);
                                final String dateStr = kot['created_time'] != null
                                    ? DateFormat('dd MMM, hh:mm a').format(DateTime.parse(kot['created_time']))
                                    : '';

                                return ListTile(
                                  selected: isSelected,
                                  selectedTileColor: Colors.blue.shade50,
                                  title: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          kotNo,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(displayStatus,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: (rawStatus.toLowerCase() == 'cancelled' || rawStatus.toLowerCase() == 'rejected')
                                                ? Colors.red
                                                : (rawStatus.toLowerCase() == 'closed' ? Colors.grey : Colors.green.shade700),
                                         )),
                                    ],
                                  ),
                                  subtitle: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Table: $table • $serviceType',
                                          style: const TextStyle(fontSize: 12),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
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
    final String table = _getDisplayTableName(kot);
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(kotNo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text('Dispatched on $created', style: const TextStyle(color: Colors.grey, fontSize: 12), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.print, size: 18),
                label: const Text('Reprint', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  final String itemLoc = _getItemLocation(item);

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
      final sysSettingsCtrl = Provider.of<SystemSettingsController>(context, listen: false);
      final sysSettings = sysSettingsCtrl.currentSettings;
      final currentMachineId = await LocalPreferences.getMachineId();

      final allKotMappings = DevicePrinterRouting.getSectionMappings(sysSettings, 'kots');
      final configuredLocs = allKotMappings
          .map((m) => m.location.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      final Map<String, List<dynamic>> locationGroups = {};
      for (final item in items) {
        String rawLoc = (item['station']?['station_name'] ??
                item['station_name'] ??
                item['location'] ??
                item['item_location'] ??
                item['kitchen_location'] ??
                item['item']?['location'] ??
                (item['item'] is Map ? item['item']['location'] ?? item['item']['kitchen_location'] : null) ??
                '')
            .toString()
            .trim();

        if (rawLoc.isEmpty) {
          rawLoc = (item['item_group'] ??
                  item['category'] ??
                  item['item']?['item_group'] ??
                  item['item']?['category'] ??
                  (item['item'] is Map ? item['item']['item_group'] ?? item['item']['category'] : null) ??
                  '')
              .toString()
              .trim();
        }

        String targetStation = rawLoc;
        if (rawLoc.isNotEmpty) {
          for (final cLoc in configuredLocs) {
            if (cLoc.toLowerCase() == rawLoc.toLowerCase() ||
                rawLoc.toLowerCase().contains(cLoc.toLowerCase()) ||
                cLoc.toLowerCase().contains(rawLoc.toLowerCase())) {
              targetStation = cLoc;
              break;
            }
          }
        }

        if (targetStation.isEmpty) {
          targetStation = configuredLocs.isNotEmpty ? configuredLocs.first : 'Main Kitchen';
        }

        locationGroups.putIfAbsent(targetStation, () => []).add(item);
      }

      final availablePrinters = await Printing.listPrinters();
      final String rawKotNo = (kot['kot_number'] ?? kot['kot_no'] ?? '#KOT-${kot['id']}').toString();

      for (final entry in locationGroups.entries) {
        final String locationName = entry.key;
        final List<dynamic> stationItems = entry.value;

        final routings = DevicePrinterRouting.resolvePrinters(
          settings: sysSettings,
          machineId: currentMachineId,
          sectionKey: 'kots',
          location: locationName,
        );

        final pdfBytes = await _generateKotPdfForPrint(kot, stationItems, locationName);
        final String jobName = 'REPRINT_KOT_${rawKotNo}_$locationName';

        bool printedDirectly = false;
        if (routings.isNotEmpty) {
          for (final routing in routings) {
            final String targetPrinterName = routing.printer.trim();
            if (targetPrinterName.isEmpty) continue;

            Printer? matchedPrinter;
            try {
              matchedPrinter = availablePrinters.firstWhere(
                (p) => p.name.toLowerCase() == targetPrinterName.toLowerCase() || p.url.toLowerCase() == targetPrinterName.toLowerCase(),
              );
            } catch (_) {
              try {
                matchedPrinter = availablePrinters.firstWhere(
                  (p) => p.name.toLowerCase().contains(targetPrinterName.toLowerCase()) || targetPrinterName.toLowerCase().contains(p.name.toLowerCase()),
                );
              } catch (_) {}
            }

            if (matchedPrinter != null) {
              try {
                final int copyCount = routing.copies > 0 ? routing.copies : 1;
                for (int c = 0; c < copyCount; c++) {
                  await Printing.directPrintPdf(
                    printer: matchedPrinter,
                    name: jobName,
                    onLayout: (_) async => pdfBytes,
                  );
                }
                printedDirectly = true;
              } catch (pErr) {
                debugPrint('Direct print printer error for station "$locationName": $pErr');
              }
            }
          }
        }

        if (!printedDirectly) {
          Printer? fallbackPrinter;
          if (sysSettings.defaultPrinterName.trim().isNotEmpty) {
            try {
              fallbackPrinter = availablePrinters.firstWhere(
                (p) => p.name.toLowerCase() == sysSettings.defaultPrinterName.trim().toLowerCase(),
              );
            } catch (_) {}
          }
          fallbackPrinter ??= availablePrinters.where((p) => p.isDefault).firstOrNull ?? availablePrinters.firstOrNull;

          if (fallbackPrinter != null) {
            try {
              await Printing.directPrintPdf(
                printer: fallbackPrinter,
                name: jobName,
                onLayout: (_) async => pdfBytes,
              );
            } catch (e) {
              debugPrint('Direct print fallback error: $e');
              await Printing.layoutPdf(
                name: jobName,
                onLayout: (_) async => pdfBytes,
              );
            }
          } else {
            await Printing.layoutPdf(
              name: jobName,
              onLayout: (_) async => pdfBytes,
            );
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('KOT Reprint sent to printer!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error reprinting KOT: $e')),
        );
      }
    }
  }

  Future<Uint8List> _generateKotPdfForPrint(Map<String, dynamic> kot, List<dynamic> items, String locationName) async {
    final pdf = pw.Document();
    
    final String tableName = kot['table']?['table_name'] ?? 'Takeaway';
    
    final rawGuest = kot['guest_count'] ?? kot['guests'] ?? kot['table']?['current_guest_count'] ?? kot['table']?['guest_count'] ?? kot['table']?['pax'];
    final parsedGuest = rawGuest != null ? int.tryParse(rawGuest.toString()) : null;
    final int guestCount = (parsedGuest != null && parsedGuest > 0) ? parsedGuest : (tableName.toLowerCase().contains('takeaway') ? 1 : 2);

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
              if (locationName.isNotEmpty)
                pw.Container(
                  margin: const pw.EdgeInsets.symmetric(vertical: 3),
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.black, width: 1.5),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      'LOCATION / STATION: ${locationName.toUpperCase()}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11.5, color: PdfColors.black),
                    ),
                  ),
                ),
              pw.Center(
                child: pw.Text(
                  (kot['kottype'] == 'nc' || kot['kottype'] == 'NC')
                      ? '*** NC (NON-CHARGEABLE) REPRINT K O T ***'
                      : ((kot['kottype'] == 'packing' || (kot['service_type'] ?? '').toString().toLowerCase().contains('takeaway'))
                          ? '*** PACKING REPRINT K O T ***'
                          : '*** REPRINT K O T ***'),
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
              pw.Row(
                children: [
                  pw.Text('✂', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  pw.SizedBox(width: 4),
                  pw.Expanded(
                    child: pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
                  ),
                  pw.SizedBox(width: 4),
                  pw.Text('CUT HERE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                  pw.SizedBox(width: 4),
                  pw.Expanded(
                    child: pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
                  ),
                  pw.SizedBox(width: 4),
                  pw.Text('✂', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                ],
              ),
              pw.SizedBox(height: 6),
            ],
          );
        },
      ),
    );
    return pdf.save();
  }
}
