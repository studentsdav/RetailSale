import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../controllers/inventory/supplier_return_controller.dart';
import '../../models/inventory/supplier_return_model.dart';

class SupplierReturnScreen extends StatefulWidget {
  const SupplierReturnScreen({super.key});

  @override
  State<SupplierReturnScreen> createState() => _SupplierReturnScreenState();
}

class _SupplierReturnScreenState extends State<SupplierReturnScreen> {
  final ctrl = SupplierReturnController();
  final dateCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  final qtyCtrl = TextEditingController();
  final rateCtrl = TextEditingController();
  final valueCtrl = TextEditingController();

  DateTime selectedDate = DateTime.now();
  List<Map<String, dynamic>> grnList = [];
  Map<String, dynamic>? selectedGrn;
  List<SupplierReturnSourceItem> receivedItems = [];
  List<SupplierReturnEntryItem> returnItems = [];
  SupplierReturnSourceItem? selectedItem;
  int? editIndex;
  double remainingQty = 0;

  String _fmtNumber(num value) {
    return value % 1 == 0 ? value.toInt().toString() : value.toString();
  }

  @override
  void initState() {
    super.initState();
    dateCtrl.text = DateFormat('dd-MMM-yyyy').format(selectedDate);
  }

  void searchGrns() async {
    await ctrl.loadGrns(DateFormat('yyyy-MM-dd').format(selectedDate));
    setState(() {
      grnList = ctrl.grns;
      selectedGrn = null;
      receivedItems.clear();
      returnItems.clear();
      clearDetail();
    });
  }

  void loadReceivedItems(Map<String, dynamic> grn) async {
    await ctrl.loadReceivedItems(grn['id']);
    setState(() {
      selectedGrn = grn;
      receivedItems = ctrl.receivedItems;
      returnItems.clear();
      clearDetail();
    });
  }

  Future<void> selectSourceItem(SupplierReturnSourceItem item) async {
    final returnedQty = await ctrl.getReturnedQty(item.receiptItemId);
    setState(() {
      selectedItem = item;
      editIndex = null;
      remainingQty = item.qty - returnedQty;
      if (remainingQty < 0) remainingQty = 0;
      qtyCtrl.text = _fmtNumber(remainingQty);
      rateCtrl.text = item.rate.toStringAsFixed(2);
      recalc();
    });
  }

  void recalc() {
    final qty = double.tryParse(qtyCtrl.text) ?? 0;
    final rate = double.tryParse(rateCtrl.text) ?? 0;
    valueCtrl.text = (qty * rate).toStringAsFixed(2);
    setState(() {});
  }

  void saveReturnItem() {
    if (selectedItem == null) return;

    final qty = double.tryParse(qtyCtrl.text) ?? 0;
    final rate = double.tryParse(rateCtrl.text) ?? 0;

    if (qty <= 0) {
      _showMessage('Enter valid return qty');
      return;
    }

    if (qty > remainingQty && editIndex == null) {
      _showMessage('Return qty exceeds remaining qty');
      return;
    }

    final alreadyExists = returnItems.any(
      (e) =>
          e.receiptItemId == selectedItem!.receiptItemId && editIndex == null,
    );

    if (alreadyExists) {
      _showMessage('Item already added. Edit or delete existing item.');
      return;
    }

    final item = SupplierReturnEntryItem(
      receiptItemId: selectedItem!.receiptItemId,
      itemId: selectedItem!.itemId,
      itemCode: selectedItem!.itemCode,
      itemName: selectedItem!.itemName,
      unit: selectedItem!.unit,
      qty: qty,
      rate: rate,
    );

    setState(() {
      if (editIndex == null) {
        returnItems.add(item);
      } else {
        returnItems[editIndex!] = item;
      }
      clearDetail();
    });
  }

  void editReturnItem(int index) async {
    final row = returnItems[index];
    final source =
        receivedItems.firstWhere((e) => e.receiptItemId == row.receiptItemId);
    final returnedQty = await ctrl.getReturnedQty(row.receiptItemId);
    setState(() {
      editIndex = index;
      selectedItem = source;
      remainingQty = source.qty - returnedQty + row.qty;
      qtyCtrl.text = _fmtNumber(row.qty);
      rateCtrl.text = row.rate.toStringAsFixed(2);
      recalc();
    });
  }

  void clearDetail() {
    selectedItem = null;
    editIndex = null;
    remainingQty = 0;
    qtyCtrl.clear();
    rateCtrl.clear();
    valueCtrl.clear();
  }

  double get receivedTotal => receivedItems.fold(0, (s, e) => s + e.amount);
  double get returnTotal => returnItems.fold(0, (s, e) => s + e.amount);

