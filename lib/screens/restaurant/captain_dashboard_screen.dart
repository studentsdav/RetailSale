import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../controllers/restaurant/restaurant_controller.dart';
import '../../core/api/api_client.dart';
import '../inventory/salescreen.dart';
import 'kot_builder_screen.dart';
import 'running_orders_screen.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'kots_history_screen.dart';
import '../../controllers/settings/system_settings_controller.dart';
import '../../core/settings/local_preferences.dart';
import '../../core/printing/device_printer_routing.dart';

class CaptainDashboardScreen extends StatefulWidget {
  const CaptainDashboardScreen({super.key});

  @override
  State<CaptainDashboardScreen> createState() => _CaptainDashboardScreenState();
}

class _CaptainDashboardScreenState extends State<CaptainDashboardScreen> {
  int? selectedFloorId;
  int? selectedAreaId;
  Map<String, dynamic>? selectedTable;
  Map<int, List<dynamic>> activeKotItemsByTable = {};
  Timer? _refreshTimer;
  Timer? _liveKdsTickerTimer;
  bool isVisualCanvasView = true;
  bool showPackingOrders = false;
  int selectedSidebarTab = 0; // 0: Dine-In Tables, 1: Packing Orders, 2: NC Orders (No Charge)
  List<dynamic> _activeTakeawayKots = [];
  List<dynamic> _activeNcKots = [];

