import 'dart:convert';
import 'dart:io';

import 'package:dropdown_search/dropdown_search.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controllers/inventory/item_controller.dart';
import '../../controllers/inventory/master_controller.dart';
import '../../core/api/api_client.dart';
import '../../core/config/app_config.dart';
import '../../models/inventory/item_model.dart';
import '../../models/inventory/settings/master_model.dart';
import '../../utils/inclusive_rate_helper.dart';
import '../../widgets/entry_shortcuts.dart';
import 'item_barcode_manager_screen.dart';

class ItemMasterScreen extends StatefulWidget {
  const ItemMasterScreen({super.key});

  @override
  State<ItemMasterScreen> createState() => _ItemMasterScreenState();
}

class _ItemMasterScreenState extends State<ItemMasterScreen> {
  final _formKey = GlobalKey<FormState>();
  final ScrollController _tableVerticalController = ScrollController();
  final ScrollController _tableHorizontalController = ScrollController();
  final FocusNode _searchNode = FocusNode();
  final FocusNode _tableFocusNode = FocusNode();
  int? _selectedRowIndex;
  final _groupDropdownKey = GlobalKey<DropdownSearchState<GroupModel>>();
  final _subCategoryDropdownKey =
      GlobalKey<DropdownSearchState<SubCategoryModel>>();
  final _brandDropdownKey = GlobalKey<DropdownSearchState<BrandModel>>();
  final _unitDropdownKey = GlobalKey<DropdownSearchState<String>>();

  // Controllers
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _hsnSac = TextEditingController();
  final _barcode = TextEditingController();
  final _imagePath = TextEditingController();
  final _rate = TextEditingController();
  final _retailSalePrice = TextEditingController();
  final _opening = TextEditingController();
  final _packQty = TextEditingController();
  final _looseItemCode = TextEditingController();
  final _min = TextEditingController();
  final _max = TextEditingController();
  final _search = TextEditingController();
  final ItemController itemCtrl = ItemController();
  final masterCtrl = MasterController();

  List<Item> _items = [];
  List<Item> _filtered = [];

  // Dropdowns
  String? _group;
  String? _subCategory;
  String? _brand;
  String? _unit;
  String _taxType = 'GST';
  bool _stockable = true;
  bool _discountApplicable = true;
  bool _schemeApplicable = true;
  bool _useInclusiveRates = false;
  String _inclusiveRateScope = 'BOTH';
  String? _pickedImagePath;
  String? _currentImagePath;

  int _autoCode = 1001;
  int? _editIndex;
  List<GroupModel> _groups = [];
  List<BrandModel> _brands = [];
  List<SubCategoryModel> _subCategories = [];

  // NEW: Double-submit prevention shield
  bool _isSaving = false;
  bool _canResetAndImport = false;

  // NEW: ================= FOCUS NODES =================
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _hsnSacFocus = FocusNode();
  final FocusNode _barcodeFocus = FocusNode();
  final FocusNode _packQtyFocus = FocusNode();
  final FocusNode _looseItemCodeFocus = FocusNode();
  final FocusNode _groupFocus = FocusNode();
  final FocusNode _subCategoryFocus = FocusNode();
  final FocusNode _brandFocus = FocusNode();
  final FocusNode _unitFocus = FocusNode();
  final FocusNode _inclusiveSwitchFocus = FocusNode();
  final FocusNode _inclusiveScopeFocus = FocusNode();
  final FocusNode _rateFocus = FocusNode();
  final FocusNode _saleRateFocus = FocusNode();
  final FocusNode _taxTypeFocus = FocusNode();
  final FocusNode _taxPercentFocus = FocusNode();
  final FocusNode _openingFocus = FocusNode();
  final FocusNode _minFocus = FocusNode();
  final FocusNode _maxFocus = FocusNode();
  final FocusNode _discountFocus = FocusNode();
  final FocusNode _schemeFocus = FocusNode();
  final FocusNode _stockableFocus = FocusNode();
  final FocusNode _saveBtnFocus = FocusNode();

  final List<String> _units = [
    'PCS',
    'NOS',
    'UNIT',
    'PAIR',
    'SET',
    'DOZEN',
    'SCORE',
    'MG',
    'GM',
    'KG',
    'QUINTAL',
    'TON',
    'ML',
    'LTR',
    'GALLON',
    'BOX',
    'PACK',
    'BAG',
    'SACK',
    'BOTTLE',
    'CAN',
    'TIN',
    'JAR',
    'CARTON',
    'TRAY',
    'ROLL',
    'MM',
    'CM',
    'MTR',
    'INCH',
    'FEET',
    'SQFT',
    'SQM',
    'CFT',
    'CBM',
    'PLATE',
    'BOWL',
    'GLASS',
    'CUP',
    'PORTION',
    'SERVING',
    'DAY',
    'HOUR',
  ];
  final List<String> _taxTypes = ['GST', 'VAT', 'CESS', 'OTHER'];

  GroupModel? _selectedGroup;
  SubCategoryModel? _selectedSubCategory;
  BrandModel? _selectedBrand;
  final _taxPercent = TextEditingController(text: '0');

  Future<void> _loadMasters() async {
    final groupsRes = await ApiClient.get('/api/inventory/groups');
    final subRes = await ApiClient.get('/api/inventory/subcategories');
    final brandRes = await ApiClient.get('/api/inventory/brands');

    _groups = List<Map<String, dynamic>>.from(groupsRes['data'])
        .map((e) => GroupModel.fromJson(e))
        .toList();
    _subCategories = List<Map<String, dynamic>>.from(subRes['data'])
        .map((e) => SubCategoryModel.fromJson(e))
        .toList();
    _brands = List<Map<String, dynamic>>.from(brandRes['data'])
        .map((e) => BrandModel.fromJson(e))
        .toList();
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _init();

    // NEW: Auto-focus the first editable field (Item Name) when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nameFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _hsnSac.dispose();
    _barcode.dispose();
    _imagePath.dispose();
    _rate.dispose();
    _retailSalePrice.dispose();
    _opening.dispose();
    _packQty.dispose();
    _looseItemCode.dispose();
    _min.dispose();
    _max.dispose();
    _search.dispose();
    _taxPercent.dispose();
    _tableVerticalController.dispose();
    _tableHorizontalController.dispose();
    _searchNode.dispose();
    _tableFocusNode.dispose();

    // NEW: Dispose nodes
    _nameFocus.dispose();
    _hsnSacFocus.dispose();
    _barcodeFocus.dispose();
    _packQtyFocus.dispose();
    _looseItemCodeFocus.dispose();
    _groupFocus.dispose();
    _subCategoryFocus.dispose();
    _brandFocus.dispose();
    _unitFocus.dispose();
    _inclusiveSwitchFocus.dispose();
    _inclusiveScopeFocus.dispose();
    _rateFocus.dispose();
    _saleRateFocus.dispose();
    _taxTypeFocus.dispose();
    _taxPercentFocus.dispose();
    _openingFocus.dispose();
    _minFocus.dispose();
    _maxFocus.dispose();
    _discountFocus.dispose();
    _schemeFocus.dispose();
    _stockableFocus.dispose();
    _saveBtnFocus.dispose();
    super.dispose();
  }

