import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';

class HrmsMastersScreen extends StatefulWidget {
  const HrmsMastersScreen({Key? key}) : super(key: key);
  @override
  State<HrmsMastersScreen> createState() => _HrmsMastersScreenState();
}

class _HrmsMastersScreenState extends State<HrmsMastersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _salaryTabController;

  // ── Data from API ──
  List<Map<String, dynamic>> _leaveTypes    = [];
  List<Map<String, dynamic>> _shifts        = [];
  List<Map<String, dynamic>> _designations  = [];
  List<Map<String, dynamic>> _salaryComps   = [];
  List<Map<String, dynamic>> _payStructures = [];

  bool _loading = true;
  String? _error;

  // ─── COLORS ───────────────────────────────────────────
  static const _navy   = Color(0xFF1A1A2E);
  static const _red    = Color(0xFFE03E2D);
  static const _green  = Color(0xFF059669);
  static const _blue   = Color(0xFF2563EB);
  static const _amber  = Color(0xFFF59E0B);
  static const _grey50 = Color(0xFFF9FAFB);
  static const _grey10 = Color(0xFFF3F4F6);
  static const _grey40 = Color(0xFF9CA3AF);

  @override
  void initState() {
    super.initState();
    _salaryTabController = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _salaryTabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        ApiClient.get(ApiEndpoints.hrmsLeaveTypes),
        ApiClient.get(ApiEndpoints.hrmsShifts),
        ApiClient.get(ApiEndpoints.hrmsDesignations),
        ApiClient.get(ApiEndpoints.hrmsSalaryComponents),
        ApiClient.get(ApiEndpoints.hrmsPayStructures),
      ]);
      setState(() {
        _leaveTypes    = _parseList(results[0]);
        _shifts        = _parseList(results[1]);
        _designations  = _parseList(results[2]);
        _salaryComps   = _parseList(results[3]);
        _payStructures = _parseList(results[4]);
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<Map<String, dynamic>> _parseList(dynamic res) {
    final d = res['data'];
    if (d is List) return d.cast<Map<String, dynamic>>();
    return [];
  }

  Future<void> _deleteMaster(String endpoint, int id, String label) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $label'),
        content: Text('Are you sure you want to delete this $label? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    
    setState(() => _loading = true);
    try {
      await ApiClient.delete('$endpoint/$id');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label deleted successfully'),
          backgroundColor: _green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      // ApiClient error handler automatically triggers a dialog/snackbar on 4xx/5xx failure
    } finally {
      _loadAll();
    }
  }

  Future<void> _editDesignation(Map<String, dynamic> d) async {
    final ctrl = TextEditingController(text: d['name']?.toString() ?? '');
    final ok = await _showCompactDialog(
      title: 'Edit Designation',
      icon: Icons.badge_outlined,
      iconColor: _blue,
      iconBg: const Color(0xFFEFF6FF),
      child: TextField(
        controller: ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        style: const TextStyle(fontSize: 13),
        decoration: _fieldDecor(
            'Designation Title *', 'e.g. Sales Manager',
            Icons.badge_outlined),
      ),
      onSave: () async {
        if (ctrl.text.trim().isEmpty) return false;
        await ApiClient.put('${ApiEndpoints.hrmsDesignations}/${d['id']}', {
          'name': ctrl.text.trim(),
          'is_active': d['is_active'] != false,
        });
        return true;
      },
    );
    if (ok == true) _loadAll();
  }

  Future<void> _editShift(Map<String, dynamic> s) async {
    final nameCtrl  = TextEditingController(text: s['name']?.toString() ?? '');
    final graceCtrl = TextEditingController(text: s['grace_period_mins']?.toString() ?? '15');
    final selectedOffs = List<String>.from(s['weekly_offs'] ?? ['Sunday']);
    final weekdayOptions = [
      'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
      '1st Saturday', '2nd Saturday', '3rd Saturday', '4th Saturday', '5th Saturday',
    ];
    
    TimeOfDay? startTime;
    TimeOfDay? endTime;
    try {
      final sParts = (s['start_time']?.toString() ?? '').split(':');
      startTime = TimeOfDay(hour: int.parse(sParts[0]), minute: int.parse(sParts[1]));
      final eParts = (s['end_time']?.toString() ?? '').split(':');
      endTime = TimeOfDay(hour: int.parse(eParts[0]), minute: int.parse(eParts[1]));
    } catch (_) {}

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          String fmt(TimeOfDay? t) {
            if (t == null) return 'Tap to pick';
            final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
            final m = t.minute.toString().padLeft(2, '0');
            return '$h:$m ${t.period == DayPeriod.am ? "AM" : "PM"}';
          }
          Widget timeTile(String label, TimeOfDay? time, bool isStart) =>
              GestureDetector(
                onTap: () async {
                  final picked = await showTimePicker(
                    context: ctx,
                    initialTime: time ?? TimeOfDay(hour: isStart ? 9 : 18, minute: 0),
                  );
                  if (picked != null) {
                    setS(() { if (isStart) startTime = picked; else endTime = picked; });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: _grey50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: time != null ? _red : const Color(0xFFE5E7EB)),
                  ),
                  child: Row(children: [
                    Icon(Icons.access_time, size: 15, color: time != null ? _red : _grey40),
                    const SizedBox(width: 6),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: const TextStyle(fontSize: 9, color: _grey40)),
                        Text(fmt(time), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: time != null ? _navy : _grey40)),
                      ],
                    )),
                  ]),
                ),
              );

          return _CompactDialogWidget(
            title: 'Edit Shift',
            icon: Icons.schedule,
            iconColor: const Color(0xFF7C3AED),
            iconBg: const Color(0xFFF5F3FF),
            body: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                style: const TextStyle(fontSize: 13),
                decoration: _fieldDecor('Shift Name *', 'e.g. Morning Shift', Icons.label_outline),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: timeTile('Start Time *', startTime, true)),
                const SizedBox(width: 8),
                Expanded(child: timeTile('End Time *', endTime, false)),
              ]),
              const SizedBox(height: 8),
              TextField(
                controller: graceCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 13),
                decoration: _fieldDecor('Grace Period (mins)', '15', Icons.timer_outlined),
              ),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Weekly Off Days', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _navy)),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: weekdayOptions.map((day) {
                  final isSelected = selectedOffs.contains(day);
                  return FilterChip(
                    label: Text(day, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : _navy)),
                    selected: isSelected,
                    selectedColor: _red,
                    backgroundColor: _grey50,
                    checkmarkColor: Colors.white,
                    onSelected: (val) {
                      setS(() {
                        if (val) {
                          selectedOffs.add(day);
                        } else {
                          selectedOffs.remove(day);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ]),
            onSave: () async {
              if (nameCtrl.text.trim().isEmpty || startTime == null || endTime == null) return false;
              String toDb(TimeOfDay t) => '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}:00';
              await ApiClient.put('${ApiEndpoints.hrmsShifts}/${s['id']}', {
                'name': nameCtrl.text.trim(),
                'start_time': toDb(startTime!),
                'end_time': toDb(endTime!),
                'grace_period_mins': int.tryParse(graceCtrl.text) ?? 15,
                'weekly_offs': selectedOffs,
                'is_active': s['is_active'] != false,
              });
              return true;
            },
          );
        },
      ),
    );
    if (ok == true) _loadAll();
  }

  Future<void> _editLeaveType(Map<String, dynamic> l) async {
    final nameCtrl  = TextEditingController(text: l['name']?.toString() ?? '');
    final quotaCtrl = TextEditingController(text: l['annual_quota']?.toString() ?? '14');
    bool isPaid = l['is_paid'] != false;
    
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => _CompactDialogWidget(
          title: 'Edit Leave Type',
          icon: Icons.event_available,
          iconColor: _amber,
          iconBg: const Color(0xFFFFFBEB),
          body: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(fontSize: 13),
              decoration: _fieldDecor('Leave Name *', 'e.g. Casual Leave', Icons.label_outline),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: quotaCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 13),
              decoration: _fieldDecor('Annual Quota (days)', '14', Icons.calendar_month_outlined),
            ),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Paid Leave', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
              Switch.adaptive(
                value: isPaid,
                activeColor: _green,
                onChanged: (v) => setS(() => isPaid = v),
              ),
            ]),
          ]),
          onSave: () async {
            if (nameCtrl.text.trim().isEmpty) return false;
            await ApiClient.put('${ApiEndpoints.hrmsLeaveTypes}/${l['id']}', {
              'name': nameCtrl.text.trim(),
              'annual_quota': int.tryParse(quotaCtrl.text) ?? 14,
              'is_paid': isPaid,
              'is_active': l['is_active'] != false,
            });
            return true;
          },
        ),
      ),
    );
    if (ok == true) _loadAll();
  }

  Future<void> _editSalaryComponent(Map<String, dynamic> c) async {
    final nameCtrl    = TextEditingController(text: c['name']?.toString() ?? '');
    final formulaCtrl = TextEditingController(text: c['formula']?.toString() ?? '');
    String nature    = c['nature']?.toString() ?? 'Earning';
    String type      = c['type']?.toString() ?? 'Fixed';
    bool   isTaxable = c['is_taxable'] != false;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => _CompactDialogWidget(
          title: 'Edit Salary Component',
          icon: Icons.account_balance_wallet_outlined,
          iconColor: _red,
          iconBg: const Color(0xFFFEF2F2),
          body: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              style: const TextStyle(fontSize: 13),
              decoration: _fieldDecor('Component Name *', 'e.g. House Rent Allowance', Icons.label_outline),
            ),
            const SizedBox(height: 10),
            _label('NATURE'),
            const SizedBox(height: 5),
            Row(children: [
              Expanded(child: _toggleChip('Earning',  nature == 'Earning',  _green, () => setS(() => nature = 'Earning'))),
              const SizedBox(width: 6),
              Expanded(child: _toggleChip('Deduction', nature == 'Deduction', _red, () => setS(() => nature = 'Deduction'))),
            ]),
            const SizedBox(height: 8),
            _label('TYPE'),
            const SizedBox(height: 5),
            Row(children: [
              Expanded(child: _toggleChip('Fixed', type == 'Fixed', _blue, () => setS(() => type = 'Fixed'))),
              const SizedBox(width: 5),
              Expanded(child: _toggleChip('Percentage', type == 'Percentage', const Color(0xFF7C3AED), () => setS(() => type = 'Percentage'))),
              const SizedBox(width: 5),
              Expanded(child: _toggleChip('Formula', type == 'Formula', _amber, () => setS(() => type = 'Formula'))),
            ]),
            if (type != 'Fixed') ...[
              const SizedBox(height: 8),
              TextField(
                controller: formulaCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: _fieldDecor(
                    type == 'Percentage' ? 'Percentage (%)' : 'Formula',
                    type == 'Percentage' ? 'e.g. 40' : 'e.g. Basic * 0.4',
                    Icons.functions).copyWith(
                  suffixIcon: type == 'Formula' ? const Tooltip(
                    message: "Supported variables:\n- BASE: Gross base salary (e.g. 50,000)\n- BASIC: Basic salary (defaults to 50% of Base, e.g. 25,000)\nExample formula: BASIC * 0.12 or BASE * 0.06",
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(Icons.info_outline, color: Colors.blue, size: 18),
                    ),
                  ) : null,
                ),
              ),
            ],
          ]),
          onSave: () async {
            if (nameCtrl.text.trim().isEmpty) return false;
            await ApiClient.put('${ApiEndpoints.hrmsSalaryComponents}/${c['id']}', {
              'name': nameCtrl.text.trim(),
              'nature': nature,
              'type': type,
              'formula': formulaCtrl.text.trim().isEmpty ? null : formulaCtrl.text.trim(),
              'is_taxable': isTaxable,
              'is_active': c['is_active'] != false,
            });
            return true;
          },
        ),
      ),
    );
    if (ok == true) _loadAll();
  }

  Future<void> _editPayStructure(Map<String, dynamic> p) async {
    final nameCtrl = TextEditingController(text: p['name']?.toString() ?? '');
    final descCtrl = TextEditingController(text: p['description']?.toString() ?? '');
    
    final pComps  = List<Map<String, dynamic>>.from(p['hr_salary_components'] ?? p['components'] ?? []);
    final Set<int> selectedIds = pComps.map((c) => (c['id'] as num).toInt()).toSet();

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => _CompactDialogWidget(
          title: 'Edit Pay Structure',
          icon: Icons.receipt_long_outlined,
          iconColor: const Color(0xFF0891B2),
          iconBg: const Color(0xFFECFEFF),
          body: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              style: const TextStyle(fontSize: 13),
              decoration: _fieldDecor('Structure Name *', 'e.g. Grade A', Icons.drive_file_rename_outline),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descCtrl,
              style: const TextStyle(fontSize: 13),
              decoration: _fieldDecor('Description', 'Optional notes', Icons.notes),
            ),
            if (_salaryComps.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(children: [
                _label('SELECT COMPONENTS'),
                const SizedBox(width: 6),
                if (selectedIds.isNotEmpty)
                  _badge('${selectedIds.length} selected', _red, Colors.white),
              ]),
              const SizedBox(height: 6),
              ..._salaryComps.map((c) {
                final id  = (c['id'] as num?)?.toInt() ?? 0;
                final sel = selectedIds.contains(id);
                final col = c['nature'] == 'Earning' ? _green : _red;
                return GestureDetector(
                  onTap: () => setS(() {
                    if (sel) selectedIds.remove(id);
                    else selectedIds.add(id);
                  }),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    decoration: BoxDecoration(
                      color: sel ? col.withAlpha(15) : Colors.white,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: sel ? col : const Color(0xFFE5E7EB), width: sel ? 1.5 : 1),
                    ),
                    child: Row(children: [
                      Container(
                        width: 16, height: 16,
                        decoration: BoxDecoration(
                          color: sel ? col : Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: sel ? col : const Color(0xFFD1D5DB)),
                        ),
                        child: sel ? const Icon(Icons.check, size: 10, color: Colors.white) : null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(c['name']?.toString() ?? '',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sel ? col : _navy))),
                      _badge(c['type']?.toString() ?? 'Fixed', const Color(0xFFEFF6FF), _blue),
                    ]),
                  ),
                );
              }),
            ],
          ]),
          onSave: () async {
            if (nameCtrl.text.trim().isEmpty) return false;
            await ApiClient.put('${ApiEndpoints.hrmsPayStructures}/${p['id']}', {
              'name': nameCtrl.text.trim(),
              'description': descCtrl.text.trim(),
              'componentIds': selectedIds.toList(),
              'is_active': p['is_active'] != false,
            });
            return true;
          },
        ),
      ),
    );
    if (ok == true) _loadAll();
  }

  // ─── BUILD ───────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text('HR Masters',
            style: TextStyle(
                color: _navy, fontWeight: FontWeight.bold, fontSize: 17)),
        iconTheme: const IconThemeData(color: _navy),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: _grey40),
            tooltip: 'Refresh all',
            onPressed: _loadAll,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _red))
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  color: _red,
                  onRefresh: _loadAll,
                  child: ListView(
                    padding: const EdgeInsets.only(top: 12, bottom: 32),
                    children: [
                      _buildDesignations(),
                      _buildShifts(),
                      _buildLeaveTypes(),
                      _buildSalaryComponents(),
                      _buildPayStructures(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cloud_off, size: 52, color: _grey40),
        const SizedBox(height: 14),
        Text(_error ?? 'Failed to load data',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _grey40, fontSize: 14)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _loadAll,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Retry'),
          style: ElevatedButton.styleFrom(
              backgroundColor: _red, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8))),
        ),
      ]),
    ),
  );

  // ─── SECTION CARD ────────────────────────────────────
  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required VoidCallback onAdd,
    required Widget body,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(11),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
          child: Row(children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                  color: iconBg, borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 10),
            Text(title,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold, color: _navy)),
            const Spacer(),
            _addBtn(onAdd),
          ]),
        ),
        const Divider(height: 1, color: Color(0xFFF0F0F0)),
        body,
      ]),
    );
  }

  Widget _addBtn(VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: _red, borderRadius: BorderRadius.circular(7)),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.add, size: 14, color: Colors.white),
        SizedBox(width: 4),
        Text('Add',
            style: TextStyle(
                fontSize: 12, color: Colors.white,
                fontWeight: FontWeight.w600)),
      ]),
    ),
  );

  Widget _emptyRow(String msg) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 22),
    child: Center(
        child: Text(msg,
            style: const TextStyle(color: _grey40, fontSize: 13))),
  );

  Widget _badge(String text, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(5)),
    child: Text(text,
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w700,
            color: fg, letterSpacing: 0.3)),
  );

  Widget _rowDivider() => const Divider(
      height: 1, color: Color(0xFFF3F4F6), indent: 16);

  InputDecoration _fieldDecor(
          String label, String hint, IconData icon) =>
      InputDecoration(
        labelText: label, hintText: hint,
        labelStyle: const TextStyle(fontSize: 13),
        hintStyle: const TextStyle(color: _grey40, fontSize: 12),
        prefixIcon: Icon(icon, size: 17, color: _grey40),
        filled: true, fillColor: _grey50,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _red, width: 1.5)),
      );

  // ═══ DESIGNATIONS ════════════════════════════════════
  Widget _buildDesignations() {
    return _sectionCard(
      title: 'Designations',
      icon: Icons.badge_outlined,
      iconColor: _blue,
      iconBg: const Color(0xFFEFF6FF),
      onAdd: _addDesignation,
      body: _designations.isEmpty
          ? _emptyRow('No designations yet. Tap Add →')
          : Column(children: _designations.asMap().entries
              .map((e) => Column(children: [
                    _desigTile(e.value),
                    if (e.key < _designations.length - 1) _rowDivider(),
                  ]))
              .toList()),
    );
  }

  Widget _desigTile(Map<String, dynamic> d) {
    final name   = d['name']?.toString() ?? '';
    final active = d['is_active'] != false;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
              color: _blue.withAlpha(15),
              borderRadius: BorderRadius.circular(9)),
          child: const Icon(Icons.work_outline, color: _blue, size: 17),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(name,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14, color: _navy)),
        ),
        _badge(active ? 'Active' : 'Inactive',
            active ? const Color(0xFFECFDF5) : _grey10,
            active ? _green : _grey40),
        const SizedBox(width: 12),
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 18, color: _blue),
          onPressed: () => _editDesignation(d),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 10),
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 18, color: _red),
          onPressed: () => _deleteMaster(ApiEndpoints.hrmsDesignations, d['id'] as int, 'Designation'),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ]),
    );
  }

  Future<void> _addDesignation() async {
    final ctrl = TextEditingController();
    final ok = await _showCompactDialog(
      title: 'Add Designation',
      icon: Icons.badge_outlined,
      iconColor: _blue,
      iconBg: const Color(0xFFEFF6FF),
      child: TextField(
        controller: ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        style: const TextStyle(fontSize: 13),
        decoration: _fieldDecor(
            'Designation Title *', 'e.g. Sales Manager',
            Icons.badge_outlined),
      ),
      onSave: () async {
        if (ctrl.text.trim().isEmpty) return false;
        await ApiClient.post(ApiEndpoints.hrmsDesignations,
            {'name': ctrl.text.trim()});
        return true;
      },
    );
    if (ok == true) _loadAll();
  }

  // ═══ SHIFTS ══════════════════════════════════════════
  Widget _buildShifts() {
    return _sectionCard(
      title: 'Shifts',
      icon: Icons.schedule,
      iconColor: const Color(0xFF7C3AED),
      iconBg: const Color(0xFFF5F3FF),
      onAdd: _addShift,
      body: _shifts.isEmpty
          ? _emptyRow('No shifts yet. Tap Add →')
          : Column(children: _shifts.asMap().entries
              .map((e) => Column(children: [
                    _shiftTile(e.value),
                    if (e.key < _shifts.length - 1) _rowDivider(),
                  ]))
              .toList()),
    );
  }

  Widget _shiftTile(Map<String, dynamic> s) {
    final name   = s['name']?.toString()             ?? '';
    final start  = _fmtTime(s['start_time']?.toString() ?? '');
    final end    = _fmtTime(s['end_time']?.toString()   ?? '');
    final grace  = s['grace_period_mins']?.toString() ?? '0';
    final active = s['is_active'] != false;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
              color: const Color(0xFFF5F3FF),
              borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.access_time,
              color: Color(0xFF7C3AED), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14, color: _navy)),
            const SizedBox(height: 2),
            Text('$start – $end  •  $grace min grace',
                style: const TextStyle(fontSize: 11, color: _grey40)),
          ],
        )),
        _badge(active ? 'Active' : 'Off',
            active ? const Color(0xFFECFDF5) : _grey10,
            active ? _green : _grey40),
        const SizedBox(width: 12),
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 18, color: _blue),
          onPressed: () => _editShift(s),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 10),
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 18, color: _red),
          onPressed: () => _deleteMaster(ApiEndpoints.hrmsShifts, s['id'] as int, 'Shift'),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ]),
    );
  }

  String _fmtTime(String t) {
    try {
      final parts = t.split(':');
      int h = int.parse(parts[0]);
      final m = parts[1];
      final period = h >= 12 ? 'PM' : 'AM';
      if (h == 0) h = 12;
      else if (h > 12) h -= 12;
      return '$h:$m $period';
    } catch (_) { return t; }
  }

  Future<void> _addShift() async {
    final nameCtrl  = TextEditingController();
    final graceCtrl = TextEditingController(text: '15');
    final selectedOffs = <String>['Sunday'];
    final weekdayOptions = [
      'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
      '1st Saturday', '2nd Saturday', '3rd Saturday', '4th Saturday', '5th Saturday',
    ];
    TimeOfDay? startTime;
    TimeOfDay? endTime;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          String fmt(TimeOfDay? t) {
            if (t == null) return 'Tap to pick';
            final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
            final m = t.minute.toString().padLeft(2, '0');
            return '$h:$m ${t.period == DayPeriod.am ? "AM" : "PM"}';
          }
          Widget timeTile(String label, TimeOfDay? time, bool isStart) =>
              GestureDetector(
                onTap: () async {
                  final picked = await showTimePicker(
                    context: ctx,
                    initialTime: time ?? TimeOfDay(
                        hour: isStart ? 9 : 18, minute: 0),
                  );
                  if (picked != null) {
                    setS(() { if (isStart) startTime = picked; else endTime = picked; });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: _grey50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: time != null
                            ? _red : const Color(0xFFE5E7EB)),
                  ),
                  child: Row(children: [
                    Icon(Icons.access_time, size: 15,
                        color: time != null ? _red : _grey40),
                    const SizedBox(width: 6),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                            style: const TextStyle(
                                fontSize: 9, color: _grey40)),
                        Text(fmt(time),
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: time != null ? _navy : _grey40)),
                      ],
                    )),
                  ]),
                ),
              );

          return _CompactDialogWidget(
            title: 'Add Shift',
            icon: Icons.schedule,
            iconColor: const Color(0xFF7C3AED),
            iconBg: const Color(0xFFF5F3FF),
            body: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                style: const TextStyle(fontSize: 13),
                decoration: _fieldDecor('Shift Name *',
                    'e.g. Morning Shift', Icons.label_outline),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: timeTile('Start Time *', startTime, true)),
                const SizedBox(width: 8),
                Expanded(child: timeTile('End Time *', endTime, false)),
              ]),
              const SizedBox(height: 8),
              TextField(
                controller: graceCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 13),
                decoration: _fieldDecor(
                    'Grace Period (mins)', '15', Icons.timer_outlined),
              ),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Weekly Off Days', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _navy)),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: weekdayOptions.map((day) {
                  final isSelected = selectedOffs.contains(day);
                  return FilterChip(
                    label: Text(day, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : _navy)),
                    selected: isSelected,
                    selectedColor: _red,
                    backgroundColor: _grey50,
                    checkmarkColor: Colors.white,
                    onSelected: (val) {
                      setS(() {
                        if (val) {
                          selectedOffs.add(day);
                        } else {
                          selectedOffs.remove(day);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ]),
            onSave: () async {
              if (nameCtrl.text.trim().isEmpty ||
                  startTime == null || endTime == null) return false;
              String toDb(TimeOfDay t) =>
                  '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}:00';
              await ApiClient.post(ApiEndpoints.hrmsShifts, {
                'name'             : nameCtrl.text.trim(),
                'start_time'       : toDb(startTime!),
                'end_time'         : toDb(endTime!),
                'grace_period_mins': int.tryParse(graceCtrl.text) ?? 15,
                'weekly_offs'      : selectedOffs,
              });
              return true;
            },
          );
        },
      ),
    );
    if (ok == true) _loadAll();
  }

  // ═══ LEAVE TYPES ═════════════════════════════════════
  Widget _buildLeaveTypes() {
    return _sectionCard(
      title: 'Leave Types',
      icon: Icons.event_available,
      iconColor: _amber,
      iconBg: const Color(0xFFFFFBEB),
      onAdd: _addLeaveType,
      body: _leaveTypes.isEmpty
          ? _emptyRow('No leave types yet. Tap Add →')
          : Column(children: _leaveTypes.asMap().entries
              .map((e) => Column(children: [
                    _leaveTile(e.value),
                    if (e.key < _leaveTypes.length - 1) _rowDivider(),
                  ]))
              .toList()),
    );
  }

  Widget _leaveTile(Map<String, dynamic> l) {
    final name   = l['name']?.toString() ?? '';
    final isPaid = l['is_paid'] != false;
    final quota  = l['annual_quota']?.toString() ?? '0';
    final active = l['is_active'] != false;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(9)),
          child: const Icon(Icons.event_available, color: _amber, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14, color: _navy)),
            const SizedBox(height: 2),
            Text('$quota days/year  •  ${isPaid ? "Paid" : "Unpaid"}',
                style: const TextStyle(fontSize: 11, color: _grey40)),
          ],
        )),
        _badge(active ? 'Active' : 'Off',
            active ? const Color(0xFFECFDF5) : _grey10,
            active ? _green : _grey40),
        const SizedBox(width: 12),
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 18, color: _blue),
          onPressed: () => _editLeaveType(l),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 10),
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 18, color: _red),
          onPressed: () => _deleteMaster(ApiEndpoints.hrmsLeaveTypes, l['id'] as int, 'Leave Type'),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ]),
    );
  }

  Future<void> _addLeaveType() async {
    final nameCtrl  = TextEditingController();
    final quotaCtrl = TextEditingController(text: '14');
    bool isPaid = true;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => _CompactDialogWidget(
          title: 'Add Leave Type',
          icon: Icons.event_available,
          iconColor: _amber,
          iconBg: const Color(0xFFFFFBEB),
          body: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(fontSize: 13),
              decoration: _fieldDecor('Leave Name *',
                  'e.g. Casual Leave', Icons.label_outline),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: quotaCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 13),
              decoration: _fieldDecor(
                  'Annual Quota (days)', '14',
                  Icons.calendar_month_outlined),
            ),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
              const Text('Paid Leave',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
              Switch.adaptive(
                value: isPaid,
                activeColor: _green,
                onChanged: (v) => setS(() => isPaid = v),
              ),
            ]),
          ]),
          onSave: () async {
            if (nameCtrl.text.trim().isEmpty) return false;
            await ApiClient.post(ApiEndpoints.hrmsLeaveTypes, {
              'name'        : nameCtrl.text.trim(),
              'annual_quota': int.tryParse(quotaCtrl.text) ?? 14,
              'is_paid'     : isPaid,
            });
            return true;
          },
        ),
      ),
    );
    if (ok == true) _loadAll();
  }

  // ═══ SALARY COMPONENTS ═══════════════════════════════
  Widget _buildSalaryComponents() {
    final earnings   = _salaryComps.where((c) => c['nature'] == 'Earning').toList();
    final deductions = _salaryComps.where((c) => c['nature'] == 'Deduction').toList();

    return _sectionCard(
      title: 'Salary Components',
      icon: Icons.account_balance_wallet_outlined,
      iconColor: _red,
      iconBg: const Color(0xFFFEF2F2),
      onAdd: _addSalaryComponent,
      body: _salaryComps.isEmpty
          ? _emptyRow('No salary components yet. Tap Add →')
          : Column(children: [
              if (earnings.isNotEmpty) ...[
                _compGroupHeader('EARNINGS', _green),
                ...earnings.asMap().entries.map((e) => Column(children: [
                      _compTile(e.value, _green),
                      if (e.key < earnings.length - 1) _rowDivider(),
                    ])),
              ],
              if (deductions.isNotEmpty) ...[
                _compGroupHeader('DEDUCTIONS', _red),
                ...deductions.asMap().entries.map((e) => Column(children: [
                      _compTile(e.value, _red),
                      if (e.key < deductions.length - 1) _rowDivider(),
                    ])),
              ],
            ]),
    );
  }

  Widget _compGroupHeader(String label, Color color) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(16, 7, 16, 6),
    color: color.withAlpha(14),
    child: Text(label,
        style: TextStyle(
            fontSize: 9, letterSpacing: 1.2,
            fontWeight: FontWeight.w700, color: color)),
  );

  Widget _compTile(Map<String, dynamic> c, Color color) {
    final name    = c['name']?.toString()    ?? '';
    final type    = c['type']?.toString()    ?? 'Fixed';
    final formula = c['formula']?.toString() ?? '';
    final taxable = c['is_taxable'] == true;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
      child: Row(children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13, color: _navy)),
            if (type != 'Fixed' && formula.isNotEmpty)
              Text(type == 'Percentage'
                  ? '$formula% of Basic' : formula,
                  style: const TextStyle(fontSize: 11, color: _grey40)),
          ],
        )),
        const SizedBox(width: 6),
        _badge(type,
            type == 'Fixed' ? const Color(0xFFEFF6FF) : color.withAlpha(20),
            type == 'Fixed' ? _blue : color),
        const SizedBox(width: 5),
        if (taxable)
          _badge('Taxable', const Color(0xFFFFFBEB), _amber),
        const SizedBox(width: 12),
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 18, color: _blue),
          onPressed: () => _editSalaryComponent(c),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 10),
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 18, color: _red),
          onPressed: () => _deleteMaster(ApiEndpoints.hrmsSalaryComponents, c['id'] as int, 'Salary Component'),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ]),
    );
  }

  Future<void> _addSalaryComponent() async {
    final nameCtrl    = TextEditingController();
    final formulaCtrl = TextEditingController();
    String nature    = 'Earning';
    String type      = 'Fixed';
    bool   isTaxable = true;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => _CompactDialogWidget(
          title: 'Add Salary Component',
          icon: Icons.account_balance_wallet_outlined,
          iconColor: _red,
          iconBg: const Color(0xFFFEF2F2),
          body: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              style: const TextStyle(fontSize: 13),
              decoration: _fieldDecor('Component Name *',
                  'e.g. House Rent Allowance', Icons.label_outline),
            ),
            const SizedBox(height: 10),
            _label('NATURE'),
            const SizedBox(height: 5),
            Row(children: [
              Expanded(child: _toggleChip('Earning',  nature == 'Earning',  _green,
                  () => setS(() => nature = 'Earning'))),
              const SizedBox(width: 6),
              Expanded(child: _toggleChip('Deduction', nature == 'Deduction', _red,
                  () => setS(() => nature = 'Deduction'))),
            ]),
            const SizedBox(height: 8),
            _label('TYPE'),
            const SizedBox(height: 5),
            Row(children: [
              Expanded(child: _toggleChip('Fixed', type == 'Fixed', _blue,
                  () => setS(() => type = 'Fixed'))),
              const SizedBox(width: 5),
              Expanded(child: _toggleChip('Percentage', type == 'Percentage',
                  const Color(0xFF7C3AED),
                  () => setS(() => type = 'Percentage'))),
              const SizedBox(width: 5),
              Expanded(child: _toggleChip('Formula', type == 'Formula', _amber,
                  () => setS(() => type = 'Formula'))),
            ]),
            if (type != 'Fixed') ...[
              const SizedBox(height: 8),
              TextField(
                controller: formulaCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: _fieldDecor(
                    type == 'Percentage' ? 'Percentage (%)' : 'Formula',
                    type == 'Percentage' ? 'e.g. 40' : 'e.g. Basic * 0.4',
                    Icons.functions).copyWith(
                  suffixIcon: type == 'Formula' ? const Tooltip(
                    message: "Supported variables:\n- BASE: Gross base salary (e.g. 50,000)\n- BASIC: Basic salary (defaults to 50% of Base, e.g. 25,000)\nExample formula: BASIC * 0.12 or BASE * 0.06",
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(Icons.info_outline, color: Colors.blue, size: 18),
                    ),
                  ) : null,
                ),
              ),
            ],
          ]),
          onSave: () async {
            if (nameCtrl.text.trim().isEmpty) return false;
            await ApiClient.post(ApiEndpoints.hrmsSalaryComponents, {
              'name'      : nameCtrl.text.trim(),
              'nature'    : nature,
              'type'      : type,
              'formula'   : formulaCtrl.text.trim().isEmpty
                  ? null : formulaCtrl.text.trim(),
              'is_taxable': isTaxable,
              'frequency' : 'Monthly',
            });
            return true;
          },
        ),
      ),
    );
    if (ok == true) _loadAll();
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          fontSize: 9, letterSpacing: 1.1,
          color: _grey40, fontWeight: FontWeight.w700));

  Widget _toggleChip(String label, bool active, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? color.withAlpha(20) : _grey10,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
                color: active ? color : Colors.transparent, width: 1.5),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: active ? color : _grey40)),
        ),
      );

  // ═══ PAY STRUCTURES ══════════════════════════════════
  Widget _buildPayStructures() {
    return _sectionCard(
      title: 'Pay Structures',
      icon: Icons.receipt_long_outlined,
      iconColor: const Color(0xFF0891B2),
      iconBg: const Color(0xFFECFEFF),
      onAdd: _addPayStructure,
      body: _payStructures.isEmpty
          ? _emptyRow('No pay structures yet. Tap Add →')
          : Column(children: _payStructures.asMap().entries
              .map((e) => Column(children: [
                    _psTile(e.value),
                    if (e.key < _payStructures.length - 1) _rowDivider(),
                  ]))
              .toList()),
    );
  }

  Widget _psTile(Map<String, dynamic> p) {
    final name   = p['name']?.toString()        ?? '';
    final desc   = p['description']?.toString() ?? '';
    final active = p['is_active'] != false;
    final comps  = (p['hr_salary_components'] as List?
        ?? p['components'] as List? ?? []);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
              color: const Color(0xFFECFEFF),
              borderRadius: BorderRadius.circular(9)),
          child: const Icon(Icons.receipt_long_outlined,
              color: Color(0xFF0891B2), size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14, color: _navy)),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(desc,
                  style: const TextStyle(fontSize: 11, color: _grey40)),
            ],
            if (comps.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text('${comps.length} component${comps.length > 1 ? "s" : ""}',
                  style: const TextStyle(fontSize: 11, color: _grey40)),
            ],
          ],
        )),
        _badge(active ? 'Active' : 'Off',
            active ? const Color(0xFFECFDF5) : _grey10,
            active ? _green : _grey40),
        const SizedBox(width: 12),
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 18, color: _blue),
          onPressed: () => _editPayStructure(p),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 10),
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 18, color: _red),
          onPressed: () => _deleteMaster(ApiEndpoints.hrmsPayStructures, p['id'] as int, 'Pay Structure'),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ]),
    );
  }

  Future<void> _addPayStructure() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final Set<int> selectedIds = {};

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => _CompactDialogWidget(
          title: 'Add Pay Structure',
          icon: Icons.receipt_long_outlined,
          iconColor: const Color(0xFF0891B2),
          iconBg: const Color(0xFFECFEFF),
          body: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              style: const TextStyle(fontSize: 13),
              decoration: _fieldDecor('Structure Name *',
                  'e.g. Grade A', Icons.drive_file_rename_outline),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descCtrl,
              style: const TextStyle(fontSize: 13),
              decoration: _fieldDecor(
                  'Description', 'Optional notes', Icons.notes),
            ),
            if (_salaryComps.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(children: [
                _label('SELECT COMPONENTS'),
                const SizedBox(width: 6),
                if (selectedIds.isNotEmpty)
                  _badge('${selectedIds.length} selected', _red, Colors.white),
              ]),
              const SizedBox(height: 6),
              ..._salaryComps.map((c) {
                final id  = (c['id'] as num?)?.toInt() ?? 0;
                final sel = selectedIds.contains(id);
                final col = c['nature'] == 'Earning' ? _green : _red;
                return GestureDetector(
                  onTap: () => setS(() {
                    if (sel) selectedIds.remove(id);
                    else selectedIds.add(id);
                  }),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 9),
                    decoration: BoxDecoration(
                      color: sel ? col.withAlpha(15) : Colors.white,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                          color: sel ? col : const Color(0xFFE5E7EB),
                          width: sel ? 1.5 : 1),
                    ),
                    child: Row(children: [
                      Container(
                        width: 16, height: 16,
                        decoration: BoxDecoration(
                          color: sel ? col : Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: sel ? col : const Color(0xFFD1D5DB)),
                        ),
                        child: sel
                            ? const Icon(Icons.check,
                                size: 10, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(c['name']?.toString() ?? '',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: sel ? col : _navy))),
                      _badge(c['type']?.toString() ?? 'Fixed',
                          const Color(0xFFEFF6FF), _blue),
                    ]),
                  ),
                );
              }),
            ],
          ]),
          onSave: () async {
            if (nameCtrl.text.trim().isEmpty) return false;
            await ApiClient.post(ApiEndpoints.hrmsPayStructures, {
              'name'        : nameCtrl.text.trim(),
              'description' : descCtrl.text.trim(),
              'componentIds': selectedIds.toList(),
            });
            return true;
          },
        ),
      ),
    );
    if (ok == true) _loadAll();
  }

  // ─── Generic compact dialog helper ───────────────────
  Future<bool?> _showCompactDialog({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required Widget child,
    required Future<bool> Function() onSave,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CompactDialogWidget(
        title: title,
        icon: icon,
        iconColor: iconColor,
        iconBg: iconBg,
        body: child,
        onSave: onSave,
      ),
    );
  }
}

