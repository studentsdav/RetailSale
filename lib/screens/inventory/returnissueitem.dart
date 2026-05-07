import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../controllers/inventory/return_controller.dart';
import '../../controllers/settings/property_info_controller.dart';
import '../../models/inventory/issued_item_model.dart';
import '../../utils/branding_storage.dart';

/// ================= SCREEN =================
class ReturnIssuedItemScreen extends StatefulWidget {
  const ReturnIssuedItemScreen({super.key});

  @override
  State<ReturnIssuedItemScreen> createState() => _ReturnIssuedItemScreenState();
}

class _ReturnIssuedItemScreenState extends State<ReturnIssuedItemScreen> {
  // ---------------- DATE ----------------
  DateTime selectedDate = DateTime.now();
  final dateCtrl = TextEditingController();
  final ReturnController returnCtrl = ReturnController();
  double remainingQty = 0;
  final propertyCtrl = PropertyInfoController();
  // ---------------- INDENT ----------------
  List<String> indentList = [];
  String? selectedIndent;

  // ---------------- DATA ----------------
  List<IssuedItem> issuedItems = [];
  List<IssuedItem> returnItems = [];

  IssuedItem? selectedIssuedItem;
  IssuedItem? editingReturnItem;

  // ---------------- DETAIL CONTROLLERS ----------------
  final qtyCtrl = TextEditingController();
  final rateCtrl = TextEditingController();
  final valueCtrl = TextEditingController();

  int? _editIndex;

  @override
  void initState() {
    super.initState();
    _loadPropertyInfo();
    dateCtrl.text = DateFormat('dd-MMM-yyyy').format(selectedDate);
  }

  Future<void> _loadPropertyInfo() async {
    await propertyCtrl.load();
  }

  // ================= SEARCH =================
  void searchByDate() async {
    final d = DateFormat('yyyy-MM-dd').format(selectedDate);
    await returnCtrl.loadIndents(d);

    setState(() {
      indentList =
          returnCtrl.indents.map((e) => e['issue_no'].toString()).toList();
      selectedIndent = null;
      issuedItems.clear();
      returnItems.clear();
      clearDetail();
    });
  }

  // ================= LOAD ISSUED ITEMS =================
  void loadIssuedItems(String indentNo) async {
    final indent = returnCtrl.indents
        .firstWhere((e) => e['issue_no'].toString() == indentNo);

    await returnCtrl.loadIssuedItems(indent['id']);

    setState(() {
      issuedItems = returnCtrl.issuedItems;
    });
  }

  // ================= SELECT ISSUED ITEM =================
  void selectIssuedItem(IssuedItem e) async {
    final alreadyReturnedDB = await returnCtrl.getReturnedQty(e.issueItemId);

    setState(() {
      selectedIssuedItem = e;
      editingReturnItem = null;

      remainingQty = selectedIssuedItem!.qty - alreadyReturnedDB.toDouble();

      if (remainingQty < 0) remainingQty = 0;

      qtyCtrl.text = remainingQty.toString();
      rateCtrl.text = e.rate.toStringAsFixed(2);

      recalc();
    });
  }

  // ================= CALC =================
  void recalc() {
    final q = int.tryParse(qtyCtrl.text) ?? 0;
    final r = double.tryParse(rateCtrl.text) ?? 0;
    valueCtrl.text = (q * r).toStringAsFixed(2);
  }

  // ================= SAVE RETURN =================

