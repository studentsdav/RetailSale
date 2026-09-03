import 'dart:convert';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/printing/pos_invoice_printer.dart';

import '../../controllers/inventory/issue_controller.dart' show IssueController;
import '../../controllers/inventory/item_controller.dart';
import '../../controllers/inventory/document_sequence_controller.dart';
import '../../controllers/inventory/supplier_controller.dart';
import '../../controllers/purchase/purchase_order_controller.dart';
import '../../controllers/settings/property_info_controller.dart';
import '../../models/common/property_info_model.dart';
import '../../models/inventory/item_model.dart';
import '../../models/inventory/purchase_item_model.dart';
import '../../models/inventory/purchase_order_model.dart';
import '../../models/inventory/stock_location_model.dart';
import '../../models/inventory/supplier_model.dart';
import '../../core/api/api_client.dart';
import '../../utils/branding_storage.dart';
import '../../utils/inclusive_rate_helper.dart';
import '../../utils/date_picker_helper.dart';

class PurchaseOrderScreen extends StatefulWidget {
  final List<dynamic>? draftItems;
  final String? supplierName;
  final int? supplierId;

  const PurchaseOrderScreen({
    super.key,
    this.draftItems,
    this.supplierName,
    this.supplierId,
  });

  @override
  State<PurchaseOrderScreen> createState() => _PurchaseOrderScreenState();
}

class _PurchaseOrderScreenState extends State<PurchaseOrderScreen> {
  final ScrollController _horizontalScrollController = ScrollController();
  // ================= HEADER =================
  final _poNo = TextEditingController(text: '3');
  DateTime _date = DateTime.now();
  int? _supplierId;

  String? _selectedItemName;
  int? _selectedBrandItemId;
  List<Item> _filteredBrands = [];

  // ================= ITEM =================
  final _code = TextEditingController();
  final numberingCtrl = DocumentSequenceController();
  final _unit = TextEditingController(text: 'PCS');
  final _qty = TextEditingController();
  final _rate = TextEditingController();
  final _tax = TextEditingController();

  final depctrl = IssueController();
  final propertyCtrl = PropertyInfoController();
  PropertyInfo? propertyInfo;

  int? _editIndex;
  final List<PurchaseItem> _items = [];
  StockLocationdata? _selectedDepartment;
  bool _isStockable = true;
  bool _rateInclusive = false;

  final supplierCtrl = SupplierController();
  final itemCtrl = ItemController();
  final poCtrl = PurchaseOrderController();

  // NEW: Double submit prevention
  bool _isSaving = false;

  // NEW: ================= FOCUS NODES =================
  final FocusNode _supplierFocus = FocusNode();
  final FocusNode _dateFocus = FocusNode();
  final FocusNode _itemCodeFocus = FocusNode();
  final FocusNode _itemNameFocus = FocusNode();
  final FocusNode _brandFocus = FocusNode();
  final FocusNode _qtyFocus = FocusNode();
  final FocusNode _rateFocus = FocusNode();
  final FocusNode _taxFocus = FocusNode();
  final FocusNode _inclusiveFocus = FocusNode(); // NEW: Focus for the checkbox
  final FocusNode _departmentFocus = FocusNode();
  final FocusNode _addBtnFocus = FocusNode();
  final FocusNode _saveBtnFocus = FocusNode();

  // NEW: GlobalKeys to control the DropdownSearch widgets programmatically
  final GlobalKey<DropdownSearchState<int>> _supplierSearchKey =
      GlobalKey<DropdownSearchState<int>>();
  final GlobalKey<DropdownSearchState<String>> _itemSearchKey =
      GlobalKey<DropdownSearchState<String>>();

  // ================= TOTAL =================
  double get totalAmount => _items.fold(0, (s, e) => s + e.amount);
  double get totalGST =>
      _items.fold(0, (s, e) => s + ((e.qty * e.rate) * (e.tax / 100)));
  double get netAmount => totalAmount + totalGST;

  String _fmtNumber(num value) {
    return value % 1 == 0 ? value.toDouble().toString() : value.toString();
  }

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _loadPropertyInfo();

