import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../controllers/inventory/issue_controller.dart' show IssueController;
import '../../controllers/inventory/item_controller.dart';
import '../../controllers/inventory/request_controller.dart';
import '../../controllers/settings/property_info_controller.dart'
    show PropertyInfoController;
import '../../core/api/api_client.dart';
import '../../models/inventory/issue_item_model.dart';
import '../../models/inventory/item_model.dart';
import '../../models/inventory/stock_location_model.dart';
import '../../utils/date_picker_helper.dart';
import '../../utils/branding_storage.dart';
import '../../widgets/entry_shortcuts.dart';

class IssueScreen extends StatefulWidget {
  const IssueScreen({super.key});

  @override
  State<IssueScreen> createState() => _IssueScreenState();
}

class _IssueScreenState extends State<IssueScreen> {
  // ================= HEADER =================
  final _indentNo = TextEditingController();
  String? _issueType;
  DateTime _date = DateTime.now();
  final _openReq = TextEditingController();
  final ctrl = IssueController();
  Item? _selectedItem;
  double _availableStock = 0;
  double _remainingStock = 0;
  String? _selectedItemName;
  int? _selectedBrandItemId;
  List<Item> _filteredBrands = [];
  final itemCtrl = ItemController();
  final propertyCtrl = PropertyInfoController();
  // ================= ITEM ENTRY =================
  final _code = TextEditingController();
  final _unit = TextEditingController(text: 'PCS');
  final _qty = TextEditingController();
  final _rate = TextEditingController();
  final _tax = TextEditingController();
  final _qtyNode = FocusNode();
  final _rateNode = FocusNode();
  int? _editIndex;
  final List<IssueItem> _items = [];
  final issueTypes = ['Internal', 'Guest', 'Damage'];
  final requestCtrl = RequestController();
  List<dynamic> requestList = [];
  int? _selectedRequestId;

  StockLocationdata? _selectedDepartment;
  final _itemNameDropdownKey = GlobalKey<DropdownSearchState<String>>();
  final FocusNode _tableFocusNode = FocusNode();
  int? _selectedRowIndex;

  // ================= TOTALS =================
  double get totalAmount => _items.fold(0, (s, e) => s + e.amount);
  double get totalGST =>
      _items.fold(0, (s, e) => s + ((e.qty * e.rate) * (e.tax / 100)));

