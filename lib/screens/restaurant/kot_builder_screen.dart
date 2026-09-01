import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../controllers/inventory/document_sequence_controller.dart';
import '../../controllers/security/user_controller.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/config/app_config.dart';
import '../../core/printing/pdf_preview_dialog.dart';
import '../../utils/offline_database_helper.dart';
import '../../core/auth/token_storage.dart';
import '../../services/restaurant/kot_routing_service.dart';
import 'package:printing/printing.dart';
import '../../controllers/restaurant/restaurant_controller.dart';
import 'package:provider/provider.dart';
import '../../controllers/settings/system_settings_controller.dart';
import '../../core/config/app_brand.dart';
import '../../core/printing/device_printer_routing.dart';
import '../../core/settings/local_preferences.dart';

class KotBuilderScreen extends StatefulWidget {
  final Map<String, dynamic> table;
  final List<dynamic>? prefilledItems;
  final int? editKotId;
  final bool isFreshOrder;
  final bool isNcOrder;
  final String? ncDepartment;
  final String? ncGuestName;
  final bool isTakeaway;

  const KotBuilderScreen({
    super.key,
    required this.table,
    this.prefilledItems,
    this.editKotId,
    this.isFreshOrder = true,
    this.isNcOrder = false,
    this.ncDepartment,
    this.ncGuestName,
    this.isTakeaway = false,
  });

  @override
  State<KotBuilderScreen> createState() => _KotBuilderScreenState();
}

class _KotBuilderScreenState extends State<KotBuilderScreen> {
  List<dynamic> allItems = [];
  List<dynamic> filteredItems = [];
  List<dynamic> _activeSchemes = [];
  List<String> categories = ['All'];
  String selectedCategory = 'All';
  String searchQuery = '';
  bool isLoadingItems = false;

  final ScrollController _categoryScrollController = ScrollController();

  // Order Meta Bar details
  String _kotNumber = 'Fetching...';
  Timer? _clockTimer;
  DateTime _currentDateTime = DateTime.now();
  String _selectedCaptain = 'N/A';
  final List<String> _captainList = ['N/A'];

  // Cart: Map of ItemID -> Map of Cart Item details
  final Map<int, Map<String, dynamic>> _cart = {};
  final Map<int, Map<String, dynamic>> _initialActiveItems = {};
  final settingsCtrl = SystemSettingsController();