  @override
  void initState() {
    super.initState();
    _loadSavedViewPreference();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctrl = Provider.of<RestaurantController>(context, listen: false);
      ctrl.loadFloors();
      ctrl.loadDiningAreas();
      _refreshData();
    });

    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _refreshData();
    });

    // 1-second Live KDS Timer ticker for occupied table stopwatch cards
    _liveKdsTickerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        final ctrl = context.read<RestaurantController>();
        final hasOccupied = ctrl.tables
            .any((t) => t['status'] == 'Occupied' || t['status'] == 'Billing');
        if (hasOccupied) {
          setState(() {});
        }
      }
    });
  }

  Future<void> _loadSavedViewPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey('captain_is_visual_canvas_view')) {
        final savedVal = prefs.getBool('captain_is_visual_canvas_view');
        if (savedVal != null && mounted) {
          setState(() {
            isVisualCanvasView = savedVal;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading view preference: $e');
    }
  }

  void _updateViewPreference(bool val) async {
    setState(() => isVisualCanvasView = val);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('captain_is_visual_canvas_view', val);
    } catch (e) {
      debugPrint('Error saving view preference: $e');
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _liveKdsTickerTimer?.cancel();
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
        final List<dynamic> takeawayList = [];
        final List<dynamic> ncList = [];

        for (final kot in kots) {
          final bool isDismissed = kot['kds_dismissed'] == true || kot['kds_dismissed'] == 1;
          final tableId = kot['table_id'];
          if (isDismissed && tableId == null) {
            continue;
          }

          final String kotStatus =
              (kot['status'] ?? '').toString().toUpperCase().trim();
          if (kotStatus == 'BILLED' ||
              kotStatus == 'COMPLETED' ||
              kotStatus == 'SETTLED' ||
              kotStatus == 'NC CLEARED' ||
              kotStatus == 'NC_CLEARED' ||
              kotStatus == 'CLOSED' ||
              kotStatus == 'CANCELLED') {
            continue;
          }

          final String serviceType = (kot['service_type'] ?? '').toString().toLowerCase();
          final String kottype = (kot['kottype'] ?? '').toString().toLowerCase();
          final String kottypeLower = (kot['kottype'] ?? '').toString().toLowerCase().trim();
          final String serviceTypeLower = (kot['service_type'] ?? '').toString().toLowerCase().trim();
          final String remarksLower = (kot['remarks'] ?? '').toString().toLowerCase().trim();

          final bool isNc = kottypeLower == 'nc' || serviceTypeLower.contains('nc') || remarksLower.contains('nc');
          if (isNc) {
            ncList.add(kot);
            continue;
          }

          if ((tableId == null && !isNc) || kottypeLower == 'packing' || serviceTypeLower.contains('packing') || serviceTypeLower.contains('takeaway')) {
            takeawayList.add(kot);
            continue;
          }
          final items = kot['items'] as List? ?? [];
          if (!tempMap.containsKey(tableId)) {
            tempMap[tableId] = [];
          }
          for (final item in items) {
            final String itemStatus =
                (item['status'] ?? '').toString().toUpperCase().trim();
            if (itemStatus != 'BILLED' &&
                itemStatus != 'COMPLETED') {
              final Map<String, dynamic> itemMap =
                  Map<String, dynamic>.from(item is Map ? item : {});
              final kotTime = kot['created_at'] ??
                  kot['kot_created_at'] ??
                  kot['created_date'] ??
                  kot['updated_at'];
              if (kotTime != null) {
                itemMap['created_at'] = kotTime;
              }
              itemMap['kot_status'] = kot['status'];
              itemMap['status'] = item['status'] ?? 'Ordered';
              tempMap[tableId]!.add(itemMap);
            }
          }
        }

        if (mounted) {
          setState(() {
            activeKotItemsByTable = tempMap;
            _activeTakeawayKots = takeawayList;
            _activeNcKots = ncList;
          });

          // AUTO-CLEAR TABLES WITH ALL ORDERS CANCELLED
          // If a table is marked 'Occupied' or 'Billing', but has 0 active running KOT items,
          // automatically clear table status to 'Available' and reset guest count to 0!
          final ctrl = context.read<RestaurantController>();
          bool needsReload = false;
          for (final t in ctrl.tables) {
            final int tId = t['id'];
            final String status = (t['status'] ?? '').toString();
            final runningItems = tempMap[tId] ?? [];
            if ((status == 'Occupied' || status == 'Billing') &&
                runningItems.isEmpty) {
              ctrl.updateTableStatus(tId, 'Available', guestCount: 0);
              needsReload = true;
            }
          }
          if (needsReload) {
            ctrl.loadTables();
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading active KOTs for dashboard: $e');
    }
  }

  Widget _buildSidebarTile({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFFF7A1A) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFF7A1A).withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                      color:
                          isSelected ? Colors.white : const Color(0xFF334155),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusLegendHeader(
      BuildContext context, RestaurantController ctrl) {
    final availableCount =
        ctrl.tables.where((t) => t['status'] == 'Available').length;
    final occupiedCount =
        ctrl.tables.where((t) => t['status'] == 'Occupied').length;
    final billedCount = ctrl.tables
        .where((t) => t['status'] == 'Billed' || t['status'] == 'Billing')
        .length;
    final dirtyCount = ctrl.tables
        .where((t) =>
            t['status'] == 'Dirty' ||
            t['status'] == 'Cleaning' ||
            t['status'] == 'Needs Cleaning')
        .length;
    final reservedCount =
        ctrl.tables.where((t) => t['status'] == 'Reserved').length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Row(
              children: [
                _buildLegendDot(
                  color: Colors.teal.shade600,
                  label: 'Available',
                  count: availableCount,
                ),
                const SizedBox(width: 16),
                _buildLegendDot(
                  color: Colors.pink.shade500,
                  label: 'Occupied',
                  count: occupiedCount,
                ),
                const SizedBox(width: 16),
                _buildLegendDot(
                  color: Colors.amber.shade700,
                  label: 'Billed',
                  count: billedCount,
                ),
                const SizedBox(width: 16),
                _buildLegendDot(
                  color: const Color(0xFF334155),
                  label: 'Needs Cleaning',
                  count: dirtyCount,
                ),
                const SizedBox(width: 16),
                _buildLegendDot(
                  color: Colors.indigo.shade500,
                  label: 'Reserved',
                  count: reservedCount,
                ),
              ],
            ),
            const SizedBox(width: 16),
            // View Mode Switcher (Floor Canvas vs Grid View)
            Container(
              height: 32,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => _updateViewPreference(true),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isVisualCanvasView
                            ? const Color(0xFFFF7A1A)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.architecture,
                              size: 14,
                              color: isVisualCanvasView
                                  ? Colors.white
                                  : const Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Text(
                            'Floor Canvas',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isVisualCanvasView
                                  ? Colors.white
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => _updateViewPreference(false),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: !isVisualCanvasView
                            ? const Color(0xFFFF7A1A)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.grid_view,
                              size: 14,
                              color: !isVisualCanvasView
                                  ? Colors.white
                                  : const Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Text(
                            'Grid View',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: !isVisualCanvasView
                                  ? Colors.white
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _showStatusGuideDialog(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8F1),
                  border: Border.all(color: const Color(0xFFFF7A1A)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Color(0xFFFF7A1A)),
                    SizedBox(width: 4),
                    Text(
                      'Color Guide & Rules',
                      style: TextStyle(
                          color: Color(0xFFFF7A1A),
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, List<dynamic>> _groupTablesByArea(
      List<dynamic> tables, RestaurantController ctrl) {
    final Map<String, List<dynamic>> map = {};
    for (final t in tables) {
      final int? areaId = t['dining_area_id'] ??
          (t['dining_area'] is Map ? t['dining_area']['id'] : null);
      final areaMatch = ctrl.diningAreas
          .firstWhere((a) => a['id'] == areaId, orElse: () => null);
      String areaName = (t['dining_area'] is Map
              ? t['dining_area']['name']
              : t['dining_area_name']) ??
          areaMatch?['name'] ??
          '';

      if (areaName.isEmpty) {
        final int? floorId =
            t['floor_id'] ?? (t['floor'] is Map ? t['floor']['id'] : null);
        final floorMatch = ctrl.floors
            .firstWhere((f) => f['id'] == floorId, orElse: () => null);
        areaName = (t['floor'] is Map ? t['floor']['name'] : t['floor_name']) ??
            floorMatch?['name'] ??
            'Main Zone';
      }

      map.putIfAbsent(areaName, () => []).add(t);
    }
    return map;
  }

  Widget _buildAreaContainerCard({
    required String areaName,
    required List<dynamic> areaTables,
    required double width,
    required double height,
  }) {
    final int total = areaTables.length;
    final int occupied = areaTables
        .where((t) => t['status'] == 'Occupied' || t['status'] == 'Billing')
        .length;
    final int available =
        areaTables.where((t) => t['status'] == 'Available').length;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: const Color(0xFF64748B).withOpacity(0.4), width: 1.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Area Header Bar ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFE2E8F0),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
              border: Border(
                  bottom: BorderSide(color: Color(0xFFCBD5E1), width: 1.5)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF7A1A),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.roofing_rounded,
                      size: 15, color: Colors.white),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$areaName Zone / Area',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                      color: Color(0xFF0F172A),
                      letterSpacing: 0.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Text(
                    '$total Tables ($occupied Occupied • $available Free)',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisualFloorCanvas(
      List<dynamic> tables, RestaurantController ctrl) {
    if (tables.isEmpty) {
      return const Center(child: Text('No tables found for this filter.'));
    }

    final groupedTables = _groupTablesByArea(tables, ctrl);
    final List<String> areaKeys = groupedTables.keys.toList();

    final int areaCount = areaKeys.length;
    final int colsCount = areaCount > 1 ? 2 : 1;

    const double cardWidth = 360.0;
    const double cardHeight = 260.0;
    const double spacingX = 40.0;
    const double spacingY = 40.0;

    final List<Widget> stackChildren = [];

    double totalMaxX = 1400;
    double totalMaxY = 1200;

    for (int areaIdx = 0; areaIdx < areaKeys.length; areaIdx++) {
      final String areaName = areaKeys[areaIdx];
      final List<dynamic> areaTables = groupedTables[areaName]!;

      // Calculate table positions & tight equal-spaced bounds
      double minX = 999999;
      double minY = 999999;
      double maxX = -999999;
      double maxY = -999999;

      for (final t in areaTables) {
        final double tx = (t['x_coordinate'] ?? 120).toDouble();
        final double ty = (t['y_coordinate'] ?? 120).toDouble();
        if (tx < minX) minX = tx;
        if (ty < minY) minY = ty;
        if (tx > maxX) maxX = tx;
        if (ty > maxY) maxY = ty;
      }

      // Default slot for empty areas
      final int col = areaIdx % colsCount;
      final int row = areaIdx ~/ colsCount;
      final double defaultLeft = spacingX + (col * (cardWidth + spacingX));
      final double defaultTop = spacingY + (row * (cardHeight + spacingY));

      // 20px left margin & 50px top margin (for header)
      final double baseAreaLeft = areaTables.isEmpty ? defaultLeft : minX - 20.0;
      final double baseAreaTop = areaTables.isEmpty ? defaultTop : minY - 50.0;

      // Exact equal 20px left & right padding around table cards
      double calculatedWidth = areaTables.isEmpty ? cardWidth : max((maxX - minX) + 155.0 + 40.0, 360.0);
      double calculatedHeight = areaTables.isEmpty ? cardHeight : max((maxY - minY) + 155.0 + 70.0, 240.0);

      if (baseAreaLeft + calculatedWidth + 100 > totalMaxX) {
        totalMaxX = baseAreaLeft + calculatedWidth + 100;
      }
      if (baseAreaTop + calculatedHeight + 100 > totalMaxY) {
        totalMaxY = baseAreaTop + calculatedHeight + 100;
      }

      // Add Area Zone Background Card Container
      stackChildren.add(
        Positioned(
          left: baseAreaLeft,
          top: baseAreaTop,
          width: calculatedWidth,
          height: calculatedHeight,
          child: _buildAreaContainerCard(
            areaName: areaName,
            areaTables: areaTables,
            width: calculatedWidth,
            height: calculatedHeight,
          ),
        ),
      );

      // Add Table Cards inside this Area Zone Container
      for (int tIdx = 0; tIdx < areaTables.length; tIdx++) {
        final table = areaTables[tIdx];
        final double tx = (table['x_coordinate'] ?? 120).toDouble();
        final double ty = (table['y_coordinate'] ?? 120).toDouble();

        final String status = (table['status'] ?? 'Available').toString();
        final gradient = _getTableGradient(status);

        final bool isOccupiedOrBilling =
            status == 'Occupied' || status == 'Billing';
        final List runningItems = isOccupiedOrBilling
            ? (activeKotItemsByTable[table['id']] ?? [])
            : [];

        stackChildren.add(
          Positioned(
            left: tx,
            top: ty,
            width: 155,
            height: 155,
            child: InkWell(
              onTap: () => _handleTableTap(context, table, ctrl),
              child: Card(
                elevation: 5,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: status == 'Occupied'
                        ? Colors.pink.shade300
                        : status == 'Billed'
                            ? Colors.amber.shade400
                            : Colors.teal.shade300,
                    width: 1.5,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(gradient: gradient),
                  padding: const EdgeInsets.all(9),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(_getTableIcon(status),
                              color: Colors.white, size: 20),
                          if (isOccupiedOrBilling)
                            (() {
                              final runningTime = _getTableRunningTime(
                                  table['id'],
                                  table: table);
                              final guestCount =
                                  table['current_guest_count'] ?? 0;
                              return Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (runningTime.isNotEmpty)
                                        Container(
                                          margin:
                                              const EdgeInsets.only(right: 3),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: Colors.black38,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                                color:
                                                    _getTimerColor(runningTime)
                                                        .withOpacity(0.6)),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(Icons.timer_outlined,
                                                  color: _getTimerColor(
                                                      runningTime),
                                                  size: 10),
                                              const SizedBox(width: 2),
                                              Text(
                                                runningTime,
                                                style: TextStyle(
                                                    color: _getTimerColor(
                                                        runningTime),
                                                    fontSize: 10,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (guestCount > 0)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: Colors.black26,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.people,
                                                  color: Colors.white,
                                                  size: 10),
                                              const SizedBox(width: 2),
                                              Text(
                                                '$guestCount',
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            })(),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        table['table_name'] ?? '',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isOccupiedOrBilling) (() {
                        final kStatus = _getKitchenStatusForTable(table['id'], runningItems);
                        if (kStatus.isEmpty) return const SizedBox.shrink();
                        
                        final Color badgeColor = kStatus == 'Rejected'
                            ? Colors.red.shade600
                            : (kStatus == 'Cancelled'
                                ? Colors.grey.shade600
                                : (kStatus == 'Ready'
                                    ? Colors.green.shade600
                                    : (kStatus == 'Preparing'
                                        ? Colors.blue.shade600
                                        : (kStatus == 'Served' ? Colors.teal.shade600 : Colors.orange.shade700))));
                                    
                        return Container(
                          margin: const EdgeInsets.only(top: 4, bottom: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.white24, width: 0.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                kStatus.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      })(),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              status == 'Dirty' ||
                                      status == 'Cleaning' ||
                                      status == 'Needs Cleaning'
                                  ? 'Needs Cleaning'
                                  : status,
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.only(left: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(4),
                              border:
                                  Border.all(color: Colors.white38, width: 0.5),
                            ),
                            child: Text(
                              areaName,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (runningItems.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        const Divider(color: Colors.white24, height: 1),
                        const SizedBox(height: 3),
                        Expanded(
                          child: Text(
                            '${runningItems.length} items running',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ] else
                        const Spacer(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    return Container(
      color: const Color(0xFFF1F5F9),
      child: InteractiveViewer(
        constrained: false,
        boundaryMargin: const EdgeInsets.all(40),
        minScale: 0.5,
        maxScale: 2.5,
        child: SizedBox(
          width: totalMaxX,
          height: totalMaxY,
          child: GridPaper(
            color: Colors.blue.withOpacity(0.03),
            interval: 100,
            divisions: 2,
            subdivisions: 5,
            child: Stack(
              children: stackChildren,
            ),
          ),
        ),
      ),
    );
  }

  String _getKitchenStatusForTable(int tableId, List<dynamic> runningItems) {
    if (runningItems.isEmpty) return '';

    // â”€â”€ Step 1: Separate active items from cancelled/rejected ones â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    // A previously-cancelled KOT may appear alongside a new active KOT.
    // Do NOT let stale cancelled items shadow the new KOT status.
    bool isCancelledOrRejected(dynamic item) {
      final ks = (item['kot_status'] ?? '').toString().trim().toLowerCase();
      final st = (item['status'] ?? '').toString().trim().toLowerCase();
      return ks == 'cancelled' || ks == 'rejected' ||
             st == 'cancelled' || st == 'rejected';
    }

    final activeItems = runningItems.where((i) => !isCancelledOrRejected(i)).toList();

    bool isStatus(dynamic item, String target) {
      final ks = (item['kot_status'] ?? '').toString().trim().toLowerCase();
      final st = (item['status'] ?? '').toString().trim().toLowerCase();
      final t = target.toLowerCase();
      if (t == 'ready') return ks == 'ready' || ks == 'r' || st == 'ready' || st == 'r';
      if (t == 'preparing') return ks == 'preparing' || st == 'preparing';
      if (t == 'served') return ks == 'served' || st == 'served';
      return ks == t || st == t;
    }

    if (activeItems.isNotEmpty) {
      if (activeItems.every((i) => isStatus(i, 'Served'))) {
        return 'Served';
      }
      if (activeItems.any((i) => isStatus(i, 'Pending') || isStatus(i, 'New') || isStatus(i, 'p'))) {
        return 'Pending';
      }
      if (activeItems.any((i) => isStatus(i, 'Preparing'))) {
        return 'Preparing';
      }
      if (activeItems.any((i) => isStatus(i, 'Ready'))) {
        return 'Ready';
      }
      return 'Pending';
    }

    final allRejected = runningItems.every((i) {
      final ks = (i['kot_status'] ?? '').toString().trim().toLowerCase();
      final st = (i['status'] ?? '').toString().trim().toLowerCase();
      return ks == 'rejected' || st == 'rejected';
    });
    return allRejected ? 'Rejected' : 'Cancelled';
  }

  String _getTableRunningTime(int tableId, {Map<String, dynamic>? table}) {
    final items = activeKotItemsByTable[tableId] ?? [];

    DateTime? earliestTime;
    for (final item in items) {
      final String? timeStr = (item['created_at'] ??
              item['kot_created_at'] ??
              item['created_date'] ??
              item['updated_at'])
          ?.toString();
      if (timeStr != null && timeStr.isNotEmpty) {
        final dt = DateTime.tryParse(timeStr);
        if (dt != null) {
          if (earliestTime == null || dt.isBefore(earliestTime)) {
            earliestTime = dt;
          }
        }
      }
    }

    if (earliestTime == null && table != null) {
      final String? tableTimeStr =
          (table['updated_at'] ?? table['created_at'])?.toString();
      if (tableTimeStr != null && tableTimeStr.isNotEmpty) {
        earliestTime = DateTime.tryParse(tableTimeStr);
      }
    }

    if (earliestTime == null) return '';

    final duration = DateTime.now().difference(earliestTime);
    final int hours = duration.inHours;
    final int mins = duration.inMinutes % 60;
    final int secs = duration.inSeconds % 60;

    final String mStr = mins.toString().padLeft(2, '0');
    final String sStr = secs.toString().padLeft(2, '0');

    if (hours > 0) {
      final String hStr = hours.toString().padLeft(2, '0');
      return '$hStr:$mStr:$sStr';
    }
    return '$mStr:$sStr';
  }

  Color _getTimerColor(String timeStr) {
    if (timeStr.isEmpty) return Colors.white;
    final parts = timeStr.split(':');
    if (parts.length == 3) {
      return const Color(0xFFFF4D4D); // Vibrant Red for > 1 hour
    }
    if (parts.length == 2) {
      final mins = int.tryParse(parts[0]) ?? 0;
      if (mins >= 30) return const Color(0xFFFF4D4D); // Red alert for >30m
      if (mins >= 15)
        return const Color(0xFFFFB800); // Amber warning for 15-30m
    }
    return const Color(0xFF00E676); // Bright Emerald Green for <15m
  }

  Widget _buildLegendDot(
      {required Color color, required String label, required int count}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label ($count)',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF475569),
          ),
        ),
      ],
    );
  }

  void _showStatusGuideDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.info_rounded, color: Color(0xFFFF7A1A)),
              SizedBox(width: 8),
              Text('Table Status Guide & Rules'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGuideItem(
                color: Colors.teal.shade600,
                status: 'Available (Emerald Green)',
                description:
                    'Table is clean and open for new guests to sit and place orders.',
              ),
              const SizedBox(height: 10),
              _buildGuideItem(
                color: Colors.pink.shade500,
                status: 'Occupied (Pink / Orange)',
                description:
                    'Guests are seated. Shows active running KOT items. Tap to add fresh orders or view KOTs.',
              ),
              const SizedBox(height: 10),
              _buildGuideItem(
                color: Colors.amber.shade700,
                status: 'Billed (Amber Gold)',
                description:
                    'Bill has been printed for table. Awaiting payment settlement.',
              ),
              const SizedBox(height: 10),
              _buildGuideItem(
                color: const Color(0xFF334155),
                status: 'Needs Cleaning / Dirty (Dark Slate)',
                description:
                    'Table was recently billed/used and needs cleaning before accepting new guests.',
              ),
              const SizedBox(height: 10),
              _buildGuideItem(
                color: Colors.indigo.shade500,
                status: 'Reserved (Indigo Blue)',
                description:
                    'Table is pre-booked for upcoming guest reservation.',
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8F1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFFFF7A1A).withOpacity(0.4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lightbulb_outline,
                        color: Color(0xFFFF7A1A), size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Note: Printing a bill automatically marks the table as Needs Cleaning. Tap a Needs Cleaning table to mark it Clean & Available.',
                        style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFFB45309),
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF7A1A)),
              onPressed: () => Navigator.pop(context),
              child: const Text('Got It',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGuideItem(
      {required Color color,
      required String status,
      required String description}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 4),
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(status,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF1E293B))),
              Text(description,
                  style: const TextStyle(
                      fontSize: 11.5, color: Color(0xFF64748B))),
            ],
          ),
        ),
      ],
    );
  }

  LinearGradient _getTableGradient(String status) {
    switch (status) {
      case 'Available':
        return LinearGradient(
          colors: [Colors.teal.shade500, Colors.teal.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'Occupied':
        return LinearGradient(
          colors: [Colors.pink.shade400, Colors.orange.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'Reserved':
        return LinearGradient(
          colors: [Colors.lightBlue.shade500, Colors.indigo.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'Billing':
      case 'Billed':
        return LinearGradient(
          colors: [Colors.amber.shade600, Colors.orange.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'Dirty':
      case 'Cleaning':
      case 'Needs Cleaning':
        return const LinearGradient(
          colors: [Color(0xFF334155), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      default:
        return LinearGradient(
          colors: [Colors.grey.shade500, Colors.grey.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  IconData _getTableIcon(String status) {
    switch (status) {
      case 'Available':
        return Icons.event_seat;
      case 'Occupied':
        return Icons.table_restaurant;
      case 'Reserved':
        return Icons.bookmark;
      case 'Billing':
      case 'Billed':
        return Icons.receipt_long;
      case 'Dirty':
      case 'Cleaning':
      case 'Needs Cleaning':
        return Icons.cleaning_services_rounded;
      default:
        return Icons.table_restaurant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<RestaurantController>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final filteredTables = ctrl.tables.where((t) {
      final matchesFloor =
          selectedFloorId == null || t['floor_id'] == selectedFloorId;
      final int? tAreaId = t['dining_area_id'] ??
          (t['dining_area'] is Map ? t['dining_area']['id'] : null);
      final matchesArea = selectedAreaId == null || tAreaId == selectedAreaId;
      return matchesFloor && matchesArea;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Captain Console / Order Desk'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0, top: 8, bottom: 8),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple.shade600,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.card_giftcard, size: 16),
              label: const Text('NC Order (Complimentary)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              onPressed: () => _showNcOrderDialog(context),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ctrl.loadTables();
              ctrl.loadFloors();
              ctrl.loadDiningAreas();
              _fetchActiveKots();
            },
          )
        ],
      ),
      body: Row(
        children: [
          // Sidebar with Floor & Dining Area selections
          Container(
            width: 190,
            decoration: BoxDecoration(
              border: Border(
                  right: BorderSide(
                      color: colorScheme.outlineVariant.withOpacity(0.5))),
              color: const Color(0xFFF8FAFD),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Floors / Zones ──────────────────────────────────
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  child: Row(
                    children: [
                      Icon(Icons.layers_outlined,
                          size: 14, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text(
                        'Floors / Zones',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: ListView(
                    padding:
                        const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                    children: [
                      _buildSidebarTile(
                        title: 'All Floors',
                        icon: Icons.all_out,
                        isSelected: selectedFloorId == null,
                        onTap: () => setState(() => selectedFloorId = null),
                      ),
                      ...ctrl.floors.map((floor) {
                        final isSelected = floor['id'] == selectedFloorId;
                        return _buildSidebarTile(
                          title: floor['name'] ?? '',
                          icon: Icons.layers,
                          isSelected: isSelected,
                          onTap: () =>
                              setState(() => selectedFloorId = floor['id']),
                        );
                      }),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // ── Dining Areas Filter ──────────────────────────────
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  child: Row(
                    children: [
                      Icon(Icons.room_service_outlined,
                          size: 14, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text(
                        'Dining Areas Filter',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: ListView(
                    padding:
                        const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                    children: [
                      _buildSidebarTile(
                        title: 'Show All Areas',
                        icon: Icons.border_all_outlined,
                        isSelected: selectedAreaId == null,
                        onTap: () => setState(() => selectedAreaId = null),
                      ),
                      ...ctrl.diningAreas.map((area) {
                        final isSelected = area['id'] == selectedAreaId;
                        return _buildSidebarTile(
                          title: area['name'] ?? '',
                          icon: Icons.meeting_room_outlined,
                          isSelected: isSelected,
                          onTap: () =>
                              setState(() => selectedAreaId = area['id']),
                        );
                      }),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // ── Navigation Section ──────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  child: Row(
                    children: [
                      Icon(Icons.navigation_outlined,
                          size: 14, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text(
                        'Console Tabs',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                  child: Column(
                    children: [
                      _buildSidebarTile(
                        title: 'Dine-In Tables',
                        icon: Icons.table_restaurant,
                        isSelected: selectedSidebarTab == 0,
                        onTap: () => setState(() {
                          selectedSidebarTab = 0;
                          showPackingOrders = false;
                        }),
                      ),
                      _buildSidebarTile(
                        title: 'Packing Orders',
                        icon: Icons.backpack,
                        isSelected: selectedSidebarTab == 1,
                        onTap: () => setState(() {
                          selectedSidebarTab = 1;
                          showPackingOrders = true;
                        }),
                      ),
                      _buildSidebarTile(
                        title: 'NC Orders (No Charge)',
                        icon: Icons.card_giftcard,
                        isSelected: selectedSidebarTab == 2,
                        onTap: () => setState(() {
                          selectedSidebarTab = 2;
                          showPackingOrders = false;
                        }),
                      ),
                      _buildSidebarTile(
                        title: 'KOT History list',
                        icon: Icons.history,
                        isSelected: false,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const KotsHistoryScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Main table grid with Top Status Legend
          Expanded(
            child: Column(
              children: [
                if (selectedSidebarTab == 0) ...[
                  // Top Status Legend & Info Header Bar
                  _buildStatusLegendHeader(context, ctrl),
                ] else if (selectedSidebarTab == 1) ...[
                  // Packing Orders Header Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    color: Colors.white,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Active Packing / Takeaway Orders',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const KotBuilderScreen(
                                  table: {'id': null, 'table_name': 'Takeaway'},
                                  isFreshOrder: true,
                                  isTakeaway: true,
                                ),
                              ),
                            ).then((_) => _fetchActiveKots());
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('New Packing Order', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade800,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                ] else ...[
                  // NC Orders Header Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    color: Colors.white,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Active NC (No Charge) Orders',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _showNcOrderDialog(context),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('New NC Order', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple.shade700,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                ],

                // Table Area vs Packing Orders vs NC Orders
                Expanded(
                  child: selectedSidebarTab == 1
                      ? _buildPackingOrdersView(ctrl)
                      : selectedSidebarTab == 2
                          ? _buildNcOrdersView(ctrl)
                          : ctrl.tables.isEmpty
                              ? const Center(
                                  child: Text(
                                      'No tables configured. Please add tables in setup.'))
                          : isVisualCanvasView
                              ? _buildVisualFloorCanvas(filteredTables, ctrl)
                              : LayoutBuilder(
                                  builder: (context, constraints) {
                                final cols = (constraints.maxWidth / 220)
                                    .floor()
                                    .clamp(2, 8);
                                return GridView.builder(
                                  padding: const EdgeInsets.all(16),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: cols,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                    childAspectRatio: 0.8,
                                  ),
                                  itemCount: filteredTables.length,
                                  itemBuilder: (context, index) {
                                    final table = filteredTables[index];
                                    final String status =
                                        (table['status'] ?? 'Available')
                                            .toString();
                                    final gradient = _getTableGradient(status);

                                    final int? areaId =
                                        table['dining_area_id'] ??
                                            (table['dining_area'] is Map
                                                ? table['dining_area']['id']
                                                : null);
                                    final areaMatch = ctrl.diningAreas
                                        .firstWhere((a) => a['id'] == areaId,
                                            orElse: () => null);
                                    final String areaName =
                                        (table['dining_area'] is Map
                                                ? table['dining_area']['name']
                                                : table['dining_area_name']) ??
                                            areaMatch?['name'] ??
                                            '';

                                    final int? floorId = table['floor_id'] ??
                                        (table['floor'] is Map
                                            ? table['floor']['id']
                                            : null);
                                    final floorMatch = ctrl.floors.firstWhere(
                                        (f) => f['id'] == floorId,
                                        orElse: () => null);
                                    final String floorName =
                                        (table['floor'] is Map
                                                ? table['floor']['name']
                                                : table['floor_name']) ??
                                            floorMatch?['name'] ??
                                            '';

                                    final bool isOccupiedOrBilling =
                                        status == 'Occupied' ||
                                            status == 'Billing';
                                    final List runningItems =
                                        isOccupiedOrBilling
                                            ? (activeKotItemsByTable[
                                                    table['id']] ??
                                                [])
                                            : [];

                                    return InkWell(
                                      onTap: () =>
                                          _handleTableTap(context, table, ctrl),
                                      child: Card(
                                        elevation: 4,
                                        clipBehavior: Clip.antiAlias,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: gradient,
                                          ),
                                          padding: const EdgeInsets.all(12),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Icon(_getTableIcon(status),
                                                      color: Colors.white,
                                                      size: 24),
                                                  if (isOccupiedOrBilling)
                                                    (() {
                                                      final runningTime =
                                                          _getTableRunningTime(
                                                              table['id'],
                                                              table: table);
                                                      final guestCount = table[
                                                              'current_guest_count'] ??
                                                          0;
                                                      return Flexible(
                                                        child: FittedBox(
                                                          fit: BoxFit.scaleDown,
                                                          alignment: Alignment
                                                              .centerRight,
                                                          child: Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              if (runningTime
                                                                  .isNotEmpty)
                                                                Container(
                                                                  margin:
                                                                      const EdgeInsets
                                                                          .only(
                                                                          right:
                                                                              4),
                                                                  padding: const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          5,
                                                                      vertical:
                                                                          2),
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    color: Colors
                                                                        .black38,
                                                                    borderRadius:
                                                                        BorderRadius
                                                                            .circular(8),
                                                                    border: Border.all(
                                                                        color: _getTimerColor(runningTime)
                                                                            .withOpacity(0.6)),
                                                                  ),
                                                                  child: Row(
                                                                    children: [
                                                                      Icon(Icons.timer_outlined,
                                                                          color: _getTimerColor(
                                                                              runningTime),
                                                                          size:
                                                                              11),
                                                                      const SizedBox(
                                                                          width:
                                                                              2),
                                                                      Text(
                                                                        runningTime,
                                                                        style: TextStyle(
                                                                            color: _getTimerColor(
                                                                                runningTime),
                                                                            fontSize:
                                                                                10.5,
                                                                            fontWeight:
                                                                                FontWeight.bold),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              if (guestCount >
                                                                  0)
                                                                Container(
                                                                  padding: const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          6,
                                                                      vertical:
                                                                          2),
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    color: Colors
                                                                        .black26,
                                                                    borderRadius:
                                                                        BorderRadius
                                                                            .circular(8),
                                                                  ),
                                                                  child: Row(
                                                                    children: [
                                                                      const Icon(
                                                                          Icons
                                                                              .people,
                                                                          color: Colors
                                                                              .white,
                                                                          size:
                                                                              12),
                                                                      const SizedBox(
                                                                          width:
                                                                              2),
                                                                      Text(
                                                                        '$guestCount',
                                                                        style: const TextStyle(
                                                                            color: Colors
                                                                                .white,
                                                                            fontSize:
                                                                                11,
                                                                            fontWeight:
                                                                                FontWeight.bold),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                            ],
                                                          ),
                                                        ),
                                                      );
                                                    })(),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                table['table_name'] ?? '',
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 15,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                              // ── Kitchen Status Badge ──────────────────────
                                              if (isOccupiedOrBilling) (() {
                                                final kStatus = _getKitchenStatusForTable(table['id'], runningItems);
                                                if (kStatus.isEmpty) return const SizedBox.shrink();

                                                final Color badgeColor = kStatus == 'Rejected'
                                                    ? Colors.red.shade600
                                                    : (kStatus == 'Cancelled'
                                                        ? Colors.grey.shade600
                                                        : (kStatus == 'Ready'
                                                            ? Colors.green.shade600
                                                            : (kStatus == 'Preparing'
                                                                ? Colors.blue.shade600
                                                                : (kStatus == 'Served'
                                                                    ? Colors.teal.shade600
                                                                    : Colors.orange.shade700))));

                                                return Container(
                                                  margin: const EdgeInsets.only(top: 4, bottom: 2),
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: badgeColor,
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: Colors.white24, width: 0.5),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Container(
                                                        width: 6,
                                                        height: 6,
                                                        decoration: const BoxDecoration(
                                                          color: Colors.white,
                                                          shape: BoxShape.circle,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        kStatus.toUpperCase(),
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 8.5,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              })(),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      status == 'Dirty' ||
                                                              status ==
                                                                  'Cleaning' ||
                                                              status ==
                                                                  'Needs Cleaning'
                                                          ? 'Needs Cleaning'
                                                          : status,
                                                      style: const TextStyle(
                                                          color: Colors.white70,
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w500),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (areaName.isNotEmpty)
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 6,
                                                          vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white24,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(4),
                                                        border: Border.all(
                                                            color:
                                                                Colors.white38,
                                                            width: 0.5),
                                                      ),
                                                      child: Text(
                                                        areaName,
                                                        style: const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 9.5,
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              if (selectedFloorId == null &&
                                                  floorName.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  floorName,
                                                  style: const TextStyle(
                                                      color: Colors.white60,
                                                      fontSize: 9.5,
                                                      fontStyle:
                                                          FontStyle.italic),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                              if (runningItems.isNotEmpty) ...[
                                                const SizedBox(height: 6),
                                                const Divider(
                                                    color: Colors.white24,
                                                    height: 1),
                                                const SizedBox(height: 6),
                                                Expanded(
                                                  child: ListView.builder(
                                                    shrinkWrap: true,
                                                    physics:
                                                        const NeverScrollableScrollPhysics(),
                                                    itemCount: runningItems
                                                        .length
                                                        .clamp(0, 3),
                                                    itemBuilder:
                                                        (context, idx) {
                                                      final item =
                                                          runningItems[idx];
                                                      final double q =
                                                          double.tryParse(item[
                                                                          'qty']
                                                                      ?.toString() ??
                                                                  '0') ??
                                                              0.0;
                                                      final String qtyStr = (q %
                                                                  1 ==
                                                              0)
                                                          ? q.toInt().toString()
                                                          : q.toStringAsFixed(
                                                              1);
                                                      final String itemBrand = (item['brand'] ?? item['item']?['brand'] ?? '').toString().trim();
                                                      final String brandSuffix = itemBrand.isNotEmpty ? ' ($itemBrand)' : '';
                                                      return Text(
                                                        '$qtyStr x ${item['item_name']}$brandSuffix',
                                                        style: const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w600),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      );
                                                    },
                                                  ),
                                                ),
                                                if (runningItems.length > 3)
                                                  Text(
                                                    '+${runningItems.length - 3} more items',
                                                    style: const TextStyle(
                                                        color: Colors.white70,
                                                        fontSize: 9,
                                                        fontStyle:
                                                            FontStyle.italic),
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
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  void _handleTableTap(BuildContext context, Map<String, dynamic> table,
      RestaurantController ctrl) {
    final status = (table['status'] ?? 'Available').toString();
    if (status == 'Available') {
      _showOpenTableDialog(context, table, ctrl);
    } else if (status == 'Dirty' ||
        status == 'Cleaning' ||
        status == 'Needs Cleaning') {
      _showDirtyTableDialog(context, table, ctrl);
    } else if (status == 'Billed') {
      _showBilledTableDialog(context, table, ctrl);
    } else {
      _showTableOptionsDialog(context, table, ctrl);
    }
  }

  void _showDirtyTableDialog(BuildContext context, Map<String, dynamic> table,
      RestaurantController ctrl) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.cleaning_services_rounded,
                  color: Color(0xFFFF7A1A)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Table ${table['table_name']} (Needs Cleaning)',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: const Text(
            'This table has been billed and needs cleaning before accepting new guests.',
            style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade600,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.check_circle, size: 18),
              label: const Text('Clean & Mark Available',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () async {
                await ctrl.updateTableStatus(table['id'], 'Available',
                    guestCount: 0);
                if (context.mounted) {
                  Navigator.pop(context);
                  _refreshData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            'Table ${table['table_name']} cleaned & marked Available!')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showBilledTableDialog(BuildContext context, Map<String, dynamic> table,
      RestaurantController ctrl) {
    showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: Text('Table: ${table['table_name']} (Billed)'),
          children: [
            SimpleDialogOption(
              onPressed: () async {
                await ctrl.updateTableStatus(table['id'], 'Dirty',
                    guestCount: 0);
                if (context.mounted) {
                  Navigator.pop(context);
                  _refreshData();
                }
              },
              child: const ListTile(
                leading: Icon(Icons.cleaning_services_rounded,
                    color: Colors.blueGrey),
                title: Text('Mark Table Dirty (Needs Cleaning)'),
              ),
            ),
            SimpleDialogOption(
              onPressed: () async {
                await ctrl.updateTableStatus(table['id'], 'Available',
                    guestCount: 0);
                if (context.mounted) {
                  Navigator.pop(context);
                  _refreshData();
                }
              },
              child: const ListTile(
                leading: Icon(Icons.check_circle, color: Colors.teal),
                title: Text('Clean & Mark Available'),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showOpenTableDialog(BuildContext context, Map<String, dynamic> table,
      RestaurantController ctrl) {
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
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final guests = int.tryParse(guestsCtrl.text) ?? 2;
                await ctrl.updateTableStatus(table['id'], 'Occupied',
                    guestCount: guests);
                table['current_guest_count'] = guests;
                table['status'] = 'Occupied';
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

  void _showTableOptionsDialog(BuildContext parentContext, Map<String, dynamic> table,
      RestaurantController ctrl) {
    showDialog(
      context: parentContext,
      builder: (dialogContext) {
        return SimpleDialog(
          title: Text('Table: ${table['table_name']} (${table['status']})'),
          children: [
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(dialogContext);
                _openOrderSheet(table, isFreshOrder: true);
              },
              child: const ListTile(
                leading:
                    Icon(Icons.add_shopping_cart, color: Color(0xFFFF7A1A)),
                title: Text('Add Fresh Order / Items'),
                subtitle: Text('Start a new KOT with empty basket'),
              ),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(dialogContext);
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
                title: Text('View / Edit Running Orders (KOT)'),
                subtitle: Text('View placed orders or modify running KOT'),
              ),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(dialogContext);
                _showBillingCheckoutDialog(context, table, ctrl);
              },
              child: const ListTile(
                leading: Icon(Icons.receipt_long, color: Colors.teal),
                title: Text('Print Bill & Settle'),
              ),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(dialogContext);
                _showTransferDialog(context, table, ctrl);
              },
              child: const ListTile(
                leading: Icon(Icons.swap_horiz, color: Colors.purple),
                title: Text('Transfer Table'),
              ),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(dialogContext);
                _showMergeDialog(context, table, ctrl);
              },
              child: const ListTile(
                leading: Icon(Icons.merge, color: Colors.orange),
                title: Text('Merge / Combine Tables'),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showTransferDialog(BuildContext parentContext,
      Map<String, dynamic> sourceTable, RestaurantController ctrl) {
    int? selectedTargetTable;
    final availableTables = ctrl.tables
        .where(
            (t) => t['status'] == 'Available' && t['id'] != sourceTable['id'])
        .toList();

    showDialog(
      context: parentContext,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return AlertDialog(
              title: Text('Transfer ${sourceTable['table_name']} to...'),
              content: DropdownButtonFormField<int>(
                initialValue: selectedTargetTable,
                decoration:
                    const InputDecoration(labelText: 'Select vacant table'),
                items: availableTables.map<DropdownMenuItem<int>>((t) {
                  return DropdownMenuItem<int>(
                      value: t['id'], child: Text(t['table_name']));
                }).toList(),
                onChanged: (val) => setState(() => selectedTargetTable = val),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedTargetTable == null) return;
                    await ctrl.transferTable(
                        sourceTable['id'], selectedTargetTable!);
                    Navigator.pop(dialogContext);
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

  void _showMergeDialog(BuildContext parentContext, Map<String, dynamic> mainTable,
      RestaurantController ctrl) {
    int? selectedMergeTable;
    final occupiedTables = ctrl.tables
        .where((t) => t['status'] == 'Occupied' && t['id'] != mainTable['id'])
        .toList();

    showDialog(
      context: parentContext,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return AlertDialog(
              title: Text('Merge Table with ${mainTable['table_name']}'),
              content: DropdownButtonFormField<int>(
                initialValue: selectedMergeTable,
                decoration: const InputDecoration(
                    labelText: 'Choose table to merge from'),
                items: occupiedTables.map<DropdownMenuItem<int>>((t) {
                  return DropdownMenuItem<int>(
                      value: t['id'], child: Text(t['table_name']));
                }).toList(),
                onChanged: (val) => setState(() => selectedMergeTable = val),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedMergeTable == null) return;
                    await ctrl.mergeTables(
                        mainTable['id'], selectedMergeTable!);
                    Navigator.pop(dialogContext);
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

  Future<void> _showBillingCheckoutDialog(BuildContext ctx,
      Map<String, dynamic> table, RestaurantController ctrl) async {
    final int tableId = int.tryParse((table['id'] ?? table['table_id'] ?? 0).toString()) ?? 0;
    final targetContext = mounted ? context : ctx;

    if (tableId <= 0) {
      if (targetContext.mounted) {
        ScaffoldMessenger.of(targetContext).showSnackBar(
          const SnackBar(content: Text('Invalid table ID selected.')),
        );
      }
      return;
    }

    dynamic res;
    try {
      res = await ApiClient.get('/api/restaurant/kots?table_id=$tableId&active_only=true');
      if (res == null || res['success'] != true || (res['data'] is List && (res['data'] as List).isEmpty)) {
        res = await ApiClient.get('/api/restaurant/kots?table_id=$tableId');
      }
    } catch (e) {
      debugPrint('Error loading table orders: $e');
    }

    if (!mounted) return;

    if (res != null && res['success'] == true) {
      final List kotsRaw = res['data'] ?? [];
      final List kots = kotsRaw.where((kot) {
        if (kot['sales_header_id'] != null) return false;
        final String status = (kot['status'] ?? '').toString().toLowerCase().trim();
        return status != 'billed' && status != 'closed' && status != 'cancelled' && status != 'rejected' && status != 'nc cleared' && status != 'nc_cleared';
      }).toList();

      if (kots.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('There are no active orders placed on Table ${table['table_name'] ?? tableId} to bill.'),
              backgroundColor: Colors.orange.shade700,
            ),
          );
        }
        return;
      }

      final Map<dynamic, Map<String, dynamic>> grouped = {};
      final List<int> kotIds = [];

      for (final kot in kots) {
        final int kId = int.tryParse((kot['id'] ?? 0).toString()) ?? 0;
        if (kId > 0 && !kotIds.contains(kId)) {
          kotIds.add(kId);
        }

        final List items = kot['items'] as List? ?? [];
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

      final consolidatedItems = grouped.values.toList();

      if (consolidatedItems.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No active items found in the orders on Table ${table['table_name'] ?? tableId} to bill.'),
              backgroundColor: Colors.orange.shade700,
            ),
          );
        }
        return;
      }

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SaleScreen(
              preloadedTableId: tableId,
              preloadedItems: consolidatedItems,
              preloadedKotIds: kotIds,
            ),
          ),
        ).then((_) {
          ctrl.loadTables();
          _refreshData();
        });
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load active orders for this table.')),
        );
      }
    }
  }

  void _openOrderSheet(Map<String, dynamic> table, {bool isFreshOrder = true}) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) =>
              KotBuilderScreen(table: table, isFreshOrder: isFreshOrder)),
    ).then((_) => _refreshData());
  }

  void _showNcOrderDialog(BuildContext context, {Map<String, dynamic>? table}) {
    String selectedDept = 'Management / Owner Guest';
    final customDeptCtrl = TextEditingController();
    final guestNotesCtrl = TextEditingController();
    bool isCustomDept = false;

    final deptOptions = [
      'Management / Owner Guest',
      'VIP Guest',
      'Staff Meal / Employee',
      'PR / Marketing / Media',
      'Food Tasting / Trial',
      'Other / Custom Guest Name...',
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.card_giftcard, color: Colors.purple),
                  SizedBox(width: 8),
                  Text('NC Order (Non-Chargeable)'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Non-Chargeable orders are 100% complimentary (Rs. 0 charge) and clear automatically without generating a financial bill.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: selectedDept,
                      decoration: const InputDecoration(
                        labelText: 'Department / NC Reason',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: deptOptions.map((dept) {
                        return DropdownMenuItem<String>(
                          value: dept,
                          child:
                              Text(dept, style: const TextStyle(fontSize: 13)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedDept = val;
                            isCustomDept = val.contains('Custom');
                          });
                        }
                      },
                    ),
                    if (isCustomDept) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: customDeptCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Enter Custom Department / Guest Name',
                          hintText: 'e.g. Director\'s Guest / Event PR',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: guestNotesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Guest Name / Remarks (Optional)',
                        hintText: 'e.g. Table 10 - Compliments of Chef',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Proceed to NC Menu',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () {
                    final finalDept = isCustomDept
                        ? (customDeptCtrl.text.trim().isNotEmpty
                            ? customDeptCtrl.text.trim()
                            : 'Custom NC Guest')
                        : selectedDept;
                    final finalNotes = guestNotesCtrl.text.trim();

                    Navigator.pop(context);

                    final targetTable = table ??
                        {
                          'id': null,
                          'table_name': 'NC Counter',
                          'current_guest_count': 1,
                        };

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => KotBuilderScreen(
                          table: targetTable,
                          isFreshOrder: true,
                          isNcOrder: true,
                          ncDepartment: finalDept,
                          ncGuestName: finalNotes,
                        ),
                      ),
                    ).then((_) => _refreshData());
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPackingOrdersView(RestaurantController ctrl) {
    if (_activeTakeawayKots.isEmpty) {
      return const Center(
        child: Text(
          'No pending packing/takeaway orders.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = (constraints.maxWidth / 300).floor().clamp(1, 4);
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.72,
          ),
          itemCount: _activeTakeawayKots.length,
          itemBuilder: (context, index) {
            final kot = _activeTakeawayKots[index];
            final int kotId = kot['id'];
            final String kotNo = kot['kot_number'] ?? kot['kot_no'] ?? '#KOT-$kotId';
            final String status = kot['status'] ?? 'p';
            final String captainName = _getCaptainName(kot['captain'] ?? kot['waiter']);
            final items = kot['items'] as List? ?? [];
            final String timeStr = kot['created_time'] != null
                ? DateTime.parse(kot['created_time'].toString()).toString().substring(11, 16)
                : '';

            return Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.blue.shade800,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(10),
                        topRight: Radius.circular(10),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            kotNo,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          timeStr,
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Colors.white, size: 18),
                          onSelected: (val) {
                            if (val == 'modify') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => KotBuilderScreen(
                                    editKotId: kotId,
                                    isTakeaway: true,
                                    table: const {'id': null, 'table_name': 'Takeaway'},
                                  ),
                                ),
                              ).then((_) => _fetchActiveKots());
                            } else if (val == 'cancel') {
                              _cancelPackingKot(kotId, kotNo);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'modify',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 16, color: Colors.blue),
                                  SizedBox(width: 8),
                                  Text('Modify / Add Item'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'cancel',
                              child: Row(
                                children: [
                                  Icon(Icons.cancel, size: 16, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Cancel Entire KOT'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Capt/Staff: $captainName',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (status == 'Ready' || status == 'ready') ? Colors.green.shade100 : Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            status == 'p' ? 'Pending' : status,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: (status == 'Ready' || status == 'ready') ? Colors.green.shade800 : Colors.amber.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: items.length,
                      itemBuilder: (context, iIdx) {
                        final item = items[iIdx];
                        final String itemStat = (item['status'] ?? '').toString().toLowerCase();
                        final isCancelled = itemStat == 'cancelled';
                        final double quantity = double.tryParse(item['quantity']?.toString() ?? item['qty']?.toString() ?? '1') ?? 1.0;
                        final String qtyStr = (quantity % 1 == 0) ? quantity.toInt().toString() : quantity.toStringAsFixed(1);
                        final int itemId = item['id'] ?? 0;
                        final String itemName = item['item_name'] ?? '';

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Text(
                                '$qtyStr x ',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  decoration: isCancelled ? TextDecoration.lineThrough : null,
                                  color: isCancelled ? Colors.red : null,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  itemName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    decoration: isCancelled ? TextDecoration.lineThrough : null,
                                    color: isCancelled ? Colors.red : null,
                                  ),
                                ),
                              ),
                              if (!isCancelled && itemId > 0)
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, size: 16, color: Colors.redAccent),
                                  tooltip: 'Cancel item',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _cancelPackingItem(itemId, itemName, kotId),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_note, size: 18, color: Colors.blue),
                          tooltip: 'Modify / Add Items',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => KotBuilderScreen(
                                  editKotId: kotId,
                                  prefilledItems: (kot['items'] is List) ? List<Map<String, dynamic>>.from((kot['items'] as List).map((x) => Map<String, dynamic>.from(x is Map ? x : {}))) : null,
                                  isTakeaway: true,
                                  table: const {'id': null, 'table_name': 'Takeaway'},
                                ),
                              ),
                            ).then((_) => _fetchActiveKots());
                          },
                        ),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              side: BorderSide(color: Colors.blue.shade700),
                            ),
                            onPressed: () => _printKotById(kot),
                            child: const Text('Print', style: TextStyle(fontSize: 11)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            onPressed: () => _settlePackingOrder(kot),
                            child: const Text('Settle', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
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
    );
  }

  String _getCaptainName(dynamic emp) {
    if (emp == null) return 'N/A';
    final String name = (emp is Map ? (emp['employee_name'] ?? emp['name'] ?? '') : emp.toString()).trim();
    if (name.isEmpty || name.toLowerCase().contains('dummy')) return 'N/A';
    return name;
  }

  Future<void> _cancelPackingKot(int kotId, String kotNo) async {
    String reason = 'Cancelled by Staff';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel Packing KOT $kotNo?'),
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
            child: const Text('Confirm Cancel'),
          )
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final res = await ApiClient.put('/api/restaurant/kots/$kotId/status', {
          'status': 'cancelled',
          'remarks': reason,
        });
        if (res['success'] == true && mounted) {
          setState(() {
            _activeTakeawayKots.removeWhere((k) => k['id'] == kotId);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cancelled Packing KOT $kotNo successfully.')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _cancelPackingItem(int itemId, String itemName, int kotId) async {
    String reason = 'Removed from Packing KOT';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel "$itemName"?'),
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
            child: const Text('Confirm Cancel'),
          )
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final res = await ApiClient.put('/api/restaurant/kots/items/$itemId/status', {
          'status': 'cancelled',
          'cancel_reason': reason,
        });
        if (res['success'] == true && mounted) {
          _fetchActiveKots();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cancelled "$itemName" successfully.')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _settlePackingOrder(Map<String, dynamic> kot) {
    final List items = kot['items'] ?? [];
    final Map<int, Map<String, dynamic>> grouped = {};
    for (final item in items) {
      final String itemStatus = (item['status'] ?? '').toString().toUpperCase().trim();
      if (itemStatus == 'CANCELLED') continue;

      final int itemId = item['item_id'];
      final double qty = double.tryParse(item['quantity']?.toString() ?? item['qty']?.toString() ?? '1') ?? 1.0;
      final double rate = double.tryParse(item['rate']?.toString() ?? '') ??
          double.tryParse(item['item_rate']?.toString() ?? '') ??
          0.0;

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

    final consolidatedItems = grouped.values.toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SaleScreen(
          preloadedTableId: null,
          preloadedItems: consolidatedItems,
          preloadedKotIds: [kot['id']],
        ),
      ),
    ).then((_) {
      _fetchActiveKots();
    });
  }

  Future<void> _printKotById(Map<String, dynamic> kot) async {
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
    } catch (e) {
      debugPrint('Error printing KOT: $e');
    }
  }

  Future<Uint8List> _generateKotPdfForPrint(Map<String, dynamic> kot, List<dynamic> items, String locationName) async {
    final pdf = pw.Document();
    
    final String kottypeLower = (kot['kottype'] ?? '').toString().toLowerCase();
    final String serviceTypeLower = (kot['service_type'] ?? '').toString().toLowerCase();
    final String remarksLower = (kot['remarks'] ?? '').toString().toLowerCase();
    final bool isNc = kottypeLower == 'nc' || serviceTypeLower.contains('nc') || remarksLower.contains('nc');

    final String tableName = isNc ? 'NC Order' : (kot['table']?['table_name'] ?? 'Takeaway');
    final String subHeader = isNc ? '*** NC ORDER (NO CHARGE) ***' : '*** PACKING K O T ***';
    final String nowStr = DateTime.now().toString().substring(0, 16);
    final String kotNo = (kot['kot_number'] ?? kot['kot_no'] ?? '#KOT-${kot['id']}').toString();
    
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
                  subHeader,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TABLE: $tableName', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
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
              ...items.map((item) {
                final double q = double.tryParse(item['quantity']?.toString() ?? item['qty']?.toString() ?? '0') ?? 0.0;
                final String qtyStr = (q % 1 == 0) ? q.toInt().toString() : q.toStringAsFixed(1);
                final String itemBrand = (item['brand'] ?? item['brand_name'] ?? item['item_brand'] ?? item['item']?['brand'] ?? (item['item'] is Map ? item['item']['brand'] : null) ?? '').toString().trim();
                final String displayName = itemBrand.isNotEmpty ? '${item['item_name'] ?? ''} ($itemBrand)' : (item['item_name'] ?? '');
                final String remark = (item['notes'] ?? item['item_remark'] ?? '').toString();
                
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

  Widget _buildNcOrdersView(RestaurantController ctrl) {
    if (_activeNcKots.isEmpty) {
      return const Center(
        child: Text(
          'No pending NC (No Charge) orders.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = (constraints.maxWidth / 300).floor().clamp(1, 4);
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.72,
          ),
          itemCount: _activeNcKots.length,
          itemBuilder: (context, index) {
            final kot = _activeNcKots[index];
            final int kotId = kot['id'];
            final String kotNo = kot['kot_number'] ?? kot['kot_no'] ?? '#NC-$kotId';
            final String captainName = _getCaptainName(kot['captain'] ?? kot['waiter']);
            final String remarks = (kot['remarks'] ?? '').toString().trim();
            final items = kot['items'] as List? ?? [];
            final String timeStr = kot['created_time'] != null
                ? DateTime.parse(kot['created_time'].toString()).toString().substring(11, 16)
                : '';

            return Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.purple.shade800,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(10),
                        topRight: Radius.circular(10),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            kotNo,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade400,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'NC Order',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          timeStr,
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Colors.white, size: 18),
                          onSelected: (val) {
                            if (val == 'cancel_kot') {
                              _cancelPackingKot(kotId, kotNo);
                            } else if (val == 'print') {
                              _printKotById(kot);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'cancel_kot',
                              child: Row(
                                children: [
                                  Icon(Icons.cancel, size: 16, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Cancel Entire NC Order'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'print',
                              child: Row(
                                children: [
                                  Icon(Icons.print, size: 16, color: Colors.blue),
                                  SizedBox(width: 8),
                                  Text('Print NC Ticket'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    color: Colors.purple.shade50,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Staff/Capt: $captainName',
                          style: TextStyle(fontSize: 11, color: Colors.purple.shade900, fontWeight: FontWeight.bold),
                        ),
                        if (remarks.isNotEmpty)
                          Text(
                            'NC Info: $remarks',
                            style: TextStyle(fontSize: 10, color: Colors.purple.shade700, fontStyle: FontStyle.italic),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: items.length,
                      itemBuilder: (context, iIdx) {
                        final item = items[iIdx];
                        final String itemStat = (item['status'] ?? '').toString().toLowerCase();
                        final isCancelled = itemStat == 'cancelled';
                        final double quantity = double.tryParse(item['quantity']?.toString() ?? item['qty']?.toString() ?? '1') ?? 1.0;
                        final String qtyStr = (quantity % 1 == 0) ? quantity.toInt().toString() : quantity.toStringAsFixed(1);
                        final int itemId = item['id'] ?? 0;
                        final String itemName = item['item_name'] ?? '';

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Text(
                                '$qtyStr x ',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  decoration: isCancelled ? TextDecoration.lineThrough : null,
                                  color: isCancelled ? Colors.red : null,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  itemName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    decoration: isCancelled ? TextDecoration.lineThrough : null,
                                    color: isCancelled ? Colors.red : null,
                                  ),
                                ),
                              ),
                              if (!isCancelled && itemId > 0)
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, size: 16, color: Colors.redAccent),
                                  tooltip: 'Cancel item',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _cancelPackingItem(itemId, itemName, kotId),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_note, size: 18, color: Colors.purple),
                          tooltip: 'Modify / Add Items',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => KotBuilderScreen(
                                  editKotId: kotId,
                                  prefilledItems: (kot['items'] is List) ? List<Map<String, dynamic>>.from((kot['items'] as List).map((x) => Map<String, dynamic>.from(x is Map ? x : {}))) : null,
                                  isNcOrder: true,
                                  table: const {'id': null, 'table_name': 'NC Order'},
                                ),
                              ),
                            ).then((_) => _fetchActiveKots());
                          },
                        ),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              side: BorderSide(color: Colors.purple.shade700),
                            ),
                            onPressed: () => _printKotById(kot),
                            child: const Text('Print', style: TextStyle(fontSize: 11)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            onPressed: () => _clearNcOrder(kotId, kotNo),
                            child: const Text('Clear Order', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
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
    );
  }

  Future<void> _clearNcOrder(int kotId, String kotNo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear NC Order $kotNo?'),
        content: const Text('This will mark the NC Order as Cleared/Closed without creating a sale bill.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Go Back'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text(
              'Confirm Clear Order',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final res = await ApiClient.put('/api/restaurant/kots/$kotId/status', {
          'status': 'NC Cleared',
          'remarks': 'NC Order Cleared by Staff',
        });
        if (res['success'] == true && mounted) {
          setState(() {
            _activeNcKots.removeWhere((k) => k['id'] == kotId);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('NC Order $kotNo cleared successfully.')),
          );
          _refreshData();
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
