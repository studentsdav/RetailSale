import 'dart:io';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controllers/inventory/supplier_controller.dart';
import '../../core/api/api_client.dart';
import '../../models/inventory/supplier_model.dart';

class SupplierMasterScreen extends StatefulWidget {
  const SupplierMasterScreen({super.key});

  @override
  State<SupplierMasterScreen> createState() => _SupplierMasterScreenState();
}

class _SupplierMasterScreenState extends State<SupplierMasterScreen> {
  final _formKey = GlobalKey<FormState>();
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  final _code = TextEditingController();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _state = TextEditingController();
  final _gstin = TextEditingController();
  final _search = TextEditingController();

  int? _editIndex;
  final SupplierController supplierCtrl = SupplierController();

  List<Supplier> _suppliers = [];
  List<Supplier> _filtered = [];
  final _taxCountryCode = TextEditingController(text: "IN");

  // ================= INDIAN STATES LIST =================
  final List<String> _indianStates = [
    'Andaman and Nicobar Islands',
    'Andhra Pradesh',
    'Arunachal Pradesh',
    'Assam',
    'Bihar',
    'Chandigarh',
    'Chhattisgarh',
    'Dadra and Nagar Haveli and Daman and Diu',
    'Delhi',
    'Goa',
    'Gujarat',
    'Haryana',
    'Himachal Pradesh',
    'Jammu and Kashmir',
    'Jharkhand',
    'Karnataka',
    'Kerala',
    'Ladakh',
    'Lakshadweep',
    'Madhya Pradesh',
    'Maharashtra',
    'Manipur',
    'Meghalaya',
    'Mizoram',
    'Nagaland',
    'Odisha',
    'Puducherry',
    'Punjab',
    'Rajasthan',
    'Sikkim',
    'Tamil Nadu',
    'Telangana',
    'Tripura',
    'Uttar Pradesh',
    'Uttarakhand',
    'West Bengal'
  ];

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
    _generateCode();
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _address.dispose();
    _phone.dispose();
    _state.dispose();
    _gstin.dispose();
    _search.dispose();
    _taxCountryCode.dispose();
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  Future<void> _loadSuppliers() async {
    await supplierCtrl.load();
    setState(() {
      _suppliers = supplierCtrl.list;
      _filtered = _suppliers;
    });
  }

  Future<void> _generateCode() async {
    final code = await supplierCtrl.getNextCode();
    setState(() {
      _code.text = code.toUpperCase();
    });
    _loadSuppliers();
  }