  double get netAmount => totalAmount + totalGST;
  void _saveItem() {
    if (_selectedItem == null || _qty.text.isEmpty) return;

    final qty = double.tryParse(_qty.text) ?? 0;
    final rate = double.tryParse(_rate.text) ?? 0;
    final tax = double.tryParse(_tax.text) ?? 0;

    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid quantity')),
      );
      return;
    }

    if (qty > _availableStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Qty exceeds available stock')),
      );
      return;
    }
    final alreadyExists =
        _items.any((e) => e.itemId == _selectedItem!.id && _editIndex == null);

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

    // if (_selectedRequestId != null) {
    //   _showMessage("Items loaded from request. Edit from list.");
    //   return;
    // }

    final item = IssueItem(
      itemId: _selectedItem!.id,
      itemCode: _selectedItem!.itemCode,
      itemName: _selectedItem!.itemName,
      unit: _selectedItem!.unit,
      qty: qty,
      rate: rate,
      tax: tax,
      type: _issueType ?? '',
      lineStatus: 'CLOSED',
    );

    setState(() {
      if (_editIndex == null) {
        _items.add(item);
        _remainingStock -= qty;
      } else {
        _items[_editIndex!] = item;
        _editIndex = null;
      }

      _clearItem();
    });
  }

  Future<void> _editItem(int i) async {
    final r = _items[i];

    _editIndex = i;
    final stock = await ctrl.getAvailableStock(r.itemCode);
    setState(() {
      _selectedItem = ctrl.items.firstWhere(
        (e) => e.itemCode == r.itemCode,
      );

      _filteredBrands =
          itemCtrl.list.where((e) => e.itemName == r.itemName).toList();
      _selectedBrandItemId = r.itemId;
      _selectedItemName = r.itemName;
      _code.text = r.itemCode;
      _unit.text = r.unit;
      _qty.text = r.qty.toString();
      _rate.text = r.rate.toString();
      _tax.text = r.tax.toString();
      _remainingStock = stock - r.qty;
      _availableStock = stock;
    });
  }

  void _deleteItem(int i) {
    setState(() => _items.removeAt(i));
  }

  void _clearItem() {
    setState(() {
      _selectedBrandItemId = null;
      _selectedItem = null;
      _selectedItemName = null;

      _code.clear();
      _qty.clear();
      _rate.clear();
      _tax.clear();

      _editIndex = null;
    });
  }

  Future<void> _finalclearItem() async {
    setState(() {
      _selectedBrandItemId = null;
      _selectedItem = null;
      _selectedItemName = null;
      _selectedRequestId = null;
      _code.clear();
      _qty.clear();
      _rate.clear();
      _tax.clear();
      _unit.clear();
      _editIndex = null;
      _items.clear();
    });
    _loadNextGrn();
    _loadRequests();
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

  @override
  void initState() {
    super.initState();
    ctrl.loadInitialData();
    itemCtrl.load();
    _loadNextGrn();
    _loadRequests();
    _loadPropertyInfo();
  }

  Future<void> _loadPropertyInfo() async {
    await propertyCtrl.load();
  }

  Future<void> _loadRequests() async {
    final res = await requestCtrl.list();
    requestList = res;
    setState(() {});
  }

  Future<void> _loadNextGrn() async {
    try {
      final res = await ApiClient.get(
          "/api/inventory/issue/next-issue-no/?date=${_date.toIso8601String()}");

      if (res['success']) {
        _indentNo.text = res['data']['number'];
      }
    } catch (e) {
      _indentNo.clear();
      showErrorSnackbar(
        'Stock out numbering is not configured for ${DateFormat('dd-MMM-yyyy').format(_date)}. Please add numbering settings first.',
      );
    }
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return EntryShortcuts(
      onSave: _saveIssue,
      onNew: _finalclearItem,
      onClearLine: _clearItem,
      child: Scaffold(
          backgroundColor: const Color(0xFFF4F6FA),
          appBar: AppBar(
            title: const Text('Stock Out Details'),
            centerTitle: true,
          ),
          body: AnimatedBuilder(
              animation: ctrl,
              builder: (_, __) {
                if (ctrl.loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                return Padding(
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
                );
              })),
    );
  }

  // ================= HEADER =================
  Widget _headerCard() {
    return _card(
      title: 'Stock Out Information',
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          DropdownButtonFormField<StockLocationdata>(
            initialValue: _selectedDepartment,
            items: ctrl.departments.map((dept) {
              return DropdownMenuItem(
                value: dept,
                child: Text(dept.locationName),
              );
            }).toList(),
            onChanged: (dept) {
              setState(() {
                _selectedDepartment = dept;
              });
            },
            decoration: const InputDecoration(labelText: 'Department'),
          ),
          _field(_indentNo, 'Stock Out No'),
          _dropdown('Stock Out Type', issueTypes, _issueType,
              (v) => setState(() => _issueType = v)),
          _dateField(),
          SizedBox(
            width: 260,
            child: DropdownButtonFormField<int>(
              initialValue: _selectedRequestId,
              items: requestList.map<DropdownMenuItem<int>>((req) {
                return DropdownMenuItem(
                  value: req['id'],
                  child: Text(req['request_no']),
                );
              }).toList(),
              onChanged: (v) async {
                final request = await requestCtrl.getById(v!);

                setState(() {
                  _selectedRequestId = v;

                  _selectedDepartment = ctrl.departments.firstWhere(
                    (d) => d.locationName == request['department'],
                  );

                  _items.clear();

                  // for (var reqItem in request['items']) {
                  //   final issuedQty = _items
                  //       .where((e) => e.itemId == reqItem['item_id'])
                  //       .fold(0, (sum, e) => sum + e.qty);

                  //   if (issuedQty > reqItem['qty']) {
                  //     _showMessage("Cannot issue more than requested qty");
                  //     return;
                  //   }
                  // }

                  for (var i in request['items']) {
                    if ((i['line_status'] ?? 'CLOSED').toString() != 'OPEN') {
                      continue;
                    }
                    _items.add(
                      IssueItem(
                        itemId: i['item_id'],
                        itemCode: i['item_code'],
                        itemName: i['item_master']['item_name'],
                        unit: i['item_master']['unit'],
                        qty: double.parse(i['qty'].toString()),
                        rate: double.parse(i['rate'].toString()),
                        tax: 0,
                        type: _issueType ?? '',
                        lineStatus: 'CLOSED',
                      ),
                    );
                  }
                });

                _selectedRequestId == null
                    ? (dept) => setState(() => _selectedDepartment = dept)
                    : null;
              },
              decoration: const InputDecoration(labelText: 'Open Request'),
            ),
          ),
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
                  'Remaining After Stock Out : $_remainingStock',
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
        decoration: const InputDecoration(labelText: 'Stock Out Qty'),
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
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Qty exceeds available stock'),
              ),
            );

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
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Type')),
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
                      DataCell(Text(r.itemName)),
                      DataCell(Text(r.unit)),
                      DataCell(Text(r.qty.toString())),
                      DataCell(Text(r.rate.toStringAsFixed(2))),
                      DataCell(Text(r.amount.toStringAsFixed(2))),
                      DataCell(Text(r.itemCode)),
                      DataCell(
                        SizedBox(
                          width: 130,
                          child: DropdownButtonFormField<String>(
                            initialValue: r.lineStatus,
                            decoration: const InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                            ),
                            items: const ['OPEN', 'CLOSED']
                                .map(
                                  (status) => DropdownMenuItem(
                                    value: status,
                                    child: Text(status),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                r.lineStatus = value;
                              });
                            },
                          ),
                        ),
                      ),
                      DataCell(Text(r.type)),
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
          _totalChip('Amount', totalAmount),
          _totalChip('GST', totalGST),
          _totalChip('Net', netAmount, highlight: true),
          const Spacer(),
          FilledButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Save'),
            onPressed: _saveIssue,
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

  Future<void> _saveIssue() async {
    if (_selectedDepartment == null) {
      _showMessage("Please select department");
      return;
    }

    if (_issueType == null) {
      _showMessage("Please select stock out type");
      return;
    }

    if (_items.isEmpty) {
      _showMessage("Add at least one item");
      return;
    }

    try {
      final header = {
        "issue_no": _indentNo.text,
        "issue_date": _date.toIso8601String(),
        "department": _selectedDepartment!.locationName,
        "indent_no": _indentNo.text,
        "issue_type": _issueType,
        "open_request_no": _selectedRequestId,
        "status": 'CLOSED'
      };

      final itemsPayload = _items.map((e) {
        return {
          "item_id": e.itemId,
          "item_code": e.itemCode,
          "qty": e.qty,
          "rate": e.rate,
          "tax": e.tax,
          "line_status": e.lineStatus,
        };
      }).toList();

      await ctrl.createIssue({
        "header": header,
        "items": itemsPayload,
      });

      _showMessage("Stock out saved successfully");

      final shouldPrint = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
        title: const Text("Print Stock Out Slip"),
          content: const Text("Do you want to print this stock out slip?"),
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
        await _printIssue();
      }

      _finalclearItem();
      _finalclearItem();
    } catch (e) {
      _showMessage(e.toString());
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  // ================= COMMON UI =================
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
    TextInputAction textInputAction = TextInputAction.next,
    ValueChanged<String>? onSubmitted,
  }) =>
      SizedBox(
        width: 200,
        child: TextField(
          controller: c,
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

  Future<void> _printIssue() async {
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
                      "STOCK OUT SLIP",
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 20),

          /// ================= ISSUE INFO =================
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("Stock Out No: ${_indentNo.text}"),
                  pw.Text("Date: ${DateFormat('dd-MMM-yyyy').format(_date)}"),
                  pw.Text(
                      "Department: ${_selectedDepartment?.locationName ?? ''}"),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("Stock Out Type: ${_issueType ?? ''}"),
                  pw.Text("Request ID: ${_selectedRequestId ?? ''}"),
                  pw.Text("Status: CLOSED"),
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
              5: const pw.FlexColumnWidth(1),
              6: const pw.FlexColumnWidth(1),
              7: const pw.FlexColumnWidth(1),
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
                  _cell("GST %"),
                  _cell("GST Amt"),
                  _cell("Amount"),
                ],
              ),
              ...List.generate(_items.length, (i) {
                final r = _items[i];
                final gstAmount = (r.qty * r.rate) * (r.tax / 100);
                return pw.TableRow(
                  children: [
                    _cell("${i + 1}"),
                    _cell(r.itemName),
                    _cell(r.unit),
                    _cell(r.qty.toString()),
                    _cell(r.rate.toStringAsFixed(2)),
                    _cell(r.tax.toStringAsFixed(2)),
                    _cell(gstAmount.toStringAsFixed(2)),
                    _cell(r.amount.toStringAsFixed(2)),
                  ],
                );
              })
            ],
          ),

          pw.SizedBox(height: 20),

          /// ================= TOTALS =================
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              width: 250,
              child: pw.Column(
                children: [
                  _total("Sub Total", totalAmount),
                  _total("GST", totalGST),
                  pw.Divider(),
                  _total("Net Amount", netAmount, bold: true),
                ],
              ),
            ),
          ),

          pw.SizedBox(height: 30),

          /// ================= FOOTER =================
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(children: [
                pw.Text("Stock Out By (Store)"),
                pw.SizedBox(height: 30),
              ]),
              pw.Column(children: [
                pw.Text("Received By (Department)"),
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

  Widget _totalChip(String label, double value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Chip(
        backgroundColor:
            highlight ? Colors.orange.shade100 : Colors.grey.shade200,
        label: Text(
          '$label : ${value.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