  Future<void> saveReturn() async {
    if (selectedGrn == null || returnItems.isEmpty) {
      _showMessage('Select GRN and add items');
      return;
    }

    try {
      await ctrl.saveReturn(
        grnId: selectedGrn!['id'],
        supplierId: selectedGrn!['supplier_id'],
        returnDate: selectedDate,
        notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
        items: returnItems,
      );

      _showMessage('Supplier return saved');
      setState(() {
        returnItems.clear();
        notesCtrl.clear();
        clearDetail();
      });
      searchGrns();
    } catch (e) {
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Return Purchase to Vendor'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _headerCard(),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _sourceTableCard()),
                  const SizedBox(width: 12),
                  Expanded(child: _returnTableCard()),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _detailCard(),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton.icon(
                    onPressed: saveReturn,
                    icon: const Icon(Icons.save),
                    label: const Text('Save'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Exit'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerCard() {
    return _card(
      title: 'Search Received GRN',
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 180,
            child: TextField(
              controller: dateCtrl,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Date',
                suffixIcon: Icon(Icons.calendar_today),
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  setState(() {
                    selectedDate = picked;
                    dateCtrl.text = DateFormat('dd-MMM-yyyy').format(picked);
                  });
                }
              },
            ),
          ),
          FilledButton.icon(
            onPressed: searchGrns,
            icon: const Icon(Icons.search),
            label: const Text('Search'),
          ),
          SizedBox(
            width: 340,
            child: DropdownSearch<Map<String, dynamic>>(
              selectedItem: selectedGrn,
              items: (f, i) => grnList,
              compareFn: (a, b) => a['id'] == b['id'],
              itemAsString: (item) =>
                  '${item['grn_no']}  |  ${item['supplier']?['supplier_name'] ?? ''}  |  Bill ${item['supplier_bill_no'] ?? ''}',
              popupProps: const PopupProps.menu(showSearchBox: true),
              decoratorProps: const DropDownDecoratorProps(
                decoration: InputDecoration(labelText: 'GRN No'),
              ),
              onChanged: (value) {
                if (value != null) {
                  loadReceivedItems(value);
                }
              },
            ),
          ),
          _amountChip('Received Total', receivedTotal),
          _amountChip('Return Total', returnTotal),
        ],
      ),
    );
  }

  Widget _sourceTableCard() {
    return _card(
      title: 'Received Items',
      expandChild: true, // Tells the card to expand this child safely
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Item')),
              DataColumn(label: Text('Unit')),
              DataColumn(label: Text('Qty')),
              DataColumn(label: Text('Rate')),
            ],
            rows: receivedItems.map((e) {
              return DataRow(
                selected: selectedItem?.receiptItemId == e.receiptItemId,
                onSelectChanged: (_) => selectSourceItem(e),
                cells: [
                  DataCell(Text(e.itemName)),
                  DataCell(Text(e.unit)),
                  DataCell(Text(_fmtNumber(e.qty))),
                  DataCell(Text(e.rate.toStringAsFixed(2))),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _returnTableCard() {
    return _card(
      title: 'Return Items',
      expandChild: true, // Tells the card to expand this child safely
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Item')),
              DataColumn(label: Text('Qty')),
              DataColumn(label: Text('Rate')),
              DataColumn(label: Text('Amount')),
              DataColumn(label: Text('Action')),
            ],
            rows: List.generate(returnItems.length, (index) {
              final item = returnItems[index];
              return DataRow(
                cells: [
                  DataCell(Text(item.itemName)),
                  DataCell(Text(_fmtNumber(item.qty))),
                  DataCell(Text(item.rate.toStringAsFixed(2))),
                  DataCell(Text(item.amount.toStringAsFixed(2))),
                  DataCell(
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => editReturnItem(index),
                          icon: const Icon(Icons.edit, color: Colors.blue),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              returnItems.removeAt(index);
                              clearDetail();
                            });
                          },
                          icon: const Icon(Icons.delete, color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _detailCard() {
    return _card(
      title: 'Return Entry',
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _readOnlyField('Item', selectedItem?.itemName),
          _readOnlyField('Unit', selectedItem?.unit),
          _readOnlyField('Remaining Qty', _fmtNumber(remainingQty)),
          _editField(qtyCtrl, 'Return Qty', recalc),
          _editField(rateCtrl, 'Purchase Rate', recalc),
          _readOnlyField('Value', valueCtrl.text),
          SizedBox(
            width: 260,
            child: TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
          ),
          FilledButton.icon(
            onPressed: saveReturnItem,
            icon: const Icon(Icons.add),
            label: Text(editIndex == null ? 'Add Item' : 'Update Item'),
          ),
          OutlinedButton(
            onPressed: () => setState(clearDetail),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  // UPDATED CARD WIDGET: Now supports a safe `expandChild` boolean
  Widget _card(
          {required Widget child, String? title, bool expandChild = false}) =>
      Material(
        color: Colors.white,
        elevation: 1,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            // If expandChild is true, tell the column to take maximum vertical space
            mainAxisSize: expandChild ? MainAxisSize.max : MainAxisSize.min,
            children: [
              if (title != null) ...[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Divider(),
              ],
              // Safely wrap the child in an Expanded widget so it fills the available area
              expandChild ? Expanded(child: child) : child,
            ],
          ),
        ),
      );

  Widget _readOnlyField(String label, String? value) => SizedBox(
        width: 180,
        child: TextField(
          readOnly: true,
          controller: TextEditingController(text: value ?? ''),
          decoration: InputDecoration(
            labelText: label,
            filled: true,
            fillColor: Colors.grey.shade100,
          ),
        ),
      );

  Widget _editField(
    TextEditingController controller,
    String label,
    VoidCallback onChanged,
  ) =>
      SizedBox(
        width: 140,
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          onChanged: (_) => onChanged(),
          decoration: InputDecoration(labelText: label),
        ),
      );

  Widget _amountChip(String label, double amount) => Chip(
        label: Text(
          '$label : ${amount.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );
}
