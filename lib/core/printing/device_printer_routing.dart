import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../models/inventory/settings/system_settings_model.dart';
import '../api/api_client.dart';
import '../api/endpoints.dart';
import '../settings/local_preferences.dart';

class StationPrinterMapping {
  final String machineId;
  final String location;
  final String printer;
  final int copies;

  StationPrinterMapping({
    required this.machineId,
    required this.location,
    required this.printer,
    this.copies = 1,
  });

  Map<String, dynamic> toJson() => {
        'machine_id': machineId,
        'location': location,
        'printer': printer,
        'copies': copies,
      };

  factory StationPrinterMapping.fromJson(
      Map<String, dynamic> json, String defaultMachineId) {
    return StationPrinterMapping(
      machineId: (json['machine_id'] ?? defaultMachineId).toString().trim().toUpperCase(),
      location: (json['location'] ?? json['location_name'] ?? json['station_name'] ?? '').toString().trim(),
      printer: (json['printer'] ?? json['printer_name'] ?? '').toString().trim(),
      copies: int.tryParse(
              json['copies']?.toString() ?? json['copies_count']?.toString() ?? '1') ??
          1,
    );
  }
}

class DevicePrinterRouting {
  DevicePrinterRouting._();

  /// Get list of known Machine IDs (auto-detecting physical OS hardware ID + saved terminal IDs)
  static List<String> getKnownMachineIds(SystemSettings settings) {
    final currentHwId = LocalPreferences.getSystemHardwareId();
    final set = <String>{currentHwId};
    final mappings = settings.devicePrinterMappings;
    for (final k in mappings.keys) {
      final key = k.toString().trim().toUpperCase();
      if (key.isNotEmpty && key != 'DEFAULT') {
        set.add(key);
      }
    }
    return set.toList();
  }

  /// Get customer bill printer for a specific machine ID
  static String getBillPrinter(SystemSettings settings, String machineId) {
    final mKey = machineId.trim().toUpperCase();
    final mData = settings.devicePrinterMappings[mKey] ?? settings.devicePrinterMappings['DEFAULT'];
    if (mData is Map) {
      return (mData['bill_printer'] ?? '').toString();
    }
    return '';
  }

  /// Set customer bill printer for a specific machine ID
  static void setBillPrinter(SystemSettings settings, String machineId, String printerName) {
    final mKey = machineId.trim().toUpperCase();
    final current = settings.devicePrinterMappings[mKey] is Map
        ? Map<String, dynamic>.from(settings.devicePrinterMappings[mKey])
        : <String, dynamic>{};
    current['bill_printer'] = printerName;
    settings.devicePrinterMappings[mKey] = current;
  }

  /// Parse section mappings ('tokens' or 'kots') into a list of StationPrinterMapping
  static List<StationPrinterMapping> getSectionMappings(
      SystemSettings settings, String sectionKey) {
    final List<StationPrinterMapping> result = [];
    final mappings = settings.devicePrinterMappings;

    for (final entry in mappings.entries) {
      final mKey = entry.key.toString().trim().toUpperCase();
      dynamic mData = entry.value;
      if (mData is String && mData.trim().isNotEmpty) {
        try {
          mData = jsonDecode(mData);
        } catch (_) {}
      }

      if (mData is Map && mData[sectionKey] != null) {
        dynamic secData = mData[sectionKey];
        if (secData is String && secData.trim().isNotEmpty) {
          try {
            secData = jsonDecode(secData);
          } catch (_) {}
        }

        if (secData is List) {
          for (final item in secData) {
            dynamic parsedItem = item;
            if (parsedItem is String && parsedItem.trim().isNotEmpty) {
              try {
                parsedItem = jsonDecode(parsedItem);
              } catch (_) {}
            }
            if (parsedItem is Map) {
              result.add(StationPrinterMapping.fromJson(
                  Map<String, dynamic>.from(parsedItem), mKey));
            }
          }
        } else if (secData is Map) {
          for (final kv in secData.entries) {
            final loc = kv.key.toString();
            final prn = kv.value is Map ? (kv.value['printer'] ?? '').toString() : kv.value.toString();
            final c = kv.value is Map ? (int.tryParse(kv.value['copies']?.toString() ?? '1') ?? 1) : 1;
            result.add(StationPrinterMapping(
              machineId: mKey,
              location: loc,
              printer: prn,
              copies: c,
            ));
          }
        }
      }
    }
    return result;
  }

