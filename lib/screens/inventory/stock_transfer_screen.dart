import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';

import '../../controllers/inventory/item_controller.dart';
import '../../models/inventory/item_model.dart';

class StockTransferScreen extends StatefulWidget {
  const StockTransferScreen({super.key});

  @override
  State<StockTransferScreen> createState() => _StockTransferScreenState();
}

class _StockTransferScreenState extends State<StockTransferScreen> {
  final ItemController itemCtrl = ItemController();
  final _formKey = GlobalKey<FormState>();

  final _packQtyCtrl = TextEditingController();
  final _packCountCtrl = TextEditingController(text: '1');
  final _noteCtrl = TextEditingController();

  Item? _sourceItem;
  Item? _looseItem;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    _packQtyCtrl.dispose();
    _packCountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    await itemCtrl.load();
    if (!mounted) return;
    setState(() {});
  }

  void _applySourceDefaults(Item? item) {
    _sourceItem = item;
    _packQtyCtrl.text = item?.packQty.toString() ?? '';

    if (item == null || item.looseItemCode.isEmpty) {
      _looseItem = null;
    } else {
      final matches = itemCtrl.list
          .where((it) => it.itemCode == item.looseItemCode)
          .toList();
      _looseItem = matches.isEmpty ? null : matches.first;
    }
  }

  Future<void> _saveAndTransfer() async {
    if (_isSaving) return;

    if (!_formKey.currentState!.validate()) return;
    if (_sourceItem == null) {
      _showMessage('Please select a source item');
      return;
    }
    if (_looseItem == null) {
      _showMessage('Please select a loose item');
      return;
    }
    if (_looseItem!.itemCode == _sourceItem!.itemCode) {
      _showMessage('Source item and loose item cannot be the same');
      return;
    }

    final packQty = double.tryParse(_packQtyCtrl.text.trim()) ?? 0;
    final packCount = double.tryParse(_packCountCtrl.text.trim()) ?? 0;
    if (packQty <= 0) {
      _showMessage('Enter a valid pack quantity');
      return;
    }
    if (packCount <= 0) {
      _showMessage('Enter a valid pack count');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final payload = Item(
        id: _sourceItem!.id,
        itemCode: _sourceItem!.itemCode,
        itemName: _sourceItem!.itemName,
        hsnSacCode: _sourceItem!.hsnSacCode,
        itemGroup: _sourceItem!.itemGroup,
        subCategory: _sourceItem!.subCategory,
        brand: _sourceItem!.brand,
        unit: _sourceItem!.unit,
        barcode: _sourceItem!.barcode,
        imagePath: _sourceItem!.imagePath,
        rate: _sourceItem!.rate,
        retailSalePrice: _sourceItem!.retailSalePrice,
        taxType: _sourceItem!.taxType,
        taxPercent: _sourceItem!.taxPercent,
        discountApplicable: _sourceItem!.discountApplicable,
        schemeApplicable: _sourceItem!.schemeApplicable,
        openingBalance: _sourceItem!.openingBalance,
        packQty: packQty,
        looseItemCode: _looseItem!.itemCode,
        minLevel: _sourceItem!.minLevel,
        maxLevel: _sourceItem!.maxLevel,
        stockable: _sourceItem!.stockable,
        isSaleable: _sourceItem!.isSaleable,
      );

      final savedItem = await itemCtrl.update(_sourceItem!.id, payload);
      _sourceItem = savedItem;

      await itemCtrl.openPack(
        id: savedItem.id,
        packCount: packCount,
        note: _noteCtrl.text.trim(),
      );

      await _loadItems();
      final refreshedSource = itemCtrl.list.firstWhere(
        (item) => item.id == savedItem.id,
        orElse: () => savedItem,
      );
      _applySourceDefaults(refreshedSource);
      _noteCtrl.clear();
      _showMessage('Stock transferred successfully');
    } catch (e) {
      _showMessage(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Stock Transfer'),
        centerTitle: true,
      ),
      body: AnimatedBuilder(
        animation: itemCtrl,
        builder: (_, __) {
          if (itemCtrl.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          return SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Form(
                          key: _formKey,
                          child: Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Wrap(
                                spacing: 16,
                                runSpacing: 16,
                                children: [
                                  SizedBox(
                                    width: 360,
                                    child: DropdownSearch<Item>(
                                      items: (filter, infiniteScrollProps) =>
                                          List<Item>.from(itemCtrl.list),
                                      selectedItem: _sourceItem,
                                      itemAsString: (item) =>
                                          '${item.itemName} (${item.itemCode})',
                                      compareFn: (a, b) => a.id == b.id,
                                      popupProps: const PopupProps.menu(
                                        showSearchBox: true,
                                      ),
                                      decoratorProps:
                                          const DropDownDecoratorProps(
                                        decoration: InputDecoration(
                                          labelText: 'Source Item',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                      onChanged: (value) => setState(() {
                                        _applySourceDefaults(value);
                                      }),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 180,
                                    child: TextFormField(
                                      controller: _packQtyCtrl,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                      decoration: const InputDecoration(
                                        labelText: 'Pack Qty',
                                        border: OutlineInputBorder(),
                                      ),
                                      onChanged: (_) => setState(() {}),
                                      validator: (value) {
                                        final qty =
                                            double.tryParse(value ?? '') ?? 0;
                                        if (qty <= 0) {
                                          return 'Required';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  SizedBox(
                                    width: 360,
                                    child: DropdownSearch<Item>(
                                      items: (filter, infiniteScrollProps) =>
                                          List<Item>.from(itemCtrl.list),
                                      selectedItem: _looseItem,
                                      itemAsString: (item) =>
                                          '${item.itemName} (${item.itemCode})',
                                      compareFn: (a, b) => a.id == b.id,
                                      popupProps: const PopupProps.menu(
                                        showSearchBox: true,
                                      ),
                                      decoratorProps:
                                          const DropDownDecoratorProps(
                                        decoration: InputDecoration(
                                          labelText: 'Loose Item',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                      onChanged: (value) => setState(() {
                                        _looseItem = value;
                                      }),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 180,
                                    child: TextFormField(
                                      controller: _packCountCtrl,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                      decoration: const InputDecoration(
                                        labelText: 'Pack Count',
                                        border: OutlineInputBorder(),
                                      ),
                                      onChanged: (_) => setState(() {}),
                                      validator: (value) {
                                        final count =
                                            double.tryParse(value ?? '') ?? 0;
                                        if (count <= 0) {
                                          return 'Required';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  SizedBox(
                                    width: 540,
                                    child: TextFormField(
                                      controller: _noteCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Note',
                                        border: OutlineInputBorder(),
                                      ),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                                  if (_sourceItem != null)
                                    _buildTransferPreview(),
                                  if (_sourceItem == null)
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 18,
                                        vertical: 18,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(
                                            Icons.swap_horiz,
                                            color: Color(0xFF64748B),
                                          ),
                                          SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              'Select a source item to preview the pack-to-loose conversion and transfer impact.',
                                              style: TextStyle(
                                                color: Color(0xFF475569),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                  child: Center(
                    child: SizedBox(
                      width: 220,
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: _isSaving ? null : _saveAndTransfer,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.swap_horiz),
                        label: const Text('Transfer'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _infoChip(String label, String value) {
    return Chip(
      label: Text('$label: $value'),
      backgroundColor: Colors.white,
    );
  }

  Widget _buildTransferPreview() {
    final looseItemText = _looseItem == null
        ? '-'
        : '${_looseItem!.itemName} (${_looseItem!.itemCode})';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF8FAFC), Color(0xFFEFF6FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDBEAFE)),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Transfer Preview',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'This will deduct the packed item and add the equivalent loose quantity.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${_packCountCtrl.text.isEmpty ? '0' : _packCountCtrl.text} pack(s)',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _previewCard(
                  title: 'Source Item',
                  value: _sourceItem!.itemName,
                  subtitle: _sourceItem!.itemCode,
                  icon: Icons.local_shipping_outlined,
                  accent: const Color(0xFF0F766E),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _previewCard(
                  title: 'Conversion',
                  value:
                      '${_packQtyCtrl.text.isEmpty ? '0' : _packQtyCtrl.text} × ${_packCountCtrl.text.isEmpty ? '0' : _packCountCtrl.text}',
                  subtitle:
                      'Loose Qty = Pack Qty × Pack Count = ${(double.tryParse(_packQtyCtrl.text.trim()) ?? 0) * (double.tryParse(_packCountCtrl.text.trim()) ?? 0)}',
                  icon: Icons.compare_arrows_rounded,
                  accent: const Color(0xFF7C3AED),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _previewCard(
                  title: 'Loose Item',
                  value: _looseItem?.itemName ?? 'Not selected',
                  subtitle: looseItemText,
                  icon: Icons.inventory_2_outlined,
                  accent: const Color(0xFFB45309),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _infoChip(
                  'Current Pack Qty',
                  _sourceItem!.packQty.toStringAsFixed(2),
                ),
                _infoChip(
                  'Source Loose Item',
                  _sourceItem!.looseItemCode.isEmpty
                      ? '-'
                      : _sourceItem!.looseItemCode,
                ),
                _infoChip(
                  'Transfer Note',
                  _noteCtrl.text.trim().isEmpty ? '-' : _noteCtrl.text.trim(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
