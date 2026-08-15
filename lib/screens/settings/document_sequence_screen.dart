import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../controllers/inventory/document_sequence_controller.dart';
import '../../models/inventory/document_sequence_model.dart';

class DocumentSequenceScreen extends StatefulWidget {
  const DocumentSequenceScreen({super.key});

  @override
  State<DocumentSequenceScreen> createState() =>
      _DocumentSequenceScreenState();
}

class _DocumentSequenceScreenState extends State<DocumentSequenceScreen> {
  final DocumentSequenceController ctrl = DocumentSequenceController();
  final List<MapEntry<String, String>> _moduleDefs = const [
    MapEntry('KOT / Restaurant Order No', 'KOT'),
    MapEntry('Purchase Order No', 'PO'),
    MapEntry('Receiving No', 'RECEIVING'),
    MapEntry('Indent No', 'INDENT'),
    MapEntry('Sales Bill No', 'SALES'),
    MapEntry('Request No', 'REQUEST'),
    MapEntry('Damage No', 'DAMAGE'),
  ];

  final Map<String, List<_NumberingRowState>> _rowsByModule = {
    'KOT': [],
    'PO': [],
    'RECEIVING': [],
    'INDENT': [],
    'SALES': [],
    'REQUEST': [],
    'DAMAGE': [],
  };

  bool _isSaving = false;

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
    setState(() => _isSaving = true);
    final settings = <DocumentSequence>[];

    try {
      for (final entry in _rowsByModule.entries) {
        for (final row in entry.value) {
          final prefix = row.prefix.text.trim();
          final postfix = row.postfix.text.trim();
          if (prefix.isEmpty || postfix.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: Colors.red.shade700,
                content: Text(
                  'Prefix and Postfix are required for module ${entry.key}.',
                ),
              ),
            );
            return;
          }

          settings.add(
            DocumentSequence(
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
        const SnackBar(
          backgroundColor: Color(0xFF008060), // Shopify Emerald
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'Document sequence settings successfully applied!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
      await _loadSettings();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text('Failed to save settings: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
      backgroundColor: const Color(0xFFF1F5F9), // Shopify Polaris Gray
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Document Sequence Settings',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Configure custom prefixes, postfixes, and numbering series',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF008060), // Shopify Emerald
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline, size: 18),
              label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
              onPressed: _isSaving ? null : _applySettings,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            ..._moduleDefs.map(
              (def) => _buildPolarisModuleSection(def.key, def.value),
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF008060),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.save, size: 18),
                label: const Text(
                  'Apply Settings',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                onPressed: _isSaving ? null : _applySettings,
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildPolarisModuleSection(String title, String module) {
    final rows = _rowsByModule[module]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Shopify Header Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    module,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _addRow(module),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF008060),
                    side: const BorderSide(color: Color(0xFF008060)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text(
                    'Add Row',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          // Subtitle instruction
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'Create multiple date-based series. Example: one row from 01-Jan and another row from 01-Apr starting again from 1.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          // Rows List
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: List.generate(
                rows.length,
                (index) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _dateField(rows[index].startDate, (picked) {
                        setState(() => rows[index].startDate = picked);
                      }),
                      _polarisField(rows[index].startNo, 'Start No From', isNumber: true),
                      _polarisField(rows[index].prefix, 'Prefix'),
                      _polarisField(rows[index].postfix, 'Postfix'),
                      Container(
                        margin: const EdgeInsets.only(top: 14),
                        child: IconButton(
                          onPressed: () => _removeRow(module, index),
                          tooltip: 'Delete Sequence Row',
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.red.shade50,
                            foregroundColor: Colors.red.shade700,
                          ),
                          icon: const Icon(Icons.delete_outline, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _polarisField(TextEditingController c, String label, {bool isNumber = false}) {
    return SizedBox(
      width: 175,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: c,
            keyboardType: isNumber ? TextInputType.number : TextInputType.text,
            style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              filled: true,
              fillColor: Colors.white,
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateField(DateTime d, ValueChanged<DateTime> onChanged) {
    final controller = TextEditingController(
      text: DateFormat('dd-MMM-yyyy').format(d),
    );

    return SizedBox(
      width: 175,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Start Date',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            readOnly: true,
            style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              filled: true,
              fillColor: Colors.white,
              suffixIcon: const Icon(Icons.calendar_month, size: 18, color: Color(0xFF008060)),
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
        ],
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

  factory _NumberingRowState.fromSetting(DocumentSequence setting) {
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
    String defaultPrefix = '';
    if (module == 'KOT') {
      defaultPrefix = 'KOT-';
    } else if (module == 'PO') {
      defaultPrefix = 'PO-';
    } else if (module == 'SALES') {
      defaultPrefix = 'SAL-';
    } else if (module == 'REQUEST') {
      defaultPrefix = 'REQ-';
    } else if (module == 'DAMAGE') {
      defaultPrefix = 'DMG-';
    } else if (module == 'RECEIVING') {
      defaultPrefix = 'REC-';
    } else if (module == 'INDENT') {
      defaultPrefix = 'IND-';
    }

    final String defaultPostfix = '-${DateTime.now().year.toString().substring(2)}';

    return _NumberingRowState(
      id: null,
      module: module,
      startDate: DateTime.now(),
      startNo: TextEditingController(text: '1'),
      prefix: TextEditingController(text: defaultPrefix),
      postfix: TextEditingController(text: defaultPostfix),
    );
  }

  void dispose() {
    startNo.dispose();
    prefix.dispose();
    postfix.dispose();
  }
}
