import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:retailpos/utils/date_picker_helper.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../controllers/inventory/issue_controller.dart';
import '../../controllers/inventory/item_controller.dart';
import '../../controllers/inventory/receiving_controller.dart';
import '../../controllers/inventory/request_controller.dart';
import '../../controllers/inventory/supplier_controller.dart';
import '../../controllers/purchase/purchase_order_controller.dart';
import '../../controllers/settings/property_info_controller.dart';
import '../../core/api/api_client.dart';
import '../../models/inventory/item_model.dart';
import '../../models/inventory/receive_item_model.dart';
import '../../models/inventory/stock_location_model.dart';
import '../../utils/branding_storage.dart';
import '../../utils/inclusive_rate_helper.dart';
import '../../widgets/entry_shortcuts.dart';

class ReceivingScreen extends StatefulWidget {
  const ReceivingScreen({super.key});

  @override
  State<ReceivingScreen> createState() => _ReceivingScreenState();
}

class _ReceivingScreenState extends State<ReceivingScreen> {
  final ctrl = ReceivingController();

  final supplierCtrl = SupplierController();
  final itemCtrl = ItemController();
  final poCtrl = PurchaseOrderController();
  final depctrl = IssueController();
  final requestCtrl = RequestController();
  final propertyCtrl = PropertyInfoController();

  String? _selectedItemName;
  int? _selectedBrandItemId;
  List<Item> _filteredBrands = [];
  StockLocationdata? _selectedDepartment;
  bool _isStockable = true;
  bool _useInclusiveRates = false;
  String _inclusiveRateScope = 'BOTH';
  List<dynamic> poList = [];

  // NEW: Double-Submit Shield
  bool _isSaving = false;

  // NEW: ================= FOCUS NODES =================
  final FocusNode _dateFocus = FocusNode();
  final FocusNode _poFocus = FocusNode();
  final FocusNode _supplierFocus = FocusNode();
  final FocusNode _billFocus = FocusNode();

  final FocusNode _itemCodeFocus = FocusNode();
  final FocusNode _itemNameFocus = FocusNode();
  final FocusNode _brandFocus = FocusNode();
  final FocusNode _qtyFocus = FocusNode();
  final FocusNode _inclusiveFocus = FocusNode();
  final FocusNode _scopeFocus = FocusNode();
  final FocusNode _rateFocus = FocusNode();
  final FocusNode _saleRateFocus = FocusNode();
  final FocusNode _taxFocus = FocusNode();
  final FocusNode _expDateFocus = FocusNode();
  final FocusNode _departmentFocus = FocusNode();
  final FocusNode _addBtnFocus = FocusNode();
  final FocusNode _saveBtnFocus = FocusNode();

  final _vendorDropdownKey = GlobalKey<DropdownSearchState<int>>();
  final _itemNameDropdownKey = GlobalKey<DropdownSearchState<String>>();
  final FocusNode _tableFocusNode = FocusNode();
  int? _selectedRowIndex;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _loadNextGrn();

