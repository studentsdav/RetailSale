import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../controllers/restaurant/restaurant_controller.dart';
import '../../controllers/settings/property_info_controller.dart';
import '../../core/config/app_config.dart';
import '../../utils/branding_storage.dart';

enum TableCardLayout {
  googleStandee,  // Google Business Profile style standee poster with cut guide
  tentCard,       // Foldable 4x6 tabletop tent card
  acrylicStand,   // A6 vertical acrylic standee
  stickerDisc,    // 3x3 compact table sticker
  a4GridSheet,    // A4 grid of multiple tables
}

class TableQrDesignerScreen extends StatefulWidget {
  final List<dynamic> tables;
  final String? initialTableId;

  const TableQrDesignerScreen({
    super.key,
    required this.tables,
    this.initialTableId,
  });

  @override
  State<TableQrDesignerScreen> createState() => _TableQrDesignerScreenState();
}

class _TableQrDesignerScreenState extends State<TableQrDesignerScreen> {
  TableCardLayout _selectedLayout = TableCardLayout.googleStandee;
  
  // Customization controls
  late TextEditingController _baseUrlCtrl;
  late TextEditingController _pageHeadlineCtrl;
  late TextEditingController _restaurantNameCtrl;
  late TextEditingController _taglineCtrl;
  late TextEditingController _ctaTitleCtrl;
  late TextEditingController _wifiSsidCtrl;
  late TextEditingController _wifiPassCtrl;

  bool _showLogoInCenter = true;
  bool _useMultiColorFrame = true;
  bool _showWifiBadge = true;
  bool _showInstructions = true;
  bool _showFloorAreaBadge = true;
  bool _showTableNumber = true;

  Color _primaryColor = const Color(0xFF4285F4); // Google Blue / Brand Blue
  Color _accentColor = const Color(0xFFEA4335);  // Accent Red
  Color _cardBgColor = Colors.white;

  // Selected tables for bulk export
  final Set<String> _selectedTableIds = {};
  String? _previewTableId;
  String _selectedFloorFilter = 'ALL';
  String _selectedAreaFilter = 'ALL';
  bool _busy = false;

  // Property Branding Logo
  Uint8List? _propertyLogoBytes;
  String? _propertyLogoPath;

  // Color Theme Presets
  final List<Map<String, dynamic>> _themePresets = [
    {
      'name': 'Google Modern',
      'primary': const Color(0xFF4285F4),
      'accent': const Color(0xFFEA4335),
      'cardBg': Colors.white,
    },
    {
      'name': 'Royal Indigo',
      'primary': const Color(0xFF0B5CAD),
      'accent': const Color(0xFFD97706),
      'cardBg': Colors.white,
    },
    {
      'name': 'Luxury Charcoal',
      'primary': const Color(0xFF1E293B),
      'accent': const Color(0xFFEAB308),
      'cardBg': const Color(0xFF0F172A),
    },
    {
      'name': 'Crimson Bistro',
      'primary': const Color(0xFFB91C1C),
      'accent': const Color(0xFFF59E0B),
      'cardBg': Colors.white,
    },
    {
      'name': 'Emerald Dining',
      'primary': const Color(0xFF047857),
      'accent': const Color(0xFF10B981),
      'cardBg': Colors.white,
    },
    {
      'name': 'Sunset Amber',
      'primary': const Color(0xFFC2410C),
      'accent': const Color(0xFFF97316),
      'cardBg': Colors.white,
    },
  ];

