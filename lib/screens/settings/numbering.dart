import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../controllers/inventory/numbering_settings_controller.dart';
import '../../models/inventory/numbering_setting_model.dart';

class NumberingSettingsScreen extends StatefulWidget {
  const NumberingSettingsScreen({super.key});

  @override
  State<NumberingSettingsScreen> createState() =>
      _NumberingSettingsScreenState();
}

class _NumberingSettingsScreenState extends State<NumberingSettingsScreen> {
  final NumberingSettingsController ctrl = NumberingSettingsController();
  final List<MapEntry<String, String>> _moduleDefs = const [
    MapEntry('Purchase Order No', 'PO'),
    MapEntry('Receiving No', 'RECEIVING'),
    MapEntry('Indent No', 'INDENT'),
    MapEntry('Sales Bill No', 'SALES'),
    MapEntry('Request No', 'REQUEST'),
    MapEntry('Damage No', 'DAMAGE'),
  ];

  final Map<String, List<_NumberingRowState>> _rowsByModule = {
    'PO': [],
    'RECEIVING': [],
    'INDENT': [],
    'SALES': [],
    'REQUEST': [],
    'DAMAGE': [],
  };

  @override
  void initState() {
    super.initState();
    _ensureModuleRows();
    _loadSettings();
  }

  void _ensureModuleRows() {
    for (final def in _moduleDefs) {
      _rowsByModule.putIfAbsent(def.value, () => []);
      if (_rowsByModule[def.value]!.isEmpty) {
        _rowsByModule[def.value]!.add(_NumberingRowState.empty(def.value));
      }
    }
  }

  Future<void> _loadSettings() async {
    await ctrl.load();

    for (final def in _moduleDefs) {
      final module = def.value;
      final records = ctrl.getByModuleList(module);
      _rowsByModule[module] = records.isEmpty
          ? [_NumberingRowState.empty(module)]
          : records.map(_NumberingRowState.fromSetting).toList();
    }

    setState(() {});
  }

  void _addRow(String module) {
    setState(() {
      _rowsByModule[module]!.add(_NumberingRowState.empty(module));
    });
  }

  void _removeRow(String module, int index) {
    setState(() {
      if (_rowsByModule[module]!.length == 1) {
        _rowsByModule[module]![index] = _NumberingRowState.empty(module);
      } else {
        _rowsByModule[module]!.removeAt(index);
      }
    });
  }

  Future<void> _applySettings() async {
    final settings = <NumberingSetting>[];

    for (final entry in _rowsByModule.entries) {
      for (final row in entry.value) {
        final prefix = row.prefix.text.trim();
        final postfix = row.postfix.text.trim();
        if (prefix.isEmpty || postfix.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Prefix and Postfix are required for module ${entry.key}.',
              ),
            ),
          );
          return;
        }

        settings.add(
          NumberingSetting(
            id: row.id,
            module: entry.key,
            startDate: row.startDate,
            startNo:
                (int.tryParse(row.startNo.text.trim()) ?? 1).clamp(1, 999999999),
            prefix: prefix,
            postfix: postfix,
          ),
        );
      }
    }

    await ctrl.save(settings);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Numbering settings applied')),
    );
    await _loadSettings();
  }

  @override
  void dispose() {
    for (final rows in _rowsByModule.values) {
      for (final row in rows) {
        row.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _ensureModuleRows();
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(title: const Text('Numbering Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            ..._moduleDefs.map(
              (def) => _moduleSection(def.key, def.value),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Apply Settings'),
                onPressed: _applySettings,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _moduleSection(String title, String module) {
    final rows = _rowsByModule[module]!;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _addRow(module),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Row'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Create multiple date-based series. Example: one row from 01-Jan and another row from 01-Apr starting again from 1.',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
            const Divider(),
            ...List.generate(
              rows.length,
              (index) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _dateField(rows[index].startDate, (picked) {
                      setState(() => rows[index].startDate = picked);
                    }),
                    _field(rows[index].startNo, 'Start No From'),
                    _field(rows[index].prefix, 'Prefix'),
                    _field(rows[index].postfix, 'Postfix'),
                    IconButton(
                      onPressed: () => _removeRow(module, index),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label) {
    return SizedBox(
      width: 180,
      child: TextField(
        controller: c,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Widget _dateField(DateTime d, ValueChanged<DateTime> onChanged) {
    final controller = TextEditingController(
      text: DateFormat('dd-MMM-yyyy').format(d),
    );

    return SizedBox(
      width: 180,
      child: TextField(
        controller: controller,
        readOnly: true,
        decoration: const InputDecoration(
          labelText: 'Start Date',
          suffixIcon: Icon(Icons.calendar_today),
        ),
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: d,
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (picked != null) {
            onChanged(picked);
          }
        },
      ),
    );
  }
}

class _NumberingRowState {
  final int? id;
  final String module;
  DateTime startDate;
  final TextEditingController startNo;
  final TextEditingController prefix;
  final TextEditingController postfix;

  _NumberingRowState({
    required this.id,
    required this.module,
    required this.startDate,
    required this.startNo,
    required this.prefix,
    required this.postfix,
  });

  factory _NumberingRowState.fromSetting(NumberingSetting setting) {
    return _NumberingRowState(
      id: setting.id,
      module: setting.module,
      startDate: setting.startDate,
      startNo: TextEditingController(text: setting.startNo.toString()),
      prefix: TextEditingController(text: setting.prefix),
      postfix: TextEditingController(text: setting.postfix),
    );
  }

  factory _NumberingRowState.empty(String module) {
    return _NumberingRowState(
      id: null,
      module: module,
      startDate: DateTime.now(),
      startNo: TextEditingController(text: '1'),
      prefix: TextEditingController(),
      postfix: TextEditingController(),
    );
  }

  void dispose() {
    startNo.dispose();
    prefix.dispose();
    postfix.dispose();
  }
}
