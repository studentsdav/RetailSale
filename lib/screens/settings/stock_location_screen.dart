import 'package:flutter/material.dart';

import '../../controllers/settings/stcok_location_controller.dart';
import '../../models/inventory/stock_location_model.dart';

class StockLocation {
  final String code;
  String name;
  String description;
  bool isActive;

  StockLocation({
    required this.code,
    required this.name,
    required this.description,
    this.isActive = true,
  });
}

class StockLocationScreen extends StatefulWidget {
  const StockLocationScreen({super.key});

  @override
  State<StockLocationScreen> createState() => _StockLocationScreenState();
}

class _StockLocationScreenState extends State<StockLocationScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _codeCtrl = TextEditingController();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController();
  final StockLocationController StockLocationApi = StockLocationController();

  List<StockLocationdata> _locations = [];
  List<StockLocationdata> _filtered = [];
  bool _isActive = true;
  int? _editIndex;

  @override
  void initState() {
    super.initState();
    _generateCode();
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    final data = await StockLocationApi.load();
    setState(() {
      _locations = StockLocationApi.list;
      _filtered = StockLocationApi.list;
    });
  }

  Future<void> _generateCode() async {
    final code = await StockLocationApi.getNextCode();
    _codeCtrl.text = code.toUpperCase();
  }

  // ---------------- SAVE ----------------
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final model = StockLocationdata(
      id: _editIndex == null ? 0 : _locations[_editIndex!].id,
      locationCode: _codeCtrl.text,
      locationName: _nameCtrl.text,
      description: _descCtrl.text,
      isActive: _isActive,
    );

    if (_editIndex == null) {
      await StockLocationApi.create(model);
    } else {
      await StockLocationApi.update(model.id, model);
      _editIndex = null;
    }

    _clearForm();
    _generateCode();

    await _loadLocations();
  }

  // ---------------- EDIT ----------------
  void _edit(int i) {
    final loc = _filtered[i];
    _editIndex = _locations.indexWhere((e) => e.id == loc.id);

    _codeCtrl.text = loc.locationCode;
    _nameCtrl.text = loc.locationName;
    _descCtrl.text = loc.description;
    _isActive = loc.isActive;
  }

  // ---------------- DELETE ----------------
  Future<void> _delete(int i) async {
    final id = _filtered[i].id;
    await StockLocationApi.delete(id);
    await _loadLocations();
    _generateCode();
  }

  // ---------------- CLEAR ----------------
  void _clearForm() {
    _nameCtrl.clear();
    _descCtrl.clear();
    _isActive = true;
  }

  // ---------------- SEARCH ----------------
  void _search(String v) {
    setState(() {
      _filtered = _locations
          .where((e) =>
              e.locationName.toLowerCase().contains(v.toLowerCase()) ||
              e.locationCode.toLowerCase().contains(v.toLowerCase()))
          .toList();
    });
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stock Location Master')),
      backgroundColor: const Color(0xFFF6F7F9),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _formCard(),
            const SizedBox(height: 12),
            _searchBox(),
            const SizedBox(height: 10),
            Expanded(
              child: _table(),
            ),
          ],
        ),
      ),
    );
  }

  // ================= FORM =================
  Widget _formCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _field(_codeCtrl, 'Location Code', readOnly: true),
              _field(_nameCtrl, 'Location Name'),
              _field(_descCtrl, 'Description', width: 300),
              SwitchListTile(
                title: const Text('Active'),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
              ),
              Row(
                children: [
                  FilledButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('Save'),
                    onPressed: _save,
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                      onPressed: _clearForm, child: const Text('Clear')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= SEARCH =================
  Widget _searchBox() {
    return SizedBox(
      width: 320,
      child: TextField(
        controller: _searchCtrl,
        onChanged: _search,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search),
          labelText: 'Search Location',
        ),
      ),
    );
  }

  // ================= TABLE =================
  Widget _table() {
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
                columns: const [
                  DataColumn(label: Text('Code')),
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Description')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Action')),
                ],
                rows: List.generate(_filtered.length, (i) {
                  final e = _filtered[i];
                  return DataRow(
                    color: WidgetStateProperty.all(
                        e.isActive ? Colors.white : Colors.grey.shade100),
                    cells: [
                      DataCell(Text(e.locationCode)),
                      DataCell(Text(e.locationName)),
                      DataCell(Text(e.description)),
                      DataCell(Text(e.isActive ? 'Active' : 'Inactive')),
                      DataCell(
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _edit(i),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _delete(i),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ));
    });
  }

  // ================= COMMON =================
  Widget _field(
    TextEditingController c,
    String l, {
    bool readOnly = false,
    double width = 200,
  }) {
    return SizedBox(
      width: width,
      child: TextFormField(
        controller: c,
        readOnly: readOnly,
        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        decoration: InputDecoration(labelText: l),
      ),
    );
  }
}
