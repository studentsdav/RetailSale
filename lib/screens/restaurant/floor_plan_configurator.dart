import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/restaurant/restaurant_controller.dart';

class FloorPlanConfigurator extends StatefulWidget {
  const FloorPlanConfigurator({super.key});

  @override
  State<FloorPlanConfigurator> createState() => _FloorPlanConfiguratorState();
}

class _FloorPlanConfiguratorState extends State<FloorPlanConfigurator> {
  int? selectedFloorId; // null = Show All Floors by default
  int? selectedAreaId; // Filter by Dining Area
  bool isEditingCoordinates = true; // Default editing enabled for drag-and-drop designer

  // Independent custom position offset for each Area Card Container
  final Map<String, Offset> areaPositions = {};

  // Custom user-adjusted sizes for each Area Card Container (Canva-style corner resizer)
  final Map<String, Size> areaSizes = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctrl = Provider.of<RestaurantController>(context, listen: false);
      ctrl.loadFloors();
      ctrl.loadDiningAreas();
      ctrl.loadTables();
    });
  }

  Map<String, List<dynamic>> _groupTablesByArea(List<dynamic> tables, RestaurantController ctrl) {
    final Map<String, List<dynamic>> map = {};

    // Pre-populate defined dining areas so newly added areas auto-draw on canvas
    for (final area in ctrl.diningAreas) {
      if (selectedAreaId == null || area['id'] == selectedAreaId) {
        final String name = area['name'] ?? 'Dining Area';
        map.putIfAbsent(name, () => []);
      }
    }

    // Group tables into their area
    for (final t in tables) {
      final int? areaId = t['dining_area_id'] ?? (t['dining_area'] is Map ? t['dining_area']['id'] : null);
      final areaMatch = ctrl.diningAreas.firstWhere((a) => a['id'] == areaId, orElse: () => null);
      String areaName = (t['dining_area'] is Map ? t['dining_area']['name'] : t['dining_area_name']) ?? areaMatch?['name'] ?? '';

      if (areaName.isEmpty) {
        final int? floorId = t['floor_id'] ?? (t['floor'] is Map ? t['floor']['id'] : null);
        final floorMatch = ctrl.floors.firstWhere((f) => f['id'] == floorId, orElse: () => null);
        areaName = (t['floor'] is Map ? t['floor']['name'] : t['floor_name']) ?? floorMatch?['name'] ?? 'Main Zone';
      }

      map.putIfAbsent(areaName, () => []).add(t);
    }
    return map;
  }

  Widget _buildAreaDesignerCard({
    required String areaName,
    required List<dynamic> areaTables,
    required double width,
    required double height,
    required ColorScheme colorScheme,
    required Function(DragUpdateDetails) onPanUpdateArea,
    required VoidCallback onPanEndArea,
    required Function(DragUpdateDetails) onPanUpdateCornerResize,
  }) {
    final int total = areaTables.length;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isEditingCoordinates ? colorScheme.primary.withValues(alpha: 0.6) : const Color(0xFF94A3B8),
              width: isEditingCoordinates ? 2.2 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Area Card Header (Draggable) ──────────────────────────────────
              GestureDetector(
                onPanUpdate: isEditingCoordinates ? onPanUpdateArea : null,
                onPanEnd: isEditingCoordinates ? (_) => onPanEndArea() : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isEditingCoordinates ? colorScheme.primaryContainer.withValues(alpha: 0.4) : const Color(0xFFE2E8F0),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                    ),
                    border: Border(bottom: BorderSide(color: colorScheme.outlineVariant, width: 1.5)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.roofing_rounded, size: 15, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$areaName Zone / Area',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                                color: colorScheme.onSurface,
                                letterSpacing: 0.3,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (isEditingCoordinates)
                              const Text(
                                '💡 Drag header to move | Drag bottom-right corner handle to resize card',
                                style: TextStyle(fontSize: 9.5, color: Colors.grey),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Text(
                          '$total ${total == 1 ? 'Table' : 'Tables'}',
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
              ),
            ],
          ),
        ),
        // ── Canva-Style Bottom-Right Corner Resizer ────────────────────────
        if (isEditingCoordinates)
          Positioned(
            right: -6,
            bottom: -6,
            child: GestureDetector(
              onPanUpdate: onPanUpdateCornerResize,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: colorScheme.primary, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 6,
                      offset: const Offset(1, 2),
                    ),
                  ],
                ),
                child: Icon(Icons.south_east_rounded, size: 14, color: colorScheme.primary),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<RestaurantController>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Filter tables by floor and optionally by dining area
    final floorTables = ctrl.tables.where((t) {
      final matchesFloor = selectedFloorId == null || t['floor_id'] == selectedFloorId;
      final int? tAreaId = t['dining_area_id'] ?? (t['dining_area'] is Map ? t['dining_area']['id'] : null);
      final matchesArea = selectedAreaId == null || tAreaId == selectedAreaId;
      return matchesFloor && matchesArea;
    }).toList();

    final groupedTables = _groupTablesByArea(floorTables, ctrl);
    final List<String> areaKeys = groupedTables.keys.toList();

    final int areaCount = areaKeys.length;
    final int colsCount = areaCount > 1 ? 2 : 1;

    const double defaultMinCardWidth = 360.0;
    const double defaultMinCardHeight = 240.0;
    const double spacingX = 40.0;
    const double spacingY = 40.0;

    final List<Widget> stackChildren = [];

    double totalMaxX = 1400;
    double totalMaxY = 1200;

    for (int areaIdx = 0; areaIdx < areaKeys.length; areaIdx++) {
      final String areaName = areaKeys[areaIdx];
      final List<dynamic> areaTables = groupedTables[areaName]!;

      // Calculate minX, minY, maxX, maxY for tables inside this area
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

      // Check if tables inside this area overlap
      bool isOverlapping = false;
      for (int i = 0; i < areaTables.length; i++) {
        for (int j = i + 1; j < areaTables.length; j++) {
          final double x1 = (areaTables[i]['x_coordinate'] ?? 120).toDouble();
          final double y1 = (areaTables[i]['y_coordinate'] ?? 120).toDouble();
          final double x2 = (areaTables[j]['x_coordinate'] ?? 120).toDouble();
          final double y2 = (areaTables[j]['y_coordinate'] ?? 120).toDouble();
          if ((x1 - x2).abs() < 20 && (y1 - y2).abs() < 20) {
            isOverlapping = true;
            break;
          }
        }
      }

      // Initialize fixed Area Card container position
      if (!areaPositions.containsKey(areaName)) {
        final int col = areaIdx % colsCount;
        final int row = areaIdx ~/ colsCount;
        final double defaultLeft = spacingX + (col * (defaultMinCardWidth + spacingX));
        final double defaultTop = spacingY + (row * (defaultMinCardHeight + spacingY));
        final double initLeft = areaTables.isEmpty ? defaultLeft : max(minX - 20.0, 15.0);
        final double initTop = areaTables.isEmpty ? defaultTop : max(minY - 50.0, 15.0);
        areaPositions[areaName] = Offset(initLeft, initTop);
      }

      final Offset currentAreaOffset = areaPositions[areaName]!;
      final double baseAreaLeft = currentAreaOffset.dx;
      final double baseAreaTop = currentAreaOffset.dy;

      // Tight, balanced Area Card width & height (Exact equal 20px padding on left, right, bottom)
      double calculatedWidth = areaTables.isEmpty ? defaultMinCardWidth : max((maxX - minX) + 140.0 + 40.0, defaultMinCardWidth);
      double calculatedHeight = areaTables.isEmpty ? defaultMinCardHeight : max((maxY - minY) + 140.0 + 70.0, defaultMinCardHeight);

      // Apply user's custom Canva resize if modified
      if (areaSizes.containsKey(areaName)) {
        calculatedWidth = areaSizes[areaName]!.width;
        calculatedHeight = areaSizes[areaName]!.height;
      }

      if (baseAreaLeft + calculatedWidth + 100 > totalMaxX) {
        totalMaxX = baseAreaLeft + calculatedWidth + 100;
      }
      if (baseAreaTop + calculatedHeight + 100 > totalMaxY) {
        totalMaxY = baseAreaTop + calculatedHeight + 100;
      }

      // Render Area Container Card
      stackChildren.add(
        Positioned(
          left: baseAreaLeft,
          top: baseAreaTop,
          width: calculatedWidth,
          height: calculatedHeight,
          child: _buildAreaDesignerCard(
            areaName: areaName,
            areaTables: areaTables,
            width: calculatedWidth,
            height: calculatedHeight,
            colorScheme: colorScheme,
            onPanUpdateArea: (details) {
              setState(() {
                final Offset oldOffset = areaPositions[areaName] ?? const Offset(40, 40);
                areaPositions[areaName] = Offset(
                  (oldOffset.dx + details.delta.dx).clamp(10.0, 4000.0),
                  (oldOffset.dy + details.delta.dy).clamp(10.0, 4000.0),
                );

                for (final table in areaTables) {
                  final double currentX = (table['x_coordinate'] ?? 120).toDouble();
                  final double currentY = (table['y_coordinate'] ?? 120).toDouble();
                  table['x_coordinate'] = (currentX + details.delta.dx).clamp(30.0, 4000.0).toInt();
                  table['y_coordinate'] = (currentY + details.delta.dy).clamp(70.0, 4000.0).toInt();
                }
              });
            },
            onPanEndArea: () {
              for (final table in areaTables) {
                ctrl.saveTable(Map<String, dynamic>.from(table));
              }
            },
            onPanUpdateCornerResize: (details) {
              setState(() {
                final Size currentSize = areaSizes[areaName] ?? Size(calculatedWidth, calculatedHeight);
                final double newW = (currentSize.width + details.delta.dx).clamp(300.0, 4000.0);
                final double newH = (currentSize.height + details.delta.dy).clamp(220.0, 4000.0);
                areaSizes[areaName] = Size(newW, newH);
              });
            },
          ),
        ),
      );

      // Render Table Cards inside Area Card
      for (int tIdx = 0; tIdx < areaTables.length; tIdx++) {
        final table = areaTables[tIdx];
        double tx = (table['x_coordinate'] ?? 120).toDouble();
        double ty = (table['y_coordinate'] ?? 120).toDouble();

        // If table coordinates overlap or are default, space them out neatly inside Area Card
        if (isOverlapping || (areaTables.length > 1 && tx == 120 && ty == 120)) {
          final int tCol = tIdx % 2;
          final int tRow = tIdx ~/ 2;
          tx = baseAreaLeft + 25.0 + (tCol * 165.0);
          ty = baseAreaTop + 65.0 + (tRow * 165.0);
          table['x_coordinate'] = tx.toInt();
          table['y_coordinate'] = ty.toInt();
        }

        final double tableLeft = tx;
        final double tableTop = ty;

        final int? floorId = table['floor_id'] ?? (table['floor'] is Map ? table['floor']['id'] : null);
        final floorMatch = ctrl.floors.firstWhere((f) => f['id'] == floorId, orElse: () => null);
        final String floorName = (table['floor'] is Map ? table['floor']['name'] : table['floor_name']) ?? floorMatch?['name'] ?? '';

        stackChildren.add(
          Positioned(
            left: tableLeft,
            top: tableTop,
            child: GestureDetector(
              onPanUpdate: isEditingCoordinates
                  ? (details) {
                      setState(() {
                        final double currentX = (table['x_coordinate'] ?? 120).toDouble();
                        final double currentY = (table['y_coordinate'] ?? 120).toDouble();
                        table['x_coordinate'] = (currentX + details.delta.dx).clamp(30.0, 4000.0).toInt();
                        table['y_coordinate'] = (currentY + details.delta.dy).clamp(70.0, 4000.0).toInt();
                      });
                    }
                  : null,
              onPanEnd: isEditingCoordinates
                  ? (_) {
                      ctrl.saveTable(Map<String, dynamic>.from(table));
                    }
                  : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isEditingCoordinates ? colorScheme.primary : Colors.grey.shade300,
                    width: isEditingCoordinates ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(3, 3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.table_restaurant,
                        color: colorScheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      table['table_name'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Seats: ${table['capacity']}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.amber.shade200, width: 0.5),
                          ),
                          child: Text(
                            areaName,
                            style: TextStyle(color: Colors.amber.shade800, fontSize: 9, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (selectedFloorId == null && floorName.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.blue.shade200, width: 0.5),
                            ),
                            child: Text(
                              floorName,
                              style: TextStyle(color: Colors.blue.shade800, fontSize: 8.5, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Floor Seating Designer'),
        actions: [
          Row(
            children: [
              Text(
                isEditingCoordinates ? 'Editing Mode Active' : 'View Mode',
                style: TextStyle(
                  fontSize: 13,
                  color: isEditingCoordinates ? colorScheme.primary : Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Switch(
                value: isEditingCoordinates,
                onChanged: (val) {
                  setState(() {
                    isEditingCoordinates = val;
                  });
                },
              )
            ],
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Row(
        children: [
          // Sidebar with Floors & Dining Areas
          Container(
            width: 250,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: colorScheme.outlineVariant)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Floor Selection Header
                Container(
                  padding: const EdgeInsets.all(16),
                  color: colorScheme.surfaceContainerHighest,
                  child: Text(
                    'Floors / Zones',
                    style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurfaceVariant),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: ListView(
                    children: [
                      ListTile(
                        leading: Icon(
                          Icons.all_out,
                          color: selectedFloorId == null ? colorScheme.primary : Colors.grey,
                        ),
                        title: const Text('Show All Floors'),
                        selected: selectedFloorId == null,
                        selectedTileColor: colorScheme.primaryContainer.withValues(alpha: 0.3),
                        onTap: () {
                          setState(() {
                            selectedFloorId = null;
                          });
                        },
                      ),
                      ...ctrl.floors.map((floor) {
                        final isSelected = floor['id'] == selectedFloorId;
                        return ListTile(
                          leading: Icon(
                            Icons.layers,
                            color: isSelected ? colorScheme.primary : Colors.grey,
                          ),
                          title: Text(
                            floor['name'] ?? '',
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          selected: isSelected,
                          selectedTileColor: colorScheme.primaryContainer.withValues(alpha: 0.3),
                          onTap: () {
                            setState(() {
                              selectedFloorId = floor['id'];
                            });
                          },
                        );
                      }),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Dining Area Filter Header
                Container(
                  padding: const EdgeInsets.all(16),
                  color: colorScheme.surfaceContainerHighest,
                  child: Text(
                    'Dining Areas Filter',
                    style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurfaceVariant),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ListTile(
                        leading: Icon(
                          Icons.all_out,
                          color: selectedAreaId == null ? colorScheme.primary : Colors.grey,
                        ),
                        title: const Text('Show All Areas'),
                        selected: selectedAreaId == null,
                        selectedTileColor: colorScheme.primaryContainer.withValues(alpha: 0.3),
                        onTap: () => setState(() => selectedAreaId = null),
                      ),
                      Expanded(
                        child: ctrl.diningAreas.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('No Dining Areas defined. Add them in setup screen first.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              )
                            : ListView.builder(
                                itemCount: ctrl.diningAreas.length,
                                itemBuilder: (context, index) {
                                  final area = ctrl.diningAreas[index];
                                  final isSelected = area['id'] == selectedAreaId;
                                  return ListTile(
                                    leading: Icon(
                                      Icons.room_service_outlined,
                                      color: isSelected ? colorScheme.primary : Colors.grey,
                                    ),
                                    title: Text(area['name'] ?? ''),
                                    selected: isSelected,
                                    selectedTileColor: colorScheme.primaryContainer.withValues(alpha: 0.3),
                                    onTap: () {
                                      setState(() {
                                        selectedAreaId = area['id'];
                                      });
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Main Interactive Layout Canvas
          Expanded(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: colorScheme.primary, size: 24),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Visual Floor Layout Designer: Drag area headers to position cards | Drag bottom-right corner handle to resize card like Canva | Drag tables inside.',
                          style: TextStyle(fontSize: 13, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
                // Layout Canvas Grid
                Expanded(
                  child: Container(
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
                          color: Colors.blue.withValues(alpha: 0.03),
                          interval: 100,
                          divisions: 2,
                          subdivisions: 5,
                          child: Stack(
                            children: stackChildren,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