// ─── Stateful compact dialog wrapper ─────────────────────
class _CompactDialogWidget extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final Widget body;
  final Future<bool> Function() onSave;

  const _CompactDialogWidget({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.body,
    required this.onSave,
  });

  @override
  State<_CompactDialogWidget> createState() =>
      _CompactDialogWidgetState();
}

class _CompactDialogWidgetState extends State<_CompactDialogWidget> {
  bool _saving = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 14, 0),
              child: Row(children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                      color: widget.iconBg,
                      borderRadius: BorderRadius.circular(9)),
                  child: Icon(widget.icon,
                      color: widget.iconColor, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(widget.title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E)))),
                GestureDetector(
                  onTap: () => Navigator.pop(context, false),
                  child: const Icon(Icons.close,
                      size: 18, color: Color(0xFF9CA3AF)),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            if (_error != null)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline,
                      color: Color(0xFFDC2626), size: 14),
                  const SizedBox(width: 6),
                  Expanded(child: Text(_error!,
                      style: const TextStyle(
                          color: Color(0xFFDC2626), fontSize: 11))),
                ]),
              ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: widget.body,
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving
                        ? null : () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8)),
                    child: const Text('Cancel',
                        style: TextStyle(
                            color: Color(0xFF6B7280), fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saving ? null : () async {
                      setState(() { _saving = true; _error = null; });
                      try {
                        final ok = await widget.onSave();
                        if (ok && mounted) {
                          Navigator.pop(context, true);
                        } else {
                          setState(() {
                            _error = 'Please fill all required fields.';
                            _saving = false;
                          });
                        }
                      } catch (e) {
                        setState(() {
                          _error = e.toString()
                              .replaceAll('Exception: ', '');
                          _saving = false;
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE03E2D),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      elevation: 0,
                    ),
                    child: _saving
                        ? const SizedBox(width: 14, height: 14,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('Save',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
