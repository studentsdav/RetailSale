import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:retailpos/models/inventory/damage_item_model.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../controllers/inventory/damage_controller.dart';
import '../../controllers/inventory/item_controller.dart';
import '../../controllers/settings/property_info_controller.dart';
import '../../models/inventory/item_model.dart';
import '../../utils/date_picker_helper.dart';
import '../../widgets/entry_shortcuts.dart';

class DamageItemScreen extends StatefulWidget {
  const DamageItemScreen({super.key});

  @override
  State<DamageItemScreen> createState() => _DamageItemScreenState();
}

class _DamageItemScreenState extends State<DamageItemScreen> {
  // ================= HEADER =================
  final _srNo = TextEditingController(text: '5');
  DateTime _date = DateTime.now();
  final _unit = TextEditingController(text: 'PCS');
  final _qty = TextEditingController();
  final _remarks = TextEditingController();
  final _code = TextEditingController(text: 'ITM-001');
  final _rate = TextEditingController(text: '100');
  int? _editIndex;
  final List<DamageItem> _items = [];
  final damageCtrl = DamageController();
  final itemCtrl = ItemController();
  final propertyCtrl = PropertyInfoController();
  Item? _selectedItem;
  double _availableStock = 0;
  double _remainingStock = 0;
  String? _selectedItemName;
  int? _selectedBrandItemId;
  List<Item> _filteredBrands = [];

  // NEW: Double-Submit protection
  bool _isSaving = false;

  // NEW: ================= FOCUS NODES =================
  final FocusNode _dateFocus = FocusNode();
  final FocusNode _itemCodeFocus = FocusNode();
  final FocusNode _itemNameFocus = FocusNode();
  final FocusNode _brandFocus = FocusNode();
  final FocusNode _qtyNode = FocusNode();
  final FocusNode _rateNode = FocusNode();
  final FocusNode _remarksNode = FocusNode();
  final FocusNode _addBtnFocus = FocusNode();
  final FocusNode _saveBtnFocus = FocusNode();

  final _itemNameDropdownKey = GlobalKey<DropdownSearchState<String>>();
  final FocusNode _tableFocusNode = FocusNode();
  int? _selectedRowIndex;