    // NEW: Auto-focus the first field (Supplier) when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _supplierFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _supplierFocus.dispose();
    _dateFocus.dispose();
    _itemCodeFocus.dispose();
    _itemNameFocus.dispose();
    _brandFocus.dispose();
    _qtyFocus.dispose();
    _rateFocus.dispose();
    _taxFocus.dispose();
    _inclusiveFocus.dispose();
    _departmentFocus.dispose();
    _addBtnFocus.dispose();
    _saveBtnFocus.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
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

    int? prefilledSupplierId;
    String suppSearchStr = (widget.supplierName ?? '').trim();
    if (suppSearchStr.isEmpty && widget.draftItems != null) {
      for (final raw in widget.draftItems!) {
        if (raw is Map) {
          final sName = (raw['Supplier'] ?? raw['supplier'] ?? raw['Vendor'] ?? raw['vendor'] ?? '').toString().trim();
          if (sName.isNotEmpty) {
            suppSearchStr = sName;
            break;
          }
        }
      }
    }

    if (widget.supplierId != null) {
      prefilledSupplierId = widget.supplierId;
    } else if (suppSearchStr.isNotEmpty) {
      final suppSearchLow = suppSearchStr.toLowerCase();
      try {
        final supp = supplierCtrl.list.firstWhere(
          (s) => s.supplierName.toLowerCase().contains(suppSearchLow) || suppSearchLow.contains(s.supplierName.toLowerCase()),
        );
        prefilledSupplierId = supp.id;
      } catch (_) {}

      if (prefilledSupplierId == null) {
        final tokens = suppSearchLow.split(RegExp(r'\s+')).where((t) => t.length >= 3);
        for (final token in tokens) {
          try {
            final supp = supplierCtrl.list.firstWhere(
              (s) => s.supplierName.toLowerCase().contains(token),
            );
            prefilledSupplierId = supp.id;
            break;
          } catch (_) {}
        }
      }
    }

    if (prefilledSupplierId == null && supplierCtrl.list.isNotEmpty) {
      prefilledSupplierId = supplierCtrl.list.first.id;
    }

    String cleanNumStr(dynamic val) {
      if (val == null) return '';
      final s = val.toString();
      final match = RegExp(r'[\d.]+').firstMatch(s);
      return match != null ? match.group(0)! : '';
    }

