import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../controllers/inventory/item_controller.dart';
import '../../models/inventory/item_model.dart';

class ItemBarcodeManagerScreen extends StatefulWidget {
  final List<Item> items;
  final ItemController itemController;
  final ValueChanged<List<Item>> onItemsUpdated;

  const ItemBarcodeManagerScreen({
    super.key,
    required this.items,
    required this.itemController,
    required this.onItemsUpdated,
  });

  @override
  State<ItemBarcodeManagerScreen> createState() =>
      _ItemBarcodeManagerScreenState();
}

class _ItemBarcodeManagerScreenState extends State<ItemBarcodeManagerScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final Map<int, bool> _selected = {};
  final Map<int, TextEditingController> _qtyCtrls = {};

  // Controllers for label metadata matching Image 1
  final TextEditingController _batchNoCtrl =
      TextEditingController(text: 'BKJ2501');
  final TextEditingController _mfgDateCtrl =
      TextEditingController(text: '16 MAY 2025');
  final TextEditingController _expiryDateCtrl =
      TextEditingController(text: '16 NOV 2025');
  final TextEditingController _countryCtrl =
      TextEditingController(text: 'INDIA');

  bool _selectAllVisible = false;
  bool _regenerateExisting = false;
  String _sizeKey = '50x30';
  bool _busy = false;

  // Checkbox toggles (default enabled for complete metadata sticker)
  bool _printBatchNo = true;
  bool _printMfgDate = true;
  bool _printExpiryDate = true;
  bool _printCountry = true;

  static const Map<String, _LabelSize> _labelSizes = {
    '38x25': _LabelSize('Small Label', 38, 25, 9),
    '50x30': _LabelSize('Medium Label (Standard)', 50, 30, 10),
    '70x40': _LabelSize('Large Label (Enterprise)', 70, 40, 12),
  };

  @override
  void initState() {
    super.initState();
    for (final item in widget.items) {
      _selected[item.id] = false;
      _qtyCtrls[item.id] = TextEditingController(text: '1');
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _batchNoCtrl.dispose();
    _mfgDateCtrl.dispose();
    _expiryDateCtrl.dispose();
    _countryCtrl.dispose();
    for (final controller in _qtyCtrls.values) {
      controller.dispose();
    }
    super.dispose();
  }

  List<Item> get _filteredItems {
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return widget.items;
    return widget.items.where((item) {
      return item.itemName.toLowerCase().contains(query) ||
          item.itemCode.toLowerCase().contains(query) ||
          item.barcode.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _toggleSelectAll(bool value) async {
    setState(() {
      _selectAllVisible = value;
      for (final item in _filteredItems) {
        _selected[item.id] = value;
      }
    });
  }

  int _qtyFor(Item item) {
    final value = int.tryParse(_qtyCtrls[item.id]?.text.trim() ?? '');
    return value == null || value < 1 ? 1 : value;
  }

  Future<void> _generateBarcodeLabels() async {
    final selectedItems =
        widget.items.where((item) => _selected[item.id] == true).toList();
    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one item to generate barcode labels')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final updatedItems = await widget.itemController.generateBarcodes(
        itemIds: selectedItems.map((item) => item.id).toList(),
        forceRegenerate: _regenerateExisting,
      );

      final updatedById = {
        for (final item in updatedItems) item.id: item,
      };
      final printableItems = selectedItems
          .map((item) => updatedById[item.id] ?? item)
          .where((item) => item.barcode.trim().isNotEmpty)
          .toList();

      widget.onItemsUpdated(
        widget.items
            .map((item) => updatedById[item.id] ?? item)
            .toList(growable: false),
      );

      final pdf = pw.Document();
      final size = _labelSizes[_sizeKey]!;
      final labels = <pw.Widget>[];

      for (final item in printableItems) {
        for (int i = 0; i < _qtyFor(item); i++) {
          labels.add(_buildPdfLabel(item, size));
        }
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(10),
          build: (_) => [
            pw.Wrap(
              spacing: 6,
              runSpacing: 6,
              children: labels,
            ),
          ],
        ),
      );

      final directory =
          Directory('${Platform.environment['USERPROFILE']}\\Downloads');
      final fileName =
          'item_barcode_labels_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${directory.path}\\$fileName');
      await file.writeAsBytes(await pdf.save(), flush: true);
      await OpenFile.open(file.path);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Barcode label PDF saved successfully: ${file.path}'),
          backgroundColor: const Color(0xFF008060),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  /// Builds PDF label sticker matching Image 1 format
  pw.Widget _buildPdfLabel(Item item, _LabelSize size) {
    final labelW = size.widthMm * PdfPageFormat.mm;
    final labelH = size.heightMm * PdfPageFormat.mm;

    final metaRows = <pw.Widget>[];

    if (_printBatchNo && _batchNoCtrl.text.trim().isNotEmpty) {
      metaRows.add(_buildPdfMetaRow('BATCH NO.', _batchNoCtrl.text.trim(), size.fontSize));
    }
    if (_printMfgDate && _mfgDateCtrl.text.trim().isNotEmpty) {
      metaRows.add(_buildPdfMetaRow('PACKED ON', _mfgDateCtrl.text.trim(), size.fontSize));
    }
    if (_printExpiryDate && _expiryDateCtrl.text.trim().isNotEmpty) {
      metaRows.add(_buildPdfMetaRow('BEST BEFORE', _expiryDateCtrl.text.trim(), size.fontSize));
    }
    if (_printCountry && _countryCtrl.text.trim().isNotEmpty) {
      metaRows.add(_buildPdfMetaRow('COUNTRY OF ORIGIN', _countryCtrl.text.trim(), size.fontSize));
    }

    final barcodeText = item.barcode.trim().isEmpty ? '8906123450128' : item.barcode.trim();

    return pw.Container(
      width: labelW,
      height: labelH,
      padding: const pw.EdgeInsets.all(5),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: PdfColors.black, width: 0.8),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (metaRows.isNotEmpty) ...[
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: metaRows,
            ),
            pw.SizedBox(height: 3),
          ],
          pw.Expanded(
            child: pw.Center(
              child: pw.BarcodeWidget(
                barcode: pw.Barcode.code128(),
                data: barcodeText,
                drawText: true,
                textStyle: pw.TextStyle(
                  fontSize: size.fontSize * 0.85,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfMetaRow(String label, String value, double baseFontSize) {
    final style = pw.TextStyle(
      fontSize: baseFontSize * 0.72,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.black,
    );

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 1.5),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 76,
            child: pw.Text(label, style: style),
          ),
          pw.Text(': ', style: style),
          pw.Expanded(
            child: pw.Text(value.toUpperCase(), style: style, maxLines: 1),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredItems;
    final selectedCount =
        widget.items.where((item) => _selected[item.id] == true).length;
    final sampleItem = items.isNotEmpty ? items.first : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Barcode Label Generator',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Enterprise Custom Label Printing Suite',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF008060),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _busy ? null : _generateBarcodeLabels,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.print, size: 18),
              label: Text(_busy ? 'Generating...' : 'Print Barcode PDF'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Control & Options Panel ──────────────────────────────────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Search Item
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _searchCtrl,
                          decoration: InputDecoration(
                            hintText: 'Search items by name, code or barcode...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Label Size Dropdown
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: _sizeKey,
                          decoration: InputDecoration(
                            labelText: 'Label Size',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          items: _labelSizes.entries
                              .map(
                                (entry) => DropdownMenuItem(
                                  value: entry.key,
                                  child: Text(
                                    '${entry.value.name} (${entry.key} mm)',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _sizeKey = value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 14),

                  const Text(
                    'Label Fields & Sticker Controls (First Checkbox -> Label -> Value)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Enterprise Option Grid: Checkbox FIRST -> Label -> Value ──
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      // 1. Batch No
                      _buildOptionTile(
                        value: _printBatchNo,
                        onChanged: (val) =>
                            setState(() => _printBatchNo = val ?? false),
                        label: 'BATCH NO.',
                        controller: _batchNoCtrl,
                        hintText: 'BKJ2501',
                      ),
                      // 2. Packed On
                      _buildOptionTile(
                        value: _printMfgDate,
                        onChanged: (val) =>
                            setState(() => _printMfgDate = val ?? false),
                        label: 'PACKED ON',
                        controller: _mfgDateCtrl,
                        hintText: '16 MAY 2025',
                      ),
                      // 3. Best Before / Expiry
                      _buildOptionTile(
                        value: _printExpiryDate,
                        onChanged: (val) =>
                            setState(() => _printExpiryDate = val ?? false),
                        label: 'BEST BEFORE',
                        controller: _expiryDateCtrl,
                        hintText: '16 NOV 2025',
                      ),
                      // 4. Country of Origin
                      _buildOptionTile(
                        value: _printCountry,
                        onChanged: (val) =>
                            setState(() => _printCountry = val ?? false),
                        label: 'COUNTRY OF ORIGIN',
                        controller: _countryCtrl,
                        hintText: 'INDIA',
                      ),
                      // 5. Select All Visible
                      _buildOptionTile(
                        value: _selectAllVisible,
                        onChanged: (val) => _toggleSelectAll(val ?? false),
                        label: 'Select All Visible Items',
                      ),
                      // 6. Regenerate Existing
                      _buildOptionTile(
                        value: _regenerateExisting,
                        onChanged: (val) =>
                            setState(() => _regenerateExisting = val ?? false),
                        label: 'Force Regenerate Barcodes',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Live Sticker Preview & Selection Table ───────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Live Sticker Preview Card matching Image 1
                SizedBox(
                  width: 320,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.remove_red_eye_outlined,
                                size: 18, color: Color(0xFF008060)),
                            SizedBox(width: 8),
                            Text(
                              'Live Sticker Label Preview',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildLiveStickerCard(sampleItem),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 20),

                // Selected Items Table
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF8FAFC),
                            borderRadius:
                                BorderRadius.vertical(top: Radius.circular(12)),
                          ),
                          child: Row(
                            children: [
                              Text(
                                '$selectedCount Item(s) Selected',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const Spacer(),
                              const Text(
                                'Set print quantity for each item',
                                style: TextStyle(
                                    fontSize: 12, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        SizedBox(
                          height: 380,
                          child: ListView.separated(
                            itemCount: items.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = items[index];
                              final selected = _selected[item.id] ?? false;
                              return ListTile(
                                leading: Checkbox(
                                  value: selected,
                                  activeColor: const Color(0xFF008060),
                                  onChanged: (value) {
                                    setState(() {
                                      _selected[item.id] = value ?? false;
                                      if (!(value ?? false)) {
                                        _selectAllVisible = false;
                                      }
                                    });
                                  },
                                ),
                                title: Text(
                                  item.itemName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14),
                                ),
                                subtitle: Text(
                                  'Code: ${item.itemCode} | Barcode: ${item.barcode.trim().isEmpty ? "Auto-generate" : item.barcode}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: SizedBox(
                                  width: 95,
                                  child: TextField(
                                    controller: _qtyCtrls[item.id],
                                    enabled: selected,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    decoration: InputDecoration(
                                      labelText: 'Print Qty',
                                      isDense: true,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Enterprise Option Tile: Checkbox FIRST -> Label -> Value
  Widget _buildOptionTile({
    required bool value,
    required ValueChanged<bool?> onChanged,
    required String label,
    TextEditingController? controller,
    String? hintText,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: value ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: value ? const Color(0xFF008060) : const Color(0xFFCBD5E1),
          width: value ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. FIRST CHECKBOX
          SizedBox(
            width: 22,
            height: 22,
            child: Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: const Color(0xFF008060),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
          ),
          const SizedBox(width: 8),
          // 2. THEN LABEL
          InkWell(
            onTap: () => onChanged(!value),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: value ? FontWeight.bold : FontWeight.w600,
                color: value ? const Color(0xFF0F172A) : const Color(0xFF475569),
              ),
            ),
          ),
          // 3. THEN VALUE INPUT
          if (controller != null && value) ...[
            const SizedBox(width: 8),
            const Text(':',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
            const SizedBox(width: 8),
            SizedBox(
              width: 120,
              height: 32,
              child: TextField(
                controller: controller,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: hintText,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  fillColor: Colors.white,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: Color(0xFF94A3B8)),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Builds Live On-Screen Sticker Card matching Image 1
  Widget _buildLiveStickerCard(Item? sampleItem) {
    final barcodeText = sampleItem != null && sampleItem.barcode.trim().isNotEmpty
        ? sampleItem.barcode.trim()
        : '8906123450128';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB), // Sticker cream tint matching Image 1
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD97706), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_printBatchNo && _batchNoCtrl.text.trim().isNotEmpty)
            _buildLiveMetaRow('BATCH NO.', _batchNoCtrl.text.trim()),
          if (_printMfgDate && _mfgDateCtrl.text.trim().isNotEmpty)
            _buildLiveMetaRow('PACKED ON', _mfgDateCtrl.text.trim()),
          if (_printExpiryDate && _expiryDateCtrl.text.trim().isNotEmpty)
            _buildLiveMetaRow('BEST BEFORE', _expiryDateCtrl.text.trim()),
          if (_printCountry && _countryCtrl.text.trim().isNotEmpty)
            _buildLiveMetaRow('COUNTRY OF ORIGIN', _countryCtrl.text.trim()),
          const SizedBox(height: 10),
          // Barcode bars representation
          Center(
            child: Column(
              children: [
                Container(
                  height: 48,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/images/barcode_pattern.png'),
                      fit: BoxFit.cover,
                      onError: null,
                    ),
                  ),
                  child: CustomPaint(
                    painter: _BarcodePainter(),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '8   ${barcodeText.length > 6 ? barcodeText.substring(0, 6) : barcodeText}   ${barcodeText.length > 6 ? barcodeText.substring(6) : "450128"}   >',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1E293B),
                letterSpacing: 0.5,
              ),
            ),
          ),
          const Text(
            ': ',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          Expanded(
            child: Text(
              value.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E293B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter to render realistic barcode bars in live preview
class _BarcodePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0F172A)
      ..strokeWidth = 2;

    double x = 4;
    int barIndex = 0;
    while (x < size.width - 4) {
      final width = (barIndex % 3 == 0) ? 3.5 : (barIndex % 2 == 0) ? 2.0 : 1.0;
      final gap = (barIndex % 5 == 0) ? 4.0 : 2.5;

      canvas.drawRect(Rect.fromLTWH(x, 0, width, size.height), paint);
      x += width + gap;
      barIndex++;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LabelSize {
  final String name;
  final double widthMm;
  final double heightMm;
  final double fontSize;

  const _LabelSize(
    this.name,
    this.widthMm,
    this.heightMm,
    this.fontSize,
  );
}