  @override
  void initState() {
    super.initState();
    itemCtrl.load();
    _loadNextDamageNo();
    _loadPropertyInfo();

    // NEW: Auto-focus the Date field when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dateFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    // NEW: Dispose all nodes
    _dateFocus.dispose();
    _itemCodeFocus.dispose();
    _itemNameFocus.dispose();
    _brandFocus.dispose();
    _qtyNode.dispose();
    _rateNode.dispose();
    _remarksNode.dispose();
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

  Future<void> _loadPropertyInfo() async {
    await propertyCtrl.load();
  }

  Future<void> _loadNextDamageNo() async {
    final data = await damageCtrl.getNextDamageNo();
    _srNo.text = data['damage_no'];
    setState(() {});
  }

  // ================= ACTIONS =================
  Future<void> _saveItem() async {
    if (_selectedBrandItemId == null || _qty.text.isEmpty) return;
    final qty = int.parse(_qty.text);

    if (qty > _availableStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insufficient stock')),
      );
      return;
    }

    if (_remarks.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Remark Required')),
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

    final selected =
        _filteredBrands.firstWhere((e) => e.id == _selectedBrandItemId);

    final d = DamageItem(
      itemId: selected.id,
      itemCode: selected.itemCode,
      itemName: selected.itemName,
      unit: selected.unit,
      qty: qty.toDouble(),
      remarks: _remarks.text,
      rate: selected.rate,
    );

    setState(() {
      if (_editIndex == null) {
        _items.add(d);
      } else {
        _items[_editIndex!] = d;
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

  Future<void> _editItem(int i) async {
    final r = _items[i];

    _editIndex = i;
    final stock = await damageCtrl.getAvailableStock(r.itemCode);
    setState(() {
      _selectedItem = itemCtrl.list.firstWhere(
        (e) => e.itemCode == r.itemCode,
      );

      _filteredBrands =
          itemCtrl.list.where((e) => e.itemName == r.itemName).toList();
      _selectedBrandItemId = r.itemId;
      _selectedItemName = r.itemName;
      _code.text = r.itemCode;
      _unit.text = r.unit;
      _qty.text = r.qty.toInt().toString(); // Adjust to int display if needed
      _rate.text = r.rate.toString();
      _remarks.text = r.remarks;
      _remainingStock = stock - r.qty;
      _availableStock = stock;
    });

    _itemNameFocus.requestFocus(); // Focus item name
  }

  void _deleteItem(int i) {
    setState(() => _items.removeAt(i));
  }

  void _clearItem() {
    setState(() {
      _selectedBrandItemId = null;
      _selectedItem = null;
      _selectedItemName = null;
      _remarks.clear();
      _code.clear();
      _qty.clear();
      _rate.clear();

      _editIndex = null;
    });
  }

  Future<void> _finalclearItem() async {
    setState(() {
      _selectedBrandItemId = null;
      _selectedItem = null;
      _selectedItemName = null;
      _remarks.clear();
      _code.clear();
      _qty.clear();
      _rate.clear();
      _unit.clear();
      _editIndex = null;
      _items.clear();
    });
    await _loadNextDamageNo();
  }

  Future<void> _saveDamage() async {
    if (_isSaving) return; // NEW: Double-Submit shield

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add items')),
      );
      return;
    }

    // NEW: Instantly throw focus away to prevent button mashing
    _itemNameFocus.requestFocus();

    setState(() {
      _isSaving = true;
    });

    try {
      final header = {
        "damage_no": _srNo.text,
        "damage_date": _date.toIso8601String(),
      };

      final itemsPayload = _items.map((e) {
        return {
          "item_id": e.itemId,
          "item_code": e.itemCode,
          "qty": e.qty,
          "rate": e.rate,
          "remarks": e.remarks,
        };
      }).toList();

      await damageCtrl.createDamage({
        "header": header,
        "items": itemsPayload,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Damage saved. Stock will reduce only after approval'),
        ),
      );

      final shouldPrint = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Print Damage Report"),
          content: const Text("Do you want to print this Damage Report?"),
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
        await _printDamage();
      }

      await _finalclearItem();
      _dateFocus.requestFocus(); // Return to top
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  double get totalDamageValue => _items.fold(0, (s, e) => s + e.amount);

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return EntryShortcuts(
      onSave: _saveDamage,
      onNew: _finalclearItem,
      onClearLine: _clearItem,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6FA),
        appBar: AppBar(
          title: const Text('Damage Items'),
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
                Expanded(child: _tableCard()),
                const SizedBox(height: 12),
                _footerCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ================= HEADER =================
  Widget _headerCard() {
    return _card(
      title: 'Damage Information',
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _field(_srNo, 'Damage No', readOnly: true),
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
                  // Backwards navigation
                  if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                    _itemCodeFocus.requestFocus();
                    return KeyEventResult.handled;
                  }
                  // Open dropdown on Enter/Down
                  if (event.logicalKey == LogicalKeyboardKey.enter ||
                      event.logicalKey == LogicalKeyboardKey.numpadEnter ||
                      event.logicalKey == LogicalKeyboardKey.arrowDown) {
                    _itemNameDropdownKey.currentState?.openDropDownSearch();
                    return KeyEventResult.handled;
                  }
                  // Swallow up arrow
                  if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                    return KeyEventResult.handled;
                  }
                }
                return KeyEventResult.ignored;
              },
              child: DropdownSearch<String>(
                key: _itemNameDropdownKey,
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
                    _qty.clear();
                    _remarks.clear();
                  });
                  _brandFocus.requestFocus(); // Forward Chaining
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
                onChanged: (v) async {
                  final selected = _filteredBrands.firstWhere((e) => e.id == v);

                  setState(() {
                    _selectedBrandItemId = v;

                    _code.text = selected.itemCode;
                    _unit.text = selected.unit;
                    _rate.text = selected.rate.toString();
                    _selectedItem = selected;
                  });
                  final stock =
                      await damageCtrl.getAvailableStock(selected.itemCode);

                  setState(() {
                    _availableStock = stock;
                    _remainingStock = stock;
                  });
                  _qtyNode.requestFocus(); // Forward chaining
                },
                decoration: const InputDecoration(labelText: 'Brand'),
              ),
            ),
          ),
          _field(_unit, 'Unit', readOnly: true, width: 100),
          _qtyField(),
          _number(_rate, 'Rate',
              focusNode: _rateNode,
              prevNode: _qtyNode,
              onSubmit: () => _remarksNode.requestFocus()),

          // Remarks field wrapped in Focus for Reverse Navigation
          SizedBox(
            width: 260,
            child: Focus(
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.arrowUp) {
                  _rateNode.requestFocus();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: TextField(
                focusNode: _remarksNode,
                controller: _remarks,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Remarks'),
                onSubmitted: (_) {
                  _addBtnFocus.requestFocus();
                },
              ),
            ),
          ),

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
            focusNode: _addBtnFocus,
            icon: const Icon(Icons.add),
            label: Text(_editIndex == null ? 'Add Item' : 'Update Item'),
            onPressed: _saveItem,
          ),
        ],
      ),
    );
  }

  // UPDATED: Wrapped in Focus for ArrowUp backwards navigation
  Widget _qtyField() {
    return SizedBox(
      width: 140,
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.arrowUp) {
            _brandFocus.requestFocus();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: TextField(
          focusNode: _qtyNode,
          controller: _qty,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              RegExp(r'^\d*\.?\d{0,2}'),
            ),
          ],
          decoration: const InputDecoration(labelText: 'Qty Issued'),
          onSubmitted: (_) => _rateNode.requestFocus(),
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
        ),
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
                    DataColumn(label: Text('Value')),
                    DataColumn(label: Text('Remarks')),
                    DataColumn(label: Text('Code')),
                    DataColumn(label: Text('Action')),
                  ],
                  rows: List.generate(_items.length, (i) {
                    final d = _items[i];
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
                        DataCell(Text(d.itemName)),
                        DataCell(Text(d.unit)),
                        DataCell(Text(d.qty.toString())),
                        DataCell(Text(d.rate.toStringAsFixed(2))),
                        DataCell(Text(d.amount.toStringAsFixed(2))),
                        DataCell(Text(d.remarks)),
                        DataCell(Text(d.itemCode)),
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
              'Total Damage : ${totalDamageValue.toStringAsFixed(2)}',
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
            onPressed: _isSaving ? null : _saveDamage,
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

  Widget _field(TextEditingController c, String l,
          {bool readOnly = false,
          double width = 200,
          FocusNode? focusNode,
          TextInputAction textInputAction = TextInputAction.next,
          VoidCallback? onSubmit}) =>
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
            controller: c,
            keyboardType: TextInputType.number,
            textInputAction: textInputAction ?? TextInputAction.next,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: l),
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
                }
                _itemCodeFocus.requestFocus(); // Move to Item Code next
                return null;
              },
            ),
          },
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
        ),
      ),
    );
  }

  Future<void> _printDamage() async {
    final pdf = pw.Document();

    final property = propertyCtrl.data;
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          /// ================= HEADER =================
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
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
                  "DAMAGE REPORT",
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
              pw.Text("Damage No: ${_srNo.text}"),
              pw.Text("Date: ${DateFormat('dd-MMM-yyyy').format(_date)}"),
            ],
          ),

          pw.SizedBox(height: 20),

          /// ================= TABLE =================
          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(30),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(1),
              4: const pw.FlexColumnWidth(1),
              5: const pw.FlexColumnWidth(2),
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
                  _cell("Remarks"),
                ],
              ),
              ...List.generate(_items.length, (i) {
                final d = _items[i];
                return pw.TableRow(
                  children: [
                    _cell("${i + 1}"),
                    _cell(d.itemName),
                    _cell(d.unit),
                    _cell(d.qty.toString()),
                    _cell(d.rate.toStringAsFixed(2)),
                    _cell(d.remarks),
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
              "Total Damage Value : ${totalDamageValue.toStringAsFixed(2)}",
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),

          pw.SizedBox(height: 40),

          /// ================= SIGNATURE =================
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(children: [
                pw.Text("Reported By"),
                pw.SizedBox(height: 30),
              ]),
              pw.Column(children: [
                pw.Text("Verified By"),
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
    await Printing.layoutPdf(name: 'Damage_Item_Report', onLayout: (format) async => pdf.save());
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
}