  /// Update section mappings ('tokens' or 'kots') ensuring NO DUPLICATES on (machineId + location + printer)
  static void saveSectionMappings(
      SystemSettings settings, String sectionKey, List<StationPrinterMapping> list) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    final Set<String> seenKeys = {};

    for (final item in list) {
      final mKey = item.machineId.trim().toUpperCase();
      final locKey = item.location.trim().toLowerCase();
      final prnKey = item.printer.trim().toLowerCase();
      final comboKey = '$mKey::$locKey::$prnKey';

      if (locKey.isEmpty || seenKeys.contains(comboKey)) {
        continue; // Skip exact duplicates and empty locations
      }
      seenKeys.add(comboKey);

      grouped.putIfAbsent(mKey, () => []).add(item.toJson());
    }

    final deviceMappings = Map<String, dynamic>.from(settings.devicePrinterMappings);

    // Clear existing section entries across all machines first
    for (final mKey in deviceMappings.keys) {
      if (deviceMappings[mKey] is Map) {
        final mData = Map<String, dynamic>.from(deviceMappings[mKey]);
        mData.remove(sectionKey);
        deviceMappings[mKey] = mData;
      }
    }

    // Write new grouped entries
    for (final entry in grouped.entries) {
      final mKey = entry.key;
      final current = deviceMappings[mKey] is Map
          ? Map<String, dynamic>.from(deviceMappings[mKey])
          : <String, dynamic>{};
      current[sectionKey] = entry.value;
      deviceMappings[mKey] = current;
    }

    settings.devicePrinterMappings = deviceMappings;
    LocalPreferences.setDevicePrinterMappings(deviceMappings);
  }

  /// Resolve ALL matching printer entries for a specific (machineId, location) with fallbacks
  static List<StationPrinterMapping> resolvePrinters({
    required SystemSettings settings,
    required String machineId,
    required String sectionKey,
    required String location,
  }) {
    final mKey = machineId.trim().toUpperCase();
    final targetLoc = location.trim().toLowerCase();

    final allMappings = getSectionMappings(settings, sectionKey);

    // 1. HIGHEST PRIORITY: Exact match on current terminal machineId + location (e.g., POS-1 + Dubai)
    final terminalMatches = allMappings
        .where((m) => m.machineId.trim().toUpperCase() == mKey && m.location.trim().toLowerCase() == targetLoc)
        .toList();
    if (terminalMatches.isNotEmpty) {
      return terminalMatches;
    }

    // 2. SECOND PRIORITY: Match on DEFAULT machineId + location
    final defaultMatches = allMappings
        .where((m) => m.machineId.trim().toUpperCase() == 'DEFAULT' && m.location.trim().toLowerCase() == targetLoc)
        .toList();
    if (defaultMatches.isNotEmpty) {
      return defaultMatches;
    }

    // 3. THIRD PRIORITY: Match on station location across ANY configured terminal/station ID (e.g. 'MASAKALI')
    final locationMatches = allMappings
        .where((m) => m.location.trim().toLowerCase() == targetLoc)
        .toList();
    if (locationMatches.isNotEmpty) {
      return locationMatches;
    }

    // 4. FOURTH PRIORITY: Partial/Substring match on location (e.g. 'Dubai' matches 'Dubai Station')
    final partialMatches = allMappings.where((m) {
      final loc = m.location.trim().toLowerCase();
      return loc.isNotEmpty && (targetLoc.contains(loc) || loc.contains(targetLoc));
    }).toList();
    if (partialMatches.isNotEmpty) {
      return partialMatches;
    }

    // 5. FALLBACK: Default system printer
    return [
      StationPrinterMapping(
        machineId: mKey,
        location: location,
        printer: settings.defaultPrinterName,
        copies: sectionKey == 'tokens' ? settings.tokenCopiesCount : 1,
      ),
    ];
  }

  /// Resolve single printer for backwards compatibility
  static StationPrinterMapping resolvePrinter({
    required SystemSettings settings,
    required String machineId,
    required String sectionKey,
    required String location,
  }) {
    final list = resolvePrinters(
      settings: settings,
      machineId: machineId,
      sectionKey: sectionKey,
      location: location,
    );
    return list.first;
  }

  /// Fetch Item Master locations dynamically from API
  static Future<List<String>> fetchItemMasterLocations() async {
    final Set<String> locations = {'General Counter', 'Main Kitchen'};
    try {
      final results = await Future.wait([
        ApiClient.get(ApiEndpoints.stockLocations).catchError((_) => {}),
        ApiClient.get(ApiEndpoints.items).catchError((_) => {}),
      ]);
      final stockLocRes = results[0];
      if (stockLocRes != null && stockLocRes['data'] is List) {
        for (final loc in stockLocRes['data']) {
          final name = (loc['location_name'] ?? loc['name'] ?? loc['location_code'] ?? '').toString().trim();
          if (name.isNotEmpty) locations.add(name);
        }
      }
      final itemsRes = results[1];
      if (itemsRes != null && itemsRes['data'] is List) {
        for (final it in itemsRes['data']) {
          final l = (it['location'] ?? it['kitchen_location'] ?? '').toString().trim();
          if (l.isNotEmpty) locations.add(l);
        }
      }
    } catch (_) {}
    return locations.toList()..sort();
  }

  /// Interactive dialog for managing station printer mappings dynamically
  static void showRoutingDialog({
    required BuildContext context,
    required SystemSettings settings,
    required String sectionKey,
    required String title,
    required String currentMachineId,
    required VoidCallback onSaved,
  }) {
    List<StationPrinterMapping> currentList = getSectionMappings(settings, sectionKey);

    showDialog(
      context: context,
      builder: (ctx) {
        return _StationRoutingDialogWidget(
          settings: settings,
          sectionKey: sectionKey,
          title: title,
          initialMachineId: currentMachineId,
          initialList: currentList,
          onSaved: (newList) {
            saveSectionMappings(settings, sectionKey, newList);
            onSaved();
          },
        );
      },
    );
  }
}

