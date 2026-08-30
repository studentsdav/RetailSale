import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../../core/api/api_client.dart';
import '../../core/printing/device_printer_routing.dart';
import '../../core/settings/local_preferences.dart';
import '../inventory/salescreen.dart';
import 'kot_builder_screen.dart';
import '../../controllers/settings/system_settings_controller.dart';

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
  final settingsCtrl = SystemSettingsController();

  @override
  void initState() {
    super.initState();
    settingsCtrl.load().then((_) {
      if (mounted) setState(() {});
    });
    _tabController = TabController(length: 2, vsync: this);
    _fetchTableKots();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

  List<dynamic> _filterActiveRunningKots(List rawKots) {
    final List<dynamic> result = [];
    for (final kot in rawKots) {
      final bool isDismissed = kot['kds_dismissed'] == true || kot['kds_dismissed'] == 1;
      if (isDismissed) {
        continue;
      }

      // If already linked to a sales header bill, ignore!
      if (kot['sales_header_id'] != null) {
        continue;
      }

      final String status = (kot['status'] ?? '').toString().toUpperCase().trim();
      // Exclude Billed, Completed, Settled, NC Cleared KOTs
      if (status == 'BILLED' ||
          status == 'COMPLETED' ||
          status == 'SETTLED' ||
          status == 'NC CLEARED' ||
          status == 'NC_CLEARED' ||
          status == 'CLOSED') {
        continue;
      }

      final List items = kot['items'] as List? ?? [];
      final List validItems = items.where((it) {
        final String itemStatus = (it['status'] ?? '').toString().toUpperCase().trim();
        return itemStatus != 'BILLED' && itemStatus != 'COMPLETED';
      }).toList();

      if (validItems.isNotEmpty) {
        final Map<String, dynamic> cleanKot = Map<String, dynamic>.from(kot);
        cleanKot['items'] = validItems;
        result.add(cleanKot);
      }
    }
    return result;
  }

  Future<void> _fetchTableKots() async {
    setState(() => isLoading = true);
    try {
      final res = await ApiClient.get('/api/restaurant/kots?table_id=${widget.tableId}&active_only=true');
      if (res['success'] == true) {
        final List raw = res['data'] ?? [];
        final filtered = _filterActiveRunningKots(raw);
        setState(() {
          activeKotsList = filtered;
        });

        // IF ALL ORDERS FOR THE TABLE ARE CANCELLED / BILLED:
        // Automatically clear table status to Available and reset guest count to 0
        if (filtered.isEmpty && widget.tableId > 0) {
          try {
            await ApiClient.put('/api/restaurant/tables/${widget.tableId}/status', {
              'status': 'Available',
              'guest_count': 0,
            });
          } catch (e) {
            debugPrint('Error auto-clearing table status when all KOTs cancelled: $e');
          }
        }
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

  Future<void> _reprintKot(Map<String, dynamic> kot) async {
    final String kotNo = (kot['kot_number'] ?? kot['kot_no'] ?? kot['id']).toString();
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
        final String jobName = 'REPRINT_KOT_${kotNo}_$locationName';

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

      await ApiClient.post('/api/restaurant/kots/${kot['id']}/reprint', {
        'is_reprint': true,
        'reprinted_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reprinted KOT Ticket #$kotNo location-wise!'),
            backgroundColor: Colors.teal.shade700,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error triggering KOT reprint: $e');
    }
  }

  Future<Uint8List> _generateKotPdfForPrint(Map<String, dynamic> kot, List<dynamic> items, String locationName) async {
    final pdf = pw.Document();
    final String tableName = widget.tableName.isNotEmpty ? widget.tableName : (kot['table']?['table_name'] ?? 'Takeaway');
    
    final rawGuest = kot['guest_count'] ?? kot['guests'] ?? kot['table']?['current_guest_count'] ?? kot['table']?['guest_count'] ?? kot['table']?['pax'];
    final parsedGuest = rawGuest != null ? int.tryParse(rawGuest.toString()) : null;
    final int guestCount = (parsedGuest != null && parsedGuest > 0) ? parsedGuest : (tableName.toLowerCase().contains('takeaway') ? 1 : 2);

    final String nowStr = DateTime.now().toString().substring(0, 16);
    final String kotNo = (kot['kot_number'] ?? kot['kot_no'] ?? '#KOT-${kot['id']}').toString();
    
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
                final String itemBrand = (item['brand'] ?? item['brand_name'] ?? item['item_brand'] ?? item['item']?['brand'] ?? (item['item'] is Map ? item['item']['brand'] : null) ?? '').toString().trim();
                final String displayName = itemBrand.isNotEmpty ? '${item['item_name'] ?? ''} ($itemBrand)' : (item['item_name'] ?? '');
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
                  pw.Text((items.fold<double>(0, (sum, i) => sum + (double.tryParse(i['quantity']?.toString() ?? i['qty']?.toString() ?? '0') ?? 0)) % 1 == 0)
                      ? items.fold<double>(0, (sum, i) => sum + (double.tryParse(i['quantity']?.toString() ?? i['qty']?.toString() ?? '0') ?? 0)).toInt().toString()
                      : items.fold<double>(0, (sum, i) => sum + (double.tryParse(i['quantity']?.toString() ?? i['qty']?.toString() ?? '0') ?? 0)).toStringAsFixed(1),
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
          if (activeKotsList.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 4.0, top: 8, bottom: 8),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.point_of_sale, size: 16),
                label: const Text('Generate Bill / Checkout', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                onPressed: () {
                  final List<int> kotIds = [];
                  final Map<dynamic, Map<String, dynamic>> grouped = {};
                  for (final kot in activeKotsList) {
                    final int kId = int.tryParse((kot['id'] ?? 0).toString()) ?? 0;
                    if (kId > 0 && !kotIds.contains(kId)) {
                      kotIds.add(kId);
                    }
                    final items = kot['items'] as List? ?? [];
                    for (final item in items) {
                      final String itemStatus = (item['status'] ?? '').toString().toUpperCase().trim();
                      if (itemStatus == 'CANCELLED' || itemStatus == 'REJECTED') continue;

                      final int itemId = int.tryParse((item['item_id'] ?? item['itemId'] ?? item['id'] ?? 0).toString()) ?? 0;
                      final String itemName = (item['item_name'] ?? item['itemName'] ?? item['name'] ?? '').toString().trim();
                      final double qty = double.tryParse((item['quantity'] ?? item['qty'] ?? 1.0).toString()) ?? 1.0;
                      final double rate = double.tryParse((item['rate'] ?? item['item_rate'] ?? item['price'] ?? 0.0).toString()) ?? 0.0;

                      final dynamic groupKey = itemId > 0 ? itemId : (itemName.isNotEmpty ? itemName : 'Item_$kId');

                      if (grouped.containsKey(groupKey)) {
                        grouped[groupKey]!['qty'] = (grouped[groupKey]!['qty'] as double) + qty;
                      } else {
                        grouped[groupKey] = {
                          'item_id': itemId,
                          'item_name': itemName,
                          'qty': qty,
                          'rate': rate,
                        };
                      }
                    }
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SaleScreen(
                        preloadedTableId: widget.tableId,
                        preloadedItems: grouped.values.toList(),
                        preloadedKotIds: kotIds,
                      ),
                    ),
                  ).then((_) => _fetchTableKots());
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0, top: 8, bottom: 8),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF7A1A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.add_shopping_cart, size: 16),
              label: const Text('Add Fresh Order', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => KotBuilderScreen(
                      table: {
                        'id': widget.tableId,
                        'table_name': widget.tableName,
                      },
                      isFreshOrder: true,
                    ),
                  ),
                ).then((_) => _fetchTableKots());
              },
            ),
          ),
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
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF7A1A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.add_shopping_cart),
                        label: const Text('Add Fresh Order / Items', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => KotBuilderScreen(
                                table: {
                                  'id': widget.tableId,
                                  'table_name': widget.tableName,
                                },
                                isFreshOrder: true,
                              ),
                            ),
                          ).then((_) => _fetchTableKots());
                        },
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

  String _formatKotStatus(String? rawStatus) {
    final s = (rawStatus ?? '').toString().trim();
    final lower = s.toLowerCase();
    if (lower == 'p' || lower == 'pending' || lower.isEmpty) return 'Pending';
    if (lower == 'billed') return 'Billed';
    if (lower == 'nc cleared' || lower == 'nc_cleared') return 'NC Cleared';
    if (lower == 'closed') return 'Closed';
    if (lower == 'cancelled') return 'Cancelled';
    if (lower == 'rejected') return 'Rejected';
    return s;
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
                        if (kot['status'] == 'Cancelled' || kot['status'] == 'Rejected') ...[
                          const SizedBox(height: 4),
                          Text(
                            '${kot['status'] == 'Rejected' ? 'REJECTED' : 'CANCELLED'}: ${kot['remarks'] ?? 'No reason provided'}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red),
                          ),
                        ],
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          _formatKotStatus(kot['status']),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: kot['status'] == 'Preparing'
                                ? Colors.blue.shade800
                                : (kot['status'] == 'Ready' ? Colors.green.shade800 : scheme.onSurface),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (kot['status'] != 'Cancelled' && kot['status'] != 'Rejected') ...[
                          IconButton(
                            icon: const Icon(Icons.print_outlined, color: Colors.teal, size: 20),
                            tooltip: 'Reprint KOT Ticket',
                            onPressed: () => _reprintKot(kot),
                          ),
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
                  final isCancelled = item['status'] == 'Cancelled' || item['status'] == 'Rejected';
                  final hasRemark = item['item_remark'] != null && item['item_remark'].toString().trim().isNotEmpty;

                  final double q = double.tryParse(item['qty'].toString()) ?? 0.0;
                  final String qtyStr = (q % 1 == 0) ? q.toInt().toString() : q.toStringAsFixed(1);

                  return ListTile(
                    dense: true,
                    title: Text(
                      _displayName(item),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        decoration: isCancelled ? TextDecoration.lineThrough : null,
                        color: isCancelled ? Colors.grey : scheme.onSurface,
                      ),
                    ),
                    subtitle: isCancelled && item['cancel_reason'] != null && item['cancel_reason'].toString().trim().isNotEmpty
                        ? Text(
                            '${item['status'] == 'Rejected' ? 'Rejected' : 'Cancelled'}: ${item['cancel_reason']}',
                            style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic),
                          )
                        : (hasRemark
                            ? Text(
                                'Remark: ${item['item_remark']}',
                                style: const TextStyle(color: Colors.orangeAccent, fontSize: 11),
                              )
                            : null),
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
        final name = _displayName(item);
        final isCancelled = item['status'] == 'Cancelled' || item['status'] == 'Rejected';
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
