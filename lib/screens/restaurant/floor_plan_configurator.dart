import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/restaurant/restaurant_controller.dart';

class FloorPlanConfigurator extends StatefulWidget {
  const FloorPlanConfigurator({super.key});

  @override
  State<FloorPlanConfigurator> createState() => _FloorPlanConfiguratorState();
}

class _FloorPlanConfiguratorState extends State<FloorPlanConfigurator> {
  int? selectedFloorId;
  int? selectedAreaId; // Filter by Dining Area
  bool isEditingCoordinates = true; // Default editing enabled for drag-and-drop designer

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
      ctrl.loadDiningAreas();
      ctrl.loadTables();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<RestaurantController>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Filter tables by floor and optionally by dining area
    final floorTables = ctrl.tables.where((t) {
      final matchesFloor = t['floor_id'] == selectedFloorId;
      final matchesArea = selectedAreaId == null || t['dining_area_id'] == selectedAreaId;
      return matchesFloor && matchesArea;
    }).toList();

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
                  setState(() => isEditingCoordinates = val);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        val
                            ? 'Editing Enabled: Drag tables to reposition them.'
                            : 'Editing Disabled: Seating coordinates locked.',
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Row(
        children: [
          // Left Sidebar: Floors & Dining Areas
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
                  color: colorScheme.surfaceVariant,
                  child: Text(
                    'Floors / Zones',
                    style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurfaceVariant),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: ctrl.floors.isEmpty
                      ? const Center(child: Text('No floors. Add in Setup.'))
                      : ListView.builder(
                          itemCount: ctrl.floors.length,
                          itemBuilder: (context, index) {
                            final floor = ctrl.floors[index];
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
                              selectedTileColor: colorScheme.primaryContainer.withOpacity(0.3),
                              onTap: () {
                                setState(() {
                                  selectedFloorId = floor['id'];
                                });
                              },
                            );
                          },
                        ),
                ),
                const Divider(height: 1),
                // Dining Area Filter Header
                Container(
                  padding: const EdgeInsets.all(16),
                  color: colorScheme.surfaceVariant,
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
                        selectedTileColor: colorScheme.primaryContainer.withOpacity(0.3),
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
                                    selectedTileColor: colorScheme.primaryContainer.withOpacity(0.3),
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
          // Right Canvas: Design Area
          Expanded(
            child: Column(
              children: [
                // Instructions Block
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: colorScheme.primary, size: 24),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Visual Floor Layout Designer: Click and hold tables to drag and drop them to match your physical restaurant layout. Coordinates auto-save to database upon releasing.',
                          style: TextStyle(fontSize: 13, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
                // Layout Canvas Grid
                Expanded(
                  child: Container(
                    color: Colors.grey.shade50,
                    // Dotted mesh grid decoration representation
                    child: GridPaper(
                      color: Colors.blue.withOpacity(0.04),
                      interval: 100,
                      divisions: 2,
                      subdivisions: 5,
                      child: Stack(
                        children: floorTables.map((table) {
                          double x = (table['x_coordinate'] ?? 120).toDouble();
                          double y = (table['y_coordinate'] ?? 120).toDouble();
                          final String areaName = table['dining_area']?['name'] ?? 'No Area';

                          return Positioned(
                            left: x,
                            top: y,
                            child: GestureDetector(
                              onPanUpdate: isEditingCoordinates
                                  ? (details) {
                                      setState(() {
                                        final double currentX = (table['x_coordinate'] ?? 120).toDouble();
                                        final double currentY = (table['y_coordinate'] ?? 120).toDouble();
                                        table['x_coordinate'] = (currentX + details.delta.dx).clamp(0.0, 900.0).toInt();
                                        table['y_coordinate'] = (currentY + details.delta.dy).clamp(0.0, 600.0).toInt();
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
                                width: 130,
                                height: 130,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isEditingCoordinates ? colorScheme.primary : Colors.grey.shade300,
                                    width: isEditingCoordinates ? 2 : 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
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
                                        color: colorScheme.primaryContainer.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.table_restaurant,
                                        color: colorScheme.primary,
                                        size: 24,
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
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
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