class _StationRoutingDialogWidget extends StatefulWidget {
  final SystemSettings settings;
  final String sectionKey;
  final String title;
  final String initialMachineId;
  final List<StationPrinterMapping> initialList;
  final ValueChanged<List<StationPrinterMapping>> onSaved;

  const _StationRoutingDialogWidget({
    required this.settings,
    required this.sectionKey,
    required this.title,
    required this.initialMachineId,
    required this.initialList,
    required this.onSaved,
  });

  @override
  State<_StationRoutingDialogWidget> createState() => _StationRoutingDialogWidgetState();
}

class _StationRoutingDialogWidgetState extends State<_StationRoutingDialogWidget> {
  late List<StationPrinterMapping> _mappings;
  List<Printer> _printers = [];
  List<String> _itemLocations = [];
  bool _isLoading = true;

  String _selectedMachineId = LocalPreferences.getSystemHardwareId();
  String _selectedLocation = '';
  String _selectedPrinter = '';
  int _selectedCopies = 1;

  @override
  void initState() {
    super.initState();
    _mappings = List.from(widget.initialList);
    _selectedMachineId = widget.initialMachineId.trim().toUpperCase();
    _loadData();
  }

  Future<void> _loadData() async {
    final printerList = await Printing.listPrinters();
    final locations = await DevicePrinterRouting.fetchItemMasterLocations();

    if (!mounted) return;
    setState(() {
      _printers = printerList;
      _itemLocations = locations;
      _isLoading = false;
      if (_itemLocations.isNotEmpty) {
        _selectedLocation = _itemLocations.first;
      }
      if (_printers.isNotEmpty) {
        _selectedPrinter = _printers.first.name;
      }
    });
  }

  void _addOrUpdateMapping() {
    final loc = _selectedLocation.trim();
    if (loc.isEmpty) return;

    final mKey = _selectedMachineId.trim().toUpperCase();
    final prnKey = _selectedPrinter.trim().toLowerCase();
    final newEntry = StationPrinterMapping(
      machineId: mKey,
      location: loc,
      printer: _selectedPrinter,
      copies: _selectedCopies,
    );

    setState(() {
      // Remove any existing duplicate row for exact same (machineId + location + printer)
      _mappings.removeWhere(
        (m) =>
            m.machineId.toUpperCase() == mKey &&
            m.location.toLowerCase() == loc.toLowerCase() &&
            m.printer.trim().toLowerCase() == prnKey,
      );
      _mappings.add(newEntry);
    });
  }

