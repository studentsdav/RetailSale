import 'dart:convert';
import 'dart:io';

import 'package:dropdown_search/dropdown_search.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controllers/inventory/item_controller.dart';
import '../../controllers/inventory/master_controller.dart';
import '../../controllers/inventory/attribute_controller.dart';
import '../../controllers/inventory/product_template_controller.dart';
import '../../core/api/api_client.dart';
import '../../core/config/app_config.dart';
import '../../models/inventory/item_model.dart';
import '../../models/inventory/attribute_model.dart';
import '../../models/inventory/product_template_model.dart';
import '../../models/inventory/settings/master_model.dart';
import '../../utils/inclusive_rate_helper.dart';
import '../../widgets/entry_shortcuts.dart';
import 'item_barcode_manager_screen.dart';
import 'stock_transfer_screen.dart';
import 'bom_setup_dialog.dart';

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
  final _location = TextEditingController(text: '-');
  final _rate = TextEditingController();
  final _retailSalePrice = TextEditingController();
  final _mrp = TextEditingController();
  final _opening = TextEditingController();
  final _packQty = TextEditingController();
  final _looseItemCode = TextEditingController();
  final _min = TextEditingController();
  final _max = TextEditingController();
  final _search = TextEditingController();
  final ItemController itemCtrl = ItemController();
  final masterCtrl = MasterController();
  final AttributeController _attributeCtrl = AttributeController();
  final ProductTemplateController _templateCtrl = ProductTemplateController();

  bool _hasVariants = false;
  final Map<Attribute, List<AttributeValue>> _selectedAttributes = {};
  List<Map<String, dynamic>> _generatedVariants = [];

  List<Item> _items = [];
  List<Item> _filtered = [];

  // Dropdowns
  String? _group;
  String? _subCategory;
  String? _brand;
  String? _unit;
  String _taxType = 'GST';
  bool _stockable = true;
  bool _isSaleable = true;
  bool _discountApplicable = true;
  bool _schemeApplicable = true;
  bool _isHappyHour = false;
  bool _useInclusiveRates = false;
  String _inclusiveRateScope = 'BOTH';
  String? _pickedImagePath;
  String? _currentImagePath;

  int _autoCode = 1001;
  int? _editIndex;
  List<GroupModel> _groups = [];
  List<BrandModel> _brands = [];
  List<SubCategoryModel> _subCategories = [];
  List<LocationModel> _locations = [];

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
  final FocusNode _mrpFocus = FocusNode();
  final FocusNode _taxTypeFocus = FocusNode();
  final FocusNode _taxPercentFocus = FocusNode();
  final FocusNode _openingFocus = FocusNode();
  final FocusNode _minFocus = FocusNode();
  final FocusNode _maxFocus = FocusNode();
  final FocusNode _discountFocus = FocusNode();
  final FocusNode _schemeFocus = FocusNode();
  final FocusNode _happyHourFocus = FocusNode();
  final FocusNode _stockableFocus = FocusNode();
  final FocusNode _isSaleableFocus = FocusNode();
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
    final locs = await masterCtrl.getLocations();
    await _attributeCtrl.load();

    _groups = List<Map<String, dynamic>>.from(groupsRes['data'] ?? [])
        .map((e) => GroupModel.fromJson(e))
        .toList();
    _subCategories = List<Map<String, dynamic>>.from(subRes['data'] ?? [])
        .map((e) => SubCategoryModel.fromJson(e))
        .toList();
    _brands = List<Map<String, dynamic>>.from(brandRes['data'] ?? [])
        .map((e) => BrandModel.fromJson(e))
        .toList();
    _locations = locs;
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
    _mrp.dispose();
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
    _mrpFocus.dispose();
    _taxTypeFocus.dispose();
    _taxPercentFocus.dispose();
    _openingFocus.dispose();
    _minFocus.dispose();
    _maxFocus.dispose();
    _discountFocus.dispose();
    _schemeFocus.dispose();
    _happyHourFocus.dispose();
    _stockableFocus.dispose();
    _isSaleableFocus.dispose();
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
    _location.text = '-';
    _rate.clear();
    _retailSalePrice.clear();
    _mrp.clear();
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
    _isSaleable = true;
    _discountApplicable = true;
    _schemeApplicable = true;
    _isHappyHour = false;
    _useInclusiveRates = false;
    _inclusiveRateScope = 'BOTH';
    _pickedImagePath = null;
    _currentImagePath = null;
    _editIndex = null;
    _autoCode++;
    _hasVariants = false;
    _selectedAttributes.clear();
    _generatedVariants.clear();
    _generateCode();
    setState(() {});

    // Auto-focus on name after clearing
    _nameFocus.requestFocus();
  }

  Future<void> _saveItem() async {
    if (_isSaving) return; // NEW: Block double submit

    if (_selectedGroup == null) {
      showErrorSnackbar("Item Group is required.");
      return;
    }
    if (_selectedSubCategory == null) {
      showErrorSnackbar("Sub Category is required.");
      return;
    }
    if (_selectedBrand == null) {
      showErrorSnackbar("Brand is required.");
      return;
    }
    if (_unit == null || _unit!.trim().isEmpty) {
      showErrorSnackbar("Unit is required.");
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    // NEW: Jump focus away to prevent mashing
    _nameFocus.requestFocus();

    setState(() {
      _isSaving = true;
    });

    try {
      final taxPercent = double.tryParse(_taxPercent.text.trim()) ?? 0;

      if (_hasVariants && _editIndex == null) {
        if (_generatedVariants.isEmpty) {
          showErrorSnackbar("Please define at least one variant configuration combination.");
          setState(() => _isSaving = false);
          return;
        }

        await _templateCtrl.createTemplate(
          name: _name.text.trim(),
          itemGroup: _selectedGroup!.groupName,
          subCategory: _selectedSubCategory!.subCategoryName ?? "",
          brand: _selectedBrand?.brandName ?? "",
          hsnSacCode: _hsnSac.text.trim(),
          taxType: _taxType,
          taxPercent: taxPercent,
          discountApplicable: _discountApplicable,
          schemeApplicable: _schemeApplicable,
          unit: _unit!,
          variants: _generatedVariants,
        );

        _clearForm();
        await _loadItems();
        return;
      }

      final buyRate = double.tryParse(_rate.text) ?? 0.0;
      final saleRate = double.tryParse(_retailSalePrice.text) ?? 0.0;
      final enteredMrp = double.tryParse(_mrp.text) ?? 0.0;

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
        location: _location.text.trim().isEmpty ? '-' : _location.text.trim(),
        rate: buyRate,
        retailSalePrice: saleRate,
        mrp: enteredMrp,
        taxType: _taxType,
        taxPercent: taxPercent,
        discountApplicable: _discountApplicable,
        schemeApplicable: _schemeApplicable,
        openingBalance:
            double.parse(_opening.text.isEmpty ? "0" : _opening.text),
        packQty: _editIndex == null ? 0 : _items[_editIndex!].packQty,
        looseItemCode:
            _editIndex == null ? '' : _items[_editIndex!].looseItemCode,
        minLevel: int.parse(_min.text.isEmpty ? "0" : _min.text),
        maxLevel: int.parse(_max.text.isEmpty ? "0" : _max.text),
        stockable: _stockable,
        isSaleable: _isSaleable,
        isTaxInclusive: _useInclusiveRates,
        isHappyHour: _isHappyHour,
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
      final msg = e.toString().replaceAll('Exception: ', '');
      final isNameBrandConflict = msg.contains('with Brand') && msg.contains('already exists');
      final isCodeConflict = msg.contains('Item Code') && msg.contains('already used by');
      if (isNameBrandConflict || isCodeConflict) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            icon: Icon(
              isCodeConflict ? Icons.pin_outlined : Icons.inventory_2_outlined,
              color: Colors.orange,
              size: 36,
            ),
            title: Text(
              isCodeConflict ? 'Duplicate Item Code' : 'Duplicate Item + Brand',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Text(msg),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK, I will fix it'),
              ),
            ],
          ),
        );
      } else {
        showErrorSnackbar(msg);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _pickItemImage() async {
    final result = await FilePicker.pickFiles(
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
    _location.text = it.location.isEmpty ? '-' : it.location;
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
    _packQty.text = it.packQty.toString();
    _looseItemCode.text = it.looseItemCode;

    _taxType = it.taxType;
    _taxPercent.text = it.taxPercent.toString();
    _discountApplicable = it.discountApplicable;
    _schemeApplicable = it.schemeApplicable;
    _isHappyHour = it.isHappyHour;
    _opening.text = it.openingBalance.toString();
    _min.text = it.minLevel.toString();
    _max.text = it.maxLevel.toString();
    _stockable = it.stockable;
    _isSaleable = it.isSaleable;
    _useInclusiveRates = it.isTaxInclusive;
    _inclusiveRateScope = 'BOTH';

    _rate.text = it.rate > 0 ? it.rate.toString() : '';
    _retailSalePrice.text = it.retailSalePrice > 0 ? it.retailSalePrice.toString() : '';
    _mrp.text = it.mrp > 0 ? it.mrp.toString() : '';

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
      TextCellValue('Location'),
      TextCellValue('HSN/SAC'),
      TextCellValue('Group'),
      TextCellValue('Sub Category'),
      TextCellValue('Brand'),
      TextCellValue('Unit'),
      TextCellValue('Barcode'),
      TextCellValue('Rate'),
      TextCellValue('Sale Rate'),
      TextCellValue('MRP'),
      TextCellValue('Tax Type'),
      TextCellValue('Tax Percent'),
      TextCellValue('Tax Inclusive'),
      TextCellValue('Discount Applicable'),
      TextCellValue('Scheme Applicable'),
      TextCellValue('Happy Hour'),
      TextCellValue('Opening'),
      TextCellValue('Min'),
      TextCellValue('Max'),
      TextCellValue('Stockable'),
      TextCellValue('Saleable'),
    ]);
    for (var item in _items) {
      sheet.appendRow([
        TextCellValue(item.itemCode),
        TextCellValue(item.itemName),
        TextCellValue(item.location),
        TextCellValue(item.hsnSacCode),
        TextCellValue(item.itemGroup),
        TextCellValue(item.subCategory),
        TextCellValue(item.brand),
        TextCellValue(item.unit),
        TextCellValue(item.barcode),
        DoubleCellValue(item.rate),
        DoubleCellValue(item.retailSalePrice),
        DoubleCellValue(item.mrp),
        TextCellValue(item.taxType),
        DoubleCellValue(item.taxPercent),
        TextCellValue(item.isTaxInclusive ? 'true' : 'false'),
        TextCellValue(item.discountApplicable ? 'true' : 'false'),
        TextCellValue(item.schemeApplicable ? 'true' : 'false'),
        TextCellValue(item.isHappyHour ? 'true' : 'false'),
        DoubleCellValue(item.openingBalance),
        IntCellValue(item.minLevel),
        IntCellValue(item.maxLevel),
        TextCellValue(item.stockable ? 'true' : 'false'),
        TextCellValue(item.isSaleable ? 'true' : 'false'),
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

    final result = await FilePicker.pickFiles(
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
          "location": cellByHeader(row, headers, 'Location')?.toString() ??
              cellByHeader(row, headers, 'Kitchen Location')?.toString() ??
              '-',
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
          "rate": double.tryParse(
                  cellByHeader(row, headers, 'Rate', fallbackIndex: 8)
                          ?.toString() ??
                      '0') ??
              0,
          "retail_sale_price": double.tryParse(
                  cellByHeader(row, headers, 'Sale Rate', fallbackIndex: 9)
                          ?.toString() ??
                      '0') ??
              0,
          "mrp": double.tryParse(
                  cellByHeader(row, headers, 'MRP', fallbackIndex: 10)
                          ?.toString() ??
                      '0') ??
              0.0,
          "tax_type": cellByHeader(row, headers, 'Tax Type', fallbackIndex: 11)
                  ?.toString() ??
              'GST',
          "tax_percent": double.tryParse(
                  cellByHeader(row, headers, 'Tax Percent', fallbackIndex: 12)
                          ?.toString() ??
                      '0') ??
              0,
          "is_tax_inclusive": _toBool(
              cellByHeader(row, headers, 'Tax Inclusive', fallbackIndex: 13),
              defaultValue: false),
          "discount_applicable":
              _toBool(cellByHeader(row, headers, 'Discount Applicable',
                  fallbackIndex: 14), defaultValue: true),
          "scheme_applicable": _toBool(
              cellByHeader(row, headers, 'Scheme Applicable',
                  fallbackIndex: 15),
              defaultValue: true),
          "is_happy_hour": _toBool(
              cellByHeader(row, headers, 'Happy Hour', fallbackIndex: 16),
              defaultValue: false),
          "opening_balance": double.tryParse(
                  cellByHeader(row, headers, 'Opening', fallbackIndex: 17)
                          ?.toString() ??
                      '0') ??
              0,
          "min_level": int.tryParse(
                  cellByHeader(row, headers, 'Min', fallbackIndex: 18)
                          ?.toString() ??
                      '0') ??
              0,
          "max_level": int.tryParse(
                  cellByHeader(row, headers, 'Max', fallbackIndex: 19)
                          ?.toString() ??
                      '0') ??
              0,
          "stockable": _toBool(
              cellByHeader(row, headers, 'Stockable', fallbackIndex: 20),
              defaultValue: true),
          "is_saleable": _toBool(
              cellByHeader(row, headers, 'Saleable', fallbackIndex: 21),
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

  Future<void> _openBulkLocationDialog() async {
    String? selectedLocation;
    final customLocationCtrl = TextEditingController();
    bool applyToFilteredOnly = false;

    final locNames = _locations
        .map((l) => l.locationName.trim())
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList();

    if (locNames.isNotEmpty) {
      selectedLocation = locNames.first;
    }

    final messenger = ScaffoldMessenger.of(context);

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final countToUpdate =
                applyToFilteredOnly ? _filtered.length : _items.length;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: const Row(
                children: [
                  Icon(Icons.edit_location_alt_outlined, color: Colors.indigo),
                  SizedBox(width: 10),
                  Text(
                    'Bulk Location Update',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select or enter the new Stock Location / Warehouse to apply across items.',
                      style:
                          TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 16),
                    const Text('Select Existing Location:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    if (locNames.isNotEmpty)
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: locNames.contains(selectedLocation)
                            ? selectedLocation
                            : null,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        items: locNames.map((loc) {
                          return DropdownMenuItem(
                            value: loc,
                            child: Text(loc),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setDialogState(() {
                            selectedLocation = val;
                            customLocationCtrl.clear();
                          });
                        },
                      ),
                    const SizedBox(height: 12),
                    const Text('Or Enter New / Custom Location:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: customLocationCtrl,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Rack A-1, Main Warehouse, Shelf 3',
                        isDense: true,
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                      onChanged: (val) {
                        if (val.trim().isNotEmpty) {
                          setDialogState(() => selectedLocation = null);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      activeColor: Colors.indigo,
                      title: Text(
                        'Apply only to current search results (${_filtered.length} items)',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        applyToFilteredOnly
                            ? 'Will update only the ${_filtered.length} filtered items'
                            : 'Will update ALL ${_items.length} catalog items',
                        style: const TextStyle(fontSize: 11),
                      ),
                      value: applyToFilteredOnly,
                      onChanged: (val) => setDialogState(
                          () => applyToFilteredOnly = val ?? false),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                  onPressed: () async {
                    final targetLoc = (customLocationCtrl.text.trim().isNotEmpty
                            ? customLocationCtrl.text.trim()
                            : selectedLocation ?? '')
                        .trim();

                    if (targetLoc.isEmpty) {
                      messenger.showSnackBar(
                        const SnackBar(
                            content:
                                Text('Please select or enter a valid location')),
                      );
                      return;
                    }

                    Navigator.pop(ctx);

                    final targetIds = applyToFilteredOnly
                        ? _filtered.map((it) => it.id).toList()
                        : <int>[];

                    try {
                      final updatedCount =
                          await itemCtrl.bulkUpdateLocation(
                        itemIds: targetIds,
                        location: targetLoc,
                      );

                      await _loadItems();
                      if (!mounted) return;
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            'Successfully updated stock location to "$targetLoc" for $updatedCount item(s)',
                          ),
                          backgroundColor: const Color(0xFF008060),
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Error updating locations: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.check, size: 18),
                  label: Text('Apply to $countToUpdate Items'),
                ),
              ],
            );
          },
        );
      },
    );
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
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  onPressed: _deleteAllAndImportNew,
                  icon: const Icon(Icons.delete_sweep, size: 16),
                  label: const Text(
                    'Delete All & Import',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF008060),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                onPressed: _openBulkLocationDialog,
                icon: const Icon(Icons.edit_location_alt_outlined, size: 16),
                label: const Text(
                  'Bulk Location',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
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
            IconButton(
              icon: const Icon(Icons.swap_horiz),
              tooltip: 'Stock Transfer',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const StockTransferScreen(),
                  ),
                );
              },
            ),
          ],
        ),
        body: FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    child: _formCard(),
                  ),
                ),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Code, Name, HSN, Location, Barcode, Image
            Wrap(
              spacing: 14,
              runSpacing: 14,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _text(_code, 'Item Code', readOnly: true, width: 130),
                _text(_name, 'Item Name',
                    focusNode: _nameFocus,
                    onSubmit: () => _hsnSacFocus.requestFocus(),
                    width: 210),
                _text(_hsnSac, 'HSN / SAC Code',
                    focusNode: _hsnSacFocus,
                    prevNode: _nameFocus,
                    onSubmit: () => _hasVariants
                        ? _groupFocus.requestFocus()
                        : _barcodeFocus.requestFocus(),
                    width: 140),
                (() {
                  final Set<String> locOptions = {};
                  for (final l in _locations) {
                    if (l.locationName.trim().isNotEmpty) locOptions.add(l.locationName.trim());
                  }
                  if (_location.text.trim().isNotEmpty) {
                    locOptions.add(_location.text.trim());
                  }
                  final List<String> dbLocations = locOptions.toList();
                  if (dbLocations.isEmpty) dbLocations.add('-');

                  final String selectedVal = dbLocations.contains(_location.text.trim())
                      ? _location.text.trim()
                      : dbLocations.first;

                  return SizedBox(
                    width: 210,
                    child: Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedVal,
                            style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                            decoration: _compactDecoration('Location / Station'),
                            items: dbLocations.map((locStr) {
                              return DropdownMenuItem<String>(
                                value: locStr,
                                child: Text(locStr, overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _location.text = val);
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: Colors.blue, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Add Location to Database',
                          onPressed: _showAddLocationDialog,
                        ),
                      ],
                    ),
                  );
                })(),
                if (!_hasVariants)
                  _text(_barcode, 'Barcode / Scan Code',
                      focusNode: _barcodeFocus,
                      prevNode: _hsnSacFocus,
                      onSubmit: () => _groupFocus.requestFocus(),
                      width: 160),
                SizedBox(
                  width: 180,
                  child: TextFormField(
                    readOnly: true,
                    controller: _imagePath,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                    decoration: _compactDecoration(
                      'Item Image',
                      suffixIcon: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.image_outlined, size: 20),
                        tooltip: 'Select Image File',
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
                          child: _imageWidget((_pickedImagePath ?? _currentImagePath)!),
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
              ],
            ),
            const SizedBox(height: 12),

            // Row 2: Group, Sub Category, Brand, Unit, Buy Rate, Sale Rate, MRP, Tax Type, Tax %, Balances
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 180,
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
                        final List<GroupModel> list = List<GroupModel>.from(_groups);
                        list.add(GroupModel(id: -1, groupName: "+ Add New Group"));
                        return list;
                      },
                      itemAsString: (item) => item.groupName,
                      compareFn: (a, b) => a.id == b.id,
                      popupProps: const PopupProps.menu(showSearchBox: true),
                      decoratorProps: DropDownDecoratorProps(
                        decoration: _compactDecoration(
                          "Group",
                          prefixIcon: _selectedGroup == null
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.edit, size: 16),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  tooltip: 'Edit Group',
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
                        _subCategoryFocus.requestFocus();
                      },
                    ),
                  ),
                ),

                SizedBox(
                  width: 180,
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
                          _subCategoryDropdownKey.currentState?.openDropDownSearch();
                          return KeyEventResult.handled;
                        }
                      }
                      return KeyEventResult.ignored;
                    },
                    child: DropdownSearch<SubCategoryModel>(
                      key: _subCategoryDropdownKey,
                      selectedItem: _selectedSubCategory,
                      items: (filter, infiniteScrollProps) {
                        if (_selectedGroup == null) return [];
                        final List<SubCategoryModel> list = _subCategories
                            .where((s) => s.groupId == _selectedGroup!.id)
                            .toList();
                        list.add(SubCategoryModel(
                            id: -1,
                            groupId: _selectedGroup!.id,
                            subCategoryName: "+ Add New SubCategory"));
                        return list;
                      },
                      itemAsString: (item) => item.subCategoryName,
                      compareFn: (a, b) => a.id == b.id,
                      popupProps: const PopupProps.menu(showSearchBox: true),
                      decoratorProps: DropDownDecoratorProps(
                        decoration: _compactDecoration(
                          "Sub Category",
                          prefixIcon: _selectedSubCategory == null
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.edit, size: 16),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  tooltip: 'Edit SubCategory',
                                  onPressed: _showEditSubCategoryDialog,
                                ),
                        ),
                      ),
                      onChanged: (value) async {
                        if (value == null) return;
                        if (value.id == -1) {
                          _showAddSubCategoryDialog();
                          return;
                        }
                        setState(() {
                          _selectedSubCategory = value;
                        });
                        _brandFocus.requestFocus();
                      },
                    ),
                  ),
                ),

                SizedBox(
                  width: 180,
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
                        final List<BrandModel> list = List<BrandModel>.from(_brands);
                        list.add(BrandModel(id: -1, brandName: "+ Add New Brand"));
                        return list;
                      },
                      itemAsString: (item) => item.brandName,
                      compareFn: (a, b) => a.id == b.id,
                      popupProps: const PopupProps.menu(showSearchBox: true),
                      decoratorProps: DropDownDecoratorProps(
                        decoration: _compactDecoration(
                          "Brand",
                          prefixIcon: _selectedBrand == null
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.edit, size: 16),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  tooltip: 'Edit Brand',
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
                        _unitFocus.requestFocus();
                      },
                    ),
                  ),
                ),

                SizedBox(
                  width: 130,
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
                      decoratorProps: DropDownDecoratorProps(
                        decoration: _compactDecoration("Unit"),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _unit = value;
                        });
                        if (_hasVariants) {
                          _taxTypeFocus.requestFocus();
                        } else {
                          _rateFocus.requestFocus();
                        }
                      },
                    ),
                  ),
                ),

                if (!_hasVariants) ...[
                  _text(
                    _rate,
                    _useInclusiveRates &&
                            (_inclusiveRateScope == 'BOTH' ||
                                _inclusiveRateScope == 'BUY_ONLY')
                        ? 'Buy Rate (Inclusive)'
                        : 'Buy Rate',
                    isDouble: true,
                    focusNode: _rateFocus,
                    prevNode: _unitFocus,
                    onSubmit: () => _saleRateFocus.requestFocus(),
                    width: 140,
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
                    onSubmit: () => _mrpFocus.requestFocus(),
                    width: 140,
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
                  _text(
                    _mrp,
                    'MRP (Crossed Price)',
                    isDouble: true,
                    focusNode: _mrpFocus,
                    prevNode: _saleRateFocus,
                    onSubmit: () => _taxTypeFocus.requestFocus(),
                    width: 150,
                  ),
                ],
                SizedBox(
                  width: 130,
                  child: Focus(
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent &&
                          event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                        _mrpFocus.requestFocus();
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: DropdownButtonFormField<String>(
                      focusNode: _taxTypeFocus,
                      initialValue: _taxType,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                      decoration: _compactDecoration('Tax Type'),
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
                        _taxPercentFocus.requestFocus();
                      },
                    ),
                  ),
                ),
                _text(_taxPercent, 'Tax %',
                    isDouble: true,
                    focusNode: _taxPercentFocus,
                    prevNode: _taxTypeFocus,
                    onSubmit: () => _hasVariants
                        ? _discountFocus.requestFocus()
                        : _openingFocus.requestFocus(),
                    width: 110),
                if (!_hasVariants) ...[
                  _text(_opening, 'Opening Balance',
                      isDouble: true,
                      readOnly: _editIndex == null ? false : true,
                      focusNode: _openingFocus,
                      prevNode: _taxPercentFocus,
                      onSubmit: () => _minFocus.requestFocus(),
                      width: 130),
                  _text(_min, 'Min Level',
                      isInt: true,
                      focusNode: _minFocus,
                      prevNode: _openingFocus,
                      onSubmit: () => _maxFocus.requestFocus(),
                      width: 110),
                  _text(_max, 'Max Level',
                      isInt: true,
                      focusNode: _maxFocus,
                      prevNode: _minFocus,
                      onSubmit: () => _discountFocus.requestFocus(),
                      width: 110),
                ],
              ],
            ),
            _buildOptionsAndActionsBar(),
            if (_hasVariants) _variantBuilderUI(),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleChip({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    FocusNode? focusNode,
  }) {
    const Color activeGreen    = Color(0xFF008060);
    const Color activeBg       = Color(0xFFE6F4EF);
    const Color activeBorder   = Color(0xFF34D399);
    const Color activeLabel    = Color(0xFF065F46);
    const Color inactiveBg     = Color(0xFFF8FAFC);
    const Color inactiveBorder = Color(0xFFCBD5E1);
    const Color inactiveLabel  = Color(0xFF64748B);

    return IntrinsicWidth(
      child: Container(
        padding: const EdgeInsets.only(left: 10, right: 4, top: 3, bottom: 3),
        decoration: BoxDecoration(
          color: value ? activeBg : inactiveBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: value ? activeBorder : inactiveBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              title,
              overflow: TextOverflow.visible,
              maxLines: 1,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: value ? activeLabel : inactiveLabel,
                letterSpacing: 0.1,
              ),
            ),
            Transform.scale(
              scale: 0.78,
              alignment: Alignment.centerRight,
              child: Switch(
                focusNode: focusNode,
                value: value,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                activeColor: activeGreen,
                activeTrackColor: const Color(0xFF6EE7B7),
                inactiveThumbColor: const Color(0xFFCBD5E1),
                inactiveTrackColor: const Color(0xFFE2E8F0),
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionsAndActionsBar() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // All toggle switches aligned in one clean row
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (_editIndex == null)
                _buildToggleChip(
                  title: 'Has Variants',
                  value: _hasVariants,
                  onChanged: (v) {
                    setState(() => _hasVariants = v);
                    _generateVariantList();
                  },
                ),
              _buildToggleChip(
                title: 'Get Inclusive',
                value: _useInclusiveRates,
                focusNode: _inclusiveSwitchFocus,
                onChanged: (v) {
                  setState(() {
                    _useInclusiveRates = v;
                    if (!v) {
                      _inclusiveRateScope = 'BOTH';
                    }
                  });
                },
              ),
              if (_useInclusiveRates)
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<String>(
                    focusNode: _inclusiveScopeFocus,
                    initialValue: _inclusiveRateScope,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
                    decoration: _compactDecoration('Apply To'),
                    items: const [
                      DropdownMenuItem(
                        value: 'BOTH',
                        child: Text('Buy & Sale Rate'),
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
                    },
                  ),
                ),
              _buildToggleChip(
                title: 'Discount Applicable',
                value: _discountApplicable,
                focusNode: _discountFocus,
                onChanged: (v) => setState(() => _discountApplicable = v),
              ),
              _buildToggleChip(
                title: 'Scheme Applicable',
                value: _schemeApplicable,
                focusNode: _schemeFocus,
                onChanged: (v) => setState(() => _schemeApplicable = v),
              ),
              _buildToggleChip(
                title: 'Happy Hour Item',
                value: _isHappyHour,
                focusNode: _happyHourFocus,
                onChanged: (v) => setState(() => _isHappyHour = v),
              ),
              _buildToggleChip(
                title: 'Stockable',
                value: _stockable,
                focusNode: _stockableFocus,
                onChanged: (v) => setState(() => _stockable = v),
              ),
              _buildToggleChip(
                title: 'Item for Sale',
                value: _isSaleable,
                focusNode: _isSaleableFocus,
                onChanged: (v) => setState(() => _isSaleable = v),
              ),
            ],
          ),

          // Prominent Action Buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: _clearForm,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  foregroundColor: const Color(0xFF475569),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Clear', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                focusNode: _saveBtnFocus,
                onPressed: _isSaving ? null : _saveItem,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF008060),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save, size: 18),
                label: Text(
                  _isSaving ? 'Saving...' : (_editIndex == null ? 'Save Item' : 'Update Item'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _generateVariantList() {
    if (_selectedAttributes.isEmpty) {
      setState(() {
        _generatedVariants = [];
      });
      return;
    }

    final keys = _selectedAttributes.keys.toList();
    List<List<AttributeValue>> combinations = [[]];

    for (var key in keys) {
      final values = _selectedAttributes[key] ?? [];
      if (values.isEmpty) continue;
      
      List<List<AttributeValue>> newCombinations = [];
      for (var combination in combinations) {
        for (var value in values) {
          newCombinations.add([...combination, value]);
        }
      }
      combinations = newCombinations;
    }

    if (combinations.isEmpty || combinations.first.isEmpty) {
      setState(() {
        _generatedVariants = [];
      });
      return;
    }

    final templateName = _name.text.trim();
    final templateCode = _code.text.trim();

    _generatedVariants = combinations.map((combination) {
      final choicesName = combination.map((e) => e.value).join(' / ');
      final choicesCode = combination.map((e) => e.value.replaceAll(RegExp(r'\s+'), '').toUpperCase()).join('-');
      
      final variantName = templateName.isNotEmpty ? '$templateName - $choicesName' : choicesName;
      final variantCode = templateCode.isNotEmpty ? '$templateCode-$choicesCode' : choicesCode;

      return {
        'item_name': variantName,
        'item_code': variantCode,
        'barcode': '',
        'rate': double.tryParse(_rate.text.trim()) ?? 0.0,
        'retail_sale_price': double.tryParse(_retailSalePrice.text.trim()) ?? 0.0,
        'mrp': double.tryParse(_mrp.text.trim()) ?? 0.0,
        'opening_balance': double.tryParse(_opening.text.trim()) ?? 0.0,
        'min_level': int.tryParse(_min.text.trim()) ?? 0,
        'max_level': int.tryParse(_max.text.trim()) ?? 0,
        'choiceIds': combination.map((e) => e.id).toList()
      };
    }).toList();

    setState(() {});
  }

  void _showAddAttributeDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Attribute Type'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'e.g., Color, Size, RAM'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) {
                try {
                  await _attributeCtrl.createAttribute(name);
                  if (!mounted) return;
                  Navigator.pop(ctx);
                  setState(() {});
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Add'),
          )
        ],
      ),
    );
  }

  void _showAddAttributeValueDialog(Attribute attr) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add value for ${attr.name}'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'e.g., Red, XL, 16GB'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final val = ctrl.text.trim();
              if (val.isNotEmpty) {
                try {
                  await _attributeCtrl.createAttributeValue(attr.id, val);
                  if (!mounted) return;
                  Navigator.pop(ctx);
                  setState(() {});
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Add'),
          )
        ],
      ),
    );
  }

  Widget _variantBuilderUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),
        const Text(
          'Product Variant Builder',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add Attribute Type'),
              onPressed: _showAddAttributeDialog,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_attributeCtrl.attributes.isEmpty && !_attributeCtrl.loading)
          const Text('No attributes defined. Click above to add one.')
        else
          ..._attributeCtrl.attributes.map((attr) {
            final selectedVals = _selectedAttributes[attr] ?? [];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          attr.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Value'),
                          onPressed: () => _showAddAttributeValueDialog(attr),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: attr.values.map((val) {
                        final isSelected = selectedVals.any((v) => v.id == val.id);
                        return FilterChip(
                          label: Text(val.value),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedAttributes.putIfAbsent(attr, () => []).add(val);
                              } else {
                                _selectedAttributes[attr]?.removeWhere((v) => v.id == val.id);
                                if (_selectedAttributes[attr]?.isEmpty ?? false) {
                                  _selectedAttributes.remove(attr);
                                }
                              }
                            });
                            _generateVariantList();
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            );
          }),
        if (_generatedVariants.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            'Variant Combinations Config',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Variant Name')),
                  DataColumn(label: Text('SKU Code')),
                  DataColumn(label: Text('Barcode')),
                  DataColumn(label: Text('Buy Rate')),
                  DataColumn(label: Text('Sale Price')),
                  DataColumn(label: Text('MRP')),
                  DataColumn(label: Text('Opening Stock')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: _generatedVariants.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final v = entry.value;

                  return DataRow(
                    cells: [
                      DataCell(
                        SizedBox(
                          width: 250,
                          child: TextFormField(
                            initialValue: v['item_name'],
                            decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                            onChanged: (val) => _generatedVariants[idx]['item_name'] = val,
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 150,
                          child: TextFormField(
                            initialValue: v['item_code'],
                            decoration: const InputDecoration(isDense: true),
                            onChanged: (val) => _generatedVariants[idx]['item_code'] = val.toUpperCase(),
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 150,
                          child: TextFormField(
                            initialValue: v['barcode'],
                            decoration: const InputDecoration(isDense: true, hintText: 'Auto/Scan'),
                            onChanged: (val) => _generatedVariants[idx]['barcode'] = val,
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 80,
                          child: TextFormField(
                            initialValue: v['rate'].toString(),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(isDense: true),
                            onChanged: (val) => _generatedVariants[idx]['rate'] = double.tryParse(val) ?? 0.0,
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 80,
                          child: TextFormField(
                            initialValue: v['retail_sale_price'].toString(),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(isDense: true),
                            onChanged: (val) => _generatedVariants[idx]['retail_sale_price'] = double.tryParse(val) ?? 0.0,
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 80,
                          child: TextFormField(
                            initialValue: (v['mrp'] ?? v['retail_sale_price'] ?? 0.0).toString(),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(isDense: true),
                            onChanged: (val) => _generatedVariants[idx]['mrp'] = double.tryParse(val) ?? 0.0,
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 80,
                          child: TextFormField(
                            initialValue: v['opening_balance'].toString(),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(isDense: true),
                            onChanged: (val) => _generatedVariants[idx]['opening_balance'] = double.tryParse(val) ?? 0.0,
                          ),
                        ),
                      ),
                      DataCell(
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _generatedVariants.removeAt(idx);
                            });
                          },
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ]
      ],
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

  void _showAddLocationDialog() {
    final TextEditingController nameCtrl = TextEditingController();
    bool isLoading = false;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Add New Kitchen / Station Location"),
              content: SizedBox(
                width: 320,
                child: TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: "Location Name",
                    hintText: "e.g. Bar, Bakery, Main Kitchen",
                    border: OutlineInputBorder(),
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
                          try {
                            await masterCtrl.createLocation(
                              nameCtrl.text.trim(),
                            );
                            await _loadMasters();
                            setState(() {
                              _location.text = nameCtrl.text.trim();
                            });
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Location Added to Database")),
                              );
                            }
                          } catch (e) {
                            setStateDialog(() => isLoading = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Error saving location: $e")),
                              );
                            }
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("Save Location"),
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
            notificationPredicate: (notification) =>
                notification.metrics.axis == Axis.vertical,
            child: Scrollbar(
              controller: _tableHorizontalController,
              thumbVisibility: true,
              notificationPredicate: (notification) =>
                  notification.metrics.axis == Axis.horizontal,
              child: SingleChildScrollView(
                controller: _tableHorizontalController,
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  controller: _tableVerticalController,
                  scrollDirection: Axis.vertical,
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
                        DataColumn(label: Text('Location')),
                        DataColumn(label: Text('HSN/SAC')),
                        DataColumn(label: Text('Group')),
                        DataColumn(label: Text('Sub Category')),
                        DataColumn(label: Text('Brand')),
                        DataColumn(label: Text('Unit')),
                        DataColumn(label: Text('Barcode')),
                        DataColumn(label: Text('Buy Rate')),
                        DataColumn(label: Text('Sale Rate')),
                        DataColumn(label: Text('MRP')),
                        DataColumn(label: Text('Tax Type')),
                        DataColumn(label: Text('Tax %')),
                        DataColumn(label: Text('Disc')),
                        DataColumn(label: Text('Scheme')),
                        DataColumn(label: Text('HH')),
                        DataColumn(label: Text('Opening')),
                        DataColumn(label: Text('Min')),
                        DataColumn(label: Text('Max')),
                        DataColumn(label: Text('Stock')),
                        DataColumn(label: Text('For Sale')),
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
                            DataCell(
                              (() {
                                final locText = (it.location.trim().isEmpty || it.location.trim() == '-')
                                    ? '-'
                                    : it.location.trim();
                                final isDefault = locText == '-';
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isDefault ? Colors.grey.shade100 : Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: isDefault ? Colors.grey.shade300 : Colors.blue.shade200,
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Text(
                                    locText,
                                    style: TextStyle(
                                      color: isDefault ? Colors.grey.shade700 : Colors.blue.shade800,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              })(),
                            ),
                            DataCell(Text(it.hsnSacCode)),
                            DataCell(Text(it.itemGroup)),
                            DataCell(Text(it.subCategory)),
                            DataCell(Text(it.brand)),
                            DataCell(Text(it.unit)),
                            DataCell(Text(it.barcode)),
                            DataCell(Text(it.rate.toStringAsFixed(2))),
                            DataCell(
                                Text(it.retailSalePrice.toStringAsFixed(2))),
                            DataCell(Text(it.mrp.toStringAsFixed(2))),
                            DataCell(Text(it.taxType)),
                            DataCell(Text(it.taxPercent.toStringAsFixed(2))),
                            DataCell(
                                Text(it.discountApplicable ? 'YES' : 'NO')),
                            DataCell(Text(it.schemeApplicable ? 'YES' : 'NO')),
                            DataCell(Text(it.isHappyHour ? 'YES' : 'NO')),
                            DataCell(
                                Text(it.openingBalance.toStringAsFixed(2))),
                            DataCell(Text(it.minLevel.toString())),
                            DataCell(Text(it.maxLevel.toString())),
                            DataCell(Icon(
                              it.stockable ? Icons.check_circle : Icons.cancel,
                              color: it.stockable ? Colors.green : Colors.red,
                              size: 18,
                            )),
                            DataCell(Icon(
                              it.isSaleable ? Icons.check_circle : Icons.cancel,
                              color: it.isSaleable ? Colors.green : Colors.red,
                              size: 18,
                            )),
                            DataCell(
                              Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                  IconButton(
                                      tooltip: 'Manage BOM',
                                      icon: const Icon(Icons.settings_input_component,
                                          color: Colors.blue),
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (_) => BOMSetupDialog(
                                            parentItem: it,
                                            itemCtrl: itemCtrl,
                                            onCostUpdated: () => _loadItems(),
                                          ),
                                        );
                                      }),
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

  InputDecoration _compactDecoration(
    String label, {
    Widget? prefixIcon,
    Widget? suffixIcon,
    String? helperText,
    bool readOnly = false,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
      floatingLabelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Color(0xFF008060),
      ),
      helperText: helperText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      filled: true,
      fillColor: readOnly ? const Color(0xFFF1F5F9) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFF008060), width: 1.5),
      ),
    );
  }

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
    bool isOptional = false,
    double width = 175,
  }) {
    return SizedBox(
      width: width,
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
          style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
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
          decoration: _compactDecoration(l, helperText: helperText, readOnly: readOnly),
          onChanged: (_) => setState(() {}),
          validator: (v) {
            if (isOptional) return null;
            return v == null || v.isEmpty ? 'Required' : null;
          },
        ),
      ),
    );
  }
}