  @override
  void initState() {
    super.initState();
    
    // Initialize default Base URL
    final serverBase = AppConfig.baseUrl;
    final defaultUrl = serverBase.isNotEmpty ? '$serverBase/dining' : 'http://localhost:5000/dining';
    
    _baseUrlCtrl = TextEditingController(text: defaultUrl);
    _pageHeadlineCtrl = TextEditingController(text: 'Here\'s your Table QR!');
    _restaurantNameCtrl = TextEditingController(text: 'Grand Royale Restaurant');
    _taglineCtrl = TextEditingController(text: 'Authentic Gourmet & Multi-Cuisine');
    _ctaTitleCtrl = TextEditingController(text: 'Scan to View Menu & Order');
    _wifiSsidCtrl = TextEditingController(text: 'GrandRoyale_Guest_WiFi');
    _wifiPassCtrl = TextEditingController(text: 'Welcome@123');

    // Select all tables by default
    for (final tbl in widget.tables) {
      final id = tbl['id']?.toString() ?? '';
      if (id.isNotEmpty) _selectedTableIds.add(id);
    }

    if (widget.initialTableId != null && widget.initialTableId!.isNotEmpty) {
      _previewTableId = widget.initialTableId;
    } else if (widget.tables.isNotEmpty) {
      _previewTableId = widget.tables.first['id']?.toString();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBrandingDetails();
    });
  }

  void _loadBrandingDetails() async {
    try {
      final propCtrl = Provider.of<PropertyInfoController>(context, listen: false);
      if (propCtrl.data == null) {
        await propCtrl.load();
      }
      final propInfo = propCtrl.data;
      if (propInfo != null) {
        if (propInfo.propertyName.isNotEmpty) {
          _restaurantNameCtrl.text = propInfo.propertyName;
        }
        if (propInfo.logoPath != null && propInfo.logoPath!.trim().isNotEmpty) {
          _propertyLogoPath = propInfo.logoPath!.trim();
        }
      }

      if (_propertyLogoPath == null || _propertyLogoPath!.isEmpty) {
        _propertyLogoPath = await BrandingStorage.getCurrentLogoPath();
      }

      if (_propertyLogoPath != null && _propertyLogoPath!.isNotEmpty) {
        final bytes = await _fetchLogoBytes(_propertyLogoPath!);
        if (mounted && bytes != null) {
          setState(() {
            _propertyLogoBytes = bytes;
          });
        }
      }
    } catch (_) {}
  }

  Future<Uint8List?> _fetchLogoBytes(String path) async {
    try {
      final clean = path.trim();
      if (clean.startsWith('data:image') || clean.contains(';base64,') || (clean.length > 100 && !clean.contains(' '))) {
        final base64Str = clean.contains(',') ? clean.split(',').last : clean;
        return base64Decode(base64Str.trim());
      }
      if (!kIsWeb && File(clean).existsSync()) {
        return await File(clean).readAsBytes();
      }
      final storageBytes = await BrandingStorage.readLogoBytes(clean);
      if (storageBytes != null) return storageBytes;

      String url = clean;
      if (clean.startsWith('/') || clean.startsWith('uploads/')) {
        final baseUrl = AppConfig.baseUrl.replaceAll(RegExp(r'/$'), '');
        url = clean.startsWith('/') ? '$baseUrl$clean' : '$baseUrl/$clean';
      }
      if (url.startsWith('http://') || url.startsWith('https://')) {
        final client = HttpClient();
        final req = await client.getUrl(Uri.parse(url));
        final resp = await req.close();
        final bytes = await consolidateHttpClientResponseBytes(resp);
        return bytes;
      }
    } catch (_) {}
    return null;
  }

  @override
  void dispose() {
    _baseUrlCtrl.dispose();
    _pageHeadlineCtrl.dispose();
    _restaurantNameCtrl.dispose();
    _taglineCtrl.dispose();
    _ctaTitleCtrl.dispose();
    _wifiSsidCtrl.dispose();
    _wifiPassCtrl.dispose();
    super.dispose();
  }

  String _buildTableUrl(dynamic table) {
    final tableId = table['id']?.toString() ?? '';
    final tableName = table['table_name']?.toString() ?? '';
    final base = _baseUrlCtrl.text.trim();
    final cleanBase = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    return '$cleanBase?table_id=$tableId&table_name=${Uri.encodeComponent(tableName)}';
  }

  dynamic _getPreviewTable() {
    if (_previewTableId == null) return widget.tables.isNotEmpty ? widget.tables.first : null;
    return widget.tables.firstWhere(
      (t) => t['id']?.toString() == _previewTableId,
      orElse: () => widget.tables.isNotEmpty ? widget.tables.first : null,
    );
  }

  List<dynamic> _getFilteredTables() {
    return widget.tables.where((tbl) {
      final floorId = tbl['floor_id']?.toString() ?? '';
      final areaId = tbl['dining_area_id']?.toString() ?? '';
      
      if (_selectedFloorFilter != 'ALL' && floorId != _selectedFloorFilter) return false;
      if (_selectedAreaFilter != 'ALL' && areaId != _selectedAreaFilter) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Provider.of<RestaurantController>(context);
    final previewTable = _getPreviewTable();
    final filteredTables = _getFilteredTables();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.qr_code_2, color: _primaryColor, size: 24),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Table QR Code Designer & Exporter',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                ),
                Text(
                  'Design tabletop tent cards, acrylic standees, and export printable A4 sheets',
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy, size: 20),
            tooltip: 'Copy Preview Table URL',
            onPressed: previewTable == null ? null : () {
              final url = _buildTableUrl(previewTable);
              Clipboard.setData(ClipboardData(text: url));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Copied Dining URL: $url'),
                  backgroundColor: Colors.green.shade700,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: _busy ? null : () => _exportAndPrintPdf(context, isBulk: false),
            icon: const Icon(Icons.print_outlined, size: 18),
            label: const Text('Print Single Card'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF047857),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: _busy ? null : () => _exportAndPrintPdf(context, isBulk: true),
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
            label: Text('Export All (${_selectedTableIds.length}) to PDF'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LEFT PANEL: Design & Content Controls
          SizedBox(
            width: 440,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCardLayoutSelector(),
                  const SizedBox(height: 16),
                  _buildThemeSelector(),
                  const SizedBox(height: 16),
                  _buildContentConfigurationCard(),
                  const SizedBox(height: 16),
                  _buildWifiConfigurationCard(),
                  const SizedBox(height: 16),
                  _buildTableSelectionList(ctrl, filteredTables),
                ],
              ),
            ),
          ),

          // VERTICAL DIVIDER
          const VerticalDivider(width: 1, color: Color(0xFFE2E8F0)),

          // RIGHT PANEL: Real-time Live Preview
          Expanded(
            child: Container(
              color: const Color(0xFFF1F5F9),
              child: Column(
                children: [
                  // Top Toolbar for preview
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    color: Colors.white,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF64748B)),
                            const SizedBox(width: 8),
                            Text(
                              'Live Preview: ${previewTable != null ? "Table ${previewTable['table_name']}" : "No Table Selected"}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _selectedLayout.name.toUpperCase(),
                                style: const TextStyle(color: Color(0xFF0369A1), fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        if (previewTable != null)
                          Text(
                            _buildTableUrl(previewTable),
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontFamily: 'monospace'),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),

                  // Card Render Zone
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(32),
                        child: previewTable == null
                            ? const Text('No table selected to preview', style: TextStyle(color: Colors.grey))
                            : _buildLiveCardPreview(previewTable),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS BUILDERS ---

  Widget _buildCardLayoutSelector() {
    return _sectionContainer(
      title: '1. Card Format & Layout',
      icon: Icons.dashboard_customize_outlined,
      child: Column(
        children: [
          _layoutOptionTile(
            title: 'Google Standee Poster',
            subtitle: 'A4 Sheet with scissors cut guide',
            icon: Icons.crop_free_outlined,
            layout: TableCardLayout.googleStandee,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _layoutOptionTile(
                  title: 'Tent Card',
                  subtitle: '4x6 Foldable tabletop',
                  icon: Icons.filter_frames_outlined,
                  layout: TableCardLayout.tentCard,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _layoutOptionTile(
                  title: 'Acrylic Standee',
                  subtitle: 'A6 Portrait display',
                  icon: Icons.stay_current_portrait_outlined,
                  layout: TableCardLayout.acrylicStand,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _layoutOptionTile(
                  title: 'Table Sticker',
                  subtitle: '3x3 Compact sticker',
                  icon: Icons.crop_square_outlined,
                  layout: TableCardLayout.stickerDisc,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _layoutOptionTile(
                  title: 'A4 Grid Sheet',
                  subtitle: 'Bulk printable 2x2',
                  icon: Icons.grid_view_outlined,
                  layout: TableCardLayout.a4GridSheet,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _layoutOptionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required TableCardLayout layout,
  }) {
    final isSelected = _selectedLayout == layout;
    return InkWell(
      onTap: () => setState(() => _selectedLayout = layout),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? _primaryColor.withOpacity(0.08) : Colors.white,
          border: Border.all(
            color: isSelected ? _primaryColor : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: isSelected ? _primaryColor : const Color(0xFF64748B)),
                const Spacer(),
                if (isSelected)
                  Icon(Icons.check_circle, size: 16, color: _primaryColor),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: isSelected ? _primaryColor : const Color(0xFF0F172A),
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeSelector() {
    return _sectionContainer(
      title: '2. Color Theme & Branding',
      icon: Icons.palette_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _themePresets.map((preset) {
              final isCurrent = _primaryColor == preset['primary'] && _cardBgColor == preset['cardBg'];
              return ChoiceChip(
                selected: isCurrent,
                selectedColor: (preset['primary'] as Color).withOpacity(0.2),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                  side: BorderSide(
                    color: isCurrent ? preset['primary'] : const Color(0xFFCBD5E1),
                    width: isCurrent ? 2 : 1,
                  ),
                ),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: preset['primary'],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      preset['name'],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        color: isCurrent ? preset['primary'] : const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
                onSelected: (_) {
                  setState(() {
                    _primaryColor = preset['primary'];
                    _accentColor = preset['accent'];
                    _cardBgColor = preset['cardBg'];
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Checkbox(
                value: _showLogoInCenter,
                activeColor: _primaryColor,
                onChanged: (v) => setState(() => _showLogoInCenter = v ?? true),
              ),
              const Text('Center Brand Emblem / Logo in QR', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContentConfigurationCard() {
    return _sectionContainer(
      title: '3. QR Content & Text',
      icon: Icons.edit_note_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _textField('Base URL (Deep link / Web)', _baseUrlCtrl, hint: 'https://yourdomain.com/dining'),
          const SizedBox(height: 8),
          _textField('Sheet Top Headline', _pageHeadlineCtrl, hint: 'Here’s your Table QR!'),
          const SizedBox(height: 8),
          _textField('Restaurant Name', _restaurantNameCtrl),
          const SizedBox(height: 8),
          _textField('Tagline / Subtitle', _taglineCtrl),
          const SizedBox(height: 8),
          _textField('Call to Action Text', _ctaTitleCtrl),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _checkToggle('Table #', _showTableNumber, (v) => setState(() => _showTableNumber = v)),
              _checkToggle('Floor / Area', _showFloorAreaBadge, (v) => setState(() => _showFloorAreaBadge = v)),
              _checkToggle('4-Color Frame', _useMultiColorFrame, (v) => setState(() => _useMultiColorFrame = v)),
              _checkToggle('3-Step Steps', _showInstructions, (v) => setState(() => _showInstructions = v)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWifiConfigurationCard() {
    return _sectionContainer(
      title: '4. Guest Wi-Fi Access Badge',
      icon: Icons.wifi,
      child: Column(
        children: [
          Row(
            children: [
              Checkbox(
                value: _showWifiBadge,
                activeColor: _primaryColor,
                onChanged: (v) => setState(() => _showWifiBadge = v ?? true),
              ),
              const Text('Display Wi-Fi Details on Card', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          if (_showWifiBadge) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(child: _textField('Wi-Fi Network (SSID)', _wifiSsidCtrl)),
                const SizedBox(width: 8),
                Expanded(child: _textField('Wi-Fi Password', _wifiPassCtrl)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTableSelectionList(RestaurantController ctrl, List<dynamic> filteredTables) {
    return _sectionContainer(
      title: '5. Select Tables to Print (${_selectedTableIds.length}/${widget.tables.length})',
      icon: Icons.table_restaurant_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Dropdowns
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedFloorFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Floor',
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: 'ALL', child: Text('All Floors', style: TextStyle(fontSize: 12))),
                    ...ctrl.floors.map((f) => DropdownMenuItem(
                      value: f['id']?.toString() ?? '',
                      child: Text(f['name'] ?? '', style: const TextStyle(fontSize: 12)),
                    )),
                  ],
                  onChanged: (v) => setState(() => _selectedFloorFilter = v ?? 'ALL'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedAreaFilter,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Area',
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: 'ALL', child: Text('All Areas', style: TextStyle(fontSize: 12))),
                    ...ctrl.diningAreas.map((a) => DropdownMenuItem(
                      value: a['id']?.toString() ?? '',
                      child: Text(a['name'] ?? '', style: const TextStyle(fontSize: 12)),
                    )),
                  ],
                  onChanged: (v) => setState(() => _selectedAreaFilter = v ?? 'ALL'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    for (final t in filteredTables) {
                      final id = t['id']?.toString() ?? '';
                      if (id.isNotEmpty) _selectedTableIds.add(id);
                    }
                  });
                },
                icon: const Icon(Icons.select_all, size: 16),
                label: const Text('Select All', style: TextStyle(fontSize: 11)),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    for (final t in filteredTables) {
                      _selectedTableIds.remove(t['id']?.toString());
                    }
                  });
                },
                icon: const Icon(Icons.deselect, size: 16),
                label: const Text('Deselect All', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
          const Divider(height: 1),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: filteredTables.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, idx) {
                final tbl = filteredTables[idx];
                final id = tbl['id']?.toString() ?? '';
                final isChecked = _selectedTableIds.contains(id);
                final isPreviewing = _previewTableId == id;

                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: Checkbox(
                    value: isChecked,
                    activeColor: _primaryColor,
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selectedTableIds.add(id);
                        } else {
                          _selectedTableIds.remove(id);
                        }
                      });
                    },
                  ),
                  title: Text(
                    'Table ${tbl['table_name']}',
                    style: TextStyle(
                      fontWeight: isPreviewing ? FontWeight.bold : FontWeight.w600,
                      color: isPreviewing ? _primaryColor : const Color(0xFF0F172A),
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Text(
                    '${tbl['floor']?['name'] ?? ''} | ${tbl['dining_area']?['name'] ?? ''} (Seats: ${tbl['capacity'] ?? 4})',
                    style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                  ),
                  trailing: IconButton(
                    icon: Icon(
                      isPreviewing ? Icons.visibility : Icons.visibility_outlined,
                      color: isPreviewing ? _primaryColor : const Color(0xFF94A3B8),
                      size: 18,
                    ),
                    tooltip: 'Preview on Card',
                    onPressed: () => setState(() => _previewTableId = id),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- LIVE VISUAL CARD PREVIEW (ON-SCREEN) ---

  Widget _buildLiveCardPreview(dynamic table) {
    final qrData = _buildTableUrl(table);
    final tableName = table['table_name']?.toString() ?? '1';
    final floorName = table['floor']?['name']?.toString() ?? '';
    final areaName = table['dining_area']?['name']?.toString() ?? '';
    final isDark = _cardBgColor == const Color(0xFF0F172A);

    switch (_selectedLayout) {
      case TableCardLayout.googleStandee:
        return _buildGoogleStandeeWidget(qrData, tableName, floorName, areaName, isDark);
      case TableCardLayout.tentCard:
        return _buildTentCardWidget(qrData, tableName, floorName, areaName, isDark);
      case TableCardLayout.acrylicStand:
        return _buildAcrylicStandWidget(qrData, tableName, floorName, areaName, isDark);
      case TableCardLayout.stickerDisc:
        return _buildStickerDiscWidget(qrData, tableName, floorName, areaName, isDark);
      case TableCardLayout.a4GridSheet:
        return _buildA4GridSheetPreview(table, isDark);
    }
  }

  Widget _buildGoogleStandeeWidget(String qrData, String tableName, String floorName, String areaName, bool isDark) {
    return Container(
      width: 470,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Top Sheet Sub-header (e.g. Google Business Profile / Restaurant Name)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 6),
                decoration: const BoxDecoration(
                  color: Color(0xFF4285F4),
                  shape: BoxShape.circle,
                ),
              ),
              Text(
                _restaurantNameCtrl.text,
                style: const TextStyle(
                  color: Color(0xFF5F6368),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // 2. Big Bold Title: "Here's your Table QR!"
          Text(
            _pageHeadlineCtrl.text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF202124),
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 20),

          // 3. Dotted Cutout Line with Scissors Icon
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Dotted outline box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFF94A3B8),
                    width: 1.2,
                    style: BorderStyle.solid,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  children: [
                    // 4. Standee Card Badge with soft blue border
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(36),
                        border: Border.all(
                          color: const Color(0xFFD0E1FD), // Google Light Blue Outline
                          width: 3.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4285F4).withOpacity(0.06),
                            blurRadius: 18,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Restaurant Brand
                          Text(
                            _restaurantNameCtrl.text,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _primaryColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 6),

                          // CTA Headline
                          Text(
                            _ctaTitleCtrl.text,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF202124),
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // QR Code Container with 4-Color Google Frame or Brand Color Frame
                          _buildQrWithFourColorFrame(qrData),

                          const SizedBox(height: 14),

                          // Table Identifier / Subtitle
                          if (_showTableNumber)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                _showFloorAreaBadge && (floorName.isNotEmpty || areaName.isNotEmpty)
                                    ? 'TABLE $tableName  •  ${[floorName, areaName].where((s) => s.isNotEmpty).join(" - ")}'
                                    : 'TABLE $tableName',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFF202124),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),

                          // Wi-Fi Details Badge (Responsive Wrap)
                          if (_showWifiBadge && _wifiSsidCtrl.text.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F0FE),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 6,
                                runSpacing: 2,
                                children: [
                                  const Icon(Icons.wifi, size: 13, color: Color(0xFF1A73E8)),
                                  Text(
                                    'Wi-Fi: ${_wifiSsidCtrl.text}  |  Pass: ${_wifiPassCtrl.text}',
                                    style: const TextStyle(
                                      color: Color(0xFF1A73E8),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // 3-Step Instructions
                          if (_showInstructions) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Wrap(
                                alignment: WrapAlignment.spaceAround,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 4,
                                runSpacing: 4,
                                children: [
                                  _stepPill('1. Scan QR', Icons.qr_code_scanner, false),
                                  const Icon(Icons.arrow_forward_ios, size: 8, color: Color(0xFF94A3B8)),
                                  _stepPill('2. Verify OTP', Icons.password, false),
                                  const Icon(Icons.arrow_forward_ios, size: 8, color: Color(0xFF94A3B8)),
                                  _stepPill('3. Enjoy Food', Icons.lunch_dining, false),
                                ],
                              ),
                            ),
                          ],
                        ],
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
  }

  // --- CENTER EMBLEM BUILDERS ---

  Widget _buildCenterEmblemWidget({required double size, required Color borderColor}) {
    return _defaultCutleryIcon(borderColor, size);
  }

  Widget _defaultCutleryIcon(Color borderColor, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 4),
        ],
      ),
      child: Center(
        child: Icon(Icons.restaurant, color: borderColor, size: size * 0.58),
      ),
    );
  }

  Widget _buildQrWithFourColorFrame(String qrData) {
    if (!_useMultiColorFrame) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _primaryColor, width: 3),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 160,
              errorCorrectionLevel: QrErrorCorrectLevel.H,
              eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: _primaryColor),
              dataModuleStyle: QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: _primaryColor,
              ),
            ),
            if (_showLogoInCenter)
              _buildCenterEmblemWidget(size: 40, borderColor: _primaryColor),
          ],
        ),
      );
    }

    // Google 4-color sweep gradient frame (Blue, Red, Yellow, Green)
    return Container(
      padding: const EdgeInsets.all(4.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const SweepGradient(
          colors: [
            Color(0xFF4285F4), // Blue
            Color(0xFFEA4335), // Red
            Color(0xFFFBBC05), // Yellow
            Color(0xFF34A853), // Green
            Color(0xFF4285F4), // Wrap back to blue
          ],
          stops: [0.0, 0.25, 0.5, 0.75, 1.0],
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 160,
              errorCorrectionLevel: QrErrorCorrectLevel.H,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Color(0xFF202124),
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Color(0xFF202124),
              ),
            ),
            if (_showLogoInCenter)
              _buildCenterEmblemWidget(size: 40, borderColor: const Color(0xFF4285F4)),
          ],
        ),
      ),
    );
  }

  Widget _buildTentCardWidget(String qrData, String tableName, String floorName, String areaName, bool isDark) {
    return Container(
      width: 360,
      decoration: BoxDecoration(
        color: _cardBgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: _primaryColor.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Banner
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: _primaryColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Column(
              children: [
                Text(
                  _restaurantNameCtrl.text.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 1.2,
                  ),
                ),
                if (_taglineCtrl.text.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    _taglineCtrl.text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                // Table Number Badge (Responsive Wrap to prevent overflow)
                if (_showTableNumber)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: _accentColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _accentColor.withOpacity(0.4)),
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 2,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.table_bar, color: _accentColor, size: 15),
                            const SizedBox(width: 4),
                            Text(
                              'TABLE $tableName',
                              style: TextStyle(
                                color: _accentColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        if (_showFloorAreaBadge && (floorName.isNotEmpty || areaName.isNotEmpty))
                          Text(
                            '• ${[floorName, areaName].where((s) => s.isNotEmpty).join(" - ")}',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : const Color(0xFF64748B),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),

                const SizedBox(height: 14),

                // QR Code Container
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 10,
                      ),
                    ],
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      QrImageView(
                        data: qrData,
                        version: QrVersions.auto,
                        size: 180,
                        errorCorrectionLevel: QrErrorCorrectLevel.H,
                        eyeStyle: QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: _primaryColor,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      if (_showLogoInCenter)
                        _buildCenterEmblemWidget(size: 44, borderColor: _primaryColor),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Call To Action
                Text(
                  _ctaTitleCtrl.text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),

                // 3-Step Instructions
                if (_showInstructions) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.spaceAround,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        _stepPill('1. Scan QR', Icons.qr_code_scanner, isDark),
                        const Icon(Icons.arrow_forward_ios, size: 9, color: Color(0xFF94A3B8)),
                        _stepPill('2. Verify OTP', Icons.password, isDark),
                        const Icon(Icons.arrow_forward_ios, size: 9, color: Color(0xFF94A3B8)),
                        _stepPill('3. Enjoy Food', Icons.lunch_dining, isDark),
                      ],
                    ),
                  ),
                ],

                // Wi-Fi Details Badge
                if (_showWifiBadge && _wifiSsidCtrl.text.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 2,
                      children: [
                        const Icon(Icons.wifi, size: 14, color: Color(0xFF0284C7)),
                        Text(
                          'Wi-Fi: ${_wifiSsidCtrl.text}  |  Pass: ${_wifiPassCtrl.text}',
                          style: const TextStyle(
                            color: Color(0xFF0284C7),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

        ],
      ),
    );
  }

  Widget _buildAcrylicStandWidget(String qrData, String tableName, String floorName, String areaName, bool isDark) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardBgColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 24, offset: const Offset(0, 10)),
        ],
        border: Border.all(color: _primaryColor, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.restaurant, color: _primaryColor, size: 32),
          const SizedBox(height: 8),
          Text(
            _restaurantNameCtrl.text.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: _primaryColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'TABLE $tableName',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 160,
                  errorCorrectionLevel: QrErrorCorrectLevel.H,
                  eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: _primaryColor),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Color(0xFF0F172A),
                  ),
                ),
                if (_showLogoInCenter)
                  _buildCenterEmblemWidget(size: 38, borderColor: _primaryColor),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _ctaTitleCtrl.text,
            style: TextStyle(
              color: isDark ? Colors.white70 : const Color(0xFF334155),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickerDiscWidget(String qrData, String tableName, String floorName, String areaName, bool isDark) {
    return Container(
      width: 240,
      height: 240,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBgColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 16),
        ],
        border: Border.all(color: _primaryColor, width: 3),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'TABLE $tableName',
            style: TextStyle(color: _primaryColor, fontWeight: FontWeight.w900, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Stack(
            alignment: Alignment.center,
            children: [
              QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 120,
                errorCorrectionLevel: QrErrorCorrectLevel.H,
                eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: _primaryColor),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF0F172A),
                ),
              ),
              if (_showLogoInCenter)
                _buildCenterEmblemWidget(size: 28, borderColor: _primaryColor),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Scan to Order',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildA4GridSheetPreview(dynamic table, bool isDark) {
    return Container(
      width: 480,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 16),
        ],
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'A4 Printable Sheet Preview (2x2 Grid)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _primaryColor),
              ),
              const Text('Standard A4 Portrait', style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.85,
            ),
            itemCount: 4,
            itemBuilder: (context, i) {
              final tbl = i < widget.tables.length ? widget.tables[i] : table;
              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: _primaryColor.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'TABLE ${tbl['table_name']}',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _primaryColor),
                    ),
                    const SizedBox(height: 4),
                    QrImageView(
                      data: _buildTableUrl(tbl),
                      size: 80,
                      version: QrVersions.auto,
                    ),
                    const SizedBox(height: 4),
                    const Text('Scan to Order', style: TextStyle(fontSize: 8, color: Colors.grey)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _stepPill(String text, IconData icon, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: _primaryColor),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : const Color(0xFF475569),
          ),
        ),
      ],
    );
  }

  // --- HIGH-FIDELITY PDF CARD BUILDER ---

  String _cleanPdfText(String text) {
    return text
        .replaceAll('’', "'")
        .replaceAll('‘', "'")
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('•', '-')
        .replaceAll('✂', '--')
        .replaceAll('🍽️', '')
        .replaceAll('🍽', '')
        .replaceAll('—', '-')
        .replaceAll('–', '-');
  }

  pw.Widget _buildPdfCenterEmblem({
    required double size,
    required PdfColor borderColor,
    pw.ImageProvider? logoImage,
  }) {
    // Restaurant Dining Cutlery Vector Icon (Crossed Knife & Spoon/Fork)
    final r = (borderColor.red * 255).round();
    final g = (borderColor.green * 255).round();
    final b = (borderColor.blue * 255).round();
    final hexColor = '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}';
    final svgCutlery = '<svg viewBox="0 0 24 24" width="${size * 0.7}" height="${size * 0.7}"><path fill="$hexColor" d="M8.1 13.34l2.83-2.83L3.91 3.5c-1.56 1.56-1.56 4.09 0 5.66l4.19 4.18zm6.78-1.81c1.53.71 3.68.21 5.27-1.38 1.91-1.91 2.28-4.65.81-6.12-1.46-1.46-4.2-1.1-6.12.81-1.59 1.59-2.09 3.74-1.38 5.27L3.7 19.87l1.41 1.41L12 14.41l6.88 6.88 1.41-1.41L13.41 13l1.47-1.47z"/></svg>';

    return pw.Container(
      width: size,
      height: size,
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        shape: pw.BoxShape.circle,
        border: pw.Border.all(color: borderColor, width: 2),
      ),
      child: pw.Center(
        child: pw.SvgImage(
          svg: svgCutlery,
          width: size * 0.60,
          height: size * 0.60,
        ),
      ),
    );
  }

  pw.Widget _buildPdfCardForTable({
    required dynamic tbl,
    required String qrUrl,
    required PdfColor primaryPdfColor,
    required PdfColor accentPdfColor,
    required bool isA4Grid,
    pw.ImageProvider? logoImage,
  }) {
    final tblName = tbl['table_name']?.toString() ?? '1';
    final flName = tbl['floor']?['name']?.toString() ?? '';
    final arName = tbl['dining_area']?['name']?.toString() ?? '';

    switch (_selectedLayout) {
      case TableCardLayout.googleStandee:
        return _buildPdfGoogleStandee(tblName, flName, arName, qrUrl, primaryPdfColor, accentPdfColor, logoImage);
      case TableCardLayout.tentCard:
      case TableCardLayout.a4GridSheet:
        return _buildPdfTentCard(tblName, flName, arName, qrUrl, primaryPdfColor, accentPdfColor, isA4Grid, logoImage);
      case TableCardLayout.acrylicStand:
        return _buildPdfAcrylicStand(tblName, flName, arName, qrUrl, primaryPdfColor, accentPdfColor, isA4Grid, logoImage);
      case TableCardLayout.stickerDisc:
        return _buildPdfStickerDisc(tblName, flName, arName, qrUrl, primaryPdfColor, accentPdfColor, isA4Grid, logoImage);
    }
  }

  pw.Widget _buildPdfGoogleStandee(
    String tblName,
    String flName,
    String arName,
    String qrUrl,
    PdfColor primaryPdfColor,
    PdfColor accentPdfColor,
    pw.ImageProvider? logoImage,
  ) {
    return pw.Container(
      width: 360,
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // 1. Top Mini Brand Row
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Container(
                width: 6,
                height: 6,
                margin: const pw.EdgeInsets.only(right: 4),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFF4285F4),
                  shape: pw.BoxShape.circle,
                ),
              ),
              pw.Text(
                _cleanPdfText(_restaurantNameCtrl.text),
                style: pw.TextStyle(
                  color: PdfColors.grey700,
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 6),

          // 2. Big Title: "Here's your Table QR!"
          pw.Text(
            _cleanPdfText(_pageHeadlineCtrl.text),
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              color: PdfColor.fromInt(0xFF202124),
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 18),

          // 3. Cutout Dotted Box
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(
                color: PdfColors.grey500,
                width: 1,
                style: pw.BorderStyle.dashed,
              ),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Column(
              children: [
                // 4. Standee Card Badge with soft light blue border
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(28)),
                    border: pw.Border.all(
                      color: PdfColor.fromInt(0xFFD0E1FD), // Light blue border
                      width: 3,
                    ),
                  ),
                  child: pw.Column(
                    mainAxisSize: pw.MainAxisSize.min,
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      // Restaurant Brand
                      pw.Text(
                        _cleanPdfText(_restaurantNameCtrl.text),
                        style: pw.TextStyle(
                          color: primaryPdfColor,
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),

                      // CTA Title
                      pw.Text(
                        _cleanPdfText(_ctaTitleCtrl.text),
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          color: PdfColor.fromInt(0xFF202124),
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 14),

                      // 4-Color QR Code Frame
                      _buildPdfQrWithFourColorFrame(qrUrl, primaryPdfColor, logoImage),

                      pw.SizedBox(height: 12),

                      // Table Identifier
                      if (_showTableNumber)
                        pw.Text(
                          _showFloorAreaBadge && (flName.isNotEmpty || arName.isNotEmpty)
                              ? _cleanPdfText('TABLE $tblName  -  ${[flName, arName].where((s) => s.isNotEmpty).join(" - ")}')
                              : 'TABLE $tblName',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            color: PdfColor.fromInt(0xFF202124),
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),

                      // Wi-Fi Details
                      if (_showWifiBadge && _wifiSsidCtrl.text.isNotEmpty) ...[
                        pw.SizedBox(height: 8),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: pw.BoxDecoration(
                            color: PdfColor.fromInt(0xFFE8F0FE),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                          ),
                          child: pw.Text(
                            _cleanPdfText('Wi-Fi: ${_wifiSsidCtrl.text}  |  Pass: ${_wifiPassCtrl.text}'),
                            style: pw.TextStyle(
                              color: PdfColor.fromInt(0xFF1A73E8),
                              fontSize: 7.5,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                      ],

                      // 3-Step Instructions
                      if (_showInstructions) ...[
                        pw.SizedBox(height: 8),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: pw.BoxDecoration(
                            color: PdfColor.fromInt(0xFFF8FAFC),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                            border: pw.Border.all(color: PdfColors.grey300, width: 0.6),
                          ),
                          child: pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                            children: [
                              pw.Text('1. Scan QR', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: primaryPdfColor)),
                              pw.Text('>', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
                              pw.Text('2. Verify OTP', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: primaryPdfColor)),
                              pw.Text('>', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
                              pw.Text('3. Enjoy Food', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: primaryPdfColor)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfQrWithFourColorFrame(String qrUrl, PdfColor primaryPdfColor, pw.ImageProvider? logoImage) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(16)),
        border: pw.Border.all(
          color: _useMultiColorFrame ? PdfColor.fromInt(0xFF4285F4) : primaryPdfColor,
          width: 3.2,
        ),
      ),
      child: pw.Stack(
        alignment: pw.Alignment.center,
        children: [
          pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(errorCorrectLevel: pw.BarcodeQRCorrectionLevel.high),
            data: qrUrl,
            width: 130,
            height: 130,
            color: PdfColor.fromInt(0xFF202124),
          ),
          if (_showLogoInCenter)
            _buildPdfCenterEmblem(
              size: 36,
              borderColor: _useMultiColorFrame ? PdfColor.fromInt(0xFF4285F4) : primaryPdfColor,
              logoImage: logoImage,
            ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfTentCard(
    String tblName,
    String flName,
    String arName,
    String qrUrl,
    PdfColor primaryPdfColor,
    PdfColor accentPdfColor,
    bool isA4Grid,
    pw.ImageProvider? logoImage,
  ) {
    final double cardWidth = isA4Grid ? 250 : 270;
    final double qrSize = isA4Grid ? 100 : 125;

    return pw.Container(
      width: cardWidth,
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(14)),
        border: pw.Border.all(color: primaryPdfColor, width: 1.5),
      ),
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          // 1. Solid Top Header Banner
          pw.Container(
            width: double.infinity,
            padding: pw.EdgeInsets.symmetric(vertical: isA4Grid ? 8 : 12, horizontal: 12),
            decoration: pw.BoxDecoration(
              color: primaryPdfColor,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(12),
                topRight: pw.Radius.circular(12),
              ),
            ),
            child: pw.Column(
              children: [
                pw.Text(
                  _cleanPdfText(_restaurantNameCtrl.text.toUpperCase()),
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: isA4Grid ? 11 : 13,
                    letterSpacing: 0.8,
                  ),
                ),
                if (_taglineCtrl.text.isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    _cleanPdfText(_taglineCtrl.text),
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: isA4Grid ? 7 : 8,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 2. Card Content Body
          pw.Padding(
            padding: pw.EdgeInsets.all(isA4Grid ? 8 : 12),
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                // Table Number Badge
                if (_showTableNumber)
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFFEF3C7),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(16)),
                      border: pw.Border.all(color: accentPdfColor, width: 1),
                    ),
                    child: pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.Text(
                          'TABLE $tblName',
                          style: pw.TextStyle(
                            color: accentPdfColor,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: isA4Grid ? 10 : 11,
                          ),
                        ),
                        if (_showFloorAreaBadge && (flName.isNotEmpty || arName.isNotEmpty)) ...[
                          pw.SizedBox(width: 4),
                          pw.Text(
                            _cleanPdfText('-  ${[flName, arName].where((s) => s.isNotEmpty).join(" - ")}'),
                            style: const pw.TextStyle(
                              color: PdfColors.grey700,
                              fontSize: 8,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                pw.SizedBox(height: isA4Grid ? 6 : 10),

                // QR Code Container with Central Emblem
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
                  ),
                  child: pw.Stack(
                    alignment: pw.Alignment.center,
                    children: [
                      pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(errorCorrectLevel: pw.BarcodeQRCorrectionLevel.high),
                        data: qrUrl,
                        width: qrSize,
                        height: qrSize,
                        color: primaryPdfColor,
                      ),
                      if (_showLogoInCenter)
                        _buildPdfCenterEmblem(
                          size: isA4Grid ? 22 : 28,
                          borderColor: primaryPdfColor,
                          logoImage: logoImage,
                        ),
                    ],
                  ),
                ),

                pw.SizedBox(height: isA4Grid ? 6 : 10),

                // Call to action
                pw.Text(
                  _cleanPdfText(_ctaTitleCtrl.text),
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    color: PdfColors.blueGrey900,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: isA4Grid ? 9 : 11,
                  ),
                ),

                // 3-Step Instructions Box
                if (_showInstructions) ...[
                  pw.SizedBox(height: 6),
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFF8FAFC),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      border: pw.Border.all(color: PdfColors.grey300, width: 0.6),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                      children: [
                        pw.Text('1. Scan QR', style: pw.TextStyle(fontSize: isA4Grid ? 6 : 7.5, fontWeight: pw.FontWeight.bold, color: primaryPdfColor)),
                        pw.Text('>', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
                        pw.Text('2. Verify OTP', style: pw.TextStyle(fontSize: isA4Grid ? 6 : 7.5, fontWeight: pw.FontWeight.bold, color: primaryPdfColor)),
                        pw.Text('>', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
                        pw.Text('3. Enjoy Food', style: pw.TextStyle(fontSize: isA4Grid ? 6 : 7.5, fontWeight: pw.FontWeight.bold, color: primaryPdfColor)),
                      ],
                    ),
                  ),
                ],

                // Wi-Fi Details Badge Box
                if (_showWifiBadge && _wifiSsidCtrl.text.isNotEmpty) ...[
                  pw.SizedBox(height: 6),
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFE0F2FE),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        _cleanPdfText('Guest Wi-Fi: ${_wifiSsidCtrl.text}  |  Pass: ${_wifiPassCtrl.text}'),
                        style: pw.TextStyle(
                          color: PdfColor.fromInt(0xFF0369A1),
                          fontSize: isA4Grid ? 6.5 : 7.5,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfAcrylicStand(
    String tblName,
    String flName,
    String arName,
    String qrUrl,
    PdfColor primaryPdfColor,
    PdfColor accentPdfColor,
    bool isA4Grid,
    pw.ImageProvider? logoImage,
  ) {
    return pw.Container(
      width: 250,
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(16)),
        border: pw.Border.all(color: primaryPdfColor, width: 2),
      ),
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          _buildPdfCenterEmblem(size: 28, borderColor: primaryPdfColor, logoImage: logoImage),
          pw.SizedBox(height: 6),
          pw.Text(
            _cleanPdfText(_restaurantNameCtrl.text.toUpperCase()),
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              color: primaryPdfColor,
              fontWeight: pw.FontWeight.bold,
              fontSize: 12,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: pw.BoxDecoration(
              color: primaryPdfColor,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(14)),
            ),
            child: pw.Text(
              'TABLE $tblName',
              style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 11),
            ),
          ),
          pw.SizedBox(height: 10),
          pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(errorCorrectLevel: pw.BarcodeQRCorrectionLevel.high),
            data: qrUrl,
            width: 120,
            height: 120,
            color: primaryPdfColor,
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            _cleanPdfText(_ctaTitleCtrl.text),
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.grey800),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfStickerDisc(
    String tblName,
    String flName,
    String arName,
    String qrUrl,
    PdfColor primaryPdfColor,
    PdfColor accentPdfColor,
    bool isA4Grid,
    pw.ImageProvider? logoImage,
  ) {
    return pw.Container(
      width: 200,
      height: 200,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        shape: pw.BoxShape.circle,
        border: pw.Border.all(color: primaryPdfColor, width: 2.5),
      ),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            'TABLE $tblName',
            style: pw.TextStyle(color: primaryPdfColor, fontWeight: pw.FontWeight.bold, fontSize: 11),
          ),
          pw.SizedBox(height: 4),
          pw.Stack(
            alignment: pw.Alignment.center,
            children: [
              pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(errorCorrectLevel: pw.BarcodeQRCorrectionLevel.high),
                data: qrUrl,
                width: 100,
                height: 100,
                color: primaryPdfColor,
              ),
              if (_showLogoInCenter)
                _buildPdfCenterEmblem(size: 22, borderColor: primaryPdfColor, logoImage: logoImage),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Scan to Order',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  // --- PDF EXPORT ENGINE ---

  Future<void> _exportAndPrintPdf(BuildContext context, {required bool isBulk}) async {
    setState(() => _busy = true);
    try {
      final doc = pw.Document();
      final tablesToPrint = isBulk
          ? widget.tables.where((t) => _selectedTableIds.contains(t['id']?.toString())).toList()
          : [_getPreviewTable()].whereType<dynamic>().toList();

      if (tablesToPrint.isEmpty) {
        throw Exception('No tables selected to export');
      }

      final primaryPdfColor = PdfColor.fromInt(_primaryColor.value);
      final accentPdfColor = PdfColor.fromInt(_accentColor.value);

      pw.ImageProvider? logoPdfImage;
      if (_propertyLogoBytes != null && _propertyLogoBytes!.isNotEmpty) {
        try {
          logoPdfImage = pw.MemoryImage(_propertyLogoBytes!);
        } catch (_) {}
      }

      if (_selectedLayout == TableCardLayout.googleStandee) {
        // Full A4 standee poster sheet per table (centered on A4 with scissors cutout guide)
        for (final tbl in tablesToPrint) {
          final qrUrl = _buildTableUrl(tbl);
          doc.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              build: (pw.Context ctx) {
                return pw.Center(
                  child: _buildPdfCardForTable(
                    tbl: tbl,
                    qrUrl: qrUrl,
                    primaryPdfColor: primaryPdfColor,
                    accentPdfColor: accentPdfColor,
                    isA4Grid: false,
                    logoImage: logoPdfImage,
                  ),
                );
              },
            ),
          );
        }
      } else if (_selectedLayout == TableCardLayout.a4GridSheet) {
        // Multi-table grid (4 per A4 page)
        for (int i = 0; i < tablesToPrint.length; i += 4) {
          final pageChunk = tablesToPrint.skip(i).take(4).toList();
          doc.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              margin: const pw.EdgeInsets.all(20),
              build: (pw.Context ctx) {
                return pw.GridView(
                  crossAxisCount: 2,
                  childAspectRatio: 0.72,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  children: pageChunk.map((tbl) {
                    final qrUrl = _buildTableUrl(tbl);
                    return _buildPdfCardForTable(
                      tbl: tbl,
                      qrUrl: qrUrl,
                      primaryPdfColor: primaryPdfColor,
                      accentPdfColor: accentPdfColor,
                      isA4Grid: true,
                      logoImage: logoPdfImage,
                    );
                  }).toList(),
                );
              },
            ),
          );
        }
      } else {
        // Individual Card per page (A6 page format matching on-screen card exactly)
        for (final tbl in tablesToPrint) {
          final qrUrl = _buildTableUrl(tbl);
          doc.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a6,
              margin: const pw.EdgeInsets.all(12),
              build: (pw.Context ctx) {
                return pw.Center(
                  child: _buildPdfCardForTable(
                    tbl: tbl,
                    qrUrl: qrUrl,
                    primaryPdfColor: primaryPdfColor,
                    accentPdfColor: accentPdfColor,
                    isA4Grid: false,
                    logoImage: logoPdfImage,
                  ),
                );
              },
            ),
          );
        }
      }

      await Printing.layoutPdf(
        onLayout: (format) async => doc.save(),
        name: 'Table_QR_Cards_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // --- HELPER WRAPPERS ---

  Widget _sectionContainer({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: _primaryColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _textField(String label, TextEditingController ctrl, {String? hint}) {
    return TextField(
      controller: ctrl,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        labelStyle: const TextStyle(fontSize: 11),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
      ),
      style: const TextStyle(fontSize: 12),
    );
  }

  Widget _checkToggle(String label, bool val, ValueChanged<bool> onChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: val,
          activeColor: _primaryColor,
          visualDensity: VisualDensity.compact,
          onChanged: (v) => onChanged(v ?? false),
        ),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