  KeyEventResult _onTableKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (_filtered.isEmpty) return KeyEventResult.ignored;

    final key = event.logicalKey;
    final current = _selectedRowIndex ?? 0;
    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _selectedRowIndex = ((current + 1).clamp(0, _filtered.length - 1));
      });
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selectedRowIndex = ((current - 1).clamp(0, _filtered.length - 1));
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

  Future<void> _init() async {
    await _loadMasters();
    await _loadItems();
    await _loadItemImportPermission();
  }

  Future<void> _loadItems() async {
    await itemCtrl.load();
    _generateCode();
    setState(() {
      _items = itemCtrl.list;
      _filtered = _items;
    });
  }

  Future<void> _loadItemImportPermission() async {
    try {
      final canReset = await _fetchCanResetAndImport();
      if (!mounted) return;
      setState(() {
        _canResetAndImport = canReset;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _canResetAndImport = false);
    }
  }

  Future<bool> _fetchCanResetAndImport() async {
    final res = await ApiClient.get('/api/inventory/items/can-import');
    return res['canImport'] == true;
  }

  Future<void> _generateCode() async {
    final code = await itemCtrl.getNextCode();
    _code.text = code.toUpperCase();
  }

  void _clearForm() {
    _name.clear();
    _hsnSac.clear();
    _barcode.clear();
    _imagePath.clear();
    _rate.clear();
    _retailSalePrice.clear();
    _opening.clear();
    _packQty.clear();
    _looseItemCode.clear();
    _min.clear();
    _max.clear();
    _taxPercent.text = '0';
    _group = null;
    _selectedGroup = null;
    _subCategory = null;
    _selectedSubCategory = null;
    _brand = null;
    _selectedBrand = null;
    _unit = null;
    _taxType = 'GST';
    _stockable = true;
    _discountApplicable = true;
    _schemeApplicable = true;
    _useInclusiveRates = false;
    _inclusiveRateScope = 'BOTH';
    _pickedImagePath = null;
    _currentImagePath = null;
    _editIndex = null;
    _autoCode++;
    _generateCode();
    setState(() {});

    // Auto-focus on name after clearing
    _nameFocus.requestFocus();
  }

  Future<void> _saveItem() async {
    if (_isSaving) return; // NEW: Block double submit

    if (!_formKey.currentState!.validate()) return;

    // NEW: Jump focus away to prevent mashing
    _nameFocus.requestFocus();

    setState(() {
      _isSaving = true;
    });

    try {
      final taxPercent = double.tryParse(_taxPercent.text.trim()) ?? 0;
      final enteredBuyRate = double.parse(_rate.text);
      final enteredSaleRate = double.parse(_retailSalePrice.text);
      final buyRate = _useInclusiveRates &&
              (_inclusiveRateScope == 'BOTH' ||
                  _inclusiveRateScope == 'BUY_ONLY')
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

      final model = Item(
        id: _editIndex == null ? 0 : _items[_editIndex!].id,
        itemCode: _code.text,
        itemName: _name.text,
        hsnSacCode: _hsnSac.text.trim(),
        itemGroup: _selectedGroup!.groupName,
        subCategory: _selectedSubCategory!.subCategoryName ?? "",
        brand: _selectedBrand!.brandName,
        unit: _unit!,
        barcode: _barcode.text.trim(),
        imagePath: _currentImagePath ?? '',
        rate: buyRate,
        retailSalePrice: saleRate,
        taxType: _taxType,
        taxPercent: taxPercent,
        discountApplicable: _discountApplicable,
        schemeApplicable: _schemeApplicable,
        openingBalance:
            double.parse(_opening.text.isEmpty ? "0" : _opening.text),
        packQty: double.parse(_packQty.text.isEmpty ? "0" : _packQty.text),
        looseItemCode: _looseItemCode.text.trim(),
        minLevel: int.parse(_min.text.isEmpty ? "0" : _min.text),
        maxLevel: int.parse(_max.text.isEmpty ? "0" : _max.text),
        stockable: _stockable,
      );

      Item savedItem;
      if (_editIndex == null) {
        savedItem = await itemCtrl.create(model);
      } else {
        savedItem = await itemCtrl.update(model.id, model);
        _editIndex = null;
      }

      if (_pickedImagePath != null && _pickedImagePath!.isNotEmpty) {
        final bytes = File(_pickedImagePath!).readAsBytesSync();
        final ext = _pickedImagePath!.toLowerCase().endsWith('.png')
            ? 'png'
            : _pickedImagePath!.toLowerCase().endsWith('.webp')
                ? 'webp'
                : _pickedImagePath!.toLowerCase().endsWith('.gif')
                    ? 'gif'
                    : 'jpg';
        await ApiClient.post('/api/inventory/items/${savedItem.id}/image', {
          'file_name': 'item_${savedItem.id}.$ext',
          'mime_type': 'image/$ext',
          'base64_data': base64Encode(bytes),
        });
      }

      _clearForm();
      await _loadItems();
    } catch (e) {
      showErrorSnackbar(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _pickItemImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) return;
    setState(() {
      _pickedImagePath = result.files.single.path;
      _imagePath.text = result.files.single.name;
    });
  }

  Future<void> _removeItemImage() async {
    if (_editIndex == null || _items.isEmpty) {
      setState(() {
        _pickedImagePath = null;
        _currentImagePath = null;
        _imagePath.clear();
      });
      return;
    }

    final itemId = _items[_editIndex!].id;
    try {
      await ApiClient.delete('/api/inventory/items/$itemId/image');
      setState(() {
        _pickedImagePath = null;
        _currentImagePath = null;
        _imagePath.clear();
      });
      await _loadItems();
    } catch (e) {
      showErrorSnackbar(e.toString());
    }
  }

  Widget _imageWidget(String path) {
    if (path.startsWith('http') || path.startsWith('/')) {
      final url = path.startsWith('http')
          ? path
          : AppConfig.baseUrl.endsWith('/')
              ? '${AppConfig.baseUrl}${path.startsWith('/') ? path.substring(1) : path}'
              : '${AppConfig.baseUrl}${path.startsWith('/') ? path : '/$path'}';
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const ColoredBox(
          color: Color(0xFFF1F5F9),
          child: Icon(Icons.image_not_supported_outlined),
        ),
      );
    }
    final file = File(path);
    if (file.existsSync()) {
      return Image.file(file, fit: BoxFit.cover);
    }
    return const ColoredBox(
      color: Color(0xFFF1F5F9),
      child: Icon(Icons.image_not_supported_outlined),
    );
  }

  void _editItem(int i) {
    final it = _filtered[i];

    _editIndex = _items.indexWhere((e) => e.id == it.id);
    _code.text = it.itemCode;
    _name.text = it.itemName;
    _hsnSac.text = it.hsnSacCode;
    _barcode.text = it.barcode;
    _imagePath.text =
        it.imagePath.isNotEmpty ? it.imagePath.split('/').last : '';
    _currentImagePath = it.imagePath.isNotEmpty ? it.imagePath : null;
    _pickedImagePath = null;

    _selectedGroup = _groups.firstWhere(
      (g) => g.groupName == it.itemGroup,
      orElse: () => _groups.first,
    );
    _selectedSubCategory = _subCategories.firstWhere(
      (s) => s.subCategoryName == it.subCategory,
      orElse: () => _subCategories.first,
    );
    _selectedBrand = _brands.firstWhere(
      (b) => b.brandName == it.brand,
      orElse: () => _brands.first,
    );
    _unit = it.unit;

    _rate.text = it.rate.toString();
    _retailSalePrice.text = it.retailSalePrice.toString();
    _packQty.text = it.packQty.toString();
    _looseItemCode.text = it.looseItemCode;
    _taxType = it.taxType;
    _taxPercent.text = it.taxPercent.toString();
    _discountApplicable = it.discountApplicable;
    _schemeApplicable = it.schemeApplicable;
    _opening.text = it.openingBalance.toString();
    _min.text = it.minLevel.toString();
    _max.text = it.maxLevel.toString();
    _stockable = it.stockable;
    _useInclusiveRates = false;
    _inclusiveRateScope = 'BOTH';

    setState(() {});
    _nameFocus.requestFocus(); // Focus to name when editing
  }

  Future<void> _deleteItem(int i) async {
    try {
      final id = _filtered[i].id;
      await itemCtrl.delete(id);
      await _loadItems();
      await _loadItemImportPermission();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  Future<void> _openPackDialog(int i) async {
    final item = _filtered[i];
    final countCtrl = TextEditingController(text: '1');
    final noteCtrl = TextEditingController();
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Open Pack - ${item.itemName}'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Pack qty: ${item.packQty.toStringAsFixed(2)} ${item.unit} per bag',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: countCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'How many bags to open',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Note (optional)',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final packCount =
                              double.tryParse(countCtrl.text.trim()) ?? 0;
                          if (packCount <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Enter a valid bag count'),
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isSaving = true);
                          try {
                            await itemCtrl.openPack(
                              id: item.id,
                              packCount: packCount,
                              note: noteCtrl.text.trim(),
                            );
                            if (!mounted) return;
                            Navigator.pop(context);
                            await _loadItems();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Opened ${packCount.toStringAsFixed(2)} bag(s) into ${item.looseItemCode}',
                                ),
                              ),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            setDialogState(() => isSaving = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  e.toString().replaceAll('Exception: ', ''),
                                ),
                              ),
                            );
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Open'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _searchItem(String q) async {
    await itemCtrl.load(q: q);
    setState(() => _filtered = itemCtrl.list);
  }

  // ================= EXPORT & IMPORT =================
  bool _toBool(dynamic raw, {bool defaultValue = false}) {
    final v = raw?.toString().trim().toLowerCase() ?? '';
    if (v == 'true' || v == 'yes' || v == '1') return true;
    if (v == 'false' || v == 'no' || v == '0') return false;
    return defaultValue;
  }

  Future<void> _exportExcel() async {
    var excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet();
    if (defaultSheet != null) {
      excel.rename(defaultSheet, 'Items');
    }

    Sheet sheet = excel['Items'];

    sheet.appendRow([
      TextCellValue('Item Code'),
      TextCellValue('Item Name'),
      TextCellValue('HSN/SAC'),
      TextCellValue('Group'),
      TextCellValue('Sub Category'),
      TextCellValue('Brand'),
      TextCellValue('Unit'),
      TextCellValue('Barcode'),
      TextCellValue('Pack Qty'),
      TextCellValue('Loose Item Code'),
      TextCellValue('Rate'),
      TextCellValue('Sale Rate'),
      TextCellValue('Tax Type'),
      TextCellValue('Tax Percent'),
      TextCellValue('Discount Applicable'),
      TextCellValue('Scheme Applicable'),
      TextCellValue('Opening'),
      TextCellValue('Min'),
      TextCellValue('Max'),
      TextCellValue('Stockable'),
    ]);
    for (var item in _items) {
      sheet.appendRow([
        TextCellValue(item.itemCode),
        TextCellValue(item.itemName),
        TextCellValue(item.hsnSacCode),
        TextCellValue(item.itemGroup),
        TextCellValue(item.subCategory),
        TextCellValue(item.brand),
        TextCellValue(item.unit),
        TextCellValue(item.barcode),
        DoubleCellValue(item.packQty),
        TextCellValue(item.looseItemCode),
        DoubleCellValue(item.rate),
        DoubleCellValue(item.retailSalePrice),
        TextCellValue(item.taxType),
        DoubleCellValue(item.taxPercent),
        TextCellValue(item.discountApplicable ? 'true' : 'false'),
        TextCellValue(item.schemeApplicable ? 'true' : 'false'),
        DoubleCellValue(item.openingBalance),
        IntCellValue(item.minLevel),
        IntCellValue(item.maxLevel),
        TextCellValue(item.stockable ? 'true' : 'false'),
      ]);
    }

    final directory =
        Directory('${Platform.environment['USERPROFILE']}\\Downloads');
    final fileName =
        'items_export_${DateTime.now().millisecondsSinceEpoch}.xlsx';

    final path = '${directory.path}\\$fileName';

    final file = File(path);
    final bytes = excel.encode();
    if (bytes == null) return;

    await file.writeAsBytes(bytes, flush: true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exported Successfully\nSaved at: $path')),
    );
  }

  Future<void> _importExcel() async {
    final canReset = await _fetchCanResetAndImport();
    if (!canReset) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Import blocked: transactions already exist.'),
        ),
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (result == null) return;

    final bytes = File(result.files.single.path!).readAsBytesSync();
    final excel = Excel.decodeBytes(bytes);

    String headerKey(dynamic value) =>
        value?.toString().trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ') ??
        '';

    dynamic cellByHeader(List<Data?> row, Map<String, int> headers, String name,
        {int fallbackIndex = -1}) {
      final idx = headers[headerKey(name)] ?? fallbackIndex;
      if (idx < 0 || idx >= row.length) return null;
      return row[idx]?.value;
    }

    List<Map<String, dynamic>> bulkData = [];
    for (var table in excel.tables.keys) {
      final rows = excel.tables[table]!.rows;
      if (rows.isEmpty) continue;

      final headerRow = rows.first;
      final headers = <String, int>{};
      for (var i = 0; i < headerRow.length; i++) {
        final key = headerKey(headerRow[i]?.value);
        if (key.isNotEmpty) headers[key] = i;
      }

      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        bulkData.add({
          "item_code": cellByHeader(row, headers, 'Item Code', fallbackIndex: 0)
              ?.toString(),
          "item_name": cellByHeader(row, headers, 'Item Name', fallbackIndex: 1)
              ?.toString(),
          "hsn_sac_code":
              cellByHeader(row, headers, 'HSN/SAC', fallbackIndex: 2)?.toString(),
          "item_group":
              cellByHeader(row, headers, 'Group', fallbackIndex: 3)?.toString(),
          "sub_category": cellByHeader(row, headers, 'Sub Category',
                  fallbackIndex: 4)
              ?.toString(),
          "brand": cellByHeader(row, headers, 'Brand', fallbackIndex: 5)
              ?.toString(),
          "unit": cellByHeader(row, headers, 'Unit', fallbackIndex: 6)?.toString(),
          "barcode":
              cellByHeader(row, headers, 'Barcode', fallbackIndex: 7)?.toString(),
          "pack_qty": double.tryParse(
                  cellByHeader(row, headers, 'Pack Qty', fallbackIndex: 8)
                          ?.toString() ??
                      '0') ??
              0,
          "loose_item_code":
              cellByHeader(row, headers, 'Loose Item Code', fallbackIndex: 9)
                  ?.toString(),
          "rate": double.tryParse(
                  cellByHeader(row, headers, 'Rate', fallbackIndex: 10)
                          ?.toString() ??
                      '0') ??
              0,
          "retail_sale_price": double.tryParse(
                  cellByHeader(row, headers, 'Sale Rate', fallbackIndex: 11)
                          ?.toString() ??
                      '0') ??
              0,
          "tax_type": cellByHeader(row, headers, 'Tax Type', fallbackIndex: 12)
                  ?.toString() ??
              'GST',
          "tax_percent": double.tryParse(
                  cellByHeader(row, headers, 'Tax Percent', fallbackIndex: 13)
                          ?.toString() ??
                      '0') ??
              0,
          "discount_applicable":
              _toBool(cellByHeader(row, headers, 'Discount Applicable',
                  fallbackIndex: 14), defaultValue: true),
          "scheme_applicable": _toBool(
              cellByHeader(row, headers, 'Scheme Applicable',
                  fallbackIndex: 15),
              defaultValue: true),
          "opening_balance": double.tryParse(
                  cellByHeader(row, headers, 'Opening', fallbackIndex: 16)
                          ?.toString() ??
                      '0') ??
              0,
          "min_level": int.tryParse(
                  cellByHeader(row, headers, 'Min', fallbackIndex: 17)
                          ?.toString() ??
                      '0') ??
              0,
          "max_level": int.tryParse(
                  cellByHeader(row, headers, 'Max', fallbackIndex: 18)
                          ?.toString() ??
                      '0') ??
              0,
          "stockable": _toBool(
              cellByHeader(row, headers, 'Stockable', fallbackIndex: 19),
              defaultValue: true),
        });
      }
    }

    // Simple flow: backend clears old items first (only when no transactions)
    // and then imports the new file in one API call.
    await ApiClient.post('/api/inventory/items/bulk-import', bulkData);

    await _loadItems();
    await _loadItemImportPermission();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Import Successful')),
    );
  }

  Future<void> _deleteAllAndImportNew() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Items?'),
        content: const Text(
            'This will delete all current items and then you can import a new Excel file.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await _importExcel();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  Future<void> _openBarcodeManager() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ItemBarcodeManagerScreen(
          items: _items,
          itemController: itemCtrl,
          onItemsUpdated: (updatedItems) {
            setState(() {
              _items = updatedItems;
              _filtered = updatedItems;
            });
          },
        ),
      ),
    );
    await _loadItems();
  }

  @override
  Widget build(BuildContext context) {
    return EntryShortcuts(
      onSave: _saveItem,
      onNew: _clearForm,
      onFocusSearch: () => FocusScope.of(context).requestFocus(_searchNode),
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6FA),
        appBar: AppBar(
          title: const Text('Item Master / Retail Catalog'),
          actions: [
            if (_canResetAndImport)
              TextButton.icon(
                onPressed: _deleteAllAndImportNew,
                icon: const Icon(Icons.delete_sweep, color: Colors.white),
                label: const Text(
                  'Delete All & Import',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.upload_file),
              tooltip: 'Import Excel',
              onPressed: _importExcel,
            ),
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Export Excel',
              onPressed: _exportExcel,
            ),
            IconButton(
              icon: const Icon(Icons.qr_code_2),
              tooltip: 'Generate Barcode Labels',
              onPressed: _openBarcodeManager,
            ),
          ],
        ),
        body: FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _formCard(),
                const SizedBox(height: 14),
                _searchBar(),
                const SizedBox(height: 14),
                Expanded(
                  child: _dataTable(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ================= FORM =================

  Widget _formCard() {
    return _card(
      title: 'Item Information',
      child: Form(
        key: _formKey,
        child: Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            // Code is readonly, so we don't pass focus node to it.
            _text(_code, 'Item Code', readOnly: true),
            _text(_name, 'Item Name',
                focusNode: _nameFocus,
                onSubmit: () => _hsnSacFocus.requestFocus()),
            _text(_hsnSac, 'HSN / SAC Code',
                focusNode: _hsnSacFocus,
                prevNode: _nameFocus,
                onSubmit: () => _barcodeFocus.requestFocus()),
            _text(_barcode, 'Barcode / Scan Code',
                focusNode: _barcodeFocus,
                prevNode: _hsnSacFocus,
                onSubmit: () => _packQtyFocus.requestFocus()),
            _text(_packQty, 'Pack Qty',
                isDouble: true,
                focusNode: _packQtyFocus,
                prevNode: _barcodeFocus,
                onSubmit: () => _looseItemCodeFocus.requestFocus()),
            _text(_looseItemCode, 'Loose Item Code',
                focusNode: _looseItemCodeFocus,
                prevNode: _packQtyFocus,
                onSubmit: () => _groupFocus.requestFocus()),
            SizedBox(
              width: 220,
              child: TextFormField(
                readOnly: true,
                controller: _imagePath,
                decoration: InputDecoration(
                  labelText: 'Item Image',
                  suffixIcon: IconButton(
                    tooltip: 'Choose Image',
                    icon: const Icon(Icons.image_outlined),
                    onPressed: _pickItemImage,
                  ),
                ),
              ),
            ),
            if ((_pickedImagePath ?? _currentImagePath) != null)
              Column(
                children: [
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: _imageWidget(
                          (_pickedImagePath ?? _currentImagePath)!),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _removeItemImage,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove Image'),
                  ),
                ],
              ),

            // 鳩 GROUP
            SizedBox(
              width: 220,
              child: Focus(
                focusNode: _groupFocus,
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent) {
                    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                      _barcodeFocus.requestFocus();
                      return KeyEventResult.handled;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.enter ||
                        event.logicalKey == LogicalKeyboardKey.numpadEnter ||
                        event.logicalKey == LogicalKeyboardKey.arrowDown) {
                      _groupDropdownKey.currentState?.openDropDownSearch();
                      return KeyEventResult.handled;
                    }
                  }
                  return KeyEventResult.ignored;
                },
                child: DropdownSearch<GroupModel>(
                  key: _groupDropdownKey,
                  selectedItem: _selectedGroup,
                  items: (filter, infiniteScrollProps) {
                    final List<GroupModel> list =
                        List<GroupModel>.from(_groups);
                    list.add(
                      GroupModel(
                        id: -1,
                        groupName: "+ Add New Group",
                      ),
                    );
                    return list;
                  },
                  itemAsString: (g) => g.groupName,
                  compareFn: (a, b) => a.id == b.id,
                  popupProps: const PopupProps.menu(
                    showSearchBox: true,
                  ),
                  decoratorProps: DropDownDecoratorProps(
                    decoration: InputDecoration(
                      labelText: "Group",
                      prefixIcon: _selectedGroup == null
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              tooltip: "Edit Group",
                              onPressed: _showEditGroupDialog,
                            ),
                    ),
                  ),
                  onChanged: (value) async {
                    if (value == null) return;
                    if (value.id == -1) {
                      _showAddGroupDialog();
                      return;
                    }

                    setState(() {
                      _selectedGroup = value;
                      _selectedSubCategory = null;
                    });
                    _subCategoryFocus.requestFocus(); // Chaining
                  },
                ),
              ),
            ),

            // 泙 SUB CATEGORY
            SizedBox(
              width: 220,
              child: Focus(
                focusNode: _subCategoryFocus,
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent) {
                    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                      _groupFocus.requestFocus();
                      return KeyEventResult.handled;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.enter ||
                        event.logicalKey == LogicalKeyboardKey.numpadEnter ||
                        event.logicalKey == LogicalKeyboardKey.arrowDown) {
                      _subCategoryDropdownKey.currentState
                          ?.openDropDownSearch();
                      return KeyEventResult.handled;
                    }
                  }
                  return KeyEventResult.ignored;
                },
                child: DropdownSearch<SubCategoryModel>(
                  key: _subCategoryDropdownKey,
                  selectedItem: _selectedSubCategory,
                  items: (filter, infiniteScrollProps) {
                    if (_selectedGroup == null) {
                      return <SubCategoryModel>[];
                    }
                    final List<SubCategoryModel> list = _subCategories
                        .where((s) => s.groupId == _selectedGroup!.id)
                        .toList();
                    list.add(
                      SubCategoryModel(
                        id: -1,
                        groupId: _selectedGroup!.id,
                        subCategoryName: "+ Add New SubCategory",
                      ),
                    );
                    return list;
                  },
                  decoratorProps: DropDownDecoratorProps(
                    decoration: InputDecoration(
                      labelText: "Sub Category",
                      prefixIcon: _selectedSubCategory == null
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              tooltip: "Edit Subcategory",
                              onPressed: _showEditSubCategoryDialog,
                            ),
                    ),
                  ),
                  itemAsString: (s) => s.subCategoryName,
                  compareFn: (a, b) => a.id == b.id,
                  onChanged: (value) async {
                    if (value == null) return;
                    if (value.id == -1) {
                      _showAddSubCategoryDialog();
                      return;
                    }

                    setState(() {
                      _selectedSubCategory = value;
                    });
                    _brandFocus.requestFocus(); // Chaining
                  },
                ),
              ),
            ),

            // 泛 BRAND
            SizedBox(
              width: 220,
              child: Focus(
                focusNode: _brandFocus,
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent) {
                    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                      _subCategoryFocus.requestFocus();
                      return KeyEventResult.handled;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.enter ||
                        event.logicalKey == LogicalKeyboardKey.numpadEnter ||
                        event.logicalKey == LogicalKeyboardKey.arrowDown) {
                      _brandDropdownKey.currentState?.openDropDownSearch();
                      return KeyEventResult.handled;
                    }
                  }
                  return KeyEventResult.ignored;
                },
                child: DropdownSearch<BrandModel>(
                  key: _brandDropdownKey,
                  selectedItem: _selectedBrand,
                  items: (filter, infiniteScrollProps) {
                    final List<BrandModel> list =
                        List<BrandModel>.from(_brands);
                    list.add(
                      BrandModel(
                        id: -1,
                        brandName: "+ Add New Brand",
                      ),
                    );
                    return list;
                  },
                  itemAsString: (b) => b.brandName,
                  compareFn: (a, b) => a.id == b.id,
                  popupProps: const PopupProps.menu(
                    showSearchBox: true,
                  ),
                  decoratorProps: DropDownDecoratorProps(
                    decoration: InputDecoration(
                      labelText: "Brand",
                      prefixIcon: _selectedBrand == null
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              tooltip: "Edit Brand",
                              onPressed: _showEditBrandDialog,
                            ),
                    ),
                  ),
                  onChanged: (value) async {
                    if (value == null) return;
                    if (value.id == -1) {
                      _showAddBrandDialog();
                      return;
                    }

                    setState(() {
                      _selectedBrand = value;
                    });
                    _unitFocus.requestFocus(); // Chaining
                  },
                ),
              ),
            ),

            SizedBox(
              width: 220,
              child: Focus(
                focusNode: _unitFocus,
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent) {
                    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                      _brandFocus.requestFocus();
                      return KeyEventResult.handled;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.enter ||
                        event.logicalKey == LogicalKeyboardKey.numpadEnter ||
                        event.logicalKey == LogicalKeyboardKey.arrowDown) {
                      _unitDropdownKey.currentState?.openDropDownSearch();
                      return KeyEventResult.handled;
                    }
                  }
                  return KeyEventResult.ignored;
                },
                child: DropdownSearch<String>(
                  key: _unitDropdownKey,
                  selectedItem: _unit,
                  items: (filter, infiniteScrollProps) => _units,
                  popupProps: const PopupProps.menu(
                    showSearchBox: true,
                    searchFieldProps: TextFieldProps(
                      decoration: InputDecoration(
                        hintText: "Search unit...",
                      ),
                    ),
                  ),
                  decoratorProps: const DropDownDecoratorProps(
                    decoration: InputDecoration(
                      labelText: "Unit",
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _unit = value;
                    });
                    _inclusiveSwitchFocus.requestFocus(); // Chaining
                  },
                ),
              ),
            ),

            SizedBox(
              width: 220,
              child: Focus(
                focusNode: _inclusiveSwitchFocus,
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent) {
                    if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                        event.logicalKey == LogicalKeyboardKey.arrowUp) {
                      _unitFocus.requestFocus();
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
                        _inclusiveScopeFocus.requestFocus();
                      } else {
                        _rateFocus.requestFocus();
                      }
                      return KeyEventResult.handled;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
                        event.logicalKey == LogicalKeyboardKey.arrowDown) {
                      if (_useInclusiveRates) {
                        _inclusiveScopeFocus.requestFocus();
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
                      _inclusiveScopeFocus.requestFocus();
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
                      _inclusiveSwitchFocus.requestFocus();
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: DropdownButtonFormField<String>(
                    focusNode: _inclusiveScopeFocus,
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
                      _rateFocus.requestFocus(); // Chaining
                    },
                  ),
                ),
              ),
            _text(
              _rate,
              _useInclusiveRates &&
                      (_inclusiveRateScope == 'BOTH' ||
                          _inclusiveRateScope == 'BUY_ONLY')
                  ? 'Buy Rate (Inclusive)'
                  : 'Buy Rate',
              isDouble: true,
              focusNode: _rateFocus,
              prevNode: _useInclusiveRates
                  ? _inclusiveScopeFocus
                  : _inclusiveSwitchFocus,
              onSubmit: () => _saleRateFocus.requestFocus(),
              helperText: _useInclusiveRates &&
                      (_inclusiveRateScope == 'BOTH' ||
                          _inclusiveRateScope == 'BUY_ONLY') &&
                      _rate.text.trim().isNotEmpty
                  ? InclusiveRateHelper.previewText(
                      label: 'Buy',
                      inclusiveAmount: double.tryParse(_rate.text.trim()) ?? 0,
                      taxPercent: double.tryParse(_taxPercent.text.trim()) ?? 0,
                    )
                  : null,
            ),
            _text(
              _retailSalePrice,
              _useInclusiveRates &&
                      (_inclusiveRateScope == 'BOTH' ||
                          _inclusiveRateScope == 'SALE_ONLY')
                  ? 'Sale Rate (Inclusive)'
                  : 'Sale Rate',
              isDouble: true,
              focusNode: _saleRateFocus,
              prevNode: _rateFocus,
              onSubmit: () => _taxTypeFocus.requestFocus(),
              helperText: _useInclusiveRates &&
                      (_inclusiveRateScope == 'BOTH' ||
                          _inclusiveRateScope == 'SALE_ONLY') &&
                      _retailSalePrice.text.trim().isNotEmpty
                  ? InclusiveRateHelper.previewText(
                      label: 'Sale',
                      inclusiveAmount:
                          double.tryParse(_retailSalePrice.text.trim()) ?? 0,
                      taxPercent: double.tryParse(_taxPercent.text.trim()) ?? 0,
                    )
                  : null,
            ),
            SizedBox(
              width: 220,
              child: Focus(
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                    _saleRateFocus.requestFocus();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: DropdownButtonFormField<String>(
                  focusNode: _taxTypeFocus,
                  initialValue: _taxType,
                  decoration: const InputDecoration(labelText: 'Tax Type'),
                  items: _taxTypes
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _taxType = value);
                    }
                    _taxPercentFocus.requestFocus(); // Chaining
                  },
                ),
              ),
            ),
            _text(_taxPercent, 'Tax %',
                isDouble: true,
                focusNode: _taxPercentFocus,
                prevNode: _taxTypeFocus,
                onSubmit: () => _openingFocus.requestFocus()),
            _text(_opening, 'Opening Balance',
                isDouble: true,
                readOnly: _editIndex == null ? false : true,
                focusNode: _openingFocus,
                prevNode: _taxPercentFocus,
                onSubmit: () => _minFocus.requestFocus()),
            _text(_min, 'Min Level',
                isInt: true,
                focusNode: _minFocus,
                prevNode: _openingFocus,
                onSubmit: () => _maxFocus.requestFocus()),
            _text(_max, 'Max Level',
                isInt: true,
                focusNode: _maxFocus,
                prevNode: _minFocus,
                onSubmit: () => _discountFocus.requestFocus()),

            SizedBox(
              width: 220,
              child: Focus(
                focusNode: _discountFocus,
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent) {
                    if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                        event.logicalKey == LogicalKeyboardKey.arrowUp) {
                      _maxFocus.requestFocus();
                      return KeyEventResult.handled;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.enter ||
                        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
                      setState(
                          () => _discountApplicable = !_discountApplicable);
                      _schemeFocus.requestFocus();
                      return KeyEventResult.handled;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
                        event.logicalKey == LogicalKeyboardKey.arrowDown) {
                      _schemeFocus.requestFocus();
                      return KeyEventResult.handled;
                    }
                  }
                  return KeyEventResult.ignored;
                },
                child: SwitchListTile(
                  title: const Text('Discount Applicable'),
                  value: _discountApplicable,
                  onChanged: (v) {
                    setState(() => _discountApplicable = v);
                    _schemeFocus.requestFocus();
                  },
                ),
              ),
            ),
            SizedBox(
              width: 220,
              child: Focus(
                focusNode: _schemeFocus,
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent) {
                    if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                        event.logicalKey == LogicalKeyboardKey.arrowUp) {
                      _discountFocus.requestFocus();
                      return KeyEventResult.handled;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.enter ||
                        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
                      setState(() => _schemeApplicable = !_schemeApplicable);
                      _stockableFocus.requestFocus();
                      return KeyEventResult.handled;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
                        event.logicalKey == LogicalKeyboardKey.arrowDown) {
                      _stockableFocus.requestFocus();
                      return KeyEventResult.handled;
                    }
                  }
                  return KeyEventResult.ignored;
                },
                child: SwitchListTile(
                  title: const Text('Scheme Applicable'),
                  value: _schemeApplicable,
                  onChanged: (v) {
                    setState(() => _schemeApplicable = v);
                    _stockableFocus.requestFocus();
                  },
                ),
              ),
            ),
            SizedBox(
              width: 220,
              child: Focus(
                focusNode: _stockableFocus,
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent) {
                    if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                        event.logicalKey == LogicalKeyboardKey.arrowUp) {
                      _schemeFocus.requestFocus();
                      return KeyEventResult.handled;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.enter ||
                        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
                      setState(() => _stockable = !_stockable);
                      _saveBtnFocus.requestFocus();
                      return KeyEventResult.handled;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
                        event.logicalKey == LogicalKeyboardKey.arrowDown) {
                      _saveBtnFocus.requestFocus();
                      return KeyEventResult.handled;
                    }
                  }
                  return KeyEventResult.ignored;
                },
                child: SwitchListTile(
                  title: const Text('Stockable'),
                  value: _stockable,
                  onChanged: (v) {
                    setState(() => _stockable = v);
                    _saveBtnFocus.requestFocus();
                  },
                ),
              ),
            ),
            FilledButton.icon(
              focusNode: _saveBtnFocus,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save),
              label: Text(_isSaving
                  ? 'Saving...'
                  : (_editIndex == null ? 'Save Item' : 'Update Item')),
              onPressed: _isSaving ? null : _saveItem,
            ),
            OutlinedButton(
              onPressed: _clearForm,
              child: const Text('Clear'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditBrandDialog() async {
    if (_selectedBrand == null) return;
    final TextEditingController nameCtrl =
        TextEditingController(text: _selectedBrand!.brandName);
    bool isLoading = false;
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Edit Brand"),
              content: TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: "Brand Name"),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (nameCtrl.text.trim().isEmpty) return;
                          setStateDialog(() => isLoading = true);
                          await ApiClient.put(
                            '/api/inventory/brands/${_selectedBrand!.id}',
                            {
                              "brand_name": nameCtrl.text.trim(),
                            },
                          );
                          Navigator.pop(context);
                          await _loadMasters();
                          final updated = _brands.firstWhere(
                            (b) => b.id == _selectedBrand!.id,
                            orElse: () => _selectedBrand!,
                          );
                          setState(() {
                            _selectedBrand = updated;
                          });
                        },
                  child: isLoading
                      ? const CircularProgressIndicator()
                      : const Text("Update"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showEditSubCategoryDialog() async {
    if (_selectedSubCategory == null) return;
    final TextEditingController nameCtrl =
        TextEditingController(text: _selectedSubCategory!.subCategoryName);
    bool isLoading = false;
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Edit SubCategory"),
              content: TextField(
                controller: nameCtrl,
                decoration:
                    const InputDecoration(labelText: "SubCategory Name"),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (nameCtrl.text.trim().isEmpty) return;
                          setStateDialog(() => isLoading = true);
                          await ApiClient.put(
                            '/api/inventory/subcategories/${_selectedSubCategory!.id}',
                            {
                              "subcategory_name": nameCtrl.text.trim(),
                            },
                          );
                          Navigator.pop(context);
                          await _loadMasters();
                          final updated = _subCategories.firstWhere(
                            (s) => s.id == _selectedSubCategory!.id,
                            orElse: () => _selectedSubCategory!,
                          );
                          setState(() {
                            _selectedSubCategory = updated;
                          });
                        },
                  child: isLoading
                      ? const CircularProgressIndicator()
                      : const Text("Update"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showEditGroupDialog() async {
    if (_selectedGroup == null) return;
    final TextEditingController nameCtrl =
        TextEditingController(text: _selectedGroup!.groupName);
    bool isLoading = false;
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Edit Group"),
              content: TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: "Group Name"),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (nameCtrl.text.trim().isEmpty) return;
                          setStateDialog(() => isLoading = true);
                          await ApiClient.put(
                            '/api/inventory/groups/${_selectedGroup!.id}',
                            {
                              "group_name": nameCtrl.text.trim(),
                            },
                          );
                          Navigator.pop(context);
                          await _loadMasters();
                          // 櫨 Re-select updated group
                          final updated = _groups.firstWhere(
                            (g) => g.id == _selectedGroup!.id,
                            orElse: () => _selectedGroup!,
                          );
                          setState(() {
                            _selectedGroup = updated;
                          });
                        },
                  child: isLoading
                      ? const CircularProgressIndicator()
                      : const Text("Update"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddGroupDialog() {
    final TextEditingController nameCtrl = TextEditingController();
    bool isLoading = false;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Add Group"),
              content: SizedBox(
                width: 300,
                child: TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: "Group Name",
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (nameCtrl.text.trim().isEmpty) return;
                          setStateDialog(() => isLoading = true);
                          await masterCtrl.createGroup(
                            nameCtrl.text.trim(),
                          );
                          await _loadMasters();
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Group Added")),
                          );
                        },
                  child: isLoading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddSubCategoryDialog() {
    if (_selectedGroup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Select Group First")),
      );
      return;
    }
    final TextEditingController nameCtrl = TextEditingController();
    bool isLoading = false;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Add SubCategory"),
              content: SizedBox(
                width: 300,
                child: TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: "SubCategory Name",
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (nameCtrl.text.trim().isEmpty) return;
                          setStateDialog(() => isLoading = true);
                          await masterCtrl.createSubCategory(
                            _selectedGroup!.id,
                            nameCtrl.text.trim(),
                          );
                          await _loadMasters();
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("SubCategory Added")),
                          );
                        },
                  child: isLoading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddBrandDialog() {
    final TextEditingController nameCtrl = TextEditingController();
    bool isLoading = false;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Add Brand"),
              content: SizedBox(
                width: 300,
                child: TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: "Brand Name",
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (nameCtrl.text.trim().isEmpty) return;
                          setStateDialog(() => isLoading = true);
                          await masterCtrl.createBrand(
                            nameCtrl.text.trim(),
                          );
                          await _loadMasters();
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Brand Added")),
                          );
                        },
                  child: isLoading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ================= SEARCH =================
  Widget _searchBar() {
    return Center(
      child: Container(
        width: 420,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: _search,
          onChanged: _searchItem,
          focusNode: _searchNode,
          decoration: const InputDecoration(
            hintText: 'Search item (code, barcode, name, group, brand)',
            prefixIcon: Icon(Icons.search),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  // ================= TABLE =================
  Widget _dataTable() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          height: constraints.maxHeight,
          child: Scrollbar(
            controller: _tableVerticalController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _tableVerticalController,
              scrollDirection: Axis.vertical,
              child: Scrollbar(
                controller: _tableHorizontalController,
                thumbVisibility: true,
                notificationPredicate: (notification) =>
                    notification.metrics.axis == Axis.horizontal,
                child: SingleChildScrollView(
                  controller: _tableHorizontalController,
                  scrollDirection: Axis.horizontal,
                  child: Focus(
                    focusNode: _tableFocusNode,
                    onKeyEvent: _onTableKey,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                      showCheckboxColumn: false,
                      dataRowMinHeight: 44,
                      dataRowMaxHeight: 54,
                      columns: const [
                        DataColumn(label: Text('Code')),
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('HSN/SAC')),
                        DataColumn(label: Text('Group')),
                        DataColumn(label: Text('Sub Category')),
                        DataColumn(label: Text('Brand')),
                        DataColumn(label: Text('Unit')),
                        DataColumn(label: Text('Barcode')),
                        DataColumn(label: Text('Pack Qty')),
                        DataColumn(label: Text('Loose Item')),
                        DataColumn(label: Text('Buy Rate')),
                        DataColumn(label: Text('Sale Rate')),
                        DataColumn(label: Text('Tax Type')),
                        DataColumn(label: Text('Tax %')),
                        DataColumn(label: Text('Disc')),
                        DataColumn(label: Text('Scheme')),
                        DataColumn(label: Text('Opening')),
                        DataColumn(label: Text('Min')),
                        DataColumn(label: Text('Max')),
                        DataColumn(label: Text('Stock')),
                        DataColumn(label: Text('Action')),
                      ],
                      rows: List.generate(_filtered.length, (i) {
                        final it = _filtered[i];
                        return DataRow(
                          selected: _selectedRowIndex == i,
                          onSelectChanged: (_) {
                            setState(() => _selectedRowIndex = i);
                            FocusScope.of(context)
                                .requestFocus(_tableFocusNode);
                          },
                          color: WidgetStateProperty.all(
                              i.isEven ? Colors.grey.shade50 : Colors.white),
                          cells: [
                            DataCell(Text(it.itemCode)),
                            DataCell(Text(it.itemName)),
                            DataCell(Text(it.hsnSacCode)),
                            DataCell(Text(it.itemGroup)),
                            DataCell(Text(it.subCategory)),
                            DataCell(Text(it.brand)),
                            DataCell(Text(it.unit)),
                            DataCell(Text(it.barcode)),
                            DataCell(Text(
                                it.packQty > 0 ? it.packQty.toString() : '-')),
                            DataCell(Text(
                                it.looseItemCode.isNotEmpty ? it.looseItemCode : '-')),
                            DataCell(Text(it.rate.toStringAsFixed(2))),
                            DataCell(
                                Text(it.retailSalePrice.toStringAsFixed(2))),
                            DataCell(Text(it.taxType)),
                            DataCell(Text(it.taxPercent.toStringAsFixed(2))),
                            DataCell(
                                Text(it.discountApplicable ? 'YES' : 'NO')),
                            DataCell(Text(it.schemeApplicable ? 'YES' : 'NO')),
                            DataCell(
                                Text(it.openingBalance.toStringAsFixed(2))),
                            DataCell(Text(it.minLevel.toString())),
                            DataCell(Text(it.maxLevel.toString())),
                            DataCell(Icon(
                              it.stockable ? Icons.check_circle : Icons.cancel,
                              color: it.stockable ? Colors.green : Colors.red,
                              size: 18,
                            )),
                            DataCell(
                              Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (it.packQty > 0 &&
                                    it.looseItemCode.isNotEmpty)
                                  IconButton(
                                      tooltip: 'Open Pack',
                                      icon: const Icon(Icons.inventory_2_outlined,
                                          color: Colors.green),
                                      onPressed: () => _openPackDialog(i)),
                                IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () => _editItem(i)),
                                  IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      onPressed: () => _deleteItem(i)),
                                ],
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
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

  Widget _text(
    TextEditingController c,
    String l, {
    bool isInt = false,
    bool isDouble = false,
    bool readOnly = false,
    String? helperText,
    FocusNode? focusNode,
    FocusNode? prevNode,
    TextInputAction textInputAction = TextInputAction.next,
    VoidCallback? onSubmit,
  }) {
    return SizedBox(
      width: 220,
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.arrowUp) {
            prevNode?.requestFocus();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: TextFormField(
          focusNode: focusNode,
          controller: c,
          readOnly: readOnly,
          keyboardType: isInt
              ? TextInputType.number
              : isDouble
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.text,
          inputFormatters: isInt
              ? [FilteringTextInputFormatter.digitsOnly]
              : isDouble
                  ? [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}'))
                    ]
                  : [],
          textInputAction: textInputAction,
          onFieldSubmitted: (_) {
            if (onSubmit != null) {
              onSubmit();
            } else if (textInputAction == TextInputAction.next) {
              FocusScope.of(context).nextFocus();
            } else {
              FocusScope.of(context).unfocus();
            }
          },
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
          decoration: InputDecoration(
            labelText: l,
            helperText: helperText,
            filled: true,
            fillColor: readOnly ? Colors.grey.shade100 : Colors.white,
          ),
          onChanged: (_) => setState(() {}),
          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        ),
      ),
    );
  }
}