  @override
  void initState() {
    super.initState();
    settingsCtrl.load().then((_) {
      if (mounted) setState(() {});
    });
    _fetchItems();
    _checkSyncQueue();
    _loadKotSequenceNumber();
    _fetchCaptainsAndWaiters();

    // Start 1-second live clock ticker
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _currentDateTime = DateTime.now());
      }
    });

    if (widget.prefilledItems != null) {
      _prefillCartIfAny();
    } else if (widget.editKotId != null || !widget.isFreshOrder) {
      _fetchActiveKotItems();
    }
  }

  Future<void> _fetchCaptainsAndWaiters() async {
    final List<String> waiterStaff = [];
    final List<String> allStaff = [];
    try {
      final empRes = await ApiClient.get(ApiEndpoints.hrmsEmployees);
      if (empRes['data'] is List) {
        for (final emp in (empRes['data'] as List)) {
          final String name = (emp['full_name'] ?? emp['employee_name'] ?? emp['name'] ?? '${emp['first_name'] ?? ''} ${emp['last_name'] ?? ''}').toString().trim();
          final String role = (emp['role'] ?? emp['designation'] ?? emp['job_title'] ?? '').toString().toLowerCase();
          if (name.isNotEmpty && !allStaff.contains(name)) {
            allStaff.add(name);
            if (role.contains('waiter') || role.contains('captain') || role.contains('caption') || role.contains('steward') || role.contains('server')) {
              waiterStaff.add(name);
            }
          }
        }
      }
    } catch (_) {}

    try {
      final userRes = await ApiClient.get(ApiEndpoints.users);
      if (userRes['data'] is List) {
        for (final u in (userRes['data'] as List)) {
          final String name = (u['full_name'] ?? u['name'] ?? u['username'] ?? '').toString().trim();
          final String role = (u['role'] ?? u['user_type'] ?? u['designation'] ?? '').toString().toLowerCase();
          if (name.isNotEmpty && !allStaff.contains(name)) {
            allStaff.add(name);
            if (role.contains('waiter') || role.contains('captain') || role.contains('caption') || role.contains('steward') || role.contains('server')) {
              waiterStaff.add(name);
            }
          }
        }
      }
    } catch (_) {}

    // Only allow filtered waiters list; do not fallback to all users if empty
    final List<String> finalStaff = waiterStaff;

    // Check logged-in user to auto-select their name
    String? loggedInName;
    bool isWaiterLoggedIn = false;
    try {
      final currentUser = await TokenStorage.getUser();
      final String role = (currentUser?['role'] ?? '').toString().toLowerCase();
      loggedInName = (currentUser?['full_name'] ?? currentUser?['name'] ?? currentUser?['username'])?.toString().trim();
      if (role.contains('waiter') || role.contains('captain') || role.contains('server') || role.contains('steward') || role.contains('caption')) {
        isWaiterLoggedIn = true;
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _captainList.clear();
        _captainList.add('N/A');
        if (finalStaff.isNotEmpty) {
          _captainList.addAll(finalStaff);
        }
        
        // Auto-select logged-in user if present in staff list AND they are a waiter
        if (isWaiterLoggedIn && loggedInName != null && loggedInName.isNotEmpty && _captainList.contains(loggedInName)) {
          _selectedCaptain = loggedInName;
        } else {
          _selectedCaptain = _captainList.length > 1 ? _captainList[1] : 'N/A';
        }
      });
    }
  }

  Future<void> _loadKotSequenceNumber() async {
    try {
      final docCtrl = DocumentSequenceController();
      await docCtrl.load();
      final num = await docCtrl.getNextKotNo(DateTime.now());
      if (mounted) {
        setState(() {
          _kotNumber = num;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _kotNumber = "KOT-1";
        });
      }
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _categoryScrollController.dispose();
    settingsCtrl.dispose();
    super.dispose();
  }

  String _itemImageUrl(dynamic item) {
    if (item == null) return '';
    String path = '';
    if (item is Map) {
      path = (item['image_path'] ?? item['imagePath'] ?? item['image'] ?? '').toString().trim();
    } else {
      path = (item.imagePath ?? '').toString().trim();
    }
    if (path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;

    final base = AppConfig.baseUrl;
    if (base.isEmpty) return path;
    return base.endsWith('/')
        ? '$base${path.startsWith('/') ? path.substring(1) : path}'
        : '$base${path.startsWith('/') ? path : '/$path'}';
  }

  Widget _buildItemImageWidget(dynamic item, {double size = 36}) {
    if (item == null) return _fallbackImagePlaceholder(size: size);

    String rawPath = '';
    if (item is Map) {
      rawPath = (item['image_path'] ?? item['imagePath'] ?? item['image'] ?? '').toString().trim();
    } else {
      rawPath = (item.imagePath ?? '').toString().trim();
    }

    if (rawPath.isNotEmpty) {
      try {
        final file = File(rawPath);
        if (file.existsSync()) {
          return Image.file(
            file,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildNetworkOrFallbackImage(item, size: size),
          );
        }
      } catch (_) {}
    }

    return _buildNetworkOrFallbackImage(item, size: size);
  }

  Widget _buildNetworkOrFallbackImage(dynamic item, {double size = 36}) {
    final url = _itemImageUrl(item);
    if (url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallbackImagePlaceholder(size: size),
      );
    }
    return _fallbackImagePlaceholder(size: size);
  }

  Widget _fallbackImagePlaceholder({double size = 36}) {
    return Container(
      color: const Color(0xFFF1F5F9),
      child: Center(
        child: Icon(
          Icons.restaurant_menu_rounded,
          size: size,
          color: const Color(0xFF94A3B8),
        ),
      ),
    );
  }

  String _getItemDisplayName(dynamic item) {
    if (item == null) return '';
    String name = '';
    if (item is Map) {
      name = (item['item_name'] ?? item['name'] ?? '').toString().trim();
    } else {
      name = (item.itemName ?? item.name ?? '').toString().trim();
    }

    final bool showBrand = settingsCtrl.settings?.showBrandName ?? true;
    if (!showBrand) {
      return name;
    }

    String brand = '';
    if (item is Map) {
      brand = (item['brand'] ?? item['brand_name'] ?? item['brandName'] ?? '').toString().trim();
    } else {
      brand = (item.brand ?? '').toString().trim();
    }
    if (brand.isNotEmpty) {
      return '$brand - $name';
    }
    return name;
  }

  String get _displayTableName {
    final raw = widget.table['table_name'] ?? widget.table['table_no'] ?? widget.table['name'] ?? widget.table['table_id'] ?? widget.table['id'];
    if (raw == null || raw.toString().trim().isEmpty) return '1';
    final s = raw.toString().trim();
    return s.toLowerCase().startsWith('table') ? s.substring(5).trim() : s;
  }

  Future<Uint8List> _generateKot80mmPdf(PdfPageFormat format) async {
    final pdf = pw.Document();

    final String tableName = _displayTableName;
    final String floorName = widget.table['floor_name']?.toString() ?? 'Main Floor';
    final int guestCount = widget.table['current_guest_count'] ?? widget.table['pax'] ?? 2;
    final String nowStr = DateTime.now().toString().substring(0, 16);
    final String kotNo = widget.editKotId != null
        ? '#${widget.editKotId}'
        : '#KOT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    double totalQty = 0;
    final List<Map<String, dynamic>> cartItems = _cart.values.toList();
    for (final item in cartItems) {
      totalQty += double.tryParse(item['qty']?.toString() ?? '0') ?? 0.0;
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 4 * PdfPageFormat.mm),
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
                  widget.isNcOrder ? '*** NON-CHARGEABLE (NC) KOT ***' : '*** K O T ***',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                ),
              ),
              if (widget.isNcOrder) ...[
                pw.SizedBox(height: 4),
                pw.Text('DEPT: ${widget.ncDepartment ?? "General NC"}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                if (widget.ncGuestName != null && widget.ncGuestName!.isNotEmpty)
                  pw.Text('GUEST/NOTE: ${widget.ncGuestName}', style: const pw.TextStyle(fontSize: 9)),
              ],
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
                  pw.Text('Floor: $floorName', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text('KOT: $kotNo', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                ],
              ),
              pw.Text('Time: $nowStr', style: const pw.TextStyle(fontSize: 9)),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),

              pw.Row(
                children: [
                  pw.SizedBox(width: 32, child: pw.Text('QTY', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                  pw.Expanded(child: pw.Text('ITEM DESCRIPTION', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                ],
              ),
              pw.Divider(thickness: 0.5),

              ...cartItems.map((item) {
                final double q = double.tryParse(item['qty']?.toString() ?? '0') ?? 0.0;
                final String qtyStr = (q % 1 == 0) ? q.toInt().toString() : q.toStringAsFixed(1);
                final String displayName = _getItemDisplayName(item);
                final String remark = (item['item_remark'] ?? '').toString();
                final List mods = item['modifier_details'] as List? ?? [];

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
                      if (mods.isNotEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(left: 32, top: 1),
                          child: pw.Text('* Mods: ${mods.join(", ")}', style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic)),
                        ),
                    ],
                  ),
                );
              }),

              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total Items: ${cartItems.length}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  pw.Text('Total Qty: ${totalQty % 1 == 0 ? totalQty.toInt() : totalQty.toStringAsFixed(1)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text(
                  '*** FOR KITCHEN USE ONLY ***',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  void _printKot80mm(BuildContext context) {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Basket is empty! Add items to print KOT.')),
      );
      return;
    }
    showPdfPreviewDialog(
      context: context,
      name: 'KOT_Table_${widget.table['table_name']}',
      pageFormat: PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 4 * PdfPageFormat.mm),
      buildPdf: (format) => _generateKot80mmPdf(format),
    );
  }

  void _prefillCartIfAny() {
    if (widget.prefilledItems != null) {
      for (final item in widget.prefilledItems!) {
        if (item is! Map) continue;
        final String itemStat = (item['status'] ?? '').toString().toLowerCase();
        if (itemStat == 'cancelled' || itemStat == 'rejected') continue;
        int itemId = int.tryParse((item['item_id'] ?? item['itemId'] ?? item['id'] ?? 0).toString()) ?? 0;
        final String itemCode = (item['item_code'] ?? item['itemCode'] ?? item['code'] ?? '').toString().trim();
        final String itemName = (item['item_name'] ?? item['itemName'] ?? item['name'] ?? '').toString().trim();
        final double qty = double.tryParse(item['qty']?.toString() ?? item['quantity']?.toString() ?? '1.0') ?? 1.0;
        final double rate = double.tryParse(item['rate']?.toString() ?? item['item_rate']?.toString() ?? item['price']?.toString() ?? '0') ?? 0.0;
        final int kotItemId = int.tryParse((item['id'] ?? 0).toString()) ?? 0;

        dynamic matched;
        if (itemId > 0 && allItems.isNotEmpty) {
          try {
            matched = allItems.firstWhere((i) => (i is Map ? i['id'] : i.id) == itemId);
          } catch (_) {}
        }
        if (matched == null && itemCode.isNotEmpty && allItems.isNotEmpty) {
          try {
            matched = allItems.firstWhere((i) => ((i is Map ? i['item_code'] ?? i['itemCode'] : i.itemCode) ?? '').toString().toLowerCase() == itemCode.toLowerCase());
          } catch (_) {}
        }
        if (matched == null && itemName.isNotEmpty && allItems.isNotEmpty) {
          final nameLow = itemName.toLowerCase();
          try {
            matched = allItems.firstWhere((i) => ((i is Map ? i['item_name'] ?? i['itemName'] : i.itemName) ?? '').toString().toLowerCase().contains(nameLow) || nameLow.contains(((i is Map ? i['item_name'] ?? i['itemName'] : i.itemName) ?? '').toString().toLowerCase()));
          } catch (_) {}

          if (matched == null) {
            final tokens = nameLow.split(RegExp(r'\s+')).where((t) => t.length >= 3);
            for (final token in tokens) {
              try {
                matched = allItems.firstWhere((i) => ((i is Map ? i['item_name'] ?? i['itemName'] : i.itemName) ?? '').toString().toLowerCase().contains(token));
                break;
              } catch (_) {}
            }
          }
        }

        if (matched != null) {
          itemId = matched is Map ? (matched['id'] ?? itemId) : matched.id;
        }
        if (itemId <= 0) {
          itemId = DateTime.now().millisecondsSinceEpoch % 1000000;
        }

        final double resolvedRate = rate > 0
            ? rate
            : (matched != null
                ? (matched is Map ? double.tryParse((matched['retail_sale_price'] ?? matched['rate'] ?? matched['mrp'] ?? '0').toString()) ?? 0.0 : (matched.retailSalePrice > 0 ? matched.retailSalePrice : matched.rate))
                : 0.0);

        _cart[itemId] = {
          'item_id': itemId,
          'item_name': matched != null ? (matched is Map ? (matched['item_name'] ?? matched['itemName'] ?? itemName) : matched.itemName) : (itemName.isNotEmpty ? itemName : 'Item'),
          'qty': qty > 0 ? qty : 1.0,
          'original_qty': qty > 0 ? qty : 1.0,
          'item_remark': item['item_remark'] ?? '',
          'modifier_details': List<String>.from(item['modifier_details'] ?? []),
          'rate': resolvedRate,
          'location': item['location'] ?? item['station']?['station_name'] ?? 'Kitchen',
          'brand': item['brand'] ?? item['item']?['brand'] ?? '',
          'kot_item_ids': kotItemId > 0 ? <int>[kotItemId] : <int>[],
        };
        _initialActiveItems[itemId] = {
          'item_id': itemId,
          'item_name': _cart[itemId]!['item_name'],
          'qty': qty > 0 ? qty : 1.0,
          'kot_item_ids': kotItemId > 0 ? <int>[kotItemId] : <int>[],
        };
      }
    }
  }

  Future<void> _checkSyncQueue() async {
    await OfflineDatabaseHelper.instance.syncPendingKots();
  }

  Future<void> _fetchActiveKotItems() async {
    try {
      final res = await ApiClient.get('/api/restaurant/kots?active_only=true');
      if (res['success'] == true) {
        final List rawKots = res['data'] ?? [];
        final List kots = (widget.editKotId != null)
            ? rawKots.where((k) => k['id'] == widget.editKotId).toList()
            : (widget.table['id'] != null
                ? rawKots.where((k) => k['table_id'] == widget.table['id']).toList()
                : rawKots);

        setState(() {
          _initialActiveItems.clear();
          for (final kot in kots) {
            final List items = kot['items'] ?? [];
            for (final item in items) {
              final int itemId = item['item_id'];
              final double qty = double.tryParse(item['qty']?.toString() ?? '0') ?? 0.0;
              final double rate = double.tryParse(item['rate']?.toString() ?? '') ?? 0.0;
              final int kotItemId = item['id'] ?? 0;
              final String itemStat = (item['status'] ?? '').toString().toLowerCase();

              if (itemStat == 'cancelled' || itemStat == 'rejected') continue;

              if (_initialActiveItems.containsKey(itemId)) {
                _initialActiveItems[itemId]!['qty'] = _initialActiveItems[itemId]!['qty'] + qty;
                if (kotItemId > 0) (_initialActiveItems[itemId]!['kot_item_ids'] as List<int>).add(kotItemId);
              } else {
                _initialActiveItems[itemId] = {
                  'item_id': itemId,
                  'item_name': item['item_name'],
                  'qty': qty,
                  'kot_item_ids': kotItemId > 0 ? <int>[kotItemId] : <int>[],
                };
              }

              if (_cart.containsKey(itemId)) {
                _cart[itemId]!['qty'] = _cart[itemId]!['qty'] + qty;
                _cart[itemId]!['original_qty'] = _cart[itemId]!['original_qty'] + qty;
                if (kotItemId > 0) (_cart[itemId]!['kot_item_ids'] as List<int>).add(kotItemId);
              } else {
                _cart[itemId] = {
                  'item_id': itemId,
                  'item_name': item['item_name'],
                  'qty': qty,
                  'original_qty': qty,
                  'kot_item_ids': kotItemId > 0 ? <int>[kotItemId] : <int>[],
                  'item_remark': item['item_remark'] ?? '',
                  'modifier_details': List<String>.from(item['modifier_details'] ?? []),
                  'rate': rate,
                  'location': item['location'] ?? item['station']?['station_name'] ?? 'Kitchen',
                  'brand': item['item']?['brand'] ?? '',
                };
              }
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching active KOT items: $e');
    }
  }

  Future<bool> _showPinOverrideDialog(BuildContext context) async {
    String enteredPin = '';
    bool isAuthorizing = false;
    bool isSendingOtp = false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.security, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Supervisor Override'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Enter Supervisor PIN or OTP',
                      hintText: 'xxxx',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) => enteredPin = val,
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: isSendingOtp
                        ? null
                        : () async {
                            setDialogState(() => isSendingOtp = true);
                            try {
                              final msg = await context.read<UserController>().sendSupervisorOtp();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(msg), backgroundColor: Colors.teal),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to send OTP: $e'), backgroundColor: Colors.red),
                                );
                              }
                            } finally {
                              setDialogState(() => isSendingOtp = false);
                            }
                          },
                    icon: isSendingOtp
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.mark_email_unread_outlined, size: 18),
                    label: const Text('Send One-Time OTP to Supervisor Email', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isAuthorizing ? null : () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isAuthorizing
                      ? null
                      : () async {
                          if (enteredPin.trim().isEmpty) return;
                          setDialogState(() => isAuthorizing = true);
                          try {
                            final isAuthorized = await context.read<UserController>().verifySupervisorPin(enteredPin.trim());
                            if (context.mounted) {
                              if (isAuthorized) {
                                Navigator.pop(context, true);
                              } else {
                                setDialogState(() => isAuthorizing = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Invalid Security PIN or OTP! Access Denied.'), backgroundColor: Colors.red),
                                );
                              }
                            }
                          } catch (e) {
                            if (context.mounted) {
                              setDialogState(() => isAuthorizing = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Verification Error: $e'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                  child: isAuthorizing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Authorize'),
                ),
              ],
            );
          },
        );
      },
    );
    return result ?? false;
  }

  Future<void> _fetchItems() async {
    setState(() => isLoadingItems = true);
    try {
      final res = await ApiClient.get(ApiEndpoints.items);
      final List data = res['data'] ?? [];

      List schemesList = [];
      try {
        final schemesRes = await ApiClient.get('/api/sales/schemes');
        schemesList = schemesRes['data'] ?? [];
      } catch (se) {
        debugPrint('Error fetching schemes for captain: $se');
      }

      final Set<String> cats = {'All'};
      for (final item in data) {
        final cat = item['category']?.toString() ?? item['item_group']?.toString();
        if (cat != null && cat.isNotEmpty) {
          cats.add(cat);
        }
      }

      setState(() {
        allItems = data;
        filteredItems = data;
        categories = cats.toList();
        _activeSchemes = schemesList;
      });
    } catch (e) {
      debugPrint('Error loading items: $e');
    } finally {
      setState(() => isLoadingItems = false);
    }
  }

  int _minutesFromHm(String hm) {
    final parts = hm.split(':');
    if (parts.length < 2) return 0;
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  Map<String, dynamic>? _getActivePromoForItem(Map<String, dynamic> item) {
    if (_activeSchemes.isEmpty) return null;
    final now = DateTime.now();
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final todayStr = weekdays[now.weekday - 1];
    final currentMinutes = TimeOfDay.fromDateTime(now).hour * 60 + TimeOfDay.fromDateTime(now).minute;

    for (final scheme in _activeSchemes) {
      final int? schemeItemId = scheme['item_id'] != null ? int.tryParse(scheme['item_id'].toString()) : null;
      final bool isActive = scheme['is_active'] == true || scheme['is_active'] == 1 || scheme['is_active'].toString() == 'true';
      if (schemeItemId == item['id'] && scheme['scheme_scope']?.toString().toUpperCase() == 'ITEM' && isActive) {
        if (scheme['days_of_week'] != null && scheme['days_of_week'].toString().trim().isNotEmpty) {
          final allowedDays = scheme['days_of_week'].toString().split(',').map((s) => s.trim().toLowerCase()).toList();
          if (!allowedDays.contains(todayStr.toLowerCase())) continue;
        }
        if (scheme['start_time'] != null && scheme['end_time'] != null &&
            scheme['start_time'].toString().trim().isNotEmpty && scheme['end_time'].toString().trim().isNotEmpty) {
          final start = _minutesFromHm(scheme['start_time'].toString());
          final end = _minutesFromHm(scheme['end_time'].toString());
          if (currentMinutes < start || currentMinutes > end) continue;
        }
        final String discountType = scheme['discount_type']?.toString().toUpperCase() ?? '';
        if (discountType == 'SPECIAL_PRICE' || discountType == 'AMOUNT_OFF') {
          return Map<String, dynamic>.from(scheme);
        }
      }
    }
    return null;
  }

  void _applyFilter() {
    setState(() {
      filteredItems = allItems.where((item) {
        final cat = item['category']?.toString() ?? item['item_group']?.toString() ?? 'General';
        final matchesCat = selectedCategory == 'All' || cat == selectedCategory;
        final matchesSearch = item['item_name'].toString().toLowerCase().contains(searchQuery.toLowerCase()) ||
            item['item_code'].toString().toLowerCase().contains(searchQuery.toLowerCase());
        return matchesCat && matchesSearch;
      }).toList();
    });
  }

  void _addToCart(Map<String, dynamic> item) {
    final bool isStockable = item['stockable'] == true || item['stockable'] == 1 || item['stockable'].toString() == 'true';
    final double stock = double.tryParse(item['opening_balance']?.toString() ?? '0') ?? 0.0;
    
    if (isStockable && stock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item['item_name']} is currently out of stock!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final itemId = item['id'];
    setState(() {
      if (_cart.containsKey(itemId)) {
        final double currentQty = double.tryParse(_cart[itemId]!['qty'].toString()) ?? 0.0;
        if (isStockable && currentQty >= stock) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cannot add more. Only ${stock.toInt()} units available in stock.'),
              backgroundColor: Colors.orangeAccent,
            ),
          );
          return;
        }
        _cart[itemId]!['qty'] = currentQty + 1;
      } else {
        final double rawRate = double.tryParse((item['retail_sale_price'] ?? item['rate'] ?? 0.0).toString()) ?? 0.0;
        // When is_tax_inclusive=true, retail_sale_price already contains GST. Do NOT add tax again.
        final double cartRate = rawRate;

        _cart[itemId] = {
          'item_id': itemId,
          'item_name': item['item_name'],
          'qty': 1.0,
          'original_qty': 0.0,
          'kot_item_ids': <int>[],
          'item_remark': '',
          'modifier_details': <String>[],
          'rate': cartRate,
          'location': item['location'] ?? 'Kitchen',
          'brand': item['brand'] ?? item['brand_name'] ?? '',
        };
      }
    });
  }

  Future<void> _removeFromCart(int itemId) async {
    if (_cart.containsKey(itemId)) {
      final double currentQty = double.tryParse(_cart[itemId]!['qty'].toString()) ?? 0.0;
      final double originalQty = double.tryParse(_cart[itemId]!['original_qty']?.toString() ?? '0.0') ?? 0.0;

      if (currentQty <= originalQty && originalQty > 0) {
        final approved = await _showPinOverrideDialog(context);
        if (!approved) return;
      }

      setState(() {
        if (currentQty > 1) {
          _cart[itemId]!['qty'] = currentQty - 1;
        } else {
          _cart.remove(itemId);
        }
      });
    }
  }

  Future<void> _showModifiersDialog(int itemId) async {
    final cartItem = _cart[itemId]!;
    final remarkCtrl = TextEditingController(text: cartItem['item_remark']);
    List<String> selectedMods = List<String>.from(cartItem['modifier_details'] ?? []);

    final modifiersList = ['Extra Cheese', 'No Onion', 'Extra Spicy', 'Less Salt', 'Gluten Free'];

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text('Modifiers: ${cartItem['item_name']}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: remarkCtrl,
                    decoration: const InputDecoration(labelText: 'Special Preparation Remarks'),
                  ),
                  const SizedBox(height: 15),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Add-on Modifiers:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 8,
                    children: modifiersList.map((mod) {
                      final hasMod = selectedMods.contains(mod);
                      return FilterChip(
                        label: Text(mod),
                        selected: hasMod,
                        onSelected: (selected) {
                          setDialogState(() {
                            if (selected) {
                              selectedMods.add(mod);
                            } else {
                              selectedMods.remove(mod);
                            }
                          });
                        },
                      );
                    }).toList(),
                  )
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _cart[itemId]!['item_remark'] = remarkCtrl.text;
                      _cart[itemId]!['modifier_details'] = selectedMods;
                    });
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Apply Customizations'),
                )
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _dispatchKot() async {
    if (_cart.isEmpty) return;

    setState(() => isLoadingItems = true);

    try {
      if (widget.editKotId != null) {
        final modifyData = {
          'items': _cart.values.toList(),
          'modification_reason': 'Modified from running orders screen',
        };
        final res = await ApiClient.put('/api/restaurant/kots/${widget.editKotId}', modifyData);
        if (res['success'] == true && mounted) {
          try {
            final changes = res['changes'];
            if (changes != null) {
              final List addedList = changes['added'] as List? ?? [];
              final List updatedList = changes['updated'] as List? ?? [];
              final List<dynamic> printItems = [];

              for (final a in addedList) {
                final String itemName = a['item_name'] ?? '';
                Map<String, dynamic>? cartItem;
                for (final val in _cart.values) {
                  if (val['item_name'] == itemName) {
                    cartItem = val;
                    break;
                  }
                }
                if (cartItem != null) {
                  printItems.add(cartItem);
                } else {
                  printItems.add({
                    'item_name': itemName,
                    'qty': a['qty'],
                    'location': 'Kitchen',
                  });
                }
              }

              for (final u in updatedList) {
                final double oldQty = double.tryParse(u['old_qty']?.toString() ?? '0') ?? 0.0;
                final double newQty = double.tryParse(u['new_qty']?.toString() ?? '0') ?? 0.0;
                if (newQty > oldQty) {
                  final double diffQty = newQty - oldQty;
                  final String itemName = u['item_name'] ?? '';
                  Map<String, dynamic>? cartItem;
                  for (final val in _cart.values) {
                    if (val['item_name'] == itemName) {
                      cartItem = val;
                      break;
                    }
                  }
                  if (cartItem != null) {
                    final Map<String, dynamic> itemCopy = Map<String, dynamic>.from(cartItem);
                    itemCopy['qty'] = diffQty;
                    printItems.add(itemCopy);
                  } else {
                    printItems.add({
                      'item_name': itemName,
                      'qty': diffQty,
                      'location': 'Kitchen',
                    });
                  }
                }
              }

              if (printItems.isNotEmpty) {
                final restCtrl = context.read<RestaurantController>();
                final kitchenStations = restCtrl.kitchenStations;
                final printers = restCtrl.printers;

                final String parentKotNo = res['kot_no'] ?? '#KOT-${widget.editKotId}';
                final String addonKotNo = '$parentKotNo (ADDON)';

                final Map<String, dynamic> addonKot = {
                  'id': widget.editKotId,
                  'kot_no': addonKotNo,
                  'kot_number': addonKotNo,
                  'items': printItems,
                };
                await _directPrintKot(addonKot, kitchenStations, printers);
              }
            }
          } catch (e) {
            debugPrint('Error printing modified KOT addon: $e');
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('KOT successfully modified!')),
          );
          Navigator.pop(context);
        } else {
          throw Exception(res['message'] ?? 'Server rejected modification');
        }
      } else {
        final List<Map<String, dynamic>> deletedItems = [];
        final List<Map<String, dynamic>> reducedItems = [];
        final List<Map<String, dynamic>> addedItems = [];

        if (!widget.isFreshOrder) {
          // Identify deleted items
          for (final entry in _initialActiveItems.entries) {
            final itemId = entry.key;
            final initialItem = entry.value;
            final double initialQty = double.tryParse(initialItem['qty'].toString()) ?? 0.0;

            if (!_cart.containsKey(itemId)) {
              deletedItems.add(initialItem);
            } else {
              final double currentQty = double.tryParse(_cart[itemId]!['qty'].toString()) ?? 0.0;
              if (currentQty < initialQty) {
                reducedItems.add({
                  'item_id': itemId,
                  'item_name': initialItem['item_name'],
                  'qty': initialQty - currentQty,
                  'target_qty': currentQty,
                  'kot_item_ids': List<int>.from(initialItem['kot_item_ids'] ?? []),
                });
              }
            }
          }
        }

        // Process cancellations/reductions
        if (deletedItems.isNotEmpty || reducedItems.isNotEmpty) {
          final List<String> namesList = [];
          for (final d in deletedItems) {
            namesList.add(d['item_name'] ?? 'Unknown');
          }
          for (final r in reducedItems) {
            namesList.add(r['item_name'] ?? 'Unknown');
          }
          final String names = namesList.join(', ');

          final String? reason = await _showCancelReasonDialog(context, names);
          if (reason == null) {
            setState(() => isLoadingItems = false);
            return;
          }

          // Apply deletions to DB
          for (final del in deletedItems) {
            final List<int> ids = List<int>.from(del['kot_item_ids'] ?? []);
            for (final kotItemId in ids) {
              await ApiClient.put('/api/restaurant/kots/items/$kotItemId/status', {
                'status': 'Cancelled',
                'cancel_reason': reason,
              });
            }
          }

          // Apply reductions to DB
          for (final red in reducedItems) {
            final List<int> ids = List<int>.from(red['kot_item_ids'] ?? []);
            final double targetQty = red['target_qty'];
            if (ids.isNotEmpty) {
              final int firstId = ids.first;
              await ApiClient.put('/api/restaurant/kots/items/$firstId/status', {
                'qty': targetQty,
                'cancel_reason': 'Reduced quantity: $reason',
              });

              if (ids.length > 1) {
                for (int i = 1; i < ids.length; i++) {
                  await ApiClient.put('/api/restaurant/kots/items/${ids[i]}/status', {
                    'status': 'Cancelled',
                    'cancel_reason': reason,
                  });
                }
              }
            }
          }
        }

        // Compile items list to send to kitchen
        for (final it in _cart.values) {
          final int itemId = it['item_id'];
          final double qty = double.tryParse(it['qty'].toString()) ?? 0.0;

          if (!widget.isFreshOrder) {
            final double initialQty = _initialActiveItems.containsKey(itemId)
                ? (double.tryParse(_initialActiveItems[itemId]!['qty'].toString()) ?? 0.0)
                : 0.0;
            if (qty > initialQty) {
              final Map<String, dynamic> itemCopy = Map<String, dynamic>.from(it);
              itemCopy['qty'] = qty - initialQty;
              addedItems.add(itemCopy);
            }
          } else {
            addedItems.add(it);
          }
        }

        if (addedItems.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Order successfully updated!')),
          );
          Navigator.pop(context);
          return;
        }

        final kotData = {
          'table_id': widget.isTakeaway ? null : widget.table['id'],
          'service_type': widget.isTakeaway ? 'Takeaway' : 'Dine In',
          'kottype': widget.isNcOrder ? 'nc' : (widget.isTakeaway ? 'packing' : 'g'),
          'status': 'p',
          'waiter_id': widget.table['waiter_id'] ?? 1,
          'captain_id': widget.table['captain_id'] ?? 1,
          'remarks': widget.isTakeaway ? 'Takeaway Order' : 'App Order',
          'items': addedItems,
        };

        final restCtrl = Provider.of<RestaurantController>(context, listen: false);
        final kitchenStations = restCtrl.kitchenStations;
        final printers = restCtrl.printers;

        final res = await KotRoutingService.routeAndSendKot(
          mainKotPayload: kotData,
          items: addedItems,
          kitchenStations: kitchenStations,
        );

        if (res['success'] == true && mounted) {
          final kot = res['data'] ?? res;
          try {
            context.read<RestaurantController>().loadTables();
          } catch (_) {}
          await _directPrintKot(kot, kitchenStations, printers);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('KOT successfully sent to kitchen!')),
          );
          Navigator.pop(context);
        } else {
          throw Exception(res['error'] ?? 'Server rejected request');
        }
      }
    } catch (e) {
      if (widget.editKotId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to modify KOT: $e')),
        );
      } else {
        final kotData = {
          'table_id': widget.isTakeaway ? null : widget.table['id'],
          'service_type': widget.isTakeaway ? 'Takeaway' : 'Dine In',
          'waiter_id': widget.table['waiter_id'] ?? 1,
          'captain_id': widget.table['captain_id'] ?? 1,
          'remarks': widget.isTakeaway ? 'Takeaway Order' : 'App Order',
          'items': _cart.values.toList(),
        };
        final localId = await OfflineDatabaseHelper.instance.cacheKot(kotData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Offline Mode: Order queued locally (ID: $localId). Will sync automatically when network restored.'),
              backgroundColor: Colors.orange.shade800,
            ),
          );
          Navigator.pop(context);
        }
      }
    } finally {
      setState(() => isLoadingItems = false);
    }
  }

  Future<String?> _showCancelReasonDialog(BuildContext context, String itemName) async {
    String reason = '';
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Cancel / Reduce "$itemName"?'),
        content: TextField(
          decoration: const InputDecoration(
            labelText: 'Cancellation Reason',
            border: OutlineInputBorder(),
          ),
          onChanged: (val) => reason = val,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Go Back'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reason.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a reason.')),
                );
                return;
              }
              Navigator.pop(context, reason.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Confirm'),
          )
        ],
      ),
    );
  }

  String get _appBarTitle {
    if (widget.isNcOrder) {
      final dept = widget.ncDepartment ?? 'Management Guest';
      final guest = (widget.ncGuestName != null && widget.ncGuestName!.isNotEmpty) ? ' (${widget.ncGuestName})' : '';
      return 'NC Order (Complimentary) - $dept$guest';
    }
    if (widget.editKotId != null) {
      return 'Edit KOT #${widget.editKotId} - Table $_displayTableName';
    }
    if (widget.isFreshOrder) {
      return 'Add Fresh Order - Table $_displayTableName';
    }
    return 'Captain Console - Table $_displayTableName';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.table_restaurant, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _appBarTitle,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            if (widget.table['current_guest_count'] != null && widget.table['current_guest_count'] > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.people, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.table['current_guest_count']} Guests',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Menu',
            onPressed: _fetchItems,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 900;

          double cartTotal = 0;
          double cartQty = 0;
          _cart.forEach((_, item) {
            final q = double.tryParse(item['qty']?.toString() ?? '0') ?? 0.0;
            final r = double.tryParse(item['rate']?.toString() ?? '0') ?? 0.0;
            cartQty += q;
            cartTotal += q * r;
          });

          return Column(
            children: [
              _buildOrderMetaSubHeader(),
              Expanded(
                child: Row(
                  children: [
                    // 1. LEFT SIDEBAR: Categories Panel (Only on Desktop)
                    if (isDesktop)
                      Container(
                        width: 180,
                        decoration: BoxDecoration(
                          border: Border(right: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5), width: 1)),
                          color: const Color(0xFFF8FAFD),
                        ),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                          itemCount: categories.length,
                          itemBuilder: (context, idx) {
                            final cat = categories[idx];
                            final isSelected = selectedCategory == cat;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () {
                                    setState(() {
                                      selectedCategory = cat;
                                      _applyFilter();
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFFFF7A1A) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: const Color(0xFFFF7A1A).withOpacity(0.3),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              )
                                            ]
                                          : null,
                                    ),
                                    child: Text(
                                      cat,
                                      style: TextStyle(
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                        fontSize: 13,
                                        color: isSelected ? Colors.white : const Color(0xFF334155),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                    // 2. CENTER PANEL: Menu Items Grid (Full Width on Mobile/Tablet)
                    Expanded(
                      child: Column(
                        children: [
                          // Top Bar: Search Input & Category Pills Horizontal Scroll Bar
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border(bottom: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.4))),
                            ),
                            child: Column(
                              children: [
                                // Search Bar
                                TextField(
                                  decoration: InputDecoration(
                                    hintText: 'Search menu item by name, group or code...',
                                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                                    prefixIcon: const Icon(Icons.search, color: Color(0xFFFF7A1A)),
                                    suffixIcon: searchQuery.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear, size: 18),
                                            onPressed: () {
                                              setState(() {
                                                searchQuery = '';
                                                _applyFilter();
                                              });
                                            },
                                          )
                                        : null,
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFD),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Color(0xFFFF7A1A), width: 1.5),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                                  ),
                                  onChanged: (val) {
                                    searchQuery = val;
                                    _applyFilter();
                                  },
                                ),
                                const SizedBox(height: 8),

                                // Horizontal Quick Filter Chips with Scroll Arrows
                                SizedBox(
                                  height: 38,
                                  child: Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.arrow_back_ios, size: 14),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                        onPressed: () {
                                          _categoryScrollController.animateTo(
                                            (_categoryScrollController.offset - 150).clamp(0.0, _categoryScrollController.position.maxScrollExtent),
                                            duration: const Duration(milliseconds: 250),
                                            curve: Curves.easeOut,
                                          );
                                        },
                                      ),
                                      Expanded(
                                        child: ListView.separated(
                                          controller: _categoryScrollController,
                                          scrollDirection: Axis.horizontal,
                                          itemCount: categories.length,
                                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                                          itemBuilder: (context, index) {
                                            final category = categories[index];
                                            final selected = category == selectedCategory;
                                            return FilterChip(
                                              selected: selected,
                                              showCheckmark: false,
                                              label: Text(category),
                                              labelStyle: TextStyle(
                                                color: selected ? Colors.white : const Color(0xFF475569),
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12,
                                              ),
                                              selectedColor: const Color(0xFFFF7A1A),
                                              backgroundColor: const Color(0xFFF8FAFD),
                                              side: BorderSide.none,
                                              onSelected: (_) {
                                                setState(() {
                                                  selectedCategory = category;
                                                  _applyFilter();
                                                });
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.arrow_forward_ios, size: 14),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                        onPressed: () {
                                          _categoryScrollController.animateTo(
                                            (_categoryScrollController.offset + 150).clamp(0.0, _categoryScrollController.position.maxScrollExtent),
                                            duration: const Duration(milliseconds: 250),
                                            curve: Curves.easeOut,
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Item Grid View (Matching Retail Sale Screen Card UI)
                          Expanded(
                            child: isLoadingItems
                                ? const Center(
                                    child: CircularProgressIndicator(color: Color(0xFFFF7A1A)),
                                  )
                                : filteredItems.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.restaurant_menu, size: 64, color: colorScheme.outline),
                                            const SizedBox(height: 16),
                                            Text(
                                              'No items found',
                                              style: TextStyle(fontSize: 16, color: colorScheme.outline),
                                            ),
                                          ],
                                        ),
                                      )
                                    : LayoutBuilder(
                                        builder: (context, constraints) {
                                          final width = constraints.maxWidth;
                                          int crossAxisCount = 4;
                                          if (width < 480) {
                                            crossAxisCount = 2;
                                          } else if (width < 720) {
                                            crossAxisCount = 3;
                                          } else if (width < 960) {
                                            crossAxisCount = 4;
                                          } else if (width < 1200) {
                                            crossAxisCount = 5;
                                          } else {
                                            crossAxisCount = 6;
                                          }

                                          const double spacing = 12.0;
                                          final double rawWidth = width > 0 ? width : 300.0;
                                          final double cellWidth = (rawWidth - (crossAxisCount - 1) * spacing) / crossAxisCount;
                                          const double targetHeight = 160.0;
                                          final double childAspectRatio = (cellWidth <= 0 || targetHeight <= 0)
                                              ? 1.0
                                              : (cellWidth / targetHeight).clamp(0.4, 3.0);

                                          return GridView.builder(
                                            padding: const EdgeInsets.all(12),
                                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: crossAxisCount,
                                              mainAxisSpacing: spacing,
                                              crossAxisSpacing: spacing,
                                              childAspectRatio: childAspectRatio,
                                            ),
                                            itemCount: filteredItems.length,
                                            itemBuilder: (context, idx) {
                                              final item = filteredItems[idx];
                                              final bool isStockable = item['stockable'] == true ||
                                                  item['stockable'] == 1 ||
                                                  item['stockable'].toString() == 'true';
                                              final cartQty = _cart[item['id']]?['qty'] ?? 0.0;
                                              final double stock = (double.tryParse(item['opening_balance']?.toString() ?? '0') ?? 0.0) - cartQty;
                                              final bool isOutOfStock = isStockable && stock <= 0;
                                              final bool allowNegativeStock = settingsCtrl.settings?.allowNegativeStock ?? false;

                                              final double rawRate = double.tryParse((item['retail_sale_price'] ?? item['rate'] ?? 0.0).toString()) ?? 0.0;
                                              final double rate = rawRate;
                                              final isSelected = cartQty > 0;

                                              final promoScheme = _getActivePromoForItem(item);
                                              double? promoPrice;
                                              if (promoScheme != null) {
                                                if (promoScheme['discount_type'] == 'SPECIAL_PRICE') {
                                                  double basePromo = double.tryParse(promoScheme['discount_value'].toString()) ?? rawRate;
                                                  promoPrice = basePromo;
                                                } else if (promoScheme['discount_type'] == 'AMOUNT_OFF') {
                                                  double baseOff = double.tryParse(promoScheme['discount_value'].toString()) ?? 0.0;
                                                  promoPrice = rate - baseOff;
                                                }
                                              }
                                              final hasPromo = promoPrice != null && promoPrice < rate;
                                              final String displayName = _getItemDisplayName(item);

                                              return Card(
                                                margin: EdgeInsets.zero,
                                                elevation: 0,
                                                color: isSelected ? const Color(0xFFFFF8F1) : Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                  side: BorderSide(
                                                    color: isSelected ? const Color(0xFFE58A20) : const Color(0xFFE2E8F0),
                                                    width: isSelected ? 1.5 : 1.0,
                                                  ),
                                                ),
                                                child: InkWell(
                                                  borderRadius: BorderRadius.circular(12),
                                                  onTap: (isOutOfStock && !allowNegativeStock) ? null : () => _addToCart(item),
                                                  child: Stack(
                                                    children: [
                                                      Positioned(
                                                        top: 26,
                                                        right: 8,
                                                        width: 48,
                                                        height: 44,
                                                        child: ClipRRect(
                                                          borderRadius: BorderRadius.circular(8),
                                                          child: _buildItemImageWidget(item, size: 24),
                                                        ),
                                                      ),
                                                      Padding(
                                                        padding: const EdgeInsets.fromLTRB(10, 26, 58, 10),
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text(
                                                              displayName,
                                                              maxLines: 2,
                                                              overflow: TextOverflow.ellipsis,
                                                              style: const TextStyle(
                                                                color: Color(0xFF1E293B),
                                                                fontWeight: FontWeight.w700,
                                                                fontSize: 12.5,
                                                                height: 1.25,
                                                              ),
                                                            ),
                                                            const SizedBox(height: 2),
                                                            Text(
                                                              item['category']?.toString() ?? item['item_group']?.toString() ?? '',
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                              style: const TextStyle(
                                                                color: Color(0xFF64748B),
                                                                fontWeight: FontWeight.w500,
                                                                fontSize: 10.5,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      Positioned(
                                                        left: 10,
                                                        right: 10,
                                                        bottom: 10,
                                                        child: Row(
                                                          crossAxisAlignment: CrossAxisAlignment.end,
                                                          children: [
                                                            Expanded(
                                                              child: Wrap(
                                                                crossAxisAlignment: WrapCrossAlignment.center,
                                                                children: [
                                                                  if (hasPromo) ...[
                                                                    Text(
                                                                      'Rs. ${rate.toStringAsFixed(2)}',
                                                                      style: const TextStyle(
                                                                        color: Colors.grey,
                                                                        decoration: TextDecoration.lineThrough,
                                                                        fontSize: 10.5,
                                                                      ),
                                                                    ),
                                                                    const SizedBox(width: 3),
                                                                    Text(
                                                                      'Rs. ${promoPrice.toStringAsFixed(2)}',
                                                                      style: const TextStyle(
                                                                        color: Color(0xFFD67D25),
                                                                        fontWeight: FontWeight.w900,
                                                                        fontSize: 13.0,
                                                                      ),
                                                                    ),
                                                                  ] else ...[
                                                                    Text(
                                                                      'Rs. ${rate.toStringAsFixed(2)}',
                                                                      style: const TextStyle(
                                                                        color: Color(0xFFD67D25),
                                                                        fontWeight: FontWeight.w900,
                                                                        fontSize: 13.0,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ],
                                                              ),
                                                            ),
                                                            if (isOutOfStock && !allowNegativeStock)
                                                              const Text(
                                                                'Unavailable',
                                                                style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                                                              )
                                                            else if (cartQty > 0)
                                                              Container(
                                                                height: 28,
                                                                decoration: BoxDecoration(
                                                                  color: const Color(0xFFFF7A1A),
                                                                  borderRadius: BorderRadius.circular(6),
                                                                ),
                                                                child: Row(
                                                                  mainAxisSize: MainAxisSize.min,
                                                                  children: [
                                                                    InkWell(
                                                                      onTap: () => _removeFromCart(item['id']),
                                                                      child: const Padding(
                                                                        padding: EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                                                                        child: Icon(Icons.remove, size: 14, color: Colors.white),
                                                                      ),
                                                                    ),
                                                                    Text(
                                                                      '${cartQty % 1 == 0 ? cartQty.toInt() : cartQty.toStringAsFixed(1)}',
                                                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                                                    ),
                                                                    InkWell(
                                                                      onTap: () => _addToCart(item),
                                                                      child: const Padding(
                                                                        padding: EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                                                                        child: Icon(Icons.add, size: 14, color: Colors.white),
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              )
                                                            else
                                                              InkWell(
                                                                onTap: () => _addToCart(item),
                                                                child: Container(
                                                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                                                  decoration: BoxDecoration(
                                                                    color: const Color(0xFFFFF8F1),
                                                                    border: Border.all(color: const Color(0xFFFF7A1A)),
                                                                    borderRadius: BorderRadius.circular(6),
                                                                  ),
                                                                  child: const Text(
                                                                    '+ ADD',
                                                                    style: TextStyle(
                                                                      color: Color(0xFFFF7A1A),
                                                                      fontWeight: FontWeight.bold,
                                                                      fontSize: 11,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                          ],
                                                        ),
                                                      ),
                                                      if (isOutOfStock)
                                                        Positioned(
                                                          top: 6,
                                                          left: 6,
                                                          child: Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                            decoration: BoxDecoration(
                                                              color: Colors.red.shade700,
                                                              borderRadius: BorderRadius.circular(4),
                                                            ),
                                                            child: const Text(
                                                              'OUT OF STOCK',
                                                              style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                                            ),
                                                          ),
                                                        )
                                                      else if (isStockable)
                                                        Positioned(
                                                          top: 6,
                                                          left: 6,
                                                          child: Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                            decoration: BoxDecoration(
                                                              color: Colors.green.shade800,
                                                              borderRadius: BorderRadius.circular(4),
                                                            ),
                                                            child: Text(
                                                              'Stock: ${stock.toInt()}',
                                                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                                            ),
                                                          ),
                                                        ),

                                                      // Floating Qty Badge (Top Right)
                                                      if (cartQty > 0)
                                                        Positioned(
                                                          top: 6,
                                                          right: 6,
                                                          child: Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                            decoration: BoxDecoration(
                                                              color: const Color(0xFFFF7A1A),
                                                              borderRadius: BorderRadius.circular(6),
                                                              boxShadow: [
                                                                BoxShadow(
                                                                  color: Colors.black.withOpacity(0.12),
                                                                  blurRadius: 3,
                                                                  offset: const Offset(0, 1),
                                                                ),
                                                              ],
                                                            ),
                                                            child: Text(
                                                              'x${cartQty % 1 == 0 ? cartQty.toInt() : cartQty.toStringAsFixed(1)}',
                                                              style: const TextStyle(
                                                                color: Colors.white,
                                                                fontWeight: FontWeight.w800,
                                                                fontSize: 10,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                    ],
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
                    ),

                    // 3. RIGHT SIDEBAR: Order Basket Panel (Only on Desktop)
                    if (isDesktop)
                      _buildOrderBasketPanel(isBottomSheet: false),
                  ],
                ),
              ),

              // 4. BOTTOM FLOATING CART BAR (Mobile & Tablet width < 900px)
              if (!isDesktop)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E293B),
                    boxShadow: [
                      BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, -2)),
                    ],
                  ),
                  child: SafeArea(
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () => _showMobileBasketBottomSheet(context),
                          child: Row(
                            children: [
                              Badge(
                                label: Text('${_cart.length}'),
                                backgroundColor: const Color(0xFFFF7A1A),
                                child: const Icon(Icons.shopping_bag, color: Colors.white, size: 22),
                              ),
                              const SizedBox(width: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${_cart.length} Items (${cartQty % 1 == 0 ? cartQty.toInt() : cartQty.toStringAsFixed(1)} Qty)',
                                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                                  ),
                                  Text(
                                    widget.isNcOrder ? 'Rs. 0.00 (NC)' : 'Rs. ${cartTotal.toStringAsFixed(2)}',
                                    style: const TextStyle(color: Color(0xFFFF7A1A), fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.isNcOrder ? Colors.purple.shade700 : const Color(0xFFFF7A1A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: Icon(_cart.isEmpty ? Icons.shopping_basket : Icons.send, size: 18),
                          label: Text(
                            _cart.isEmpty ? 'View Basket' : 'Send to Kitchen',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          onPressed: () {
                            if (_cart.isEmpty) {
                              _showMobileBasketBottomSheet(context);
                            } else {
                              _dispatchKot();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _showMobileBasketBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              clipBehavior: Clip.antiAlias,
              child: _buildOrderBasketPanel(isBottomSheet: true, onCartUpdated: () => setModalState(() {})),
            );
          },
        );
      },
    );
  }

  Widget _buildOrderBasketPanel({bool isBottomSheet = false, VoidCallback? onCartUpdated}) {
    return Container(
      width: isBottomSheet ? double.infinity : 340,
      decoration: BoxDecoration(
        border: isBottomSheet ? null : const Border(left: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
        color: const Color(0xFFF8FAFD),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Banner (Slate Gradient Header)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF334155)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Order Basket',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF7A1A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_cart.length} Items',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (isBottomSheet) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Basket Items List
          Expanded(
            child: _cart.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_basket_outlined, size: 56, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text(
                          'Basket is Empty',
                          style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Select items from menu to start KOT',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _cart.length,
                    itemBuilder: (context, index) {
                      final key = _cart.keys.elementAt(index);
                      final item = _cart[key]!;
                      final double qty = double.tryParse(item['qty']?.toString() ?? '0') ?? 0.0;
                      final double rate = double.tryParse(item['rate']?.toString() ?? '0') ?? 0.0;
                      final double total = qty * rate;
                      final String displayName = _getItemDisplayName(item);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Item Title & Remove Action
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    displayName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    _removeFromCart(key);
                                    onCartUpdated?.call();
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.all(2.0),
                                    child: Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),

                            // Rate Breakdown & Subtotal
                            Row(
                              children: [
                                Text(
                                  'Rs. ${rate.toStringAsFixed(2)} x ${qty % 1 == 0 ? qty.toInt() : qty.toStringAsFixed(1)}',
                                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                                const Spacer(),
                                Text(
                                  'Rs. ${total.toStringAsFixed(2)}',
                                  style: const TextStyle(color: Color(0xFFD67D25), fontSize: 13, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),

                            // Remarks & Modifiers Pills
                            if (item['item_remark'].toString().isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(top: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.edit_note, size: 13, color: Color(0xFFDC2626)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Note: ${item['item_remark']}',
                                      style: const TextStyle(color: Color(0xFFDC2626), fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            if (item['modifier_details'] != null && (item['modifier_details'] as List).isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(top: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.tune, size: 13, color: Color(0xFF2563EB)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Mods: ${(item['modifier_details'] as List).join(", ")}',
                                      style: const TextStyle(color: Color(0xFF2563EB), fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),

                            const SizedBox(height: 8),

                            // Customize & Stepper Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  icon: const Icon(Icons.tune, size: 14, color: Color(0xFFFF7A1A)),
                                  label: const Text(
                                    'Customize',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFFFF7A1A)),
                                  ),
                                  onPressed: () async {
                                    await _showModifiersDialog(key);
                                    onCartUpdated?.call();
                                  },
                                ),

                                // Cart Stepper Controls
                                Container(
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                  ),
                                  child: Row(
                                    children: [
                                      InkWell(
                                        onTap: () {
                                          _removeFromCart(key);
                                          onCartUpdated?.call();
                                        },
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          child: Icon(Icons.remove, size: 14, color: Color(0xFF334155)),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 6),
                                        child: Text(
                                          '${qty % 1 == 0 ? qty.toInt() : qty.toStringAsFixed(1)}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)),
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () {
                                          final matching = allItems.firstWhere((it) => it['id'] == key, orElse: () => null);
                                          if (matching != null) {
                                            _addToCart(matching);
                                          } else {
                                            setState(() {
                                              item['qty'] = qty + 1;
                                            });
                                          }
                                          onCartUpdated?.call();
                                        },
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          child: Icon(Icons.add, size: 14, color: Color(0xFF334155)),
                                        ),
                                      ),
                                    ],
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

          // Footer Summary & Action Panel
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 6,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Total Summary Box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFD),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: (() {
                    double totalAmount = 0;
                    double totalQty = 0;
                    _cart.forEach((_, item) {
                      final q = double.tryParse(item['qty']?.toString() ?? '0') ?? 0.0;
                      final r = double.tryParse(item['rate']?.toString() ?? '0') ?? 0.0;
                      totalQty += q;
                      totalAmount += q * r;
                    });
                    return Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_cart.length} Items (${totalQty % 1 == 0 ? totalQty.toInt() : totalQty.toStringAsFixed(1)} Qty)',
                                style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  widget.isNcOrder ? 'Rs. 0.00 (NC Complimentary)' : 'Rs. ${totalAmount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: widget.isNcOrder ? Colors.purple.shade700 : const Color(0xFFD67D25),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  })(),
                ),
                const SizedBox(height: 8),

                // Send to Kitchen (KOT) Button
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.isNcOrder ? Colors.purple.shade700 : const Color(0xFFFF7A1A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 2,
                    ),
                    icon: Icon(widget.isNcOrder ? Icons.check_circle_outline : Icons.soup_kitchen, size: 20),
                    label: Text(
                      widget.isNcOrder ? 'Dispatch NC KOT (Send to Kitchen)' : 'Send to Kitchen (KOT)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    onPressed: _cart.isEmpty
                        ? null
                        : () {
                            if (isBottomSheet) Navigator.pop(context);
                            _dispatchKot();
                          },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderMetaSubHeader() {
    final String formattedDate = DateFormat('dd-MMM-yyyy hh:mm:ss a').format(_currentDateTime);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(bottom: BorderSide(color: Color(0xFF334155))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Order / KOT Number Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFF7A1A),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.receipt_long, size: 14, color: Colors.white),
                  const SizedBox(width: 5),
                  Text(
                    'Order / KOT No: $_kotNumber',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Date & Live Ticking Clock
            const Icon(Icons.access_time_rounded, size: 15, color: Colors.white70),
            const SizedBox(width: 6),
            Text(
              formattedDate,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 20),

            // Captain / Waiter Name Selection
            const Icon(Icons.person_outline, size: 16, color: Colors.white70),
            const SizedBox(width: 6),
            const Text('Captain / Waiter: ', style: TextStyle(color: Colors.white70, fontSize: 12)),
            DropdownButton<String>(
              value: _selectedCaptain,
              dropdownColor: const Color(0xFF1E293B),
              underline: const SizedBox(),
              isDense: true,
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 18),
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              items: _captainList.map((c) {
                return DropdownMenuItem<String>(
                  value: c,
                  child: Text(c, style: const TextStyle(color: Colors.white)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedCaptain = val);
                }
              },
            ),
            const SizedBox(width: 20),

            // Table Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.table_restaurant, size: 14, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    'Table $_displayTableName',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  String _resolveKotNumber(Map<String, dynamic> kot) {
    final candidate = (kot['kot_number'] ?? kot['kot_no'] ?? kot['kotNo'] ?? '').toString().trim();
    if (candidate.isNotEmpty && candidate.toLowerCase() != 'null' && !candidate.contains('null')) {
      return candidate;
    }
    if (_kotNumber.isNotEmpty && _kotNumber.toLowerCase() != 'null' && !_kotNumber.contains('null')) {
      return _kotNumber;
    }
    final idVal = (kot['id'] ?? kot['kot_id'] ?? widget.editKotId)?.toString();
    if (idVal != null && idVal.isNotEmpty && idVal.toLowerCase() != 'null') {
      return 'KOT-$idVal';
    }
    return 'KOT-1';
  }

  Future<void> _directPrintKot(Map<String, dynamic> kot, List<dynamic> kitchenStations, List<dynamic> printers) async {
    final items = kot['items'] as List? ?? [];
    if (items.isEmpty) return;

    try {
      final sysSettingsCtrl = Provider.of<SystemSettingsController>(context, listen: false);
      final sysSettings = sysSettingsCtrl.currentSettings;

      // 1. Settings Validation: Enable Physical KOT Print switch & KOT Print Mode
      if (!sysSettings.enableKotPrint || sysSettings.kotPrintMode == 'NONE') {
        debugPrint('Physical paper KOT printing is disabled in settings (enableKotPrint=${sysSettings.enableKotPrint}, mode=${sysSettings.kotPrintMode}). KOT order sent to KDS screen only.');
        return;
      }

      // 2. KOT Print Mode DIALOG / PREVIEW
      if (sysSettings.kotPrintMode == 'DIALOG') {
        final pdfBytes = await _generateKotPdfForPrint(kot, items);
        await showPdfPreviewDialog(
          context: context,
          name: 'KOT_Table_${_displayTableName}',
          pageFormat: const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 4 * PdfPageFormat.mm),
          buildPdf: (_) async => pdfBytes,
        );
        return;
      }

      // 3. Location / Station Routing
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

        // Master lookup fallback if location is missing or default
        if (rawLoc.isEmpty || rawLoc.toLowerCase() == 'kitchen') {
          final int itemId = int.tryParse((item['item_id'] ?? item['id'] ?? 0).toString()) ?? 0;
          final String itemName = (item['item_name'] ?? item['name'] ?? '').toString().trim().toLowerCase();
          
          dynamic foundMaster;
          if (itemId > 0 && allItems.isNotEmpty) {
            try {
              foundMaster = allItems.firstWhere((i) => (i is Map ? i['id'] : i.id) == itemId);
            } catch (_) {}
          }
          if (foundMaster == null && itemName.isNotEmpty && allItems.isNotEmpty) {
            try {
              foundMaster = allItems.firstWhere((i) => ((i is Map ? i['item_name'] ?? i['itemName'] : i.itemName) ?? '').toString().trim().toLowerCase() == itemName);
            } catch (_) {}
          }

          if (foundMaster != null && foundMaster is Map) {
            final masterLoc = (foundMaster['location'] ??
                    foundMaster['location_name'] ??
                    foundMaster['station_name'] ??
                    foundMaster['kitchen_location'] ??
                    foundMaster['item_location'] ??
                    '')
                .toString()
                .trim();
            if (masterLoc.isNotEmpty) {
              rawLoc = masterLoc;
            }
          }
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
          targetStation = rawLoc.isNotEmpty ? rawLoc : (configuredLocs.isNotEmpty ? configuredLocs.first : 'Kitchen');
        }

        locationGroups.putIfAbsent(targetStation, () => []).add(item);
      }

      final availablePrinters = await Printing.listPrinters();
      final String rawKotNo = _resolveKotNumber(kot);

      for (final entry in locationGroups.entries) {
        final String locationName = entry.key;
        final List<dynamic> stationItems = entry.value;

        // Resolve mapped printer via DevicePrinterRouting first
        final routings = DevicePrinterRouting.resolvePrinters(
          settings: sysSettings,
          machineId: currentMachineId,
          sectionKey: 'kots',
          location: locationName,
        );

        final pdfBytes = await _generateKotPdfForPrint(kot, stationItems, locationName: locationName);
        final String jobName = 'KOT_${rawKotNo}_$locationName';

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
              } catch (e) {
                debugPrint('Error direct printing KOT to ${matchedPrinter.name}: $e');
              }
            }
          }
        }

        // Fallback: Backend kitchen station printer configuration
        if (!printedDirectly) {
          final station = kitchenStations.firstWhere(
            (s) => (s['station_name'] ?? '').toString().toLowerCase() == locationName.toLowerCase(),
            orElse: () => null,
          );
          if (station != null && station['printer_id'] != null) {
            final int printerId = station['printer_id'];
            final printerConfig = printers.firstWhere(
              (p) => p['id'] == printerId,
              orElse: () => null,
            );
            if (printerConfig != null) {
              final String printerName = printerConfig['printer_name'] ?? '';
              if (printerName.isNotEmpty) {
                Printer? targetPrinter;
                try {
                  targetPrinter = availablePrinters.firstWhere(
                    (p) => p.name.toLowerCase() == printerName.toLowerCase(),
                  );
                } catch (_) {}

                if (targetPrinter != null) {
                  await Printing.directPrintPdf(
                    printer: targetPrinter,
                    name: jobName,
                    onLayout: (_) async => pdfBytes,
                  );
                  printedDirectly = true;
                }
              }
            }
          }
        }

        // Ultimate Fallback: System Default Printer
        if (!printedDirectly && availablePrinters.isNotEmpty) {
          try {
            await Printing.directPrintPdf(
              printer: availablePrinters.first,
              name: jobName,
              onLayout: (_) async => pdfBytes,
            );
          } catch (e) {
            debugPrint('Ultimate fallback direct print failed: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error in _directPrintKot: $e');
    }
  }

  bool _isValidBrand(String brand) {
    final b = brand.trim();
    if (b.isEmpty) return false;
    final low = b.toLowerCase();
    if (low == '-' || low == 'n/a' || low == 'na' || low == 'none' || low == 'null' || low == '0') {
      return false;
    }
    return true;
  }

  String _extractItemBrand(Map<String, dynamic> item) {
    String b = (item['brand'] ?? item['brand_name'] ?? item['item_brand'] ?? '').toString().trim();
    if (_isValidBrand(b)) return b;

    final int itemId = int.tryParse((item['item_id'] ?? item['id'] ?? 0).toString()) ?? 0;
    final String itemName = (item['item_name'] ?? item['name'] ?? '').toString().trim().toLowerCase();

    dynamic master;
    if (itemId > 0 && allItems.isNotEmpty) {
      try {
        master = allItems.firstWhere((i) => (i is Map ? i['id'] : i.id) == itemId);
      } catch (_) {}
    }
    if (master == null && itemName.isNotEmpty && allItems.isNotEmpty) {
      try {
        master = allItems.firstWhere((i) => ((i is Map ? i['item_name'] ?? i['itemName'] : i.itemName) ?? '').toString().trim().toLowerCase() == itemName);
      } catch (_) {}
    }

    if (master != null && master is Map) {
      b = (master['brand'] ?? master['brand_name'] ?? master['item_brand'] ?? '').toString().trim();
    }
    return _isValidBrand(b) ? b : '';
  }

  Future<Uint8List> _generateKotPdfForPrint(Map<String, dynamic> kot, List<dynamic> items, {String? locationName}) async {
    final pdf = pw.Document();
    final String brandName = AppBrand.companyName.trim();
    
    final String rawTableName = widget.isTakeaway ? 'Takeaway' : _displayTableName;
    final String tableName = (rawTableName.startsWith('T-') || rawTableName == 'Takeaway') ? rawTableName : 'T-$rawTableName';
    final String floorName = widget.isTakeaway ? '' : (widget.table['floor_name']?.toString() ?? 'Main Floor');
    final int guestCount = widget.isTakeaway ? 1 : (widget.table['current_guest_count'] ?? widget.table['pax'] ?? 2);
    final String nowStr = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    final String kotNo = _resolveKotNumber(kot);
    
    double totalQty = 0;
    for (final item in items) {
      totalQty += double.tryParse(item['qty']?.toString() ?? item['quantity']?.toString() ?? '0') ?? 0.0;
    }

    final String stationLabel = (locationName != null && locationName.isNotEmpty) 
        ? locationName 
        : (items.isNotEmpty ? (items.first['station_name'] ?? items.first['location'] ?? 'BAR').toString() : 'BAR');
    
    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 4 * PdfPageFormat.mm),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              if (_isValidBrand(brandName))
                pw.Center(
                  child: pw.Text(
                    brandName.toUpperCase(),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13),
                  ),
                ),
              pw.SizedBox(height: 2),
              pw.Center(
                child: pw.Text(
                  'KITCHEN ORDER TICKET',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                ),
              ),
              pw.SizedBox(height: 3),

              // Station Location Box Header
              pw.Center(
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.black, width: 1.5),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Text(
                    'STATION LOCATION: ${stationLabel.toUpperCase()}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                  ),
                ),
              ),
              pw.SizedBox(height: 3),

              pw.Center(
                child: pw.Text(
                  widget.isNcOrder ? '*** NON-CHARGEABLE (NC) KOT ***' : '*** K O T ***',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),

              // Table & Guests Row
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TABLE: $tableName', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                  pw.Text('GUESTS: $guestCount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                ],
              ),
              // Floor & KOT No Row
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  if (floorName.isNotEmpty) pw.Text('Floor: $floorName', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('KOT: $kotNo', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                ],
              ),
              pw.Text('Time: $nowStr', style: const pw.TextStyle(fontSize: 10)),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),

              // QTY ITEM DESCRIPTION Header
              pw.Row(
                children: [
                  pw.SizedBox(width: 36, child: pw.Text('QTY', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                  pw.Expanded(child: pw.Text('ITEM DESCRIPTION', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                ],
              ),
              pw.Divider(thickness: 0.8),

              // Items List
              ...items.map((item) {
                final double q = double.tryParse(item['qty']?.toString() ?? item['quantity']?.toString() ?? '0') ?? 0.0;
                final String qtyStr = (q % 1 == 0) ? q.toInt().toString() : q.toStringAsFixed(1);
                final String displayName = item['item_name'] ?? '';
                final String itemBrand = _extractItemBrand(item);
                final String remark = (item['item_remark'] ?? item['notes'] ?? '').toString();
                final List mods = item['modifier_details'] as List? ?? [];
                
                final bool showBrandSubline = itemBrand.isNotEmpty && !displayName.toLowerCase().contains(itemBrand.toLowerCase());

                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 3),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.SizedBox(
                            width: 36,
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
                      if (showBrandSubline)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(left: 36, top: 1),
                          child: pw.Text('Brand: $itemBrand', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        ),
                      if (remark.isNotEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(left: 36, top: 1),
                          child: pw.Text('* Note: $remark', style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic)),
                        ),
                      if (mods.isNotEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(left: 36, top: 1),
                          child: pw.Text('* Mods: ${mods.join(", ")}', style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic)),
                        ),
                    ],
                  ),
                );
              }),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),

              // Total Qty Row
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total Qty:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  pw.Text((totalQty % 1 == 0) ? totalQty.toInt().toString() : totalQty.toStringAsFixed(1),
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                ],
              ),
              pw.SizedBox(height: 8),

              // Cut Here Indicator Line
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
