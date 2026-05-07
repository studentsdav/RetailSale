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
  bool _selectAllVisible = false;
  bool _regenerateExisting = false;
  String _sizeKey = '50x30';
  bool _busy = false;

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

    return pw.Container(
      width: size.widthMm * PdfPageFormat.mm,
      height: size.heightMm * PdfPageFormat.mm,
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: .6),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(
            item.itemName,
            maxLines: 1,
            textAlign: pw.TextAlign.center,
            style: textStyle.copyWith(fontSize: size.fontSize + 1),
          ),
          pw.SizedBox(height: 3),
          pw.Expanded(
            child: pw.Center(
              child: pw.BarcodeWidget(
                barcode: pw.Barcode.code128(),
                data: item.barcode,
                width: (size.widthMm - 10) * PdfPageFormat.mm,
                height: (size.heightMm * 0.42) * PdfPageFormat.mm,
                drawText: false,
              ),
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            item.barcode,
            textAlign: pw.TextAlign.center,
            style: textStyle,
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