    final List<PurchaseItem> prefilledItems = [];
    if (widget.draftItems != null && widget.draftItems!.isNotEmpty) {
      for (final raw in widget.draftItems!) {
        if (raw is Map) {
          final itemCodeStr = (raw['Item Code'] ?? raw['Code'] ?? raw['code'] ?? raw['itemCode'] ?? raw['item_code'] ?? raw['ITEM_CODE'] ?? '').toString().trim();
          final itemNameStr = (raw['Item Name'] ?? raw['ItemName'] ?? raw['itemName'] ?? raw['item_name'] ?? raw['name'] ?? raw['title'] ?? raw['ITEM_NAME'] ?? '').toString().trim();
          final qtyRaw = raw['Quantity'] ?? raw['Quantity (Units)'] ?? raw['Quantity (Pcs)'] ?? raw['Qty'] ?? raw['qty'] ?? raw['quantity'] ?? raw['reorderQty'] ?? raw['count'] ?? raw['units'] ?? raw['Current Stock'] ?? raw['stock'] ?? 10;
          final rateRaw = raw['Rate'] ?? raw['rate'] ?? raw['price'] ?? raw['cost'] ?? raw['purchase_rate'] ?? raw['mrp'] ?? 0;
          final taxRaw = raw['Tax %'] ?? raw['Tax'] ?? raw['tax'] ?? raw['tax_percent'] ?? 0;

          final qtyVal = double.tryParse(cleanNumStr(qtyRaw)) ?? 10.0;
          final rateVal = double.tryParse(cleanNumStr(rateRaw)) ?? 0.0;
          final taxVal = double.tryParse(cleanNumStr(taxRaw)) ?? 0.0;

          Item? matchedItem;
          if (itemCodeStr.isNotEmpty) {
            try {
              matchedItem = itemCtrl.list.firstWhere(
                (i) => i.itemCode.toLowerCase() == itemCodeStr.toLowerCase(),
              );
            } catch (_) {}
          }
          if (matchedItem == null && itemNameStr.isNotEmpty) {
            final nameLow = itemNameStr.toLowerCase();
            try {
              matchedItem = itemCtrl.list.firstWhere(
                (i) => i.itemName.toLowerCase().contains(nameLow) || nameLow.contains(i.itemName.toLowerCase()),
              );
            } catch (_) {}

            if (matchedItem == null) {
              final tokens = nameLow.split(RegExp(r'\s+')).where((t) => t.length >= 3);
              for (final token in tokens) {
                try {
                  matchedItem = itemCtrl.list.firstWhere(
                    (i) => i.itemName.toLowerCase().contains(token),
                  );
                  break;
                } catch (_) {}
              }
            }
          }

          final effectiveRate = rateVal > 0 
              ? rateVal 
              : (matchedItem != null 
                  ? (matchedItem.rate > 0 ? matchedItem.rate : (matchedItem.retailSalePrice > 0 ? matchedItem.retailSalePrice : matchedItem.mrp)) 
                  : 0.0);

          final effectiveTax = taxVal > 0 
              ? taxVal 
              : (matchedItem != null ? matchedItem.taxPercent : 0.0);

          if (matchedItem != null) {
            prefilledItems.add(PurchaseItem(
              itemId: matchedItem.id,
              itemCode: matchedItem.itemCode,
              itemName: matchedItem.itemName,
              brand: matchedItem.brand.isNotEmpty ? matchedItem.brand : 'General',
              unit: matchedItem.unit.isNotEmpty ? matchedItem.unit : 'PCS',
              qty: qtyVal > 0 ? qtyVal : 10.0,
              rate: effectiveRate,
              tax: effectiveTax,
              department: '',
            ));
          } else if (itemNameStr.isNotEmpty || itemCodeStr.isNotEmpty) {
            prefilledItems.add(PurchaseItem(
              itemId: 0,
              itemCode: itemCodeStr.isNotEmpty ? itemCodeStr : 'ITEM-DRAFT',
              itemName: itemNameStr.isNotEmpty ? itemNameStr : 'Draft Item',
              brand: 'General',
              unit: 'PCS',
              qty: qtyVal > 0 ? qtyVal : 10.0,
              rate: effectiveRate,
              tax: effectiveTax,
              department: '',
            ));
          }
        }
      }
    }