  Future<void> _saveSupplier() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vendor Name is required.')),
      );
      return;
    }
    if (_address.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Address is required.')),
      );
      return;
    }
    if (_state.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('State is required.')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final model = Supplier(
      id: _editIndex == null ? 0 : _suppliers[_editIndex!].id,
      supplierCode: _code.text,
      supplierName: _name.text.trim(),
      address: _address.text.trim(),
      phone: _phone.text.trim(),
      state: _state.text.trim().isEmpty ? null : _state.text.trim(),
      gstin: _gstin.text.trim().isEmpty ? null : _gstin.text.trim(),
      taxCountryCode: _taxCountryCode.text.trim().isEmpty
          ? null
          : _taxCountryCode.text.trim(),
    );

    if (_editIndex == null) {
      await supplierCtrl.create(model);
    } else {
      await supplierCtrl.update(model.id, model);
      _editIndex = null;
    }

    _clearForm();
    await _generateCode();
  }

  void _editSupplier(int i) {
    final s = _filtered[i];
    _editIndex = _suppliers.indexWhere((e) => e.id == s.id);

    _code.text = s.supplierCode;
    _name.text = s.supplierName;
    _address.text = s.address;
    _phone.text = s.phone;
    _state.text = s.state ?? '';
    _gstin.text = s.gstin ?? '';
    _taxCountryCode.text = s.taxCountryCode ?? '';
  }

  Future<void> _deleteSupplier(int i) async {
    await supplierCtrl.delete(_filtered[i].id);
    await _loadSuppliers();
  }

  // ================= CLEAR =================
  void _clearForm() {
    _name.clear();
    _address.clear();
    _phone.clear();
    _editIndex = null;
    _state.clear();
    _gstin.clear();
    _taxCountryCode.text = "IN";
    _generateCode();
  }

  // ================= SEARCH =================
  void _searchSupplier(String q) async {
    await supplierCtrl.load(q: q);
    setState(() => _filtered = supplierCtrl.list);
  }

  Future<void> _exportSupplierExcel() async {
    var excel = Excel.createExcel();

    final defaultSheet = excel.getDefaultSheet();
    if (defaultSheet != null) {
      excel.rename(defaultSheet, 'Suppliers');
    }

    Sheet sheet = excel['Suppliers'];

    sheet.appendRow([
      TextCellValue('Supplier Code'),
      TextCellValue('Supplier Name'),
      TextCellValue('Address'),
      TextCellValue('Phone'),
      TextCellValue('State'),
      TextCellValue('GSTIN'),
      TextCellValue('Tax ID Number'),
      TextCellValue('Tax ID Type'),
      TextCellValue('Tax Country Code'),
    ]);

    for (var s in _suppliers) {
      sheet.appendRow([
        TextCellValue(s.supplierCode),
        TextCellValue(s.supplierName),
        TextCellValue(s.address ?? ''),
        TextCellValue(s.phone ?? ''),
        TextCellValue(s.state ?? ''),
        TextCellValue(s.gstin ?? ''),
        TextCellValue(s.taxIdNumber ?? ''),
        TextCellValue(s.taxIdType ?? ''),
        TextCellValue(s.taxCountryCode ?? ''),
      ]);
    }

    final directory =
        Directory('${Platform.environment['USERPROFILE']}\\Downloads');

    final fileName =
        'suppliers_export_${DateTime.now().millisecondsSinceEpoch}.xlsx';

    final path = '${directory.path}\\$fileName';

    final bytes = excel.encode();
    if (bytes == null) return;

    await File(path).writeAsBytes(bytes, flush: true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exported Successfully\nSaved at: $path')),
    );
  }

  Future<void> _importSupplierExcel() async {
    final res = await ApiClient.get('/api/inventory/suppliers/can-import');

    if (res['canImport'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Import allowed only on first setup')),
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

    List<Map<String, dynamic>> bulkData = [];

    for (var table in excel.tables.keys) {
      for (int i = 1; i < excel.tables[table]!.rows.length; i++) {
        final row = excel.tables[table]!.rows[i];

        bulkData.add({
          "supplier_code": row[0]?.value.toString(),
          "supplier_name": row[1]?.value.toString(),
          "address": row[2]?.value.toString(),
          "phone": row[3]?.value.toString(),
          "state": row.length > 4 ? row[4]?.value.toString() : null,
          "gstin": row.length > 5 ? row[5]?.value.toString() : null,
          "tax_id_number": row.length > 6 ? row[6]?.value.toString() : null,
          "tax_id_type": row.length > 7 ? row[7]?.value.toString() : null,
          "tax_country_code": row.length > 8 ? row[8]?.value.toString() : null,
        });
      }
    }

    await ApiClient.post('/api/inventory/suppliers/bulk-import', bulkData);

    await _loadSuppliers();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Import Successful')),
    );
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Vendor Master'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: _importSupplierExcel,
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportSupplierExcel,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _formCard(),
            const SizedBox(height: 16),
            _searchBar(),
            const SizedBox(height: 16),
            Expanded(
              child: _dataTable(),
            ),
          ],
        ),
      ),
    );
  }

  // ================= FORM CARD =================
  Widget _formCard() {
    return _card(
      title: 'Vendor Information',
      child: Form(
        key: _formKey,
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _field(_code, 'Vendor Code', readOnly: true),
            _field(_name, 'Vendor Name'),
            _field(_address, 'Address', width: 360),
            _field(_phone, 'Phone', isNumber: true, required: false),

            // Replaced the basic _field with our searchable DropdownMenu
            _stateDropdown(),

            _field(_gstin, 'GSTIN', required: false),
            _field(_taxCountryCode, 'Country Code (IN/US/UK)', required: false),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.save),
                  label: Text(_editIndex == null ? 'Save' : 'Update'),
                  onPressed: _saveSupplier,
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: _clearForm,
                  child: const Text('Clear'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ================= SEARCHABLE STATE DROPDOWN =================
  Widget _stateDropdown() {
    return DropdownMenu<String>(
      width: 220,
      controller: _state,
      label: const Text('State'),
      enableFilter: true, // Enables typing to search the list
      requestFocusOnTap: true,
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
      ),
      dropdownMenuEntries: _indianStates.map((String state) {
        return DropdownMenuEntry<String>(
          value: state,
          label: state,
        );
      }).toList(),
      onSelected: (String? selectedState) {
        if (selectedState != null) {
          _state.text = selectedState;
        }
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
            )
          ],
        ),
        child: TextField(
          controller: _search,
          onChanged: _searchSupplier,
          decoration: const InputDecoration(
            hintText: 'Search vendor (code, name, phone)',
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
    return LayoutBuilder(builder: (context, constraints) {
      return SizedBox(
        height: constraints.maxHeight,
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: Scrollbar(
            controller: _horizontalController,
            thumbVisibility: true,
            trackVisibility: true,
            child: SingleChildScrollView(
              controller: _horizontalController,
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                dataRowMinHeight: 46,
                dataRowMaxHeight: 54,
                columns: const [
                  DataColumn(label: Text('Code')),
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Phone')),
                  DataColumn(label: Text('Address')),
                  DataColumn(label: Text('State')),
                  DataColumn(label: Text('GSTIN')),
                  DataColumn(label: Text('Action')),
                ],
                rows: List.generate(_filtered.length, (i) {
                  final s = _filtered[i];
                  return DataRow(
                    color: WidgetStateProperty.all(
                        i.isEven ? Colors.grey.shade50 : Colors.white),
                    cells: [
                      DataCell(Text(s.supplierCode)),
                      DataCell(Text(s.supplierName)),
                      DataCell(Text(s.phone ?? '')),
                      DataCell(Text(s.address ?? '')),
                      DataCell(Text(s.state ?? '')),
                      DataCell(Text(s.gstin ?? '')),
                      DataCell(Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _editSupplier(i),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteSupplier(i),
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

  // ================= COMMON =================
  Widget _card({String? title, required Widget child}) {
    return Material(
      color: Colors.white,
      elevation: 1,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // VERY IMPORTANT
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
  }

  Widget _field(
    TextEditingController c,
    String l, {
    bool readOnly = false,
    bool isNumber = false,
    bool required = true,
    double width = 220,
  }) {
    return SizedBox(
      width: width,
      child: TextFormField(
        controller: c,
        readOnly: readOnly,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        inputFormatters:
            isNumber ? [FilteringTextInputFormatter.digitsOnly] : [],
        validator: (v) =>
            required && (v == null || v.isEmpty) ? 'Required' : null,
        decoration: InputDecoration(
          labelText: l,
          filled: true,
          fillColor: readOnly ? Colors.grey.shade100 : Colors.white,
        ),
      ),
    );
  }
}
