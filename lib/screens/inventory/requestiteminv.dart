import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../controllers/inventory/item_controller.dart';
import '../../controllers/inventory/request_controller.dart';
import '../../controllers/settings/property_info_controller.dart';
import '../../models/inventory/item_model.dart';
import '../../models/inventory/request_item_model.dart';
import '../../models/inventory/stock_location_model.dart';
import '../../utils/branding_storage.dart';
import '../../utils/date_picker_helper.dart' show pickSingleDate;
import '../../widgets/entry_shortcuts.dart';

class RequestItemScreen extends StatefulWidget {
  const RequestItemScreen({super.key});

  @override
  State<RequestItemScreen> createState() => _RequestItemScreenState();
}

class _RequestItemScreenState extends State<RequestItemScreen> {
  // ================= HEADER =================
  final _requestNo = TextEditingController(text: '4');
  final _openRequestNo = TextEditingController();
  DateTime _date = DateTime.now();
  final ctrl = RequestController();
  Item? _selectedItem;
  double _availableStock = 0;
  double _remainingStock = 0;
  String? _selectedItemName;
  int? _selectedBrandItemId;
  List<Item> _filteredBrands = [];
  final itemCtrl = ItemController();
  final propertyCtrl = PropertyInfoController();
  final _itemNameDropdownKey = GlobalKey<DropdownSearchState<String>>();
  final FocusNode _tableFocusNode = FocusNode();
  int? _selectedRowIndex;
  // ================= ITEM ENTRY =================
  final _unit = TextEditingController(text: 'PCS');
  final _qty = TextEditingController();
  final _rate = TextEditingController();
  final _code = TextEditingController(text: 'ITM-001');
  final _tax = TextEditingController();
  final _qtyNode = FocusNode();
  final _rateNode = FocusNode();

  int? _editIndex;
  final List<RequestItem> _items = [];
  StockLocationdata? _selectedDepartment;

  // ================= TOTAL =================
  double get totalAmount => _items.fold(0, (s, e) => s + e.amount);

  @override
  void initState() {
    super.initState();
    _loadInit();
    itemCtrl.load();
  }

  Future<void> _loadInit() async {
    await ctrl.loadInitialData();
    _loadPropertyInfo();
    final nextNo = await ctrl.getNextRequestNo();
    _requestNo.text = nextNo;
    setState(() {});
  }

  Future<void> _loadPropertyInfo() async {
    await propertyCtrl.load();
  }

  // ================= ACTIONS =================
  void _saveItem() {
    if (_selectedItem == null || _qty.text.isEmpty) return;

    final qty = double.parse(_qty.text);
    final rate = double.parse(_rate.text);

    if (_items
        .any((e) => e.code == _selectedItem!.itemCode && _editIndex == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item already added')),
      );
      return;
    }

    if (qty > _availableStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Qty exceeds available stock')),
      );
      return;
    }

    final r = RequestItem(
        code: _selectedItem!.itemCode,
        name: _selectedItem!.itemName,
        unit: _selectedItem!.unit,
        qty: qty,
        rate: rate,
        type: 'REQ',
        itemid: _selectedItem!.id,
        lineStatus: 'OPEN');