  void _removeMapping(int index) {
    setState(() {
      _mappings.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final knownMachineIds = DevicePrinterRouting.getKnownMachineIds(widget.settings);
    if (!knownMachineIds.contains(_selectedMachineId)) {
      knownMachineIds.add(_selectedMachineId);
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.print_rounded, color: Color(0xFF0B5CAD)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 680,
        height: 520,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Machine ID, Item Master Location, Printer, and Copies. Duplicate machine + location mappings are automatically prevented.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 12),

                  // INPUT ROW TO ADD NEW MAPPING
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Add / Update Station Routing Entry',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            // Machine ID Dropdown
                            SizedBox(
                              width: 145,
                              child: DropdownButtonFormField<String>(
                                isExpanded: true,
                                value: _selectedMachineId,
                                decoration: const InputDecoration(
                                  labelText: 'Machine ID',
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  border: OutlineInputBorder(),
                                ),
                                items: knownMachineIds.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                                onChanged: (v) => setState(() => _selectedMachineId = v ?? LocalPreferences.getSystemHardwareId()),
                              ),
                            ),

                            // Item Master Location Dropdown
                            SizedBox(
                              width: 165,
                              child: DropdownButtonFormField<String>(
                                isExpanded: true,
                                value: _itemLocations.contains(_selectedLocation) ? _selectedLocation : (_itemLocations.isNotEmpty ? _itemLocations.first : null),
                                decoration: const InputDecoration(
                                  labelText: 'Item Master Location',
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  border: OutlineInputBorder(),
                                ),
                                items: _itemLocations.map((l) => DropdownMenuItem(value: l, child: Text(l, overflow: TextOverflow.ellipsis))).toList(),
                                onChanged: (v) => setState(() => _selectedLocation = v ?? ''),
                              ),
                            ),

                            // Printer Dropdown
                            SizedBox(
                              width: 155,
                              child: DropdownButtonFormField<String>(
                                isExpanded: true,
                                value: _printers.any((p) => p.name == _selectedPrinter)
                                    ? _selectedPrinter
                                    : (_printers.isNotEmpty ? _printers.first.name : null),
                                decoration: const InputDecoration(
                                  labelText: 'Output Printer',
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  border: OutlineInputBorder(),
                                ),
                                items: [
                                  const DropdownMenuItem(value: '', child: Text('Default System Printer')),
                                  ..._printers.map((p) => DropdownMenuItem(value: p.name, child: Text(p.name, overflow: TextOverflow.ellipsis))),
                                ],
                                onChanged: (v) => setState(() => _selectedPrinter = v ?? ''),
                              ),
                            ),

                            // Copies Dropdown
                            SizedBox(
                              width: 85,
                              child: DropdownButtonFormField<int>(
                                value: _selectedCopies,
                                decoration: const InputDecoration(
                                  labelText: 'Copies',
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  border: OutlineInputBorder(),
                                ),
                                items: List.generate(5, (i) => i + 1).map((c) => DropdownMenuItem(value: c, child: Text('$c'))).toList(),
                                onChanged: (v) => setState(() => _selectedCopies = v ?? 1),
                              ),
                            ),

                            // Add Button
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0B5CAD),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              onPressed: _addOrUpdateMapping,
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add Entry'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                  const Text(
                    'Active Configured Routing Table:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 6),

                  // MAPPINGS TABLE LIST
                  Expanded(
                    child: _mappings.isEmpty
                        ? const Center(child: Text('No station routing entries added yet.', style: TextStyle(color: Colors.grey)))
                        : ListView.separated(
                            itemCount: _mappings.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                            itemBuilder: (context, index) {
                              final item = _mappings[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.blue.shade200),
                                      ),
                                      child: Text(
                                        item.machineId,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0B5CAD)),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(item.location, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                          const Text('Item Master Location', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        item.printer.isEmpty ? 'Default Printer' : item.printer,
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                                      ),
                                    ),
                                    Text(
                                      '${item.copies} Cop${item.copies > 1 ? "ies" : "y"}',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                      onPressed: () => _removeMapping(index),
                                    ),
                                  ],
                                ),
                              );
                            },
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
        FilledButton(
          onPressed: () {
            widget.onSaved(_mappings);
            Navigator.pop(context);
          },
          child: const Text('Save Routing Settings'),
        ),
      ],
    );
  }
}
