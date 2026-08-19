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
  final TextEditingController _batchNoCtrl = TextEditingController(text: 'BAT-2608');
  final TextEditingController _mfgDateCtrl = TextEditingController(text: '19/08/26');
  bool _selectAllVisible = false;
  bool _regenerateExisting = false;
  String _sizeKey = '50x30';
  bool _busy = false;
  bool _printBatchNo = false;
  bool _printMfgDate = false;

  static const Map<String, _LabelSize> _labelSizes = {
    '38x25': _LabelSize('Small', 38, 25, 10),
    '50x30': _LabelSize('Medium', 50, 30, 12),
    '70x40': _LabelSize('Large', 70, 40, 13),
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
        const SnackBar(content: Text('Select at least one item')),
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
          labels.add(_buildLabel(item, size));
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
        SnackBar(content: Text('Barcode label PDF saved at: ${file.path}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  pw.Widget _buildLabel(Item item, _LabelSize size) {
    final textStyle = pw.TextStyle(
      fontSize: size.fontSize,
      color: PdfColors.black,
    );

    final String batchStr = _batchNoCtrl.text.trim().isEmpty
        ? 'BAT-2608'
        : _batchNoCtrl.text.trim();
    final String mfgStr = _mfgDateCtrl.text.trim().isEmpty
        ? '19/08/26'
        : _mfgDateCtrl.text.trim();

    // ── Dimensions ─────────────────────────────────────────────────
    const double vertPad = 3.0;
    const double sideW = 8.0; // column visual width (= text height after rotate)
    const double gap = 1.5;
    const double divW = 0.5;

    // Compute barcode-row height so we can pre-size the rotated text box.
    final double labelH = size.heightMm * PdfPageFormat.mm;
    final double nameRowH = (size.fontSize + 0.5) * 1.5 + 2;
    final double codeRowH = size.fontSize * 1.5 + 2;
    final double rowH = labelH - vertPad * 2 - nameRowH - codeRowH;

    // â”€â”€ Vertical side text via stacked characters â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    // pw.Transform.rotate does NOT re-arrange layout constraints in the pdf
    // package, so text stays horizontal and clipped. Instead we stack each
    // character as a separate pw.Text in a Column (reversed) so the label
    // reads bottom-to-top when viewed upright.
    const pw.TextStyle sideStyle =
        pw.TextStyle(fontSize: 5.5, color: PdfColors.black);

    pw.Widget sideText(String t) {
      final chars = t.split('').reversed.toList();
      return pw.SizedBox(
        width: sideW,
        height: rowH,
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: chars
              .map((c) => pw.Text(c,
                  style: sideStyle, textAlign: pw.TextAlign.center))
              .toList(),
        ),
      );
    }

    pw.Widget divider() => pw.Container(
          width: divW,
          height: rowH,
          color: PdfColors.black,
        );

    return pw.Container(
      width: size.widthMm * PdfPageFormat.mm,
      height: labelH,
      padding:
          const pw.EdgeInsets.symmetric(horizontal: 0, vertical: vertPad),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: .6),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // ── Item name ──────────────────────────────────────────────
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 4),
            child: pw.Text(
              item.itemName,
              maxLines: 1,
              textAlign: pw.TextAlign.center,
              style: textStyle.copyWith(
                fontSize: size.fontSize + 0.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(height: 2),
          // ── Barcode row ────────────────────────────────────────────
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // LEFT: Batch No column
              if (_printBatchNo) ...[
                sideText('B: $batchStr'),
                pw.SizedBox(width: gap),
                divider(),
                pw.SizedBox(width: gap),
              ],
              // CENTRE: barcode
              pw.Expanded(
                child: pw.Padding(
                  padding: pw.EdgeInsets.symmetric(
                    horizontal:
                        (_printBatchNo || _printMfgDate) ? 0 : 3,
                  ),
                  child: pw.Center(
                    child: pw.BarcodeWidget(
                      barcode: pw.Barcode.code128(),
                      data: item.barcode,
                      height: rowH * 0.85,
                      drawText: false,
                    ),
                  ),
                ),
              ),
              // RIGHT: Mfg Date column
              if (_printMfgDate) ...[
                pw.SizedBox(width: gap),
                divider(),
                pw.SizedBox(width: gap),
                sideText('M: $mfgStr'),
              ],
            ],
          ),
          pw.SizedBox(height: 2),
          // ── Barcode number ─────────────────────────────────────────
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 4),
            child: pw.Text(
              item.barcode,
              textAlign: pw.TextAlign.center,
              style: textStyle,
            ),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Barcode Label Generator'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth > 1100;
                final medium = constraints.maxWidth > 760;
                final searchWidth = wide ? 300.0 : medium ? 260.0 : constraints.maxWidth;
                final controlWidth = wide ? 240.0 : medium ? 220.0 : constraints.maxWidth;

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: searchWidth,
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Search Item',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    SizedBox(
                      width: controlWidth,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _sizeKey,
                        decoration: const InputDecoration(labelText: 'Label Size'),
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
                    SizedBox(
                      width: controlWidth,
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Regenerate Existing'),
                        subtitle: const Text(
                          'Update barcode even if already set',
                        ),
                        value: _regenerateExisting,
                        onChanged: (value) =>
                            setState(() => _regenerateExisting = value),
                      ),
                    ),
                    SizedBox(
                      width: controlWidth,
                      child: CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Select All Visible'),
                        value: _selectAllVisible,
                        onChanged: (value) => _toggleSelectAll(value ?? false),
                      ),
                    ),
                    SizedBox(
                      width: controlWidth,
                      child: CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Print Batch No'),
                        value: _printBatchNo,
                        onChanged: (value) => setState(() => _printBatchNo = value ?? false),
                      ),
                    ),
                    if (_printBatchNo)
                      SizedBox(
                        width: 160,
                        child: TextField(
                          controller: _batchNoCtrl,
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: 'Batch No Text',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    SizedBox(
                      width: controlWidth,
                      child: CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Print Mfg Date'),
                        value: _printMfgDate,
                        onChanged: (value) => setState(() => _printMfgDate = value ?? false),
                      ),
                    ),
                    if (_printMfgDate)
                      SizedBox(
                        width: 160,
                        child: TextField(
                          controller: _mfgDateCtrl,
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: 'Mfg Date Text',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '$selectedCount item(s) selected. Set print qty for each selected item.',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Card(
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final selected = _selected[item.id] ?? false;
                    return ListTile(
                      leading: Checkbox(
                        value: selected,
                        onChanged: (value) {
                          setState(() {
                            _selected[item.id] = value ?? false;
                            if (!(value ?? false)) {
                              _selectAllVisible = false;
                            }
                          });
                        },
                      ),
                      title: Text(item.itemName),
                      subtitle: Text(
                        '${item.itemCode} | ${item.barcode.trim().isEmpty ? "No barcode" : item.barcode}',
                      ),
                      trailing: SizedBox(
                        width: 110,
                        child: TextField(
                          controller: _qtyCtrls[item.id],
                          enabled: selected,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Print Qty',
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Selected items will be barcode-updated, then a barcode label PDF will open.',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _busy ? null : _generateBarcodeLabels,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.view_week_outlined),
                  label:
                      Text(_busy ? 'Generating...' : 'Generate Barcode PDF'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
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