  void saveReturnItem() {
    if (selectedIssuedItem == null) return;

    final qty = double.tryParse(qtyCtrl.text) ?? 0;

    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter valid return quantity")),
      );
      return;
    }

    final alreadyExists = returnItems.any(
      (e) =>
          e.issueItemId == selectedIssuedItem!.issueItemId &&
          _editIndex == null,
    );

    if (alreadyExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Item already added. Edit or delete existing item."),
        ),
      );
      return;
    }

    final item = IssuedItem(
      issueItemId: selectedIssuedItem!.issueItemId,
      itemCode: selectedIssuedItem!.itemCode,
      itemName: selectedIssuedItem!.itemName,
      unit: selectedIssuedItem!.unit,
      qty: qty,
      rate: selectedIssuedItem!.rate,
      tax: selectedIssuedItem!.tax,
      itemId: selectedIssuedItem!.itemId,
    );

    setState(() {
      if (_editIndex == null) {
        returnItems.add(item);
      } else {
        returnItems[_editIndex!] = item;
        _editIndex = null;
      }

      clearDetail();
    });
  }

  // ================= EDIT RETURN =================
  Future<void> editReturnItem(int index) async {
    final e = returnItems[index];
    final issued = issuedItems.firstWhere(
      (x) => x.issueItemId == e.issueItemId,
    );
    final alreadyReturnedDB = await returnCtrl.getReturnedQty(e.issueItemId);
    setState(() {
      _editIndex = index;
      selectedIssuedItem = e;
      remainingQty = issued.qty - alreadyReturnedDB.toDouble();
      editingReturnItem = e;
      qtyCtrl.text = e.qty.toString();
      rateCtrl.text = e.rate.toStringAsFixed(2);

      recalc();
    });
  }

  // ================= CLEAR =================
  void clearDetail() {
    selectedIssuedItem = null;
    editingReturnItem = null;
    qtyCtrl.clear();
    rateCtrl.clear();
    valueCtrl.clear();
    _editIndex = null;
    setState(() {});
  }

  void finalclearDetail() {
    selectedIssuedItem = null;
    editingReturnItem = null;
    qtyCtrl.clear();
    rateCtrl.clear();
    valueCtrl.clear();
    _editIndex = null;
    returnItems.clear();
    setState(() {});
  }

  double get issuedTotal => issuedItems.fold(0, (s, e) => s + e.amount);

  double get returnTotal => returnItems.fold(0, (s, e) => s + e.amount);

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text("Return Department Items"),
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
                  Expanded(child: _issuedTableCard()),
                  const SizedBox(width: 12),
                  Expanded(child: _returnTableCard()),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _detailEntryCard(),
            const SizedBox(height: 12),
            _footer(),
          ],
        ),
      ),
    );
  }

  // ================= HEADER =================
  Widget _headerCard() {
    return _card(
      title: 'Search Stock Out Reference',
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _dateField(),
          FilledButton.icon(
            icon: const Icon(Icons.search),
            onPressed: searchByDate,
            label: const Text('Search'),
          ),
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<String>(
              initialValue: selectedIndent,
              items: indentList
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  selectedIndent = v;
                  issuedItems.clear();
                  returnItems.clear();
                  clearDetail();
                  if (v != null) loadIssuedItems(v);
                });
              },
              decoration: const InputDecoration(labelText: 'Stock Out No'),
            ),
          ),
          _amountChip('Stock Out Total', issuedTotal),
        ],
      ),
    );
  }

  // ================= ISSUED TABLE =================
  Widget _issuedTableCard() {
    return LayoutBuilder(builder: (context, constraints) {
      return SizedBox(
          height: constraints.maxHeight,
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
                rows: issuedItems.map((e) {
                  return DataRow(
                    selected: selectedIssuedItem == e,
                    onSelectChanged: (_) => selectIssuedItem(e),
                    cells: [
                      DataCell(Text(e.itemName)),
                      DataCell(Text(e.unit)),
                      DataCell(Text(e.qty.toString())),
                      DataCell(Text(e.rate.toStringAsFixed(2))),
                    ],
                  );
                }).toList(),
              ),
            ),
          ));
    });
  }

  // ================= RETURN TABLE =================
  Widget _returnTableCard() {
    return LayoutBuilder(builder: (context, constraints) {
      return SizedBox(
          height: constraints.maxHeight,
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
                rows: List.generate(returnItems.length, (i) {
                  final e = returnItems[i];

                  return DataRow(cells: [
                    DataCell(Text(e.itemName)),
                    DataCell(Text(e.qty.toString())),
                    DataCell(Text(e.rate.toStringAsFixed(2))),
                    DataCell(Text(e.amount.toStringAsFixed(2))),
                    DataCell(Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => editReturnItem(i),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _editIndex = null;
                              returnItems.removeAt(i);
                            });
                          },
                        ),
                      ],
                    )),
                  ]);
                }),
              ),
            ),
          ));
    });
  }

  // ================= DETAIL ENTRY =================
  Widget _detailEntryCard() {
    return _card(
      title: 'Department Return Entry',
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _roField('Item', selectedIssuedItem?.itemName),
          _roField('Unit', selectedIssuedItem?.unit),
          _editField(qtyCtrl, 'Return Qty', recalc),
          _editField(rateCtrl, 'Rate', recalc),
          _roField('Value', valueCtrl.text),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: Text(_editIndex == null ? 'Add Item' : 'Update Item'),
            onPressed: () async {
              saveReturnItem();
            },
          ),
          OutlinedButton(
            onPressed: clearDetail,
            child: const Text('Clear'),
          ),
          _amountChip('Returned Total', returnTotal),
        ],
      ),
    );
  }

  // ================= FOOTER =================
  Widget _footer() {
    return Align(
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton.icon(
            icon: const Icon(Icons.save),
            onPressed: _savereturn,
            label: const Text('Save'),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }

  Future<void> _savereturn() async {
    if (returnItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('items required')),
      );
      return;
    }

    final indent = returnCtrl.indents.firstWhere(
      (e) => e['issue_no'].toString() == selectedIndent,
    );

    final payloadItems = returnItems.map((e) {
      return {
        'item_code': e.itemCode,
        'issue_item_id': e.issueItemId,
        'item_id': e.itemId,
        'qty': e.qty,
        'rate': e.rate,
      };
    }).toList();

    await returnCtrl.saveReturn(
      issueId: indent['id'],
      returnDate: DateFormat('yyyy-MM-dd').format(selectedDate),
      items: payloadItems,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Department return saved successfully')),
    );

    final shouldPrint = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Print Department Return Slip"),
        content: const Text("Do you want to print this department return slip?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("No"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Yes"),
          ),
        ],
      ),
    );

    if (shouldPrint == true) {
      await _printReturn(indent['issue_no']);
    }

    finalclearDetail();
  }

  Future<void> _printReturn(String issueNo) async {
    final pdf = pw.Document();

    final property = propertyCtrl.data; // ensure loaded
    final logo = await BrandingStorage.loadPdfLogo(property?.logoPath);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          /// ================= HEADER =================
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (logo != null)
                pw.Container(
                  width: 56,
                  height: 56,
                  margin: const pw.EdgeInsets.only(right: 12),
                  child: pw.Image(logo, fit: pw.BoxFit.contain),
                ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      property?.propertyName ?? '',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(property?.address ?? ''),
                    pw.Text("GSTIN: ${property?.gstNo ?? ''}"),
                  ],
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(border: pw.Border.all()),
                child: pw.Text(
                  "STOCK RETURN SLIP",
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 20),

          /// ================= INFO =================
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("Stock Out No: $issueNo"),
                  pw.Text(
                      "Return Date: ${DateFormat('dd-MMM-yyyy').format(selectedDate)}"),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 20),

          /// ================= ITEM TABLE =================
          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(30),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(1),
              4: const pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _cell("S.No", bold: true),
                  _cell("Item"),
                  _cell("Unit"),
                  _cell("Qty"),
                  _cell("Rate"),
                ],
              ),
              ...List.generate(returnItems.length, (i) {
                final r = returnItems[i];
                return pw.TableRow(
                  children: [
                    _cell("${i + 1}"),
                    _cell(r.itemName),
                    _cell(r.unit),
                    _cell(r.qty.toString()),
                    _cell(r.rate.toStringAsFixed(2)),
                  ],
                );
              })
            ],
          ),

          pw.SizedBox(height: 20),

          /// ================= TOTALS =================
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  "Stock Out Total : ${issuedTotal.toStringAsFixed(2)}",
                ),
                pw.Text(
                  "Returned Total : ${returnTotal.toStringAsFixed(2)}",
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 40),

          /// ================= SIGNATURE =================
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(children: [
                pw.Text("Returned By"),
                pw.SizedBox(height: 30),
              ]),
              pw.Column(children: [
                pw.Text("Store Verified"),
                pw.SizedBox(height: 30),
              ]),
              pw.Column(children: [
                pw.Text("Authorized Signatory"),
                pw.SizedBox(height: 30),
              ]),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }

  pw.Widget _cell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  // ================= COMMON =================
  Widget _card({String? title, required Widget child}) => Material(
        color: Colors.white,
        elevation: 1,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null) ...[
                Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const Divider(),
              ],
              child,
            ],
          ),
        ),
      );

  Widget _dateField() => SizedBox(
        width: 180,
        child: TextField(
          controller: dateCtrl,
          readOnly: true,
          decoration: const InputDecoration(labelText: 'Date'),
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: selectedDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
            );
            if (d != null) {
              setState(() {
                selectedDate = d;
                dateCtrl.text = DateFormat('dd-MMM-yyyy').format(d);
              });
            }
          },
        ),
      );

  Widget _roField(String l, String? v) => SizedBox(
        width: 220,
        child: TextField(
          controller: TextEditingController(text: v ?? ''),
          readOnly: true,
          decoration: InputDecoration(labelText: l),
        ),
      );

  Widget _editField(
    TextEditingController c,
    String l,
    VoidCallback f,
  ) =>
      SizedBox(
        width: 140,
        child: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              RegExp(r'^\d*\.?\d{0,2}'),
            ),
          ],
          decoration: InputDecoration(labelText: l),
          onChanged: (val) {
            final entered = int.tryParse(val) ?? 0;

            if (entered > remainingQty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    "Max return allowed: $remainingQty",
                  ),
                ),
              );

              c.text = remainingQty.toString();
              c.selection = TextSelection.fromPosition(
                TextPosition(offset: c.text.length),
              );
            }

            f();
          },
        ),
      );
  Widget _amountChip(String label, double value) => Chip(
        label: Text(
          '$label : ${value.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );
}