    setState(() {
      if (_editIndex == null) {
        _items.add(r);
        //_availableStock -= qty;
        _remainingStock -= qty;
      } else {
        _items[_editIndex!] = r;
        _editIndex = null;
      }
    });
    _clearItem();
  }

  Future<void> _editItem(int i) async {
    final r = _items[i];

    _editIndex = i;
    final stock = await ctrl.getAvailableStock(r.code);
    setState(() {
      _selectedItem = ctrl.items.firstWhere(
        (e) => e.itemCode == r.code,
      );

      _filteredBrands =
          itemCtrl.list.where((e) => e.itemName == r.name).toList();
      _selectedBrandItemId = r.itemid;
      _selectedItemName = r.name;
      _code.text = r.code;
      _unit.text = r.unit;
      _qty.text = r.qty.toString();
      _rate.text = r.rate.toString();
      _remainingStock = stock - r.qty;
      _availableStock = stock;
    });
  }

  Future<void> _saveRequest() async {
    if (_selectedDepartment == null || _items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Department and items required')),
      );
      return;
    }

    final payload = {
      "department": _selectedDepartment!.locationName,
      "request_date": _date.toIso8601String(),
      "open_request_no": _requestNo.text,
      "items": _items
          .map((e) => {
                "item_id":
                    ctrl.items.firstWhere((i) => i.itemCode == e.code).id,
                "code": e.code,
                "qty": e.qty,
                "rate": e.rate,
                "line_status": 'OPEN',
              })
          .toList()
    };

    await ctrl.createRequest(payload);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Request Saved Successfully')),
    );

    final shouldPrint = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Print Request"),
        content: const Text("Do you want to print this Request?"),
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
      await _printRequest();
    }
    _finalclearItem();
    // Navigator.pop(context);
  }

  void _deleteItem(int i) {
    setState(() => _items.removeAt(i));
  }

  @override
  void dispose() {
    _qtyNode.dispose();
    _rateNode.dispose();
    _tableFocusNode.dispose();
    super.dispose();
  }

  KeyEventResult _onTableKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (_items.isEmpty) return KeyEventResult.ignored;

    final key = event.logicalKey;
    final current = _selectedRowIndex ?? 0;

    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _selectedRowIndex = ((current + 1).clamp(0, _items.length - 1)) as int;
      });
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selectedRowIndex = ((current - 1).clamp(0, _items.length - 1)) as int;
      });
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.f2 || key == LogicalKeyboardKey.enter) {
      final i = _selectedRowIndex;
      if (i != null) _editItem(i);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.delete) {
      final i = _selectedRowIndex;
      if (i != null) _deleteItem(i);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  Future<void> _clearItem() async {
    setState(() {
      _selectedBrandItemId = null;
      _selectedItem = null;
      _selectedItemName = null;

      _code.clear();
      _qty.clear();
      _rate.clear();
      _tax.clear();
      _unit.clear();
      _editIndex = null;
    });
  }

  Future<void> _finalclearItem() async {
    final nextNo = await ctrl.getNextRequestNo();
    setState(() {
      _selectedBrandItemId = null;
      _selectedItem = null;
      _selectedItemName = null;

      _code.clear();
      _qty.clear();
      _rate.clear();
      _tax.clear();
      _unit.clear();
      _editIndex = null;
      _items.clear();

      _requestNo.text = nextNo;
    });
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return EntryShortcuts(
      onSave: _saveRequest,
      onNew: _finalclearItem,
      onClearLine: _clearItem,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6FA),
        appBar: AppBar(
          title: const Text('Request Item'),
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
              Expanded(child: _tableCard()),
              const SizedBox(height: 12),
              _footerCard(),
            ],
          ),
        ),
      ),
    );
  }

  // ================= HEADER =================
  Widget _headerCard() {
    return _card(
      title: 'Request Information',
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          DropdownButtonFormField<StockLocationdata>(
            initialValue: _selectedDepartment,
            decoration: const InputDecoration(labelText: 'Department'),
            items: ctrl.departments.map((d) {
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
          _field(_requestNo, 'Request No', readOnly: true),
          // _field(_openRequestNo, 'Open Request No'),
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
          SizedBox(
            width: 200,
            child: TextField(
              controller: _code,
              readOnly: true,
              decoration: const InputDecoration(labelText: 'Item Code'),
            ),
          ),
          SizedBox(
            width: 260,
            child: Shortcuts(
              shortcuts: const {
                SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
                SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
              },
              child: Actions(
                actions: {
                  ActivateIntent: CallbackAction<ActivateIntent>(
                    onInvoke: (_) {
                      _itemNameDropdownKey.currentState?.openDropDownSearch();
                      return null;
                    },
                  ),
                },
                child: DropdownSearch<String>(
                  key: _itemNameDropdownKey,
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

                      _filteredBrands = itemCtrl.list
                          .where((e) => e.itemName == value)
                          .toList();

                      _selectedBrandItemId = null;

                      _code.clear();
                      _rate.clear();
                      _qty.clear();
                    });
                  },
                ),
              ),
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
              onChanged: (v) async {
                final selected = _filteredBrands.firstWhere((e) => e.id == v);

                setState(() {
                  _selectedBrandItemId = v;

                  _code.text = selected.itemCode;
                  _unit.text = selected.unit;
                  _rate.text = selected.rate.toString();
                  _selectedItem = selected;
                });
                final stock = await ctrl.getAvailableStock(selected.itemCode);

                setState(() {
                  _availableStock = stock;
                  _remainingStock = stock;
                });
                FocusScope.of(context).requestFocus(_qtyNode);
              },
              decoration: const InputDecoration(labelText: 'Brand'),
            ),
          ),
          _field(_unit, 'Unit'),
          _qtyField(
            focusNode: _qtyNode,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => FocusScope.of(context).requestFocus(_rateNode),
          ),
          _number(
            _rate,
            'Rate',
            focusNode: _rateNode,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _saveItem(),
          ),
          _number(_tax, 'Tax %'),
          SizedBox(
            width: 260,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Available Stock : $_availableStock',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Remaining After Issue : $_remainingStock',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _remainingStock <= 0 ? Colors.red : Colors.green,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: Text(_editIndex == null ? 'Add Item' : 'Update Item'),
            onPressed: _saveItem,
          ),
        ],
      ),
    );
  }

  Widget _qtyField({
    FocusNode? focusNode,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
  }) {
    return SizedBox(
      width: 140,
      child: TextField(
        focusNode: focusNode,
        controller: _qty,
        keyboardType: TextInputType.number,
        textInputAction: textInputAction,
        inputFormatters: [
          FilteringTextInputFormatter.allow(
            RegExp(r'^\d*\.?\d{0,2}'),
          ),
        ],
        decoration: const InputDecoration(labelText: 'Qty Issued'),
        onChanged: (val) {
          if (val.isEmpty) {
            setState(() => _remainingStock = _availableStock);
            return;
          }

          final enteredQty = double.tryParse(val) ?? 0;

          if (enteredQty < 0) {
            _qty.clear();
            return;
          }

          if (enteredQty > _availableStock) {
            //    _showMessage('Qty exceeds available stock');

            _qty.text = _availableStock.toString();
            _qty.selection = TextSelection.fromPosition(
              TextPosition(offset: _qty.text.length),
            );

            setState(() => _remainingStock = 0);
          } else {
            setState(() {
              _remainingStock = _availableStock - enteredQty;
            });
          }
        },
        onSubmitted: onSubmitted,
      ),
    );
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  // ================= TABLE =================
  Widget _tableCard() {
    return LayoutBuilder(builder: (context, constraints) {
      return SizedBox(
          height: constraints.maxHeight,
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Focus(
                focusNode: _tableFocusNode,
                onKeyEvent: _onTableKey,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  showCheckboxColumn: false,
                  columns: const [
                    DataColumn(label: Text('S.No')),
                    DataColumn(label: Text('Item')),
                    DataColumn(label: Text('Unit')),
                  DataColumn(label: Text('Qty')),
                  DataColumn(label: Text('Rate')),
                  DataColumn(label: Text('Amount')),
                  DataColumn(label: Text('Code')),
                  DataColumn(label: Text('Action')),
                  ],
                  rows: List.generate(_items.length, (i) {
                  final r = _items[i];
                  return DataRow(
                    selected: _selectedRowIndex == i,
                    onSelectChanged: (_) {
                      setState(() => _selectedRowIndex = i);
                      FocusScope.of(context).requestFocus(_tableFocusNode);
                    },
                    color: WidgetStateProperty.all(
                        i.isEven ? Colors.grey.shade50 : Colors.white),
                    cells: [
                      DataCell(Text('${i + 1}')),
                      DataCell(Text(r.name)),
                      DataCell(Text(r.unit)),
                      DataCell(Text(r.qty.toString())),
                      DataCell(Text(r.rate.toStringAsFixed(2))),
                      DataCell(Text(r.amount.toStringAsFixed(2))),
                      DataCell(Text(r.code)),
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
              'Total : ${totalAmount.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const Spacer(),
          Chip(
            label: Text(
              'Approval: Pending',
              style: TextStyle(
                color: Colors.orange.shade800,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Save'),
            onPressed: _saveRequest,
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

  Future<void> _printRequest() async {
    final pdf = pw.Document();

    final property = propertyCtrl.data;
    final logo = await BrandingStorage.loadPdfLogo(property?.logoPath);

    // pw.MemoryImage? logo;

    // if (property?.logoPath != null && property!.logoPath!.isNotEmpty) {
    //   final response = await http.get(Uri.parse(property.logoPath!));
    //   if (response.statusCode == 200) {
    //     logo = pw.MemoryImage(response.bodyBytes);
    //   }
    // }

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
                    pw.Text(property?.address ?? ''),
                    pw.Text("GSTIN: ${property?.gstNo ?? ''}"),
                  ],
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(border: pw.Border.all()),
                child: pw.Text(
                  "MATERIAL REQUEST",
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 20),

          /// ================= REQUEST INFO =================
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("Request No: ${_requestNo.text}"),
                  pw.Text("Date: ${DateFormat('dd-MMM-yyyy').format(_date)}"),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                      "Department: ${_selectedDepartment?.locationName ?? ''}"),
                  pw.Text("Status: Auto"),
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
              ...List.generate(_items.length, (i) {
                final r = _items[i];
                return pw.TableRow(
                  children: [
                    _cell("${i + 1}"),
                    _cell(r.name),
                    _cell(r.unit),
                    _cell(r.qty.toString()),
                    _cell(r.rate.toStringAsFixed(2)),
                  ],
                );
              })
            ],
          ),

          pw.SizedBox(height: 20),

          /// ================= TOTAL =================
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              "Total Amount : ${totalAmount.toStringAsFixed(2)}",
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),

          pw.SizedBox(height: 30),

          /// ================= SIGNATURE SECTION =================
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(children: [
                pw.Text("Requested By"),
                pw.SizedBox(height: 30),
              ]),
              pw.Column(children: [
                pw.Text("Store Incharge"),
                pw.SizedBox(height: 30),
              ]),
              pw.Column(children: [
                pw.Text("Approved By"),
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

  pw.Widget _total(String label, double value, {bool bold = false}) {
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

  Widget _field(TextEditingController c, String l,
          {bool readOnly = false,
          double width = 200,
          TextInputAction textInputAction = TextInputAction.next,
          ValueChanged<String>? onSubmitted}) =>
      SizedBox(
        width: width,
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
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(labelText: l),
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

  Widget _dropdown(
    String l,
    List<String> d,
    String? v,
    ValueChanged<String?> c,
  ) =>
      SizedBox(
        width: 260,
        child: DropdownButtonFormField<String>(
          initialValue: v,
          items:
              d.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: c,
          decoration: InputDecoration(labelText: l),
        ),
      );

  Widget _dateField() {
    return SizedBox(
      width: 180,
      child: Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        child: Actions(
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) async {
                final selected = await pickSingleDate(
                  context: context,
                  initialDate: _date,
                );

                if (selected != null) {
                  setState(() {
                    _date = selected;
                  });
                }
                return null;
              },
            ),
          },
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
        ),
      ),
    );
  }
}
