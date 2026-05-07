import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../controllers/inventory/issue_controller.dart' show IssueController;
import '../../controllers/inventory/item_controller.dart';
import '../../controllers/inventory/numbering_settings_controller.dart';
import '../../controllers/inventory/supplier_controller.dart';
import '../../controllers/purchase/purchase_order_controller.dart';
import '../../controllers/settings/property_info_controller.dart';
import '../../models/common/property_info_model.dart';
import '../../models/inventory/item_model.dart';
import '../../models/inventory/purchase_item_model.dart';
import '../../models/inventory/purchase_order_model.dart';
import '../../models/inventory/stock_location_model.dart';
import '../../utils/branding_storage.dart';
import '../../utils/inclusive_rate_helper.dart';
import '../../utils/date_picker_helper.dart';

class PurchaseOrderScreen extends StatefulWidget {
  const PurchaseOrderScreen({super.key});

  @override
  State<PurchaseOrderScreen> createState() => _PurchaseOrderScreenState();
}

class _PurchaseOrderScreenState extends State<PurchaseOrderScreen> {
  // ================= HEADER =================
  final _poNo = TextEditingController(text: '3');
  DateTime _date = DateTime.now();
  int? _supplierId;

  String? _selectedItemName;
  int? _selectedBrandItemId;
  List<Item> _filteredBrands = [];
  // ================= ITEM =================
  final _code = TextEditingController();
  final numberingCtrl = NumberingSettingsController();
  final _unit = TextEditingController(text: 'PCS');
  final _qty = TextEditingController();
  final _rate = TextEditingController();
  final _tax = TextEditingController();
  final _qtyNode = FocusNode();
  final _rateNode = FocusNode();
  final _taxNode = FocusNode();
  final depctrl = IssueController();
  final propertyCtrl = PropertyInfoController();
  PropertyInfo? propertyInfo;
  // final DateTime _expDate = DateTime.now();
  int? _editIndex;
  final List<PurchaseItem> _items = [];
  StockLocationdata? _selectedDepartment;
  bool _isStockable = true;
  bool _rateInclusive = false;
  final supplierCtrl = SupplierController();
  final itemCtrl = ItemController();
  final poCtrl = PurchaseOrderController();
  // ================= TOTAL =================
  double get totalAmount => _items.fold(0, (s, e) => s + e.amount);
  double get totalGST =>
      _items.fold(0, (s, e) => s + ((e.qty * e.rate) * (e.tax / 100)));
  double get netAmount => totalAmount + totalGST;

  String _fmtNumber(num value) {
    return value % 1 == 0 ? value.toDouble().toString() : value.toString();
  }