    // NEW: Auto-focus the first field when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dateFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _dateFocus.dispose();
    _poFocus.dispose();
    _supplierFocus.dispose();
    _billFocus.dispose();
    _itemCodeFocus.dispose();
    _itemNameFocus.dispose();
    _brandFocus.dispose();
    _qtyFocus.dispose();
    _inclusiveFocus.dispose();
    _scopeFocus.dispose();
    _rateFocus.dispose();
    _saleRateFocus.dispose();
    _taxFocus.dispose();
    _expDateFocus.dispose();
    _departmentFocus.dispose();
    _addBtnFocus.dispose();
    _saveBtnFocus.dispose();
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
        _selectedRowIndex = ((current + 1).clamp(0, _items.length - 1));
      });
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selectedRowIndex = ((current - 1).clamp(0, _items.length - 1));
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

  Future<void> _loadInitialData() async {
    await supplierCtrl.load();
    await depctrl.getdepartment();
    await itemCtrl.load();
    _loadPropertyInfo();
    poList = await poCtrl.list();
    setState(() {});
  }

  Future<void> _loadPropertyInfo() async {
    await propertyCtrl.load();
  }

  Future<void> _loadNextGrn() async {
    try {
      final res = await ApiClient.get(
          "/api/receiving/next-grn?date=${_date.toIso8601String()}");
      if (res['success']) {
        _sno.text = res['data']['number'];
      }
    } catch (e) {
      _sno.clear();
      showErrorSnackbar(
        'Receiving numbering is not configured for ${DateFormat('dd-MMM-yyyy').format(_date)}. Please add numbering settings first.',
      );
    }
  }

  // ================= HEADER =================
  final _sno = TextEditingController(text: '1276');
  final _manualNo = TextEditingController(text: '1276');
  final _supplierBill = TextEditingController(text: '0');
  DateTime _date = DateTime.now();
  String? _poNo;

  // ================= ITEM =================
  final _code = TextEditingController();
  final _unit = TextEditingController(text: 'PCS');
  final _qty = TextEditingController();
  final _rate = TextEditingController();
  final _saleRate = TextEditingController();
  final _tax = TextEditingController();
  DateTime _expDate = DateTime.now();

  int? _editIndex;
  final List<ReceiveItem> _items = [];

  int? _supplierId;
  int? _selectedPoId;

  String? _selectedSupplier;

  // ================= CALC =================
  double get totalAmount => _items.fold(0, (s, e) => s + e.amount);
  double get totalGST => _items.fold(0, (s, e) => s + e.gst);
  double get netAmount => totalAmount + totalGST;

  String _fmtNumber(num value) {
    return value % 1 == 0 ? value.toInt().toString() : value.toString();
  }

  // ================= ADD / MODIFY =================
  Future<void> _saveItem() async {
    if (_qty.text.isEmpty) return;
    if (_selectedBrandItemId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Brand is required'),
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
              'Item already added. Please modify or delete existing item.'),
        ),
      );
      return;
    }

    if (!_isStockable && _selectedDepartment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Department is required'),
        ),
      );
      return;
    }

    final taxPercent = double.tryParse(_tax.text.trim()) ?? 0;
    final enteredBuyRate = double.tryParse(_rate.text.trim()) ?? 0;
    final enteredSaleRate = double.tryParse(_saleRate.text.trim()) ?? 0;

    final buyRate = _useInclusiveRates &&
            (_inclusiveRateScope == 'BOTH' || _inclusiveRateScope == 'BUY_ONLY')
        ? InclusiveRateHelper.exclusiveFromInclusive(
            enteredBuyRate,
            taxPercent,
          )
        : enteredBuyRate;

    final saleRate = _useInclusiveRates &&
            (_inclusiveRateScope == 'BOTH' ||
                _inclusiveRateScope == 'SALE_ONLY')
        ? InclusiveRateHelper.exclusiveFromInclusive(
            enteredSaleRate,
            taxPercent,
          )
        : enteredSaleRate;

    final item = ReceiveItem(
      code: _code.text,
      name: _selectedItemName!,
      brand:
          _filteredBrands.firstWhere((e) => e.id == _selectedBrandItemId).brand,
      unit: _unit.text,
      qty: double.parse(_qty.text),
      rate: buyRate,
      saleRate: saleRate,
      tax: taxPercent,
      itemId: _selectedBrandItemId.toString(),
      expiryDate: _expDate,
      department: !_isStockable ? _selectedDepartment!.id.toString() : "",
      lineStatus: 'CLOSED',
    );

    setState(() {
      if (_editIndex == null) {
        _items.add(item);
      } else {
        _items[_editIndex!] = item;
        _editIndex = null;
      }
    });

    // NEW: "Add More" Loop logic
    final addMore = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Item Added"),
        content: const Text("Do you want to add more items?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("No"),
          ),
          FilledButton(
            autofocus: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Yes, Add More"),
          ),
        ],
      ),
    );

    if (addMore == true) {
      await _clearItem();
      _itemCodeFocus.requestFocus(); // Back to start of loop
    } else {
      await _clearItem();
      _saveBtnFocus.requestFocus(); // Straight to save button
    }
  }

  Future<void> _saveReceiving() async {
    if (_isSaving) return; // NEW: Block double submit

    if (_supplierId == null || _items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vendor and items required')),
      );
      return;
    }

    // NEW: Instantly throw focus away to prevent button mashing
    _itemNameFocus.requestFocus();

    setState(() {
      _isSaving = true;
    });

    final nextNo = await requestCtrl.getNextRequestNo();
    final requestNo = nextNo;

    try {
      await ctrl.createReceiving(
        grnNo: _sno.text,
        manualNo: _manualNo.text,
        poNo: _selectedPoId,
        supplierId: _supplierId!,
        receiptDate: _date,
        supplierBillNo: _supplierBill.text,
        status: 'CLOSED',
        items: _items
            .map((e) => {
                  "code": e.code,
                  "name": e.name,
                  "brand": e.brand,
                  "unit": e.unit,
                  "qty": e.qty,
                  "item_id": e.itemId,
                  "rate": e.rate,
                  "sale_rate": e.saleRate,
                  "tax": e.tax,
                  "line_status": e.lineStatus,
                  "department": e.department,
                  "expiry_date": e.expiryDate != null
                      ? DateFormat('yyyy-MM-dd').format(e.expiryDate!)
                      : null
                })
            .toList(),
      );

      final departmentItems = _items
          .where(
              (e) => e.department != null && e.department.toString().isNotEmpty)
          .toList();

      if (departmentItems.isNotEmpty) {
        String depname = "";

        final deptId = int.tryParse(departmentItems.first.department ?? "");
        if (deptId != null) {
          final dept = depctrl.departments
              .where((e) => e.id == deptId)
              .cast<StockLocationdata?>()
              .firstOrNull;
          if (dept != null) {
            depname = dept.locationName;
          }
        }

        final requestPayload = {
          "department": depname,
          "request_date": _date.toIso8601String(),
          "open_request_no": requestNo,
          "items": departmentItems
              .map((e) => {
                    "item_id": e.itemId,
                    "code": e.code,
                    "qty": e.qty,
                    "rate": e.rate,
                    "line_status": "OPEN",
                  })
              .toList()
        };
        await requestCtrl.createRequest(requestPayload);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GRN Saved Successfully')),
      );

      final shouldPrint = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Print GRN"),
          content: const Text("Do you want to print this GRN?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("No"),
            ),
            FilledButton(
              autofocus: true,
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Yes"),
            ),
          ],
        ),
      );

      if (shouldPrint == true) {
        await _printReceiving();
      }

      await _finalclearItem();
      _dateFocus.requestFocus(); // Focus back to top for new GRN
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _editItem(int i) {
    final r = _items[i];
    _editIndex = i;
    _code.text = r.code;
    _selectedItemName = r.name;

    _filteredBrands = itemCtrl.list.where((e) => e.itemName == r.name).toList();

    final id = int.tryParse(r.itemId);
    if (_filteredBrands.any((e) => e.id == id)) {
      _selectedBrandItemId = id;
    } else {
      _selectedBrandItemId = null;
    }
    _unit.text = r.unit;
    _qty.text = r.qty.toString();
    _rate.text = r.rate.toString();
    _saleRate.text = r.saleRate.toString();
    _tax.text = r.tax.toString();
    _useInclusiveRates = false;
    _inclusiveRateScope = 'BOTH';
    _expDate = r.expiryDate ?? DateTime.now();

    final hasDepartment =
        r.department != null && r.department!.trim().isNotEmpty;
    _isStockable = !hasDepartment;

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

    setState(() {});
    _itemNameFocus.requestFocus(); // Jump to item name on edit
  }

  void _deleteItem(int i) {
    setState(() => _items.removeAt(i));
  }

  Future<void> _clearItem() async {
    _code.clear();
    _qty.clear();
    _rate.clear();
    _saleRate.clear();
    _tax.clear();
    _selectedItemName = null;
    _selectedBrandItemId = null;
    _isStockable = true;
    _selectedDepartment = null;
    _useInclusiveRates = false;
    _inclusiveRateScope = 'BOTH';
    setState(() {});
  }

  Future<void> _finalclearItem() async {
    poList = await poCtrl.list();
    setState(() {
      _selectedBrandItemId = null;
      _selectedItemName = null;
      _supplierId = null;
      _supplierBill.clear();
      _selectedPoId = null;
      _code.clear();
      _qty.clear();
      _rate.clear();
      _saleRate.clear();
      _tax.clear();
      _unit.clear();
      _editIndex = null;
      _items.clear();
      _useInclusiveRates = false;
      _inclusiveRateScope = 'BOTH';
    });
    await _loadNextGrn();
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return EntryShortcuts(
      onSave: _saveReceiving,
      onNew: _finalclearItem,
      onClearLine: () => _clearItem(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6FA),
        appBar: AppBar(
          title: const Text('Vendor Receive Order'),
          centerTitle: true,
        ),
        body: AnimatedBuilder(
          animation: ctrl,
          builder: (_, __) {
            return _mainBody();
          },
        ),
      ),
    );
  }

  Widget _mainBody() {
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Padding(
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
    );
  }

  // ================= HEADER =================
  Widget _headerCard() {
    return _card(
      title: 'Receiving Information',
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _field(_sno, 'S.No', readOnly: true),
          _dateField(),
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<int>(
              focusNode: _poFocus,
              initialValue: _selectedPoId,
              items: poList.map<DropdownMenuItem<int>>((po) {
                return DropdownMenuItem(
                  value: po['id'],
                  child: Text(po['po_no']),
                );
              }).toList(),
              onChanged: (v) async {
                final po = await poCtrl.getById(v!);

                setState(() {
                  _selectedPoId = v;
                  _supplierId = po['supplier_id'];
                  _items.clear();

                  final selected = supplierCtrl.list
                      .where((s) => s.id == _supplierId)
                      .toList();
                  _selectedSupplier =
                      selected.isNotEmpty ? selected.first.supplierName : null;

                  for (var i in po['items']) {
                    if ((i['line_status'] ?? 'CLOSED').toString() != 'OPEN') {
                      continue;
                    }
                    final matchedItem = itemCtrl.list
                        .where((e) => e.id == i['item_id'])
                        .cast<Item?>()
                        .firstOrNull;

                    _items.add(
                      ReceiveItem(
                          code: i['item_code'],
                          name: i['item_name'],
                          brand: i['brand'],
                          unit: i['unit'],
                          qty: double.parse(i['qty'].toString()),
                          rate: double.tryParse(i['rate'].toString()) ?? 0,
                          saleRate:
                              matchedItem?.retailSalePrice.toDouble() ?? 0,
                          tax: (double.tryParse(i['tax'].toString()) ?? 0) > 0
                              ? (double.tryParse(i['tax'].toString()) ?? 0)
                              : (matchedItem?.taxPercent ?? 0),
                          itemId: i['item_id'].toString(),
                          expiryDate: null,
                          department: i['department'],
                          lineStatus: 'CLOSED'),
                    );
                  }
                });
                _supplierFocus.requestFocus(); // Move to Supplier
              },
              decoration: const InputDecoration(labelText: 'PO No'),
            ),
          ),
          SizedBox(
            width: 260,
            child: Focus(
              focusNode: _supplierFocus,
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent &&
                    (event.logicalKey == LogicalKeyboardKey.enter ||
                        event.logicalKey == LogicalKeyboardKey.numpadEnter ||
                        event.logicalKey == LogicalKeyboardKey.arrowDown)) {
                  _vendorDropdownKey.currentState?.openDropDownSearch();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: DropdownSearch<int>(
                key: _vendorDropdownKey,
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
                  _billFocus.requestFocus(); // Move to Bill No
                },
              ),
            ),
          ),
          _field(_supplierBill, 'Vendor Bill No',
              focusNode: _billFocus,
              onSubmit: () => _itemCodeFocus.requestFocus()),
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
            child: Focus(
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent &&
                    (event.logicalKey == LogicalKeyboardKey.enter ||
                        event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
                  _itemNameFocus.requestFocus();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: TextField(
                focusNode: _itemCodeFocus,
                controller: _code,
                readOnly: true,
                decoration: const InputDecoration(labelText: 'Item Code'),
              ),
            ),
          ),
          SizedBox(
            width: 260,
            child: Focus(
              focusNode: _itemNameFocus,
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent) {
                  if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                    _itemCodeFocus.requestFocus();
                    return KeyEventResult.handled;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.enter ||
                      event.logicalKey == LogicalKeyboardKey.numpadEnter ||
                      event.logicalKey == LogicalKeyboardKey.arrowDown) {
                    _itemNameDropdownKey.currentState?.openDropDownSearch();
                    return KeyEventResult.handled;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                    return KeyEventResult.handled;
                  }
                }
                return KeyEventResult.ignored;
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
                    _tax.clear();
                    _code.clear();
                    _rate.clear();
                    _saleRate.clear();
                    _qty.clear();
                    _useInclusiveRates = false;
                    _inclusiveRateScope = 'BOTH';
                  });
                  _brandFocus.requestFocus();
                },
              ),
            ),
          ),
          SizedBox(
            width: 220,
            child: Focus(
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                  _itemNameFocus.requestFocus();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: DropdownButtonFormField<int>(
                focusNode: _brandFocus,
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
                    _saleRate.text = selected.retailSalePrice.toString();
                    _tax.text = selected.taxPercent.toString();
                    _isStockable = selected.stockable;
                    _useInclusiveRates = false;
                    _inclusiveRateScope = 'BOTH';
                    if (_isStockable) {
                      _selectedDepartment = null;
                    }
                  });
                  _qtyFocus.requestFocus();
                },
                decoration: const InputDecoration(labelText: 'Brand'),
              ),
            ),
          ),
          _field(_unit, 'Unit', readOnly: true, width: 100),
          _number(
            _qty,
            'Qty',
            focusNode: _qtyFocus,
            prevNode: _brandFocus,
            onSubmit: () => _inclusiveFocus.requestFocus(),
          ),
          SizedBox(
            width: 220,
            child: Focus(
              focusNode: _inclusiveFocus,
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent) {
                  if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                      event.logicalKey == LogicalKeyboardKey.arrowUp) {
                    _qtyFocus.requestFocus();
                    return KeyEventResult.handled;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.enter ||
                      event.logicalKey == LogicalKeyboardKey.numpadEnter) {
                    setState(() {
                      _useInclusiveRates = !_useInclusiveRates;
                      if (!_useInclusiveRates) {
                        _inclusiveRateScope = 'BOTH';
                      }
                    });
                    if (_useInclusiveRates) {
                      _scopeFocus.requestFocus();
                    } else {
                      _rateFocus.requestFocus();
                    }
                    return KeyEventResult.handled;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
                      event.logicalKey == LogicalKeyboardKey.arrowDown) {
                    if (_useInclusiveRates) {
                      _scopeFocus.requestFocus();
                    } else {
                      _rateFocus.requestFocus();
                    }
                    return KeyEventResult.handled;
                  }
                }
                return KeyEventResult.ignored;
              },
              child: SwitchListTile(
                title: const Text('Get Inclusive'),
                value: _useInclusiveRates,
                contentPadding: EdgeInsets.zero,
                onChanged: (value) {
                  setState(() {
                    _useInclusiveRates = value;
                    if (!value) {
                      _inclusiveRateScope = 'BOTH';
                    }
                  });
                  if (value) {
                    _scopeFocus.requestFocus();
                  } else {
                    _rateFocus.requestFocus();
                  }
                },
              ),
            ),
          ),
          if (_useInclusiveRates)
            SizedBox(
              width: 220,
              child: Focus(
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                    _inclusiveFocus.requestFocus();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: DropdownButtonFormField<String>(
                  focusNode: _scopeFocus,
                  initialValue: _inclusiveRateScope,
                  decoration:
                      const InputDecoration(labelText: 'Inclusive Apply To'),
                  items: const [
                    DropdownMenuItem(
                      value: 'BOTH',
                      child: Text('Buy and Sale Rate'),
                    ),
                    DropdownMenuItem(
                      value: 'SALE_ONLY',
                      child: Text('Sale Rate Only'),
                    ),
                    DropdownMenuItem(
                      value: 'BUY_ONLY',
                      child: Text('Buy Rate Only'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _inclusiveRateScope = value);
                    }
                    _rateFocus.requestFocus();
                  },
                ),
              ),
            ),
          _number(
            _rate,
            _useInclusiveRates &&
                    (_inclusiveRateScope == 'BOTH' ||
                        _inclusiveRateScope == 'BUY_ONLY')
                ? 'Buy Rate (Inclusive)'
                : 'Buy Rate',
            helperText: _useInclusiveRates &&
                    (_inclusiveRateScope == 'BOTH' ||
                        _inclusiveRateScope == 'BUY_ONLY') &&
                    _rate.text.trim().isNotEmpty
                ? InclusiveRateHelper.previewText(
                    label: 'Buy',
                    inclusiveAmount: double.tryParse(_rate.text.trim()) ?? 0,
                    taxPercent: double.tryParse(_tax.text.trim()) ?? 0,
                  )
                : null,
            focusNode: _rateFocus,
            prevNode: _useInclusiveRates ? _scopeFocus : _inclusiveFocus,
            onSubmit: () => _saleRateFocus.requestFocus(),
          ),
          _number(
            _saleRate,
            _useInclusiveRates &&
                    (_inclusiveRateScope == 'BOTH' ||
                        _inclusiveRateScope == 'SALE_ONLY')
                ? 'Sale Rate (Inclusive)'
                : 'Sale Rate',
            helperText: _useInclusiveRates &&
                    (_inclusiveRateScope == 'BOTH' ||
                        _inclusiveRateScope == 'SALE_ONLY') &&
                    _saleRate.text.trim().isNotEmpty
                ? InclusiveRateHelper.previewText(
                    label: 'Sale',
                    inclusiveAmount:
                        double.tryParse(_saleRate.text.trim()) ?? 0,
                    taxPercent: double.tryParse(_tax.text.trim()) ?? 0,
                  )
                : null,
            focusNode: _saleRateFocus,
            prevNode: _rateFocus,
            onSubmit: () => _taxFocus.requestFocus(),
          ),
          _number(
            _tax,
            'Tax %',
            focusNode: _taxFocus,
            prevNode: _saleRateFocus,
            onSubmit: () => _expDateFocus.requestFocus(),
          ),
          _dateFieldexp(),
          if (!_isStockable)
            SizedBox(
              width: 260,
              child: Focus(
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                    _expDateFocus.requestFocus();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: DropdownButtonFormField<StockLocationdata>(
                  focusNode: _departmentFocus,
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
                    _addBtnFocus.requestFocus();
                  },
                ),
              ),
            ),
          FilledButton.icon(
            focusNode: _addBtnFocus,
            icon: const Icon(Icons.add),
            label: Text(_editIndex == null ? 'Add Item' : 'Update Item'),
            onPressed: _saveItem,
          ),
        ],
      ),
    );
  }

  Widget _dateFieldexp() {
    return SizedBox(
      width: 180,
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _taxFocus.requestFocus();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: TextField(
          focusNode: _expDateFocus,
          readOnly: true,
          controller: TextEditingController(
            text: DateFormat('dd-MMM-yyyy').format(_expDate),
          ),
          decoration: const InputDecoration(
            labelText: 'Exp Date',
            suffixIcon: Icon(Icons.calendar_today),
          ),
          onTap: () async {
            final selected = await pickSingleDate(
              context: context,
              initialDate: _expDate,
            );

            if (selected != null) {
              setState(() {
                _expDate = selected;
              });
            }
            if (!_isStockable) {
              _departmentFocus.requestFocus();
            } else {
              _addBtnFocus.requestFocus();
            }
          },
        ),
      ),
    );
  }

  // ================= TABLE =================
  Widget _tableCard() {
    final showDepartment = _items.any(
      (e) => (e.department ?? '').trim().isNotEmpty,
    );
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
                  columns: [
                    const DataColumn(label: Text('S.No')),
                    const DataColumn(label: Text('Code')),
                    const DataColumn(label: Text('Item')),
                    const DataColumn(label: Text('Brand')),
                    const DataColumn(label: Text('Unit')),
                    const DataColumn(label: Text('Buy Rate')),
                    const DataColumn(label: Text('Sale Rate')),
                    const DataColumn(label: Text('GST %')),
                    const DataColumn(label: Text('Qty')),
                    const DataColumn(label: Text('Status')),
                    const DataColumn(label: Text('Amount')),
                    const DataColumn(label: Text('Vendor')),
                    if (showDepartment)
                      const DataColumn(label: Text('Department')),
                    const DataColumn(label: Text('Action')),
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
                      selected: _selectedRowIndex == i,
                      onSelectChanged: (_) {
                        setState(() => _selectedRowIndex = i);
                        FocusScope.of(context).requestFocus(_tableFocusNode);
                      },
                      color: WidgetStateProperty.all(
                          i.isEven ? Colors.grey.shade50 : Colors.white),
                      cells: [
                        DataCell(Text('${i + 1}')),
                        DataCell(Text(r.code)),
                        DataCell(Text(r.name)),
                        DataCell(Text(r.brand)),
                        DataCell(Text(r.unit)),
                        DataCell(Text(r.rate.toStringAsFixed(2))),
                        DataCell(Text(r.saleRate.toStringAsFixed(2))),
                        DataCell(Text(r.tax.toStringAsFixed(2))),
                        DataCell(Text(_fmtNumber(r.qty))),
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
                        DataCell(Text(r.amount.toString())),
                        DataCell(Text(_selectedSupplier ?? '')),
                        if (showDepartment) DataCell(Text(depname)),
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
            focusNode: _saveBtnFocus,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.save),
            label: Text(_isSaving ? 'Saving...' : 'Save'),
            onPressed: _isSaving ? null : _saveReceiving,
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
    bool readOnly = false,
    double width = 200,
    FocusNode? focusNode,
    TextInputAction textInputAction = TextInputAction.next,
    VoidCallback? onSubmit,
  }) =>
      SizedBox(
        width: width,
        child: TextField(
          focusNode: focusNode,
          controller: c,
          readOnly: readOnly,
          textInputAction: textInputAction,
          onSubmitted: (_) {
            if (onSubmit != null) {
              onSubmit();
            } else {
              if (textInputAction == TextInputAction.next) {
                FocusScope.of(context).nextFocus();
              } else {
                FocusScope.of(context).unfocus();
              }
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
    FocusNode? prevNode,
    TextInputAction? textInputAction,
    VoidCallback? onSubmit,
  }) =>
      SizedBox(
        width: 140,
        child: Focus(
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.arrowUp) {
              prevNode?.requestFocus();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: TextField(
            focusNode: focusNode,
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                RegExp(r'^\d*\.?\d{0,2}'),
              ),
            ],
            controller: c,
            keyboardType: TextInputType.number,
            textInputAction: textInputAction ?? TextInputAction.next,
            decoration: InputDecoration(labelText: l, helperText: helperText),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) {
              if (onSubmit != null) {
                onSubmit();
              } else {
                if ((textInputAction ?? TextInputAction.next) ==
                    TextInputAction.next) {
                  FocusScope.of(context).nextFocus();
                } else {
                  FocusScope.of(context).unfocus();
                }
              }
            },
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
          ),
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
                  await _loadNextGrn();
                }
                _poFocus.requestFocus(); // Move to PO
                return null;
              },
            ),
          },
          child: TextField(
            focusNode: _dateFocus, // UPDATED
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
                await _loadNextGrn();
              }
              _poFocus.requestFocus(); // Move to PO
            },
          ),
        ),
      ),
    );
  }

  Widget _totalChip(String label, double value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Chip(
        backgroundColor:
            highlight ? Colors.green.shade100 : Colors.grey.shade200,
        label: Text(
          '$label : ${value.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Future<void> _printReceiving() async {
    final pdf = pw.Document();

    final supplier = supplierCtrl.list.firstWhere((e) => e.id == _supplierId);

    final property = propertyCtrl.data;
    final logo = await BrandingStorage.loadPdfLogo(property?.logoPath);
    final selectedPo = poList.firstWhere(
      (po) => po['id'] == _selectedPoId,
      orElse: () => null,
    );

    final poNumber = selectedPo != null ? selectedPo['po_no'] : '';
    // pw.MemoryImage? logo;

    // if (property.logoPath != null && property.logoPath!.isNotEmpty) {
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
                  width: 70,
                  height: 70,
                  margin: const pw.EdgeInsets.only(right: 12),
                  child: pw.Image(logo, fit: pw.BoxFit.contain),
                ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      property!.propertyName,
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(property.address),
                    pw.Text("GSTIN: ${property.gstNo}"),
                    pw.Text("Mobile: ${property.mobile}"),
                  ],
                ),
              ),
              pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: pw.BoxDecoration(border: pw.Border.all()),
                child: pw.Text(
                  "VENDOR RECEIVE ORDER",
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 20),

          /// ================= INFO SECTION =================
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("GRN No: ${_sno.text}"),
                  pw.Text("Date: ${DateFormat('dd-MMM-yyyy').format(_date)}"),
                  pw.Text("PO No: ${poNumber ?? ''}"),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("Vendor: ${supplier.supplierName}"),
                  pw.Text("Bill No: ${_supplierBill.text}"),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 20),

          /// ================= ITEM TABLE =================
          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(25),
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
                    _cell(r.name),
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
          pw.Text(
            "Goods received in good condition.",
          ),

          pw.SizedBox(height: 40),

          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(children: [
                pw.Text("Store Incharge"),
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
}