    setState(() {
      _poNo.text = no;
      if (prefilledSupplierId != null) {
        _supplierId = prefilledSupplierId;
      }
      if (prefilledItems.isNotEmpty) {
        _items.addAll(prefilledItems);
      }
    });
  }

  // ================= ADD / UPDATE ITEM =================
  Future<void> _saveItem() async {
    if (_qty.text.isEmpty) return;

    if (_selectedBrandItemId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Brand is required')),
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
        const SnackBar(content: Text('Department is required')),
      );
      return;
    }

    final taxPercent = double.tryParse(_tax.text.trim()) ?? 0;
    final enteredRate = double.tryParse(_rate.text.trim()) ?? 0;

    final baseRate = _rateInclusive
        ? InclusiveRateHelper.exclusiveFromInclusive(enteredRate, taxPercent)
        : enteredRate;

    final item = PurchaseItem(
      itemCode: _code.text,
      itemName: _selectedItemName!,
      brand: _filteredBrands.cast<Item?>().firstWhere(
            (e) => e?.id == _selectedBrandItemId,
            orElse: () => null,
          )?.brand ?? 'General',
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
      _clearItem();
      _itemCodeFocus.requestFocus(); // Back to start of loop
    } else {
      _clearItem();
      _saveBtnFocus.requestFocus(); // Straight to save button
    }
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
    _itemNameFocus.requestFocus(); // Jump to item name on edit
  }

  void _deleteItem(int i) {
    setState(() => _items.removeAt(i));
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

  Future<void> _savePurchaseOrder() async {
    if (_isSaving) return; // NEW: Block double submit

    if (_supplierId == null) {
      _showMessage("Select vendor");
      return;
    }

    if (_items.isEmpty) {
      _showMessage("Add at least one item");
      return;
    }

    // NEW: Instantly throw focus away to prevent button mashing
    _itemNameFocus.requestFocus();

    setState(() {
      _isSaving = true;
    });

    try {
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

      final actionChoice = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.teal),
              SizedBox(width: 8),
              Text("Purchase Order Saved"),
            ],
          ),
          content: const Text("Would you like to print this Purchase Order or email it to the Vendor?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, "CLOSE"),
              child: const Text("Close"),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.print, size: 16),
              label: const Text("Print PO"),
              onPressed: () => Navigator.pop(context, "PRINT"),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF7A1A), foregroundColor: Colors.white),
              icon: const Icon(Icons.email_outlined, size: 16),
              label: const Text("Email Vendor"),
              onPressed: () => Navigator.pop(context, "EMAIL"),
            ),
          ],
        ),
      );

      if (actionChoice == "PRINT") {
        await _printPurchaseOrder();
      } else if (actionChoice == "EMAIL") {
        await _emailPurchaseOrderToVendor();
      }

      _showMessage("Purchase Order Saved Successfully");
      _finalclearItem();
      _itemCodeFocus.requestFocus(); // Focus back to start for new PO
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
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
      body: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: Padding(
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
          SizedBox(
            width: 260,
            // UPDATED: Wrapped Supplier DropdownSearch to handle Enter key
            child: Focus(
              focusNode: _supplierFocus,
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent &&
                    (event.logicalKey == LogicalKeyboardKey.enter ||
                        event.logicalKey == LogicalKeyboardKey.numpadEnter ||
                        event.logicalKey == LogicalKeyboardKey.arrowDown)) {
                  _supplierSearchKey.currentState?.openDropDownSearch();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: DropdownSearch<int>(
                key: _supplierSearchKey,
                selectedItem: _supplierId,
                items: (filter, infiniteScrollProps) =>
                    supplierCtrl.list.map((s) => s.id).toList(),
                itemAsString: (id) {
                  final supplier = supplierCtrl.list.cast<Supplier?>().firstWhere(
                    (e) => e?.id == id,
                    orElse: () => null,
                  );
                  return supplier?.supplierName ?? 'Select Vendor';
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
                  _dateFocus.requestFocus(); // Move to Date
                },
              ),
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
          // UPDATED: Catch Enter on Item Code
          SizedBox(
            width: 220,
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
            // UPDATED: Item Name handles Enter/Down to open, Left arrow to go back
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
                    _itemSearchKey.currentState?.openDropDownSearch();
                    return KeyEventResult.handled;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                    return KeyEventResult.handled;
                  }
                }
                return KeyEventResult.ignored;
              },
              child: DropdownSearch<String>(
                key: _itemSearchKey,
                selectedItem: _selectedItemName,
                items: (filter, infiniteScrollProps) {
                      final q = filter.trim().toLowerCase();
                      final all = itemCtrl.list;
                      final filtered = q.isEmpty
                          ? all
                          : all.where((e) =>
                              e.itemName.toLowerCase().contains(q) ||
                              e.brand.toLowerCase().contains(q) ||
                              e.itemCode.toLowerCase().contains(q)).toList();
                      return filtered.map((e) => e.itemName).toSet().toList();
                    },
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
                    _tax.clear();
                    _qty.clear();
                    _rateInclusive = false;
                  });
                  _brandFocus.requestFocus();
                },
              ),
            ),
          ),

          SizedBox(
            width: 220,
            // UPDATED: Brand handles left arrow
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
                  Item? selected;
                  try {
                    selected = _filteredBrands.firstWhere((e) => e.id == v);
                  } catch (_) {}
                  if (selected != null) {
                    setState(() {
                      _selectedBrandItemId = v;
                      _code.text = selected!.itemCode;
                      _unit.text = selected.unit;
                      _rate.text = selected.rate.toString();
                      _tax.text = selected.taxPercent.toString();
                      _isStockable = selected.stockable;
                      _rateInclusive = false;
                      if (_isStockable) {
                        _selectedDepartment = null;
                      }
                    });
                  }
                  _qtyFocus.requestFocus();
                },
                decoration: const InputDecoration(labelText: 'Brand'),
              ),
            ),
          ),
          _field(_unit, 'Unit', readOnly: true, width: 100),

          _number(_qty, 'Qty',
              focusNode: _qtyFocus,
              prevNode: _brandFocus,
              onSubmit: () => _rateFocus.requestFocus()),

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
            focusNode: _rateFocus,
            prevNode: _qtyFocus,
            onSubmit: () => _taxFocus.requestFocus(),
          ),

          _number(_tax, 'Tax %',
              focusNode: _taxFocus,
              prevNode: _rateFocus,
              onSubmit: () => _inclusiveFocus.requestFocus()),

          SizedBox(
            width: 180,
            // UPDATED: Checkbox wrapped in Focus for navigation and toggling
            child: Focus(
              focusNode: _inclusiveFocus,
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent) {
                  if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                      event.logicalKey == LogicalKeyboardKey.arrowUp) {
                    _taxFocus.requestFocus();
                    return KeyEventResult.handled;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.enter ||
                      event.logicalKey == LogicalKeyboardKey.numpadEnter) {
                    setState(() {
                      _rateInclusive = !_rateInclusive;
                    });
                    return KeyEventResult.handled;
                  }
                }
                return KeyEventResult.ignored;
              },
              child: CheckboxListTile(
                value: _rateInclusive,
                contentPadding: EdgeInsets.zero,
                title: const Text('Inclusive'),
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (value) {
                  setState(() {
                    _rateInclusive = value ?? false;
                  });
                  if (!_isStockable) {
                    _departmentFocus.requestFocus();
                  } else {
                    _addBtnFocus.requestFocus();
                  }
                },
              ),
            ),
          ),

          if (!_isStockable)
            SizedBox(
              width: 260,
              child: Focus(
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                    _inclusiveFocus.requestFocus();
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

  // ================= TABLE =================
  Widget _itemsTableCard() {
    return LayoutBuilder(builder: (context, constraints) {
      return SizedBox(
          height: constraints.maxHeight,
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: Scrollbar(
              controller: _horizontalScrollController,
              thumbVisibility: true,
              trackVisibility: true,
              child: SingleChildScrollView(
                controller: _horizontalScrollController,
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
                      DataCell(Text('${r.itemName}${r.brand.isNotEmpty ? ' (${r.brand})' : ''}')),
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
          ),
        ),
      );
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
            focusNode: _saveBtnFocus,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.save),
            label: Text(_isSaving ? 'Saving...' : 'Save'),
            onPressed: _isSaving ? null : _savePurchaseOrder,
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

  // UPDATED: Now supports FocusNode and onSubmit for chaining
  Widget _field(
    TextEditingController c,
    String l, {
    bool readOnly = false,
    double width = 220,
    FocusNode? focusNode,
    VoidCallback? onSubmit,
  }) =>
      SizedBox(
        width: width,
        child: TextField(
          focusNode: focusNode,
          controller: c,
          readOnly: readOnly,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) {
            if (onSubmit != null) onSubmit();
          },
          onEditingComplete: onSubmit == null ? _nextFocus : null,
          decoration: InputDecoration(labelText: l),
        ),
      );

  // UPDATED: Custom number field now catches the Up arrow to go backwards
  Widget _number(
    TextEditingController c,
    String l, {
    String? helperText,
    FocusNode? focusNode,
    FocusNode? prevNode,
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
            controller: c,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))
            ],
            decoration: InputDecoration(labelText: l, helperText: helperText),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) {
              if (onSubmit != null) onSubmit();
            },
          ),
        ),
      );

  void _nextFocus() {
    FocusScope.of(context).nextFocus();
  }

  Widget _dateField() {
    return SizedBox(
      width: 180,
      child: TextField(
        focusNode: _dateFocus,
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
          _itemCodeFocus.requestFocus(); // Move to Item Code next
        },
      ),
    );
  }

  Future<void> _emailPurchaseOrderToVendor() async {
    final Supplier? supplier = supplierCtrl.list.cast<Supplier?>().firstWhere(
          (e) => e?.id == _supplierId,
          orElse: () => null,
        );

    final String initialEmail = (supplier?.email ?? '').trim();
    final String vendorName = supplier?.supplierName ?? 'Vendor';

    final emailCtrl = TextEditingController(text: initialEmail);

    final String? recipientEmail = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            const Icon(Icons.email_outlined, color: Color(0xFFFF7A1A)),
            const SizedBox(width: 8),
            Text(initialEmail.isNotEmpty ? 'Email Purchase Order' : 'Vendor Email Missing'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              initialEmail.isNotEmpty
                  ? 'Confirm recipient email address for "$vendorName":'
                  : 'Vendor "$vendorName" does not have an email registered in Vendor Master. Enter email:',
              style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Recipient Email Address',
                hintText: 'vendor@supplier.com',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF7A1A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('Send Email'),
            onPressed: () => Navigator.pop(context, emailCtrl.text.trim()),
          ),
        ],
      ),
    );

    if (recipientEmail == null || recipientEmail.isEmpty) return;
    await _sendPoEmailToAddress(recipientEmail, vendorName);
  }

  Future<void> _sendPoEmailToAddress(String emailAddr, String vendorName) async {
    try {
      final totalGST = _items.fold<double>(
          0, (sum, item) => sum + ((item.qty * item.rate) * (item.tax / 100)));
      final grandTotal = totalAmount + totalGST;

      String? pdfBase64;
      try {
        final pdfDoc = await _buildPurchaseOrderPdf();
        final bytes = await pdfDoc.save();
        pdfBase64 = base64Encode(bytes);
      } catch (err) {
        debugPrint('Error generating PO PDF for email: $err');
      }

      final res = await ApiClient.post('/api/inventory/purchase-orders/send-email', {
        'to_email': emailAddr,
        'po_no': _poNo.text,
        'vendor_name': vendorName,
        'total_amount': grandTotal,
        if (pdfBase64 != null) 'pdf_base64': pdfBase64,
        'pdf_filename': 'PO_${_poNo.text.replaceAll(' ', '_')}.pdf',
        'items': _items.map((e) => {
          'item_name': e.itemName,
          'qty': e.qty,
          'unit_rate': e.rate,
          'tax': e.tax,
          'total': (e.qty * e.rate) * (1 + (e.tax / 100)),
        }).toList(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Purchase Order emailed successfully to $emailAddr!'),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Purchase Order dispatched! (Email note: $e)'),
            backgroundColor: Colors.orange.shade700,
          ),
        );
      }
    }
  }

  Future<pw.Document> _buildPurchaseOrderPdf() async {
    final pdf = pw.Document();

    final Supplier? supplier = supplierCtrl.list.cast<Supplier?>().firstWhere(
      (e) => e?.id == _supplierId,
      orElse: () => null,
    );

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
          PosInvoicePrinter.buildStandardA4Header(
            property: property,
            logo: logo,
            rightWidget: pw.Text(
              "PURCHASE ORDER",
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.deepOrange700,
              ),
            ),
          ),
          pw.SizedBox(height: 12),

          /// ================= VENDOR & PO DETAILS CARD =================
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              color: PdfColors.grey50,
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 3,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "VENDOR / BILL FROM",
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 8,
                          color: PdfColors.blueGrey800,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        supplier?.supplierName ?? 'Vendor',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 8.5,
                          color: PdfColors.blueGrey900,
                        ),
                      ),
                      if (supplier != null && (supplier.address ?? '').trim().isNotEmpty)
                        pw.Text(
                          supplier.address!.trim(),
                          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
                        ),
                      if (supplier != null && (supplier.gstin ?? '').trim().isNotEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(top: 2),
                          child: pw.Text(
                            "GSTIN: ${supplier.gstin!.trim()}",
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blueGrey800,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                pw.Container(
                  width: 0.5,
                  height: 45,
                  color: PdfColors.grey300,
                  margin: const pw.EdgeInsets.symmetric(horizontal: 16),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "ORDER DETAILS",
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 8,
                          color: PdfColors.blueGrey800,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      _metaRow("PO No", _poNo.text),
                      _metaRow("Date", PosInvoicePrinter.formatTzDate(_date)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          /// ================= ITEM TABLE =================
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(30),
              1: const pw.FlexColumnWidth(2.5),
              2: const pw.FlexColumnWidth(1.5),
              3: const pw.FlexColumnWidth(1),
              4: const pw.FlexColumnWidth(1.2),
              5: const pw.FlexColumnWidth(1.2),
              6: const pw.FlexColumnWidth(1),
              7: const pw.FlexColumnWidth(1.2),
              8: const pw.FlexColumnWidth(1.5),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
                children: [
                  _tableCell("S.No", bold: true, alignment: pw.Alignment.center),
                  _tableCell("Item", bold: true),
                  _tableCell("Brand", bold: true),
                  _tableCell("Unit", bold: true, alignment: pw.Alignment.center),
                  _tableCell("Qty", bold: true, alignment: pw.Alignment.centerRight),
                  _tableCell("Rate", bold: true, alignment: pw.Alignment.centerRight),
                  _tableCell("GST %", bold: true, alignment: pw.Alignment.centerRight),
                  _tableCell("GST Amt", bold: true, alignment: pw.Alignment.centerRight),
                  _tableCell("Amount", bold: true, alignment: pw.Alignment.centerRight),
                ],
              ),
              ...List.generate(_items.length, (i) {
                final item = _items[i];
                final gstAmount = (item.qty * item.rate) * (item.tax / 100);
                return pw.TableRow(
                  children: [
                    _tableCell("${i + 1}", alignment: pw.Alignment.center),
                    _tableCell(item.itemName),
                    _tableCell(item.brand),
                    _tableCell(item.unit, alignment: pw.Alignment.center),
                    _tableCell(_fmtNumber(item.qty), alignment: pw.Alignment.centerRight),
                    _tableCell(item.rate.toStringAsFixed(2), alignment: pw.Alignment.centerRight),
                    _tableCell(item.tax.toStringAsFixed(2), alignment: pw.Alignment.centerRight),
                    _tableCell(gstAmount.toStringAsFixed(2), alignment: pw.Alignment.centerRight),
                    _tableCell(item.amount.toStringAsFixed(2), alignment: pw.Alignment.centerRight),
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
                  pw.Divider(color: PdfColors.grey400, thickness: 0.5),
                  _totalRow("Grand Total", grandTotal, bold: true),
                ],
              ),
            ),
          ),

          pw.SizedBox(height: 30),

          /// ================= FOOTER =================
          pw.Text(
            "Thank you for your business. Please supply the above items as per agreed terms.",
            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800),
          ),

          pw.SizedBox(height: 40),

          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("Authorized Signature", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  pw.SizedBox(height: 30),
                  pw.Text(property?.legalName ?? '',
                      style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text("Vendor Signature", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  pw.SizedBox(height: 30),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    return pdf;
  }

  pw.Widget _tableCell(String text, {bool bold = false, pw.Alignment alignment = pw.Alignment.centerLeft}) {
    return pw.Container(
      alignment: alignment,
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: bold ? PdfColors.blueGrey900 : PdfColors.grey900,
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

  pw.Widget _metaRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.SizedBox(
            width: 65,
            child: pw.Text(
              label.endsWith(':') ? label : "$label:",
              style: pw.TextStyle(fontSize: 7.8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 7.8, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
          ),
        ],
      ),
    );
  }

  Future<void> _printPurchaseOrder() async {
    final pdf = await _buildPurchaseOrderPdf();
    await Printing.layoutPdf(name: _poNo.text.isNotEmpty ? 'PO_${_poNo.text}' : 'Purchase_Order', onLayout: (format) async => pdf.save());
  }
}