  // ================= ADD / UPDATE ITEM =================
  void _saveItem() {
    if (_qty.text.isEmpty) return;
    if (_selectedBrandItemId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Brand is required',
          ),
        ),
      );
      return;
    }

    final alreadyExists = _items.any((e) =>
        int.parse(e.itemId.toString()) ==
            int.parse(_selectedBrandItemId.toString()) &&
        _editIndex == null);

    if (alreadyExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Item already added. Please modify or delete existing item.',
          ),
        ),
      );
      return;
    }

    if (!_isStockable && _selectedDepartment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Department is required',
          ),
        ),
      );
      return;
    }
    final taxPercent = double.tryParse(_tax.text.trim()) ?? 0;
    final enteredRate = double.tryParse(_rate.text.trim()) ?? 0;
    final baseRate = _rateInclusive
        ? InclusiveRateHelper.exclusiveFromInclusive(
            enteredRate,
            taxPercent,
          )
        : enteredRate;
    final item = PurchaseItem(
      itemCode: _code.text,
      itemName: _selectedItemName!,
      brand:
          _filteredBrands.firstWhere((e) => e.id == _selectedBrandItemId).brand,
      unit: _unit.text,
      qty: double.parse(_qty.text),
      rate: baseRate,
      tax: taxPercent,
      itemId: int.parse(_selectedBrandItemId.toString()),
      department: !_isStockable ? _selectedDepartment!.id.toString() : "",
    );

    setState(() {
      if (_editIndex == null) {
        _items.add(item);
      } else {
        _items[_editIndex!] = item;
        _editIndex = null;
      }
    });
    _clearItem();
  }

  void _editItem(int i) {
    final r = _items[i];
    _editIndex = i;
    _code.text = r.itemCode;
    _selectedItemName = r.itemName;
    _filteredBrands =
        itemCtrl.list.where((e) => e.itemName == r.itemName).toList();
    _selectedBrandItemId = r.itemId;
    _unit.text = r.unit;
    _qty.text = r.qty.toString();
    _rate.text = r.rate.toString();
    _isStockable = r.department.isEmpty;
    _rateInclusive = false;
    final deptId = int.tryParse(r.department ?? "");

    if (deptId != null) {
      final dept = depctrl.departments
          .where((e) => e.id == deptId)
          .cast<StockLocationdata?>()
          .firstOrNull;

      if (dept != null) {
        _selectedDepartment = dept;
      }
    }
    _tax.text = r.tax.toString();

    setState(() {});
  }

  void _deleteItem(int i) {
    setState(() => _items.removeAt(i));
  }

  @override
  void dispose() {
    _qtyNode.dispose();
    _rateNode.dispose();
    _taxNode.dispose();
    super.dispose();
  }

  void _clearItem() {
    _code.clear();
    _qty.clear();
    _rate.clear();
    _tax.clear();
    _selectedItemName = null;
    _isStockable = true;
    _selectedDepartment = null;
    _rateInclusive = false;
    setState(() {});
  }

  Future<void> _finalclearItem() async {
    final no = await numberingCtrl.getNextPoNo(_date);
    setState(() {
      _selectedBrandItemId = null;
      _selectedItemName = null;
      _supplierId = null;

      _code.clear();
      _qty.clear();
      _rate.clear();
      _tax.clear();
      _unit.clear();
      _editIndex = null;
      _items.clear();
      _rateInclusive = false;

      _poNo.text = no;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _loadPropertyInfo();
  }

  Future<void> _loadPropertyInfo() async {
    await propertyCtrl.load();
    setState(() {
      propertyInfo = propertyCtrl.data;
    });
  }

  Future<void> _loadInitialData() async {
    await supplierCtrl.load();
    await itemCtrl.load();
    await depctrl.getdepartment();
    final no = await numberingCtrl.getNextPoNo(_date);
    setState(() {
      setState(() => _poNo.text = no);
    });
  }

  Future<void> _savePurchaseOrder() async {
    if (_supplierId == null) {
      _showMessage("Select vendor");
      return;
    }

    if (_items.isEmpty) {
      _showMessage("Add at least one item");
      return;
    }

    final po = PurchaseOrder(
      poNo: _poNo.text,
      manualNo: "",
      supplierId: int.parse(_supplierId.toString()),
      poDate: _date,
      items: _items.map((e) {
        return PurchaseItem(
          itemId: e.itemId,
          itemCode: e.itemCode,
          itemName: e.itemName,
          brand: e.brand,
          unit: e.unit,
          qty: e.qty,
          rate: e.rate,
          tax: e.tax,
          department: e.department,
        );
      }).toList(),
    );

    await poCtrl.create(po);

    final shouldPrint = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Print Purchase Order"),
        content: const Text("Do you want to print this Purchase Order?"),
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
      await _printPurchaseOrder();
    }

    _showMessage("Purchase Order Saved");

    _finalclearItem();
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Purchase Order'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _headerCard(),
            const SizedBox(height: 12),
            _itemEntryCard(),
            const SizedBox(height: 12),
            Expanded(child: _itemsTableCard()),
            const SizedBox(height: 12),
            _footerCard(),
          ],
        ),
      ),
    );
  }

  // ================= HEADER =================
  Widget _headerCard() {
    return _card(
      title: 'Purchase Order Information',
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _field(_poNo, 'PO No', readOnly: true),
          //  _field(_manualNo, 'Manual No'),
          SizedBox(
            width: 260,
            child: DropdownSearch<int>(
              selectedItem: _supplierId,
              items: (filter, infiniteScrollProps) =>
                  supplierCtrl.list.map((s) => s.id).toList(),
              itemAsString: (id) {
                final supplier =
                    supplierCtrl.list.firstWhere((e) => e.id == id);
                return supplier.supplierName;
              },
              popupProps: const PopupProps.menu(
                showSearchBox: true,
                searchFieldProps: TextFieldProps(
                  decoration: InputDecoration(
                    hintText: "Search vendor...",
                  ),
                ),
              ),
              decoratorProps: const DropDownDecoratorProps(
                decoration: InputDecoration(
                  labelText: "Vendor",
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _supplierId = value;
                });
              },
            ),
          ),

          _dateField(),
        ],
      ),
    );
  }

  // ================= ITEM ENTRY =================
  Widget _itemEntryCard() {
    return _card(
      title: 'Item Entry',
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _field(_code, 'Item Code', readOnly: true),
          SizedBox(
            width: 260,
            child: DropdownSearch<String>(
              selectedItem: _selectedItemName,
              items: (filter, infiniteScrollProps) =>
                  itemCtrl.list.map((e) => e.itemName).toSet().toList(),
              popupProps: const PopupProps.menu(
                showSearchBox: true,
                searchFieldProps: TextFieldProps(
                  decoration: InputDecoration(
                    hintText: "Search item...",
                  ),
                ),
              ),
              decoratorProps: const DropDownDecoratorProps(
                decoration: InputDecoration(
                  labelText: "Item Name",
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _selectedItemName = value;

                  _filteredBrands =
                      itemCtrl.list.where((e) => e.itemName == value).toList();

                  _selectedBrandItemId = null;

                  _code.clear();
                  _rate.clear();
                  _tax.clear();
                  _qty.clear();
                  _rateInclusive = false;
                });
              },
            ),
          ),

          SizedBox(
            width: 220,
            child: DropdownButtonFormField<int>(
              initialValue: _selectedBrandItemId,
              items: _filteredBrands
                  .map((e) => DropdownMenuItem(
                        value: e.id,
                        child: Text(e.brand),
                      ))
                  .toList(),
              onChanged: (v) {
                final selected = _filteredBrands.firstWhere((e) => e.id == v);

                setState(() {
                  _selectedBrandItemId = v;

                  _code.text = selected.itemCode;
                  _unit.text = selected.unit;
                  _rate.text = selected.rate.toString();
                  _tax.text = selected.taxPercent.toString();
                  _isStockable = selected.stockable;
                  _rateInclusive = false;
                  if (_isStockable) {
                    _selectedDepartment = null;
                  }
                });
                FocusScope.of(context).requestFocus(_qtyNode);
              },
              decoration: const InputDecoration(labelText: 'Brand'),
            ),
          ),
          _field(_unit, 'Unit'),
          _number(
            _qty,
            'Qty',
            focusNode: _qtyNode,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => FocusScope.of(context).requestFocus(_rateNode),
          ),
          _number(
            _rate,
            _rateInclusive ? 'Rate (Inclusive)' : 'Rate',
            helperText: _rateInclusive && _rate.text.trim().isNotEmpty
                ? InclusiveRateHelper.previewText(
                    label: 'Rate',
                    inclusiveAmount: double.tryParse(_rate.text.trim()) ?? 0,
                    taxPercent: double.tryParse(_tax.text.trim()) ?? 0,
                  )
                : null,
            focusNode: _rateNode,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => FocusScope.of(context).requestFocus(_taxNode),
          ),
          _number(
            _tax,
            'Tax %',
            focusNode: _taxNode,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _saveItem(),
          ),
          SizedBox(
            width: 180,
            child: CheckboxListTile(
              value: _rateInclusive,
              contentPadding: EdgeInsets.zero,
              title: const Text('Inclusive'),
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (value) {
                setState(() {
                  _rateInclusive = value ?? false;
                });
              },
            ),
          ),
          if (!_isStockable)
            SizedBox(
              width: 260,
              child: DropdownButtonFormField<StockLocationdata>(
                initialValue: _selectedDepartment,
                decoration: const InputDecoration(labelText: 'Department'),
                items: depctrl.departments.map((d) {
                  return DropdownMenuItem(
                    value: d,
                    child: Text(d.locationName),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedDepartment = val;
                  });
                },
              ),
            ),
          //   _dateField('Exp Date', _expDate, (d) => setState(() => _expDate = d)),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: Text(_editIndex == null ? 'Add Item' : 'Update Item'),
            onPressed: _saveItem,
          ),
        ],
      ),
    );
  }

  // ================= TABLE =================
  Widget _itemsTableCard() {
    return LayoutBuilder(builder: (context, constraints) {
      return SizedBox(
          height: constraints.maxHeight,
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                showCheckboxColumn: false,
                columns: const [
                  DataColumn(label: Text('S.No')),
                  DataColumn(label: Text('Item Code')),
                  DataColumn(label: Text('Item Name')),
                  DataColumn(label: Text('Brand')),
                  DataColumn(label: Text('Unit')),
                  DataColumn(label: Text('Qty')),
                  DataColumn(label: Text('Rate')),
                  DataColumn(label: Text('Tax %')),
                  DataColumn(label: Text('Amount')),
                  DataColumn(label: Text('Department')),
                  DataColumn(label: Text('Action')),
                ],
                rows: List.generate(_items.length, (i) {
                  final r = _items[i];
                  String depname = "";

                  final deptId = int.tryParse(r.department ?? "");

                  if (deptId != null) {
                    final dept = depctrl.departments
                        .where((e) => e.id == deptId)
                        .cast<StockLocationdata?>()
                        .firstOrNull;

                    if (dept != null) {
                      depname = dept.locationName;
                    }
                  }

                  return DataRow(
                    color: WidgetStateProperty.all(
                        i.isEven ? Colors.grey.shade50 : Colors.white),
                    cells: [
                      DataCell(Text('${i + 1}')),
                      DataCell(Text(r.itemCode)),
                      DataCell(Text(r.itemName)),
                      DataCell(Text(r.brand)),
                      DataCell(Text(r.unit)),
                      DataCell(Text(_fmtNumber(r.qty))),
                      DataCell(Text(r.rate.toStringAsFixed(2))),
                      DataCell(Text(r.tax.toStringAsFixed(2))),
                      DataCell(Text(r.amount.toStringAsFixed(2))),
                      DataCell(Text(depname)),
                      DataCell(Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _editItem(i),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteItem(i),
                          ),
                        ],
                      )),
                    ],
                  );
                }),
              ),
            ),
          ));
    });
  }

  // ================= FOOTER =================
  Widget _footerCard() {
    return _card(
        child: Row(
          children: [
            Chip(
              label: Text(
              'Before GST : ${totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Chip(
              label: Text(
                'GST : ${totalGST.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Chip(
              label: Text(
                'Net : ${netAmount.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          const Spacer(),
          FilledButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Save'),
            onPressed: _savePurchaseOrder,
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Exit'),
          ),
        ],
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

  Widget _field(
    TextEditingController c,
    String l, {
    bool readOnly = false,
    TextInputAction textInputAction = TextInputAction.next,
    ValueChanged<String>? onSubmitted,
  }) =>
      SizedBox(
        width: 220,
        child: TextField(
          controller: c,
          readOnly: readOnly,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted ??
              (_) {
                if (textInputAction == TextInputAction.next) {
                  FocusScope.of(context).nextFocus();
                } else {
                  FocusScope.of(context).unfocus();
                }
              },
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
          decoration: InputDecoration(labelText: l),
        ),
      );

  Widget _number(
    TextEditingController c,
    String l, {
    String? helperText,
    FocusNode? focusNode,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
  }) =>
      SizedBox(
        width: 140,
        child: TextField(
          focusNode: focusNode,
          controller: c,
          keyboardType: TextInputType.number,
          textInputAction: textInputAction ?? TextInputAction.next,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))
          ],
          decoration: InputDecoration(labelText: l, helperText: helperText),
          onChanged: (_) => setState(() {}),
          onSubmitted: onSubmitted ??
              (_) {
                if ((textInputAction ?? TextInputAction.next) ==
                    TextInputAction.next) {
                  FocusScope.of(context).nextFocus();
                } else {
                  FocusScope.of(context).unfocus();
                }
              },
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
        ),
      );

  Future<pw.MemoryImage?> _loadLogoFromUrl(String url) async {
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        Uint8List bytes = response.bodyBytes;
        return pw.MemoryImage(bytes);
      }
    } catch (e) {
      debugPrint("Logo load error: $e");
    }

    return null;
  }

  Future<void> _printPurchaseOrder() async {
    final pdf = pw.Document();

    final supplier = supplierCtrl.list.firstWhere((e) => e.id == _supplierId);

    final totalGST = _items.fold<double>(
        0, (sum, item) => sum + ((item.qty * item.rate) * (item.tax / 100)));

    final grandTotal = totalAmount + totalGST;

    final property = propertyInfo;
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
                  width: 60,
                  height: 60,
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
                    pw.Text("${property?.address}"),
                    pw.Text("Mobile: ${property?.mobile}"),
                    pw.Text("Email: ${property?.email}"),
                    pw.Text("GSTIN: ${property?.gstNo}"),
                  ],
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(),
                ),
                child: pw.Text(
                  "PURCHASE ORDER",
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 20),

          /// ================= SUPPLIER & PO INFO =================
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("To,",
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text(supplier.supplierName),
                  pw.Text(supplier.address ?? ""),
                  pw.Text("GSTIN: ${supplier.gstin ?? ""}"),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("PO No: ${_poNo.text}"),
                  pw.Text("Date: ${DateFormat('dd-MMM-yyyy').format(_date)}"),
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
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(1),
              4: const pw.FlexColumnWidth(1),
              5: const pw.FlexColumnWidth(1),
              6: const pw.FlexColumnWidth(1),
              7: const pw.FlexColumnWidth(1),
              8: const pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _tableCell("S.No", bold: true),
                  _tableCell("Item"),
                  _tableCell("Brand"),
                  _tableCell("Unit"),
                  _tableCell("Qty"),
                  _tableCell("Rate"),
                  _tableCell("GST %"),
                  _tableCell("GST Amt"),
                  _tableCell("Amount"),
                ],
              ),
              ...List.generate(_items.length, (i) {
                final item = _items[i];
                final gstAmount = (item.qty * item.rate) * (item.tax / 100);
                return pw.TableRow(
                  children: [
                    _tableCell("${i + 1}"),
                    _tableCell(item.itemName),
                    _tableCell(item.brand),
                    _tableCell(item.unit),
                    _tableCell(_fmtNumber(item.qty)),
                    _tableCell(item.rate.toStringAsFixed(2)),
                    _tableCell(item.tax.toStringAsFixed(2)),
                    _tableCell(gstAmount.toStringAsFixed(2)),
                    _tableCell(item.amount.toStringAsFixed(2)),
                  ],
                );
              }),
            ],
          ),

          pw.SizedBox(height: 20),

          /// ================= TOTAL SECTION =================
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              width: 250,
              child: pw.Column(
                children: [
                  _totalRow("Sub Total", totalAmount),
                  _totalRow("GST", totalGST),
                  pw.Divider(),
                  _totalRow("Grand Total", grandTotal, bold: true),
                ],
              ),
            ),
          ),

          pw.SizedBox(height: 30),

          /// ================= FOOTER =================
          pw.Text(
            "Thank you for your business. Please supply the above items as per agreed terms.",
          ),

          pw.SizedBox(height: 40),

          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                children: [
                  pw.Text("Authorized Signature"),
                  pw.SizedBox(height: 30),
                  pw.Text(property!.legalName,
                      style: const pw.TextStyle(fontSize: 7)),
                ],
              ),
              pw.Column(
                children: [
                  pw.Text("Vendor Signature"),
                  pw.SizedBox(height: 30),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }

  pw.Widget _tableCell(String text, {bool bold = false}) {
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

  pw.Widget _totalRow(String label, double value, {bool bold = false}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label,
            style: pw.TextStyle(
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        pw.Text(value.toStringAsFixed(2),
            style: pw.TextStyle(
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      ],
    );
  }

  Widget _dropdown(
    String label,
    List<String> data,
    String? value,
    ValueChanged<String?> onChanged,
  ) =>
      SizedBox(
        width: 260,
        child: DropdownButtonFormField<String>(
          initialValue: value,
          items: data
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: onChanged,
          decoration: InputDecoration(labelText: label),
        ),
      );

  Widget _dateField() {
    return SizedBox(
      width: 180,
      child: TextField(
        readOnly: true,
        controller: TextEditingController(
          text: DateFormat('dd-MMM-yyyy').format(_date),
        ),
        decoration: const InputDecoration(
          labelText: 'Date',
          suffixIcon: Icon(Icons.calendar_today),
        ),
        onTap: () async {
          final selected = await pickSingleDate(
            context: context,
            initialDate: _date,
          );

          if (selected != null) {
            setState(() {
              _date = selected;
            });
          }
        },
      ),
    );
  }
}
