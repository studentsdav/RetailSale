import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/auth/token_storage.dart';

class EmployeeScreen extends StatefulWidget {
  const EmployeeScreen({Key? key}) : super(key: key);

  @override
  State<EmployeeScreen> createState() => _EmployeeScreenState();
}

class _EmployeeScreenState extends State<EmployeeScreen> {
  bool _isLoading = false;
  String _searchQuery = '';
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _designations = [];
  List<Map<String, dynamic>> _shifts = [];
  List<Map<String, dynamic>> _payStructures = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        ApiClient.get(ApiEndpoints.hrmsEmployees),
        ApiClient.get(ApiEndpoints.hrmsDesignations),
        ApiClient.get(ApiEndpoints.hrmsShifts),
        ApiClient.get(ApiEndpoints.hrmsPayStructures),
      ]);
      setState(() {
        _employees = List<Map<String, dynamic>>.from(results[0]['data'] ?? []);
        _designations = List<Map<String, dynamic>>.from(results[1]['data'] ?? []);
        _shifts = List<Map<String, dynamic>>.from(results[2]['data'] ?? []);
        _payStructures = List<Map<String, dynamic>>.from(results[3]['data'] ?? []);
      });
    } catch (e) {
      // show empty list on error
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _employees.where((e) {
      final name = (e['full_name'] ?? '').toString().toLowerCase();
      final code = (e['employee_code'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();
      return name.contains(q) || code.contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Employees',
            style: TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Color(0xFF1A1A2E)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: () => _showAddEmployeeSheet(context),
              icon: const Icon(Icons.add, color: Colors.white, size: 16),
              label: const Text('Add Employee',
                  style: TextStyle(color: Colors.white, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE03E2D),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by name or code…',
                hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF9CA3AF)),
                filled: true,
                fillColor: const Color(0xFFF3F4F6),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
            child: Text(
              'ACTIVE EMPLOYEES (${filtered.length})',
              style: const TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.2,
                  color: Color(0xFF9CA3AF),
                  fontWeight: FontWeight.w600),
            ),
          ),
          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFE03E2D)))
                : filtered.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        onRefresh: _loadAll,
                        color: const Color(0xFFE03E2D),
                        child: ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (_, i) => _buildEmployeeCard(filtered[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          const Text('No employees yet',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 16)),
          const SizedBox(height: 6),
          const Text('Tap "+ Add Employee" to get started',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildEmployeeCard(Map<String, dynamic> emp) {
    final name = emp['full_name'] ?? '';
    final code = emp['employee_code'] ?? '';
    
    String designation = '';
    if (emp['designation'] != null) {
      if (emp['designation'] is Map) {
        designation = (emp['designation']['name'] ?? '').toString();
      } else {
        designation = emp['designation'].toString();
      }
    } else if (emp['designation_id'] != null) {
      final destId = emp['designation_id'];
      final found = _designations.firstWhere((d) => d['id'].toString() == destId.toString(), orElse: () => {});
      if (found.isNotEmpty) {
        designation = (found['name'] ?? '').toString();
      }
    }

    final status = emp['status'] ?? 'Active';
    
    String shiftStr = '';
    if (emp['shift'] != null) {
      if (emp['shift'] is Map) {
        shiftStr = (emp['shift']['name'] ?? '').toString();
      } else {
        shiftStr = emp['shift'].toString();
      }
    } else if (emp['shift_id'] != null) {
      final shId = emp['shift_id'];
      final found = _shifts.firstWhere((s) => s['id'].toString() == shId.toString(), orElse: () => {});
      if (found.isNotEmpty) {
        shiftStr = (found['name'] ?? '').toString();
      }
    }

    final approver1 = emp['level1_approver_id'];
    final approver2 = emp['level2_approver_id'];

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _EmployeeDetailScreen(
            employee: emp,
            employees: _employees,
            designations: _designations,
            shifts: _shifts,
            payStructures: _payStructures,
            onRefresh: _loadAll,
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildAvatar(name, size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A2E))),
                    const SizedBox(height: 2),
                    Text(code,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF9CA3AF))),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (designation.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(4)),
                            child: Text(designation,
                                style: const TextStyle(
                                    color: Color(0xFF2563EB),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (shiftStr.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                                color: const Color(0xFFE6F4F1),
                                borderRadius: BorderRadius.circular(4)),
                            child: Text(shiftStr,
                                style: const TextStyle(
                                    color: Color(0xFF0D9488),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (approver1 != null)
                          _buildLevelBadge('Level 1'),
                        if (approver2 != null) ...[
                          const SizedBox(width: 4),
                          _buildLevelBadge('Level 2'),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildStatusChip(status),
                  if (emp['commission_percent'] != null &&
                      double.tryParse(emp['commission_percent'].toString())! > 0) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(4)),
                      child: Text(
                          '${emp['commission_percent']}% Comm',
                          style: const TextStyle(
                              color: Color(0xFFD97706),
                              fontSize: 10,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLevelBadge(String label) {
    return Text(label,
        style: const TextStyle(
            color: Color(0xFFE03E2D), fontWeight: FontWeight.bold, fontSize: 12));
  }

  // ─────────── ADD EMPLOYEE BOTTOM SHEET ───────────
  void _showAddEmployeeSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddEmployeeForm(
        employees: _employees,
        onSaved: _loadAll,
      ),
    );
  }

  // ─────────── HELPERS ───────────
  Widget _buildAvatar(String name, {double size = 38}) {
    const colors = [
      Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFEC4899),
      Color(0xFFEF4444), Color(0xFFF97316), Color(0xFF10B981),
      Color(0xFF3B82F6), Color(0xFF14B8A6),
    ];
    final color = colors[name.isNotEmpty ? name.codeUnitAt(0) % colors.length : 0];
    final initials = name.trim().split(' ').take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: color,
      child: Text(initials,
          style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.36,
              fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bg, fg;
    switch (status.toLowerCase()) {
      case 'active':
        bg = const Color(0xFFECFDF5); fg = const Color(0xFF059669); break;
      case 'terminated':
        bg = const Color(0xFFFEF2F2); fg = const Color(0xFFDC2626); break;
      case 'inactive':
        bg = const Color(0xFFF3F4F6); fg = const Color(0xFF6B7280); break;
      default:
        bg = const Color(0xFFF3F4F6); fg = const Color(0xFF6B7280);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(status,
          style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  ADD EMPLOYEE FORM (Full Plan Fields)
// ═══════════════════════════════════════════════════════
class _AddEmployeeForm extends StatefulWidget {
  final List<Map<String, dynamic>> employees;
  final VoidCallback onSaved;
  final Map<String, dynamic>? employee;

  const _AddEmployeeForm({
    required this.employees,
    required this.onSaved,
    this.employee,
  });

  @override
  State<_AddEmployeeForm> createState() => _AddEmployeeFormState();
}

class _AddEmployeeFormState extends State<_AddEmployeeForm> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _loadingMasters = true;
  int _currentStep = 0;

  // Master data (self-loaded so inline add works)
  List<Map<String, dynamic>> _designations = [];
  List<Map<String, dynamic>> _shifts = [];
  List<Map<String, dynamic>> _payStructures = [];
  List<Map<String, dynamic>> _users = [];

  // Sentinel int for the "+ Add New" item in dropdowns
  static const int _kAddNew = -1;

  // Section 1: Personal Info
  final _nameCtrl = TextEditingController();
  final _fatherNameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  String? _gender;
  DateTime? _dob;
  String? _bloodGroup;

  // Section 2: Work Info
  DateTime? _hireDate;
  int? _designationId;
  int? _shiftId;
  bool _requiresAttendance = true;
  bool _payIfUnmarked = false;
  int? _approver1Id;
  int? _approver2Id;
  int? _userId;

  // Section 3: Salary & Pay
  final _baseSalaryCtrl = TextEditingController();
  final _commissionCtrl = TextEditingController(text: '0.00');
  String? _commissionTargetType = 'None';
  final _commissionTargetAmountCtrl = TextEditingController(text: '0.00');
  int? _payStructureId;
  DateTime? _payrollStartDate;

  // Section 4: Bank & Statutory Details
  final _bankNameCtrl = TextEditingController();
  final _bankAccountCtrl = TextEditingController();
  final _bankIfscCtrl = TextEditingController();
  final _panCtrl = TextEditingController();
  final _esiCtrl = TextEditingController();
  final _pfCtrl = TextEditingController();

  List<Map<String, dynamic>> _leaveTypes = [];
  Map<int, TextEditingController> _leaveQuotaControllers = {};

  @override
  void initState() {
    super.initState();
    _baseSalaryCtrl.addListener(() {
      if (mounted) setState(() {});
    });
    _commissionCtrl.addListener(() {
      if (mounted) setState(() {});
    });
    _loadMasters();
    
    if (widget.employee != null) {
      final emp = widget.employee!;
      _nameCtrl.text = (emp['full_name'] ?? '').toString();
      _fatherNameCtrl.text = (emp['father_name'] ?? '').toString();
      _codeCtrl.text = (emp['employee_code'] ?? '').toString();
      _emailCtrl.text = (emp['contact_email'] ?? '').toString();
      _mobileCtrl.text = (emp['mobile'] ?? '').toString();
      _gender = emp['gender']?.toString();
      _dob = emp['date_of_birth'] != null ? DateTime.tryParse(emp['date_of_birth'].toString()) : null;
      _bloodGroup = emp['blood_group']?.toString();
      
      _hireDate = emp['hire_date'] != null ? DateTime.tryParse(emp['hire_date'].toString()) : null;
      _designationId = emp['designation_id'] as int?;
      _shiftId = emp['shift_id'] as int?;
      _requiresAttendance = emp['requires_attendance'] == true;
      _payIfUnmarked = emp['pay_if_unmarked'] == true;
      _approver1Id = emp['level1_approver_id'] as int?;
      _approver2Id = emp['level2_approver_id'] as int?;
      _userId = emp['user_id'] as int?;
      
      _baseSalaryCtrl.text = (emp['base_salary'] ?? '0.00').toString();
      _commissionCtrl.text = (emp['commission_percent'] ?? '0.00').toString();
      _commissionTargetType = emp['commission_target_type']?.toString() ?? 'None';
      _commissionTargetAmountCtrl.text = (emp['commission_target_amount'] ?? '0.00').toString();
      _payStructureId = emp['pay_structure_id'] as int?;
      _payrollStartDate = emp['payroll_start_date'] != null ? DateTime.tryParse(emp['payroll_start_date'].toString()) : null;
      
      _bankNameCtrl.text = (emp['bank_name'] ?? '').toString();
      _bankAccountCtrl.text = (emp['bank_account_no'] ?? '').toString();
      _bankIfscCtrl.text = (emp['bank_ifsc'] ?? '').toString();
      
      final Map<String, dynamic> kyc = emp['kyc_documents'] is Map
          ? Map<String, dynamic>.from(emp['kyc_documents'])
          : {};
      _panCtrl.text = (kyc['pan'] ?? '').toString();
      _esiCtrl.text = (kyc['esi'] ?? '').toString();
      _pfCtrl.text = (kyc['pf_uan'] ?? '').toString();

      if (emp['leaveBalances'] != null) {
        final balances = List<Map<String, dynamic>>.from(emp['leaveBalances']);
        for (final b in balances) {
          final ltId = b['leave_type_id'] as int?;
          if (ltId != null) {
            _leaveQuotaControllers[ltId] = TextEditingController(text: (b['allocated_quota'] ?? '0').toString());
          }
        }
      }
    } else {
      _loadNextEmployeeCode();
    }
  }

  Future<void> _loadNextEmployeeCode() async {
    try {
      final res = await ApiClient.get('/api/hrms/employees/next-code');
      if (res['success'] == true && res['code'] != null) {
        setState(() {
          _codeCtrl.text = res['code'].toString();
        });
      }
    } catch (_) {}
  }

  Future<void> _loadMasters() async {
    setState(() => _loadingMasters = true);
    try {
      final results = await Future.wait([
        ApiClient.get(ApiEndpoints.hrmsDesignations),
        ApiClient.get(ApiEndpoints.hrmsShifts),
        ApiClient.get(ApiEndpoints.hrmsPayStructures),
        ApiClient.get(ApiEndpoints.users),
        ApiClient.get(ApiEndpoints.hrmsLeaveTypes),
        ApiClient.get(ApiEndpoints.hrmsSalaryComponents),
      ]);

      final allComponents = List<Map<String, dynamic>>.from(results[5]['data'] ?? []);
      if (allComponents.isEmpty && widget.employee == null) {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                  SizedBox(width: 8),
                  Text('Setup Components First'),
                ],
              ),
              content: const Text('You must first add salary components in master (HR Masters → Salary Components) before adding an employee.'),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE03E2D)),
                  onPressed: () {
                    Navigator.pop(ctx); // pop alert dialog
                    Navigator.pop(context); // pop modal bottom sheet
                  },
                  child: const Text('OK', style: TextStyle(color: Colors.white)),
                )
              ],
            ),
          );
        }
        return;
      }

      setState(() {
        _designations = List<Map<String, dynamic>>.from(results[0]['data'] ?? []);
        _shifts       = List<Map<String, dynamic>>.from(results[1]['data'] ?? []);
        _payStructures= List<Map<String, dynamic>>.from(results[2]['data'] ?? []);
        _users        = List<Map<String, dynamic>>.from(results[3]['data'] ?? []);
        _leaveTypes   = List<Map<String, dynamic>>.from(results[4]['data'] ?? []);

        for (final lt in _leaveTypes) {
          final ltId = lt['id'] as int;
          if (!_leaveQuotaControllers.containsKey(ltId)) {
            _leaveQuotaControllers[ltId] = TextEditingController(
              text: (lt['annual_quota'] ?? '14').toString(),
            );
          }
        }
      });
    } catch (_) {}
    finally { if (mounted) setState(() => _loadingMasters = false); }
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return 'Select Date';
    return '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
  }

  Future<void> _pickDate({required bool isDob}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isDob ? DateTime(1990) : DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFFE03E2D))),
        child: child!,
      ),
    );
    if (picked != null) setState(() => isDob ? _dob = picked : _hireDate = picked);
  }

  // ── Quick-add dialogs ──────────────────────────────────

  Future<void> _quickAddDesignation() async {
    final ctrl = TextEditingController();
    final created = await showDialog<Map<String,dynamic>>(
      context: context,
      builder: (ctx) => _QuickAddDialog(
        title: 'New Designation',
        icon: Icons.work_outline,
        iconColor: const Color(0xFF6B7280),
        fields: [_QField(ctrl: ctrl, label: 'Designation Title *',
            hint: 'e.g. Store Manager', icon: Icons.badge_outlined)],
        onSave: () async {
          if (ctrl.text.trim().isEmpty) return null;
          final res = await ApiClient.post(ApiEndpoints.hrmsDesignations,
              {'name': ctrl.text.trim()});
          return res['data'] as Map<String,dynamic>?;
        },
      ),
    );
    if (created != null) {
      setState(() {
        _designations.add(created);
        _designationId = created['id'] as int?;
      });
    }
  }

  Future<void> _quickAddShift() async {
    final created = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _ShiftQuickAddDialog(),
    );
    if (created != null) {
      setState(() {
        _shifts.add(created);
        _shiftId = (created['id'] as num?)?.toInt();
      });
    }
  }

  Future<void> _quickAddPayStructure() async {
    final created = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _PayStructureQuickAddDialog(),
    );
    if (created != null) {
      setState(() {
        _payStructures.add(created);
        _payStructureId = (created['id'] as num?)?.toInt();
      });
    }
  }


  // ── Save employee ──────────────────────────────────────

  bool _validateStep(int step) {
    if (step == _currentStep) {
      if (!_formKey.currentState!.validate()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Required fields are missing! Please fill all required fields.'))
        );
        return false;
      }
    }
    if (step == 0) {
      if (_nameCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Full Name is required! Please enter the employee\'s name.'))
        );
        return false;
      }
      if (_fatherNameCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Father\'s Name is required! Please enter the father\'s name.'))
        );
        return false;
      }
    } else if (step == 1) {
      if (_hireDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hire Date is required! Please select a hire date.'))
        );
        return false;
      }
      if (_designationId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Designation is required! Please select a designation.'))
        );
        return false;
      }
      if (_shiftId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shift is required! Please select a shift.'))
        );
        return false;
      }
    } else if (step == 2) {
      final baseSalary = double.tryParse(_baseSalaryCtrl.text.trim()) ?? 0.0;
      if (baseSalary <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Base Salary must be greater than zero! Please enter a valid base salary.'))
        );
        return false;
      }
      if (_payStructureId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pay Grade (Pay Structure) is required! Please select a grade.'))
        );
        return false;
      }
    }
    return true;
  }

  void _navigateToStep(int targetStep) {
    if (targetStep > _currentStep) {
      for (int step = _currentStep; step < targetStep; step++) {
        if (!_validateStep(step)) {
          setState(() {
            _currentStep = step;
          });
          return;
        }
      }
    }
    setState(() {
      _currentStep = targetStep;
    });
  }

  Future<void> _save() async {
    for (int step = 0; step < 4; step++) {
      if (!_validateStep(step)) {
        setState(() {
          _currentStep = step;
        });
        return;
      }
    }
    setState(() => _isSaving = true);
    try {
      final isEdit = widget.employee != null;
      final payload = {
        'full_name'          : _nameCtrl.text.trim(),
        'father_name'        : _fatherNameCtrl.text.trim(),
        'employee_code'      : _codeCtrl.text.trim(),
        'contact_email'      : _emailCtrl.text.trim(),
        'mobile'             : _mobileCtrl.text.trim(),
        'gender'             : _gender,
        'date_of_birth'      : _dob?.toIso8601String().split('T')[0],
        'blood_group'        : _bloodGroup,
        'hire_date'          : _hireDate!.toIso8601String().split('T')[0],
        'designation_id'     : _designationId,
        'shift_id'           : _shiftId,
        'requires_attendance': _requiresAttendance,
        'pay_if_unmarked': _payIfUnmarked,
        'level1_approver_id' : _approver1Id,
        'level2_approver_id' : _approver2Id,
        'user_id'            : _userId,
        'base_salary'        : double.tryParse(_baseSalaryCtrl.text) ?? 0,
        'commission_percent' : double.tryParse(_commissionCtrl.text) ?? 0,
        'commission_target_type': _commissionTargetType,
        'commission_target_amount': double.tryParse(_commissionTargetAmountCtrl.text) ?? 0,
        'pay_structure_id'   : _payStructureId,
        'payroll_start_date' : _payrollStartDate?.toIso8601String().split('T')[0],
        'bank_name'          : _bankNameCtrl.text.trim(),
        'bank_account_no'    : _bankAccountCtrl.text.trim(),
        'bank_ifsc'          : _bankIfscCtrl.text.trim(),
        'kyc_documents'      : {
          'pan': _panCtrl.text.trim().toUpperCase(),
          'esi': _esiCtrl.text.trim(),
          'pf_uan': _pfCtrl.text.trim(),
        },
        'leave_quotas': _leaveQuotaControllers.map((key, controller) {
          return MapEntry(key.toString(), double.tryParse(controller.text) ?? 0.0);
        }),
      };

      if (isEdit) {
        await ApiClient.put('${ApiEndpoints.hrmsEmployees}/${widget.employee!['id']}', payload);
      } else {
        payload['status'] = 'Active';
        await ApiClient.post(ApiEndpoints.hrmsEmployees, payload);
      }

      widget.onSaved();
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('"${_nameCtrl.text.trim()}" ${isEdit ? "updated" : "added"} successfully'),
        backgroundColor: const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.93,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      builder: (_, scrollCtrl) => Form(
        key: _formKey,
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('New Employee',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E))),
                  IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
                      onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            // Step indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: List.generate(5, (i) {
                  final labels = ['Personal', 'Work', 'Salary', 'Bank', 'Leaves'];
                  final isActive = i == _currentStep;
                  final isDone = i < _currentStep;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => _navigateToStep(i),
                      child: Column(
                        children: [
                          Container(
                            height: 3,
                            margin: EdgeInsets.only(right: i < 4 ? 4 : 0),
                            decoration: BoxDecoration(
                              color: isDone || isActive
                                  ? const Color(0xFFE03E2D)
                                  : const Color(0xFFE5E7EB),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(labels[i],
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isActive
                                    ? const Color(0xFFE03E2D)
                                    : const Color(0xFF9CA3AF),
                              )),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
            const Divider(height: 1),
            // Content
            Expanded(
              child: SingleChildScrollView(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(20),
                child: _buildStep(_currentStep),
              ),
            ),
            // Navigation buttons
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade100)),
              ),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _currentStep--),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Back',
                            style: TextStyle(color: Color(0xFF6B7280))),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSaving
                          ? null
                          : () {
                              if (_currentStep < 4) {
                                _navigateToStep(_currentStep + 1);
                              } else {
                                _save();
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE03E2D),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text(
                              _currentStep < 4 ? 'Next →' : 'Save Employee',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(int step) {
    switch (step) {
      case 0: return _buildPersonalStep();
      case 1: return _buildWorkStep();
      case 2: return _buildSalaryStep();
      case 3: return _buildBankStep();
      case 4: return _buildLeavesStep();
      default: return const SizedBox();
    }
  }

  Widget _buildLeavesStep() {
    if (_loadingMasters) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFE03E2D)));
    }
    if (_leaveTypes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Text(
            'No active leave types found in master. Please configure leave types in master settings first.',
            style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Leave Quotas Allocation',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E3A5F)),
        ),
        const SizedBox(height: 4),
        const Text(
          'Assign the annual leave days allowed for this employee for each leave type.',
          style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 16),
        ..._leaveTypes.map((lt) {
          final ltId = lt['id'] as int;
          final ltName = lt['name'] ?? 'Leave';
          final isPaid = lt['is_paid'] != false;
          final controller = _leaveQuotaControllers[ltId];

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ltName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF374151)),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isPaid ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isPaid ? 'Paid' : 'Unpaid',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isPaid ? const Color(0xFF059669) : const Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 100,
                  child: TextFormField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                      hintText: 'e.g. 14',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (double.tryParse(v.trim()) == null) return 'Invalid';
                      return null;
                    },
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildPersonalStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Personal Information'),
        _field(_nameCtrl, 'Full Name *', Icons.person_outline, required: true),
        _field(_fatherNameCtrl, 'Father\'s Name *', Icons.supervisor_account, required: true),
        _field(_codeCtrl, 'Employee Code (Blank for Auto-Gen)', Icons.badge_outlined, required: false),
        _field(_emailCtrl, 'Email Address', Icons.email_outlined,
            keyboardType: TextInputType.emailAddress),
        _field(_mobileCtrl, 'Mobile Number', Icons.phone_outlined,
            keyboardType: TextInputType.phone),
        const SizedBox(height: 4),
        _dropdownField<String>(
          label: 'Gender',
          icon: Icons.wc,
          value: _gender,
          items: ['Male', 'Female', 'Other']
              .map((g) => DropdownMenuItem(value: g, child: Text(g)))
              .toList(),
          onChanged: (v) => setState(() => _gender = v),
        ),
        const SizedBox(height: 12),
        _dateTile(
          label: 'Date of Birth',
          value: _fmtDate(_dob),
          icon: Icons.cake_outlined,
          onTap: () => _pickDate(isDob: true),
        ),
        const SizedBox(height: 12),
        _dropdownField<String>(
          label: 'Blood Group',
          icon: Icons.bloodtype_outlined,
          value: _bloodGroup,
          items: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
              .map((g) => DropdownMenuItem(value: g, child: Text(g)))
              .toList(),
          onChanged: (v) => setState(() => _bloodGroup = v),
        ),
      ],
    );
  }

  Widget _buildWorkStep() {
    if (_loadingMasters) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator(color: Color(0xFFE03E2D))),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Work Details'),
        _dateTile(
          label: 'Hire Date *',
          value: _fmtDate(_hireDate),
          icon: Icons.calendar_today_outlined,
          onTap: () => _pickDate(isDob: false),
        ),
        const SizedBox(height: 12),
        // ── Designation with inline Add New ──
        _smartDropdown<int>(
          label: 'Designation',
          icon: Icons.work_outline,
          value: _designationId,
          items: _designations,
          labelKey: 'name',
          emptyHint: 'No designations — tap to add',
          addLabel: '+ Add New Designation',
          onAddNew: _quickAddDesignation,
          onChanged: (v) => setState(() => _designationId = v),
        ),
        const SizedBox(height: 12),
        // ── Shift with inline Add New ──
        _smartDropdown<int>(
          label: 'Shift',
          icon: Icons.schedule,
          value: _shiftId,
          items: _shifts,
          labelKey: 'name',
          emptyHint: 'No shifts — tap to add',
          addLabel: '+ Add New Shift',
          onAddNew: _quickAddShift,
          onChanged: (v) => setState(() => _shiftId = v),
        ),
        const SizedBox(height: 12),
        // ── Approvers (from existing employees list — no add needed) ──
        _dropdownField<int>(
          label: 'Level 1 Approver (Leave)',
          icon: Icons.verified_user_outlined,
          value: _approver1Id,
          items: [
            const DropdownMenuItem<int>(value: null, child: Text('None', style: TextStyle(color: Color(0xFF9CA3AF)))),
            ...widget.employees.map((e) => DropdownMenuItem<int>(
                value: e['id'] as int?,
                child: Text('${e['full_name']} (${e['employee_code']})'))),
          ],
          onChanged: (v) => setState(() => _approver1Id = v),
        ),

        const SizedBox(height: 12),
        _dropdownField<int>(
          label: 'Level 2 Approver (Escalation)',
          icon: Icons.admin_panel_settings_outlined,
          value: _approver2Id,
          items: [
            const DropdownMenuItem<int>(value: null, child: Text('None', style: TextStyle(color: Color(0xFF9CA3AF)))),
            ...widget.employees.map((e) => DropdownMenuItem<int>(
                value: e['id'] as int?,
                child: Text('${e['full_name']} (${e['employee_code']})'))),
          ],
          onChanged: (v) => setState(() => _approver2Id = v),
        ),

        const SizedBox(height: 12),
        _dropdownField<int>(
          label: 'Linked System User (for Login Attendance & POS)',
          icon: Icons.person_pin_outlined,
          value: _userId,
          items: [
            const DropdownMenuItem<int>(value: null, child: Text('None (No Software Access)', style: TextStyle(color: Color(0xFF9CA3AF)))),
            ..._users.map((u) => DropdownMenuItem<int>(
                value: u['id'] as int?,
                child: Text('${u['full_name']} (@${u['username']})'))),
          ],
          onChanged: (v) => setState(() => _userId = v),
        ),

        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Requires Attendance', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text('Track daily punch-in/out', style: TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                ],
              ),
              Switch(
                value: _requiresAttendance,
                activeColor: const Color(0xFFE03E2D),
                onChanged: (v) => setState(() => _requiresAttendance = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pay Full if Attendance Unmarked',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      _payIfUnmarked
                          ? 'Days with no punch will be counted as Present (special policy)'
                          : 'Days with no punch counted as Absent — pay only for marked days',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Switch(
                value: _payIfUnmarked,
                activeColor: Colors.amber.shade700,
                onChanged: (v) => setState(() => _payIfUnmarked = v),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSalaryStep() {
    if (_loadingMasters) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator(color: Color(0xFFE03E2D))),
      );
    }

    final baseSalary = double.tryParse(_baseSalaryCtrl.text.trim()) ?? 0.0;
    
    Map<String, dynamic>? selectedStructure;
    if (_payStructureId != null) {
      selectedStructure = _payStructures.firstWhere(
        (p) => p['id'] == _payStructureId,
        orElse: () => {},
      );
    }
    
    final breakdown = (baseSalary > 0 && selectedStructure != null && selectedStructure.isNotEmpty)
        ? _calculateSalaryBreakdown(baseSalary, selectedStructure)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Salary & Compensation'),
        _field(_baseSalaryCtrl, 'Base Salary (₹) *', Icons.currency_rupee,
            keyboardType: TextInputType.number, required: true),
        _field(_commissionCtrl, 'Commission % (0 if not sales rep)',
            Icons.percent_outlined, keyboardType: TextInputType.number),
        if ((double.tryParse(_commissionCtrl.text) ?? 0.0) > 0) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _commissionTargetType,
            decoration: const InputDecoration(
              labelText: 'Commission Target / Limit Type',
              prefixIcon: Icon(Icons.track_changes_outlined),
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'None', child: Text('None (Commission on full sales)')),
              DropdownMenuItem(value: 'Daily', child: Text('Daily Target (Commission on sales above Daily Target)')),
              DropdownMenuItem(value: 'Monthly', child: Text('Monthly Target (Commission on sales above Monthly Target)')),
            ],
            onChanged: (val) {
              setState(() {
                _commissionTargetType = val;
              });
            },
          ),
          if (_commissionTargetType != null && _commissionTargetType != 'None') ...[
            const SizedBox(height: 12),
            _field(
              _commissionTargetAmountCtrl,
              'Commission Target Amount (₹)',
              Icons.currency_rupee_outlined,
              keyboardType: TextInputType.number,
            ),
          ],
        ],
        const SizedBox(height: 12),
        // ── Pay Structure with inline Add New ──
        _smartDropdown<int>(
          label: 'Pay Structure / Scale',
          icon: Icons.account_balance_wallet_outlined,
          value: _payStructureId,
          items: _payStructures,
          labelKey: 'name',
          emptyHint: 'No pay structures — tap to add',
          addLabel: '+ Add New Pay Structure',
          onAddNew: _quickAddPayStructure,
          onChanged: (v) => setState(() => _payStructureId = v),
        ),
        const SizedBox(height: 12),
        _dateTile(
          label: 'Payroll Start Date (EPD)',
          value: _fmtDate(_payrollStartDate),
          icon: Icons.calendar_month_outlined,
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _payrollStartDate ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2035),
              builder: (ctx, child) => Theme(
                data: Theme.of(ctx).copyWith(
                    colorScheme: const ColorScheme.light(primary: Color(0xFFE03E2D))),
                child: child!,
              ),
            );
            if (picked != null) {
              setState(() => _payrollStartDate = picked);
            }
          },
        ),
        const SizedBox(height: 16),
        
        if (breakdown != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.analytics_outlined, color: Color(0xFFE03E2D), size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Monthly Salary Breakdown',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                
                // Earnings
                const Text(
                  'EARNINGS & ALLOWANCES',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF059669),
                  ),
                ),
                const SizedBox(height: 6),
                ...List<Widget>.from((breakdown['earnings'] as List).map((e) {
                  final name = e['name'];
                  final val = e['value'] as double;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
                        ),
                        Text(
                          '+ ₹${val.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                  );
                })),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Additions',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4B5563)),
                    ),
                    Text(
                      '₹${(breakdown['totalEarnings'] as double).toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4B5563)),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                
                // Deductions
                const Text(
                  'DEDUCTIONS',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFDC2626),
                  ),
                ),
                const SizedBox(height: 6),
                if ((breakdown['deductions'] as List).isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text('No deductions assigned', style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic)),
                  )
                else
                  ...List<Widget>.from((breakdown['deductions'] as List).map((d) {
                    final name = d['name'];
                    final val = d['value'] as double;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
                          ),
                          Text(
                            '- ₹${val.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                    );
                  })),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Deductions',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4B5563)),
                    ),
                    Text(
                      '₹${(breakdown['totalDeductions'] as double).toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4B5563)),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                
                // Net Salary
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Estimated In-Hand Salary',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF065F46),
                            ),
                          ),
                          Text(
                            'Per Month',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF047857),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '₹ ${(breakdown['netSalary'] as double).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF065F46),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Color(0xFFD97706), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _payStructureId == null
                        ? 'Select a Pay Structure to preview the monthly in-hand salary breakdown.'
                        : 'Enter Base Salary > 0 to preview the breakdown of HRA, PF, etc.',
                    style: const TextStyle(color: Color(0xFF92400E), fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBankStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Bank & Payment Details'),
        _field(_bankNameCtrl, 'Bank Name', Icons.account_balance_outlined),
        _field(_bankAccountCtrl, 'Account Number', Icons.credit_card_outlined,
            keyboardType: TextInputType.number),
        _field(_bankIfscCtrl, 'IFSC Code', Icons.sort_by_alpha),
        
        const SizedBox(height: 8),
        _sectionLabel('Statutory & KYC Details (ESI / TDS / PF)'),
        _field(_panCtrl, 'PAN Number (TDS / Income Tax)', Icons.assignment_ind_outlined),
        _field(_esiCtrl, 'ESI Number (Employee State Insurance)', Icons.badge_outlined),
        _field(_pfCtrl, 'PF UAN Number (Provident Fund)', Icons.security_outlined),
        
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: const Row(
            children: [
              Icon(Icons.lock_outline, color: Color(0xFF2563EB), size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Bank and statutory details are used for payroll calculations and direct salary disbursement.',
                  style: TextStyle(color: Color(0xFF1E40AF), fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Smart dropdown: shows "+ Add New" and handles empty state ──────────
  Widget _smartDropdown<T extends int>({
    required String label,
    required IconData icon,
    required T? value,
    required List<Map<String,dynamic>> items,
    required String labelKey,
    required String emptyHint,
    required String addLabel,
    required Future<void> Function() onAddNew,
    required ValueChanged<T?> onChanged,
  }) {
    // Safety check: is the active value actually in the loaded list of IDs?
    // If not, and it is not null, coerce it to null to avoid Flutter's Dropdown crash assertion.
    final bool hasValue = value != null && items.any((m) => m['id'] == value);
    final T? safeValue = hasValue ? value : null;

    // Build item list: existing items + sentinel "Add New"
    final List<DropdownMenuItem<int>> menuItems = [
      ...items.map((m) => DropdownMenuItem<int>(
        value: m['id'] as int?,
        child: Text(m[labelKey]?.toString() ?? ''),
      )),
      DropdownMenuItem<int>(
        value: _kAddNew,
        child: Row(
          children: [
            const Icon(Icons.add_circle_outline, color: Color(0xFFE03E2D), size: 18),
            const SizedBox(width: 8),
            Text(addLabel,
                style: const TextStyle(
                    color: Color(0xFFE03E2D), fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<int>(
            value: safeValue,
            items: menuItems,
            hint: items.isEmpty
                ? Row(children: [
                    const Icon(Icons.add_circle_outline,
                        color: Color(0xFFE03E2D), size: 16),
                    const SizedBox(width: 6),
                    Text(emptyHint,
                        style: const TextStyle(
                            color: Color(0xFFE03E2D), fontSize: 13)),
                  ])
                : null,
            onChanged: (v) {
              if (v == _kAddNew) {
                onAddNew();
              } else {
                onChanged(v as T?);
              }
            },
            decoration: InputDecoration(
              labelText: label,
              prefixIcon: Icon(icon, color: const Color(0xFF9CA3AF), size: 20),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: Color(0xFFE03E2D), width: 1.5)),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            ),
            isExpanded: true,
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 12),
              child: Text(
                'Tap "$addLabel" to create one now',
                style: const TextStyle(
                    color: Color(0xFF9CA3AF), fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(text,
          style: const TextStyle(
              fontSize: 11,
              letterSpacing: 1.2,
              color: Color(0xFF9CA3AF),
              fontWeight: FontWeight.w700)),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {TextInputType keyboardType = TextInputType.text,
      bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? '$label is required' : null
            : null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF9CA3AF), size: 20),
          filled: true,
          fillColor: const Color(0xFFF9FAFB),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE03E2D), width: 1.5)),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        ),
      ),
    );
  }

  Widget _dateTile({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF9CA3AF), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: Color(0xFF9CA3AF), fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: TextStyle(
                          color: value == 'Select Date'
                              ? const Color(0xFF9CA3AF)
                              : const Color(0xFF1A1A2E),
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }

  Widget _dropdownField<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    // Safety check: is the active value actually in the loaded list of DropdownMenuItem values?
    // If not, and it is not null, coerce it to null to avoid Flutter's Dropdown crash assertion.
    final bool hasValue = value != null && items.any((item) => item.value == value);
    final T? safeValue = hasValue ? value : null;

    return DropdownButtonFormField<T>(
      value: safeValue,
      items: items,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF9CA3AF), size: 20),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE03E2D), width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      ),
      isExpanded: true,
    );
  }


}

// ═══════════════════════════════════════════════════════
//  EMPLOYEE DETAIL SCREEN (All plan fields, tabbed)
// ═══════════════════════════════════════════════════════
class _EmployeeDetailScreen extends StatefulWidget {
  final Map<String, dynamic> employee;
  final List<Map<String, dynamic>> employees;
  final List<Map<String, dynamic>> designations;
  final List<Map<String, dynamic>> shifts;
  final List<Map<String, dynamic>> payStructures;
  final VoidCallback onRefresh;

  const _EmployeeDetailScreen({
    required this.employee,
    required this.employees,
    required this.designations,
    required this.shifts,
    required this.payStructures,
    required this.onRefresh,
  });

  @override
  State<_EmployeeDetailScreen> createState() => _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends State<_EmployeeDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  late Map<String, dynamic> emp;
  List<Map<String, dynamic>> _loans = [];
  List<Map<String, dynamic>> _payslips = [];
  List<Map<String, dynamic>> _punches = [];
  List<Map<String, dynamic>> _revisions = [];
  List<Map<String, dynamic>> _bonuses = [];
  List<Map<String, dynamic>> _commissions = [];
  double _currentCycleCommission = 0.0;
  bool _loadingLoans = false;
  bool _loadingAttendance = false;
  bool _loadingPayslips = false;
  bool _loadingRevisionsAndBonuses = false;
  bool _loadingCommissions = false;

  @override
  void initState() {
    super.initState();
    emp = Map.from(widget.employee);
    _tab = TabController(length: 5, vsync: this);
    _loadLoans();
    _loadAttendance();
    _loadPayslips();
    _loadRevisionsAndBonuses();
    _loadCommissions();
  }

  Future<void> _loadCommissions() async {
    setState(() => _loadingCommissions = true);
    try {
      final res = await ApiClient.get('/api/hrms/employees/${emp['id']}/commissions');
      if (res['success'] == true && res['data'] != null) {
        final list = List<Map<String, dynamic>>.from(res['data']);
        _commissions = list;
        
        final now = DateTime.now();
        double sum = 0.0;
        for (final item in list) {
          final createdAtStr = item['created_at']?.toString();
          if (createdAtStr != null) {
            final dt = DateTime.tryParse(createdAtStr);
            if (dt != null && dt.year == now.year && dt.month == now.month) {
              sum += double.tryParse(item['commission_amount']?.toString() ?? '0') ?? 0.0;
            }
          }
        }
        setState(() {
          _currentCycleCommission = sum;
        });
      }
    } catch (_) {}
    finally {
      setState(() => _loadingCommissions = false);
    }
  }

  Future<void> _loadLoans() async {
    setState(() => _loadingLoans = true);
    try {
      final res = await ApiClient.get(
          '${ApiEndpoints.hrmsLoans}?employee_id=${emp['id']}');
      _loans = List<Map<String, dynamic>>.from(res['data'] ?? []);
    } catch (_) {}
    finally { setState(() => _loadingLoans = false); }
  }

  Future<void> _loadAttendance() async {
    setState(() => _loadingAttendance = true);
    try {
      final res = await ApiClient.get(
          '${ApiEndpoints.hrmsAttendance}?employee_id=${emp['id']}');
      setState(() {
        _punches = List<Map<String, dynamic>>.from(res['data'] ?? []);
      });
    } catch (_) {}
    finally { setState(() => _loadingAttendance = false); }
  }

  Future<void> _loadPayslips() async {
    setState(() => _loadingPayslips = true);
    try {
      final res = await ApiClient.get(
          '${ApiEndpoints.hrmsPayrollHistory}?employee_id=${emp['id']}');
      setState(() {
        _payslips = List<Map<String, dynamic>>.from(res['data'] ?? []);
      });
    } catch (_) {}
    finally { setState(() => _loadingPayslips = false); }
  }

  Future<void> _loadRevisionsAndBonuses() async {
    setState(() => _loadingRevisionsAndBonuses = true);
    try {
      final revRes = await ApiClient.get('/api/hrms/employees/${emp['id']}/revisions');
      final bonRes = await ApiClient.get('/api/hrms/employees/${emp['id']}/bonuses');
      setState(() {
        _revisions = List<Map<String, dynamic>>.from(revRes['data'] ?? []);
        _bonuses = List<Map<String, dynamic>>.from(bonRes['data'] ?? []);
      });
    } catch (_) {}
    finally {
      setState(() => _loadingRevisionsAndBonuses = false);
    }
  }

  String _lookup(List<Map<String, dynamic>> list, dynamic id, String field) {
    if (id == null) return '—';
    final found = list.where((x) => x['id'].toString() == id.toString()).toList();
    return found.isNotEmpty ? (found.first[field] ?? '—').toString() : id.toString();
  }

  @override
  Widget build(BuildContext context) {
    final name = emp['full_name'] ?? '';
    final code = emp['employee_code'] ?? '';
    final status = emp['status'] ?? 'Active';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A1A2E)),
        title: Text(name,
            style: const TextStyle(
                color: Color(0xFF1A1A2E), fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          TextButton.icon(
            onPressed: _showEditEmployeeForm,
            icon: const Icon(Icons.edit_outlined,
                color: Color(0xFF2563EB), size: 16),
            label: const Text('Edit Details',
                style: TextStyle(color: Color(0xFF2563EB), fontSize: 13)),
          ),
          const SizedBox(width: 8),
          if (status.toString().toLowerCase() == 'terminated')
            TextButton.icon(
              onPressed: _rejoinEmployee,
              icon: const Icon(Icons.person_add_alt_1_outlined,
                  color: Color(0xFF059669), size: 16),
              label: const Text('Rejoin',
                  style: TextStyle(color: Color(0xFF059669), fontSize: 13)),
            )
          else
            TextButton.icon(
              onPressed: _showTerminateDialog,
              icon: const Icon(Icons.person_off_outlined,
                  color: Color(0xFFDC2626), size: 16),
              label: const Text('Terminate',
                  style: TextStyle(color: Color(0xFFDC2626), fontSize: 13)),
            ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tab,
          labelColor: const Color(0xFFE03E2D),
          unselectedLabelColor: const Color(0xFF6B7280),
          indicatorColor: const Color(0xFFE03E2D),
          indicatorWeight: 2.5,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Salary Details'),
            Tab(text: 'Attendance'),
            Tab(text: 'Loans'),
            Tab(text: 'Payslips'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Profile header card
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Row(
              children: [
                _buildAvatar(name, size: 60),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A2E))),
                      const SizedBox(height: 2),
                      Text(code,
                          style: const TextStyle(
                              color: Color(0xFF9CA3AF), fontSize: 13)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _buildStatusChip(status),
                          const SizedBox(width: 8),
                          if (emp['designation_id'] != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(4)),
                              child: Text(
                                _lookup(widget.designations,
                                    emp['designation_id'], 'name'),
                                style: const TextStyle(
                                    color: Color(0xFF2563EB),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _buildOverviewTab(),
                _buildSalaryTab(),
                _buildAttendanceSummaryTab(),
                _buildLoansTab(),
                _buildPayslipsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final Map<String, dynamic> kyc = emp['kyc_documents'] is Map
        ? Map<String, dynamic>.from(emp['kyc_documents'])
        : {};
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        _infoCard('BASIC INFORMATION', [
          _infoRow('Full Name', emp['full_name']),
          _infoRow('Father\'s Name', emp['father_name']),
          _infoRow('Employee Code', emp['employee_code']),
          _infoRow('Email', emp['contact_email'], isLink: true),
          _infoRow('Mobile', emp['mobile']),
          _infoRow('Gender', emp['gender']),
          _infoRow('Date of Birth', emp['date_of_birth']),
          _infoRow('Blood Group', emp['blood_group']),
        ]),
        _infoCard('WORK INFORMATION', [
          _infoRow('Hire Date', emp['hire_date']),
          _infoRow('Payroll Start (EPD)', emp['payroll_start_date']),
          _infoRow('Designation',
              _lookup(widget.designations, emp['designation_id'], 'name')),
          _infoRow('Shift', _lookup(widget.shifts, emp['shift_id'], 'name')),
          _infoRow('Status', emp['status']),
          _infoRow('Requires Attendance',
              emp['requires_attendance'] == true ? 'Yes' : 'No'),
          _infoRow('Pay if Attendance Unmarked',
              emp['pay_if_unmarked'] == true ? 'Yes (Full Pay)' : 'No (Paid Days Only)'),
        ]),
        _infoCard('LEAVE APPROVERS', [
          _infoRow('Level 1 Approver',
              _lookup(widget.employees, emp['level1_approver_id'], 'full_name')),
          _infoRow('Level 2 Approver',
              _lookup(widget.employees, emp['level2_approver_id'], 'full_name')),
        ]),
        if (emp['status'].toString().toLowerCase() == 'terminated')
          _infoCard('TERMINATION DETAILS', [
            _infoRow('Termination Date', emp['terminated_date']),
            _infoRow('Termination Reason', emp['termination_reason']),
          ]),
        _infoCard('BANK & STATUTORY DETAILS', [
          _infoRow('PAN (Income Tax)', kyc['pan']),
          _infoRow('ESI Number', kyc['esi']),
          _infoRow('PF UAN Number', kyc['pf_uan']),
          _infoRow('Bank Name', emp['bank_name']),
          _infoRow('Account No.', emp['bank_account_no']),
          _infoRow('IFSC Code', emp['bank_ifsc']),
        ]),
      ],
    );
  }

  Widget _buildSalaryTab() {
    final base = double.tryParse(emp['base_salary']?.toString() ?? '0') ?? 0;
    final commission =
        double.tryParse(emp['commission_percent']?.toString() ?? '0') ?? 0;

    Map<String, dynamic>? selectedStructure;
    if (emp['pay_structure_id'] != null) {
      selectedStructure = widget.payStructures.firstWhere(
        (p) => p['id'] == emp['pay_structure_id'],
        orElse: () => {},
      );
    }
    
    final breakdown = (base > 0 && selectedStructure != null && selectedStructure.isNotEmpty)
        ? _calculateSalaryBreakdown(base, selectedStructure)
        : null;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        // Summary stat boxes
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              _statBox('Base Salary', '₹${base.toStringAsFixed(0)}', const Color(0xFF059669)),
              const SizedBox(width: 10),
              _statBox('Commission', '${commission.toStringAsFixed(1)}%', const Color(0xFFD97706)),
              if (commission > 0) ...[
                const SizedBox(width: 10),
                _statBox('Comm. Earned (Month)', '₹${_currentCycleCommission.toStringAsFixed(2)}', const Color(0xFFE03E2D)),
              ],
            ],
          ),
        ),
        _infoCard('SALARY STRUCTURE', [
          _infoRow('Base Salary', '₹ ${emp['base_salary'] ?? '—'}'),
          _infoRow('Commission %', '${emp['commission_percent'] ?? 0}%'),
          if (commission > 0) ...[
            _infoRow('Commission Target', _getCommissionTargetRuleText(emp)),
            _infoRow('Commission Earned (Month)', '₹ ${_currentCycleCommission.toStringAsFixed(2)}', textColor: const Color(0xFFD97706), isBold: true),
          ],
          _infoRow('Pay Structure',
              _lookup(widget.payStructures, emp['pay_structure_id'], 'name')),
        ]),
        if (breakdown != null) ...[
          _infoCard('MONTHLY IN-HAND CALCULATION', [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text('EARNINGS & ALLOWANCES', style: TextStyle(color: Color(0xFF059669), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            ),
            ...List<Widget>.from(breakdown['earnings'].map((e) => _infoRow(e['name'].toString(), '+ ₹${(e['value'] as double).toStringAsFixed(2)}'))),
            _infoRow('Total Additions', '₹${(breakdown['totalEarnings'] as double).toStringAsFixed(2)}', isBold: true),
            const Divider(),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text('DEDUCTIONS', style: TextStyle(color: Color(0xFFDC2626), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            ),
            ...List<Widget>.from(breakdown['deductions'].map((d) => _infoRow(d['name'].toString(), '- ₹${(d['value'] as double).toStringAsFixed(2)}'))),
            _infoRow('Total Deductions', '₹${(breakdown['totalDeductions'] as double).toStringAsFixed(2)}', isBold: true),
            const Divider(),
            _infoRow('Estimated In-Hand Salary', '₹${(breakdown['netSalary'] as double).toStringAsFixed(2)}', isBold: true, textColor: const Color(0xFF059669)),
          ]),
        ],

        _infoCard('SALARY REVISION HISTORY', [
          if (_revisions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No salary revision history found.', style: TextStyle(color: Colors.grey, fontSize: 13)),
            )
          else
            Column(
              children: _revisions.map((rev) {
                final prev = double.tryParse(rev['previous_salary']?.toString() ?? '0') ?? 0;
                final next = double.tryParse(rev['new_salary']?.toString() ?? '0') ?? 0;
                final date = rev['effective_date']?.toString() ?? '—';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(date, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                      Row(
                        children: [
                          Text('₹${prev.toStringAsFixed(0)}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                          const Icon(Icons.arrow_right_alt, size: 16, color: Colors.grey),
                          Text('₹${next.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF059669), fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ]),
        _infoCard('BONUS HISTORY', [
          if (_bonuses.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No bonus history found.', style: TextStyle(color: Colors.grey, fontSize: 13)),
            )
          else
            Column(
              children: _bonuses.map((bon) {
                final amt = double.tryParse(bon['amount']?.toString() ?? '0') ?? 0;
                final reason = bon['reason']?.toString() ?? 'Bonus';
                final month = bon['payment_month']?.toString() ?? '—';
                final status = bon['status']?.toString() ?? 'Pending';
                final isPaid = status.toLowerCase() == 'paid';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(reason, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                          Text(month, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                        ],
                      ),
                      Row(
                        children: [
                          Text('₹${amt.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF059669), fontSize: 13)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isPaid ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                color: isPaid ? const Color(0xFF059669) : const Color(0xFF2563EB),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ]),
      ],
    );
  }

  String _getCommissionTargetRuleText(Map<String, dynamic> emp) {
    final type = emp['commission_target_type']?.toString();
    final amountVal = emp['commission_target_amount'];
    final amount = double.tryParse(amountVal?.toString() ?? '0') ?? 0.0;
    if (type == null || type == 'None' || type.isEmpty) {
      return 'None (On full sales)';
    }
    return '$type (Above ₹${amount.toStringAsFixed(2)})';
  }

  Widget _buildAttendanceSummaryTab() {
    if (_loadingAttendance) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFE03E2D)));
    }

    final now = DateTime.now();
    final currentYear = now.year;
    
    double totalWorkedHours = 0.0;
    double totalOvertimeHours = 0.0;
    int totalLatenessMins = 0;
    
    for (final punch in _punches) {
      final punchDateStr = punch['punch_date']?.toString() ?? '';
      try {
        final date = DateTime.parse(punchDateStr);
        if (date.year == now.year && date.month == now.month) {
          totalWorkedHours += double.tryParse(punch['hours_worked']?.toString() ?? '0') ?? 0.0;
          totalOvertimeHours += double.tryParse(punch['overtime_hours']?.toString() ?? '0') ?? 0.0;
          totalLatenessMins += int.tryParse(punch['lateness_mins']?.toString() ?? '0') ?? 0;
        }
      } catch (_) {}
    }

    final List<Map<String, dynamic>> leaveBalances = emp['leaveBalances'] != null
        ? List<Map<String, dynamic>>.from(emp['leaveBalances'])
        : [];

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        // ── Leave balances card ──
        _infoCard('YEARLY LEAVE ACCOUNT (Jan $currentYear - Dec $currentYear)', [
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(Icons.calendar_month_outlined, color: Color(0xFF6B7280), size: 16),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Yearly leave allocation. Year closing resets balances on 31st December.',
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 11, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
          ),
          if (leaveBalances.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text('No leave quotas assigned for the current cycle.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 13))),
            )
          else
            Column(
              children: [
                // Header row
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1.5)),
                  ),
                  child: const Row(
                    children: [
                      Expanded(flex: 3, child: Text('Leave Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E3A5F)))),
                      Expanded(flex: 2, child: Text('Assigned', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E3A5F)), textAlign: TextAlign.center)),
                      Expanded(flex: 2, child: Text('Taken', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E3A5F)), textAlign: TextAlign.center)),
                      Expanded(flex: 2, child: Text('Pending', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF059669)), textAlign: TextAlign.center)),
                    ],
                  ),
                ),
                ...leaveBalances.map((b) {
                  final ltName = b['leaveType'] != null ? (b['leaveType']['name'] ?? 'Leave') : 'Leave';
                  final allocated = double.tryParse(b['allocated_quota']?.toString() ?? '0') ?? 0.0;
                  final used = double.tryParse(b['used_quota']?.toString() ?? '0') ?? 0.0;
                  final pending = allocated - used;
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
                    ),
                    child: Row(
                      children: [
                        Expanded(flex: 3, child: Text(ltName, style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A2E), fontWeight: FontWeight.w600))),
                        Expanded(flex: 2, child: Text(allocated.toStringAsFixed(1), style: const TextStyle(fontSize: 13), textAlign: TextAlign.center)),
                        Expanded(flex: 2, child: Text(used.toStringAsFixed(1), style: const TextStyle(fontSize: 13), textAlign: TextAlign.center)),
                        Expanded(flex: 2, child: Text(pending.toStringAsFixed(1), style: const TextStyle(fontSize: 13, color: Color(0xFF059669), fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
        ]),

        // ── Monthly worked hours card ──
        _infoCard('MONTHLY HOURS SUMMARY (Current Month)', [
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFF6B7280), size: 16),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Worked hours and overtime stats reset automatically at the start of every calendar month.',
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 11, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
          ),
          _infoRow('Total Hours Worked', '${totalWorkedHours.toStringAsFixed(2)} hrs', isBold: true),
          _infoRow('Total Overtime', '${totalOvertimeHours.toStringAsFixed(2)} hrs', textColor: const Color(0xFFD97706), isBold: true),
          _infoRow('Late Arrival Time', '$totalLatenessMins mins', textColor: const Color(0xFFDC2626)),
        ]),
      ],
    );
  }

  Widget _buildLoansTab() {
    if (_loadingLoans) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFFE03E2D)));
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Issued Loans',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E3A5F)),
              ),
              ElevatedButton.icon(
                onPressed: _showAddLoanDialog,
                icon: const Icon(Icons.add, color: Colors.white, size: 14),
                label: const Text('Issue New Loan',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE03E2D),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ],
          ),
        ),
        if (_loans.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: [
                Icon(Icons.monetization_on_outlined,
                    size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 10),
                const Text('No active loans',
                    style: TextStyle(color: Color(0xFF6B7280))),
              ],
            ),
          )
        else
          ..._loans.map((loan) => _loanCard(loan)).toList(),
      ],
    );
  }

  Widget _loanCard(Map<String, dynamic> loan) {
    final double amount = double.tryParse(loan['loan_amount']?.toString() ?? '0') ?? 0.0;
    final double emi = double.tryParse(loan['monthly_emi']?.toString() ?? '0') ?? 0.0;
    final double remaining = double.tryParse(loan['remaining_balance']?.toString() ?? '0') ?? 0.0;
    final status = loan['status'] ?? 'Active';
    
    final double repaid = amount - remaining;
    final double progress = amount > 0 ? (repaid / amount) : 0.0;
    final int progressPct = (progress * 100).round();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.account_balance_wallet, color: Color(0xFF2563EB), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Loan Reference #${loan['id']}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B))),
                      const SizedBox(height: 2),
                      Text('Created: ${loan['created_at'] != null ? DateFormat('dd MMM yyyy').format(DateTime.parse(loan['created_at'].toString()).toLocal()) : '—'}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    ],
                  ),
                ],
              ),
              _buildStatusChip(status),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _loanStat('Loan Amount', '₹${amount.toStringAsFixed(2)}'),
              _loanStat('Monthly EMI', '₹${emi.toStringAsFixed(2)}'),
              _loanStat('Remaining Balance', '₹${remaining.toStringAsFixed(2)}'),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Repayment Progress', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                  Text('$progressPct% Repaid (₹${repaid.toStringAsFixed(2)} paid)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: const Color(0xFFE5E7EB),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    status.toLowerCase() == 'closed' ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
                  ),
                ),
              ),
            ],
          ),
          if ((loan['notes'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF3F4F6)),
              ),
              child: Text(
                'Notes: ${loan['notes']}',
                style: const TextStyle(color: Color(0xFF4B5563), fontSize: 11, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _loanStat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF9CA3AF), fontSize: 11)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildPayslipsTab() {
    if (_loadingPayslips) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFE03E2D)));
    }
    if (_payslips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text('Payslips appear here after payroll is approved',
                style: TextStyle(color: Color(0xFF6B7280)),
                textAlign: TextAlign.center),
            const SizedBox(height: 6),
            const Text('Run payroll from the Payroll screen to generate payslips',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      itemCount: _payslips.length,
      itemBuilder: (context, index) {
        final payslip = _payslips[index];
        final run = payslip['payrollRun'] ?? {};
        final period = run['pay_period']?.toString() ?? '—';
        
        final net = double.tryParse(payslip['net_pay']?.toString() ?? '0') ?? 0.0;
        final gross = double.tryParse(payslip['gross_pay']?.toString() ?? '0') ?? 0.0;
        final deduct = double.tryParse(payslip['total_deductions']?.toString() ?? '0') ?? 0.0;
        final status = run['status']?.toString() ?? 'Draft';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Pay Period: $period',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E3A5F)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: status.toLowerCase() == 'approved' ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: status.toLowerCase() == 'approved' ? const Color(0xFF065F46) : const Color(0xFF92400E),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _slipStat('Gross Pay', '₹${gross.toStringAsFixed(2)}'),
                    _slipStat('Deductions', '₹${deduct.toStringAsFixed(2)}', color: const Color(0xFFDC2626)),
                    _slipStat('Net Paid', '₹${net.toStringAsFixed(2)}', color: const Color(0xFF059669), isBold: true),
                  ],
                ),
                const Divider(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: () => _showPayslipPrintDialog(payslip),
                    icon: const Icon(Icons.print, size: 16, color: Colors.white),
                    label: const Text('Reprint Slip', style: TextStyle(color: Colors.white, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE03E2D),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _slipStat(String label, String value, {Color? color, bool isBold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color ?? const Color(0xFF1F2937),
          ),
        ),
      ],
    );
  }

  // ─────────── Dialogs ───────────

  void _showSalaryRevisionDialog() {
    final newSalaryCtrl = TextEditingController(
        text: emp['base_salary']?.toString() ?? '');
    final reasonCtrl = TextEditingController();
    DateTime effectiveDate = DateTime.now();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Request Salary Revision',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Current: ₹${emp['base_salary'] ?? 0}',
                  style: const TextStyle(color: Color(0xFF6B7280))),
              const SizedBox(height: 12),
              TextField(
                controller: newSalaryCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'New Base Salary (₹)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.currency_rupee),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2030),
                    builder: (c, child) => Theme(
                      data: Theme.of(c).copyWith(
                          colorScheme: const ColorScheme.light(
                              primary: Color(0xFFE03E2D))),
                      child: child!,
                    ),
                  );
                  if (d != null) setDs(() => effectiveDate = d);
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16,
                          color: Color(0xFF9CA3AF)),
                      const SizedBox(width: 8),
                      Text(
                          'Effective: ${effectiveDate.day}-${effectiveDate.month}-${effectiveDate.year}'),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel',
                    style: TextStyle(color: Color(0xFF6B7280)))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE03E2D),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
              onPressed: () async {
                final newSalary = double.tryParse(newSalaryCtrl.text) ?? 0.0;
                if (newSalary <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid salary amount')),
                  );
                  return;
                }
                try {
                  await ApiClient.post('/api/hrms/employees/${emp['id']}/revise-salary', {
                    'new_salary': newSalary,
                    'effective_date':
                        '${effectiveDate.year}-${effectiveDate.month.toString().padLeft(2, '0')}-${effectiveDate.day.toString().padLeft(2, '0')}',
                  });
                  Navigator.pop(ctx);
                  setState(() {
                    emp['base_salary'] = newSalary;
                  });
                  widget.onRefresh();
                  _loadRevisionsAndBonuses();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Salary revised successfully!'),
                        backgroundColor: Color(0xFF059669),
                        behavior: SnackBarBehavior.floating),
                  );
                } catch (e) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Submit',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddBonusDialog() {
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController(text: 'Diwali Bonus');
    bool payInstantly = false;
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Issue Bonus / Reward', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Bonus Amount (₹)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.currency_rupee),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                decoration: InputDecoration(
                  labelText: 'Reason / Occasion',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.star_border),
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Pay Instantly', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                subtitle: const Text('Else paid with monthly payroll', style: TextStyle(fontSize: 11)),
                value: payInstantly,
                activeColor: const Color(0xFFE03E2D),
                onChanged: (val) => setDs(() => payInstantly = val),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE03E2D),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final amt = double.tryParse(amountCtrl.text) ?? 0.0;
                if (amt <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid amount')),
                  );
                  return;
                }
                try {
                  await ApiClient.post('/api/hrms/employees/${emp['id']}/bonus', {
                    'amount': amt,
                    'reason': reasonCtrl.text,
                    'pay_instantly': payInstantly,
                  });
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(payInstantly
                          ? 'Bonus paid instantly successfully!'
                          : 'Bonus queued for next payroll cycle!'),
                      backgroundColor: const Color(0xFF059669),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  _loadPayslips(); // refresh history tabs
                  _loadRevisionsAndBonuses();
                } catch (e) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
              child: const Text('Submit', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddLoanDialog() {
    final amountCtrl = TextEditingController();
    final emiCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String paymentMethod = 'Cash';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              CircleAvatar(
                backgroundColor: Color(0xFFFFFBEB),
                child: Icon(Icons.monetization_on, color: Color(0xFFD97706)),
              ),
              SizedBox(width: 12),
              Text('Issue Loan', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Loan Amount (₹)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.currency_rupee),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emiCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Monthly EMI (₹)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.payments_outlined),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: paymentMethod,
                decoration: InputDecoration(
                  labelText: 'Payment Method',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer')),
                  DropdownMenuItem(value: 'Cheque', child: Text('Cheque')),
                  DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                ],
                onChanged: (v) => setDs(() => paymentMethod = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                decoration: InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280)))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE03E2D),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text) ?? 0;
                if (amount <= 0) return;
                try {
                  await ApiClient.post(ApiEndpoints.hrmsLoans, {
                    'employee_id': emp['id'],
                    'loan_amount': amount,
                    'monthly_emi': double.tryParse(emiCtrl.text) ?? 0,
                    'remaining_balance': amount,
                    'notes': notesCtrl.text.trim(),
                    'payment_method': paymentMethod,
                    'status': 'Active',
                  });
                  Navigator.pop(ctx);
                  await _loadLoans();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Loan issued successfully'),
                        backgroundColor: Color(0xFF059669),
                        behavior: SnackBarBehavior.floating),
                  );
                } catch (e) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Issue', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditEmployeeForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddEmployeeForm(
        employees: widget.employees,
        employee: emp,
        onSaved: () async {
          try {
            final res = await ApiClient.get('${ApiEndpoints.hrmsEmployees}/${emp['id']}');
            if (res['success'] == true && res['data'] != null) {
              setState(() {
                emp = Map<String, dynamic>.from(res['data']);
              });
            }
          } catch (_) {}
          widget.onRefresh();
        },
      ),
    );
  }

  Future<void> _rejoinEmployee() async {
    final salaryCtrl = TextEditingController(text: emp['base_salary']?.toString() ?? '0');
    DateTime rejoinDate = DateTime.now();
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              CircleAvatar(
                backgroundColor: Color(0xFFECFDF5),
                child: Icon(Icons.person_add_alt_1_outlined, color: Color(0xFF059669)),
              ),
              SizedBox(width: 12),
              Text('Rejoin Employee', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Assign new salary and details to rejoin ${emp['full_name']}:', style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563))),
              const SizedBox(height: 16),
              TextField(
                controller: salaryCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'New Base Salary (₹) *',
                  prefixIcon: const Icon(Icons.currency_rupee, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: rejoinDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                  );
                  if (picked != null) {
                    setDialogState(() => rejoinDate = picked);
                  }
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Rejoin Date *',
                    prefixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('${rejoinDate.day.toString().padLeft(2, '0')}-${rejoinDate.month.toString().padLeft(2, '0')}-${rejoinDate.year}'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Rejoin Employee', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    
    if (confirm != true) return;
    
    final newSalary = double.tryParse(salaryCtrl.text.trim()) ?? (double.tryParse(emp['base_salary']?.toString() ?? '0') ?? 0);
    
    try {
      final res = await ApiClient.put('${ApiEndpoints.hrmsEmployees}/${emp['id']}', {
        'status': 'Active',
        'base_salary': newSalary,
        'hire_date': rejoinDate.toIso8601String().split('T')[0],
        'terminated_date': null,
        'termination_reason': null,
      });
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Employee rejoined and salary updated successfully'),
            backgroundColor: Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
        widget.onRefresh();
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error rejoining: $e'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showTerminateDialog() {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFFFEF2F2),
              child: Icon(Icons.person_off_outlined, color: Color(0xFFDC2626)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Terminate Employee',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(emp['full_name'] ?? '',
                      style: const TextStyle(
                          color: Color(0xFF6B7280), fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'This will mark the employee as Terminated. '
                'Their payroll and attendance data will be retained.',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
            const SizedBox(height: 14),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Reason for termination *',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF6B7280)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              if (reasonCtrl.text.trim().isEmpty) return;
              try {
                await ApiClient.post(
                    '${ApiEndpoints.hrmsEmployees}/${emp['id']}/terminate',
                    {
                      'termination_reason': reasonCtrl.text.trim(),
                      'terminated_date': DateTime.now()
                          .toIso8601String()
                          .split('T')[0],
                    });
                Navigator.pop(ctx);
                Navigator.pop(context);
                widget.onRefresh();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Employee terminated'),
                    backgroundColor: Color(0xFFDC2626),
                    behavior: SnackBarBehavior.floating));
              } catch (e) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Confirm Terminate',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ─────────── UI helpers ───────────

  Widget _infoCard(String title, List<Widget> rows) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.2,
                    color: Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 14),
            ...rows,
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, dynamic value, {bool isLink = false, Color? textColor, bool isBold = false}) {
    final display = (value == null || value.toString().isEmpty)
        ? '—'
        : value.toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: const TextStyle(
                    color: Color(0xFF6B7280), fontSize: 13)),
          ),
          Expanded(
            child: Text(display,
                style: TextStyle(
                    color: textColor ?? (isLink
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF1A1A2E)),
                    fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                    fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _statBox(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String name, {double size = 40}) {
    const colors = [
      Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFEC4899),
      Color(0xFFEF4444), Color(0xFFF97316), Color(0xFF10B981),
      Color(0xFF3B82F6), Color(0xFF14B8A6),
    ];
    final color = colors[name.isNotEmpty ? name.codeUnitAt(0) % colors.length : 0];
    final initials = name.trim().split(' ').take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: color,
      child: Text(initials,
          style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.34,
              fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bg, fg;
    switch (status.toLowerCase()) {
      case 'active': bg = const Color(0xFFECFDF5); fg = const Color(0xFF059669); break;
      case 'terminated': bg = const Color(0xFFFEF2F2); fg = const Color(0xFFDC2626); break;
      default: bg = const Color(0xFFF3F4F6); fg = const Color(0xFF6B7280);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(status,
          style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  void _showPayslipPrintDialog(Map<String, dynamic> payslip) async {
    final user = await TokenStorage.getUser();
    final propName = user?['property_name']?.toString() ?? 'RETAIL SALE STORE';
    final propAddress = user?['property_address']?.toString() ?? '';
    final propContact = user?['property_contact']?.toString() ?? '';
    final propEmail = user?['property_email']?.toString() ?? '';

    String periodText = payslip['payrollRun'] != null
        ? payslip['payrollRun']['pay_period']?.toString() ?? ''
        : '';
        
    final base = double.tryParse(payslip['base_salary']?.toString() ?? '0') ?? 0.0;
    final prorated = double.tryParse(payslip['prorated_salary']?.toString() ?? '0') ?? 0.0;
    final commission = double.tryParse(payslip['sales_commission']?.toString() ?? '0') ?? 0.0;
    final arrears = double.tryParse(payslip['arrears']?.toString() ?? '0') ?? 0.0;
    final bonuses = double.tryParse(payslip['bonuses']?.toString() ?? '0') ?? 0.0;
    
    final shortage = double.tryParse(payslip['shortage_penalties']?.toString() ?? '0') ?? 0.0;
    final emi = double.tryParse(payslip['loan_emi']?.toString() ?? '0') ?? 0.0;
    final statutory = double.tryParse(payslip['statutory_deductions']?.toString() ?? '0') ?? 0.0;
    final totalDeducts = double.tryParse(payslip['total_deductions']?.toString() ?? '0') ?? 0.0;
    
    final gross = double.tryParse(payslip['gross_pay']?.toString() ?? '0') ?? 0.0;
    final net = double.tryParse(payslip['net_pay']?.toString() ?? '0') ?? 0.0;
    
    final daysPresent = double.tryParse(payslip['days_present']?.toString() ?? '0') ?? 0.0;
    final daysAbsent = double.tryParse(payslip['days_absent']?.toString() ?? '0') ?? 0.0;
    final daysLeave = double.tryParse(payslip['days_on_leave']?.toString() ?? '0') ?? 0.0;

    final employeeMap = payslip['employee'] ?? {};
    final designationMap = employeeMap['designation'] ?? {};
    final payStructureMap = employeeMap['payStructure'] ?? {};
    final rawComponents = payStructureMap['components'] ?? [];
    final List<Map<String, dynamic>> earningComponents = [];
    final List<Map<String, dynamic>> deductionComponents = [];

    for (var item in rawComponents) {
      final comp = item['component'] ?? item;
      final name = comp['name']?.toString() ?? '';
      final nature = comp['nature']?.toString() ?? '';
      if (name.isNotEmpty) {
        if (nature == 'Earning') {
          earningComponents.add(comp);
        } else if (nature == 'Deduction') {
          deductionComponents.add(comp);
        }
      }
    }

    final breakdown = payslip['components_breakdown'] is Map
        ? Map<String, dynamic>.from(payslip['components_breakdown'])
        : {};

    final Map<String, dynamic> kyc = emp['kyc_documents'] is Map
        ? Map<String, dynamic>.from(emp['kyc_documents'])
        : {};

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Print Payslip', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(ctx).pop(),
            )
          ],
        ),
        content: SingleChildScrollView(
          child: Container(
            width: 550,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Company / Outlet Header
                Center(
                  child: Column(
                    children: [
                      Text(propName.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E3A5F))),
                      if (propAddress.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(propAddress, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                      if (propContact.isNotEmpty || propEmail.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text('Contact: $propContact | Email: $propEmail', textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                      const SizedBox(height: 6),
                      const Text('PAYSLIP FOR THE MONTH OF', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600)),
                      Text(periodText.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFE03E2D))),
                      const SizedBox(height: 10),
                      const Divider(thickness: 1.5),
                    ],
                  ),
                ),
                
                // Employee Details Grid
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _payslipField('Employee Name:', emp['full_name']),
                          _payslipField('Employee Code:', emp['employee_code']),
                          _payslipField('Designation:', designationMap['name']?.toString() ?? _lookup(widget.designations, emp['designation_id'], 'name')),
                          _payslipField('Pay Grade:', payStructureMap['name']?.toString() ?? '—'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _payslipField('Shift:', _lookup(widget.shifts, emp['shift_id'], 'name')),
                          _payslipField('PAN:', kyc['pan']),
                          _payslipField('ESI No:', kyc['esi']),
                          _payslipField('PF UAN:', kyc['pf_uan']),
                          _payslipField('Bank Acc:', emp['bank_account_no']),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(thickness: 1.5),
                
                // Attendance Summary
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Expanded(child: _payslipField('Days Present:', daysPresent.toStringAsFixed(1))),
                    Expanded(child: _payslipField('Days Absent:', daysAbsent.toStringAsFixed(1))),
                    Expanded(child: _payslipField('On Leave:', daysLeave.toStringAsFixed(1))),
                  ],
                ),
                const Divider(thickness: 1.5),
                
                // Earnings vs Deductions Table
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Earnings column
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          border: Border(right: BorderSide(color: Colors.grey.shade300)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('EARNINGS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF059669))),
                            const SizedBox(height: 8),
                            _payslipRow('Prorated Base Pay', prorated),
                            ...earningComponents.where((c) => !c['name'].toString().toLowerCase().contains('basic')).map((c) {
                              final name = c['name']?.toString() ?? '';
                              final val = double.tryParse(breakdown[name]?.toString() ?? '0') ?? 0.0;
                              return _payslipRow(name, val);
                            }).toList(),
                            _payslipRow('Sales Commission', commission),
                            _payslipRow('Arrears', arrears),
                            _payslipRow('Bonuses', bonuses),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Deductions column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('DEDUCTIONS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFDC2626))),
                          const SizedBox(height: 8),
                          ...deductionComponents.map((c) {
                            final name = c['name']?.toString() ?? '';
                            final val = double.tryParse(breakdown[name]?.toString() ?? '0') ?? 0.0;
                            return _payslipRow(name, val);
                          }).toList(),
                          _payslipRow('Shortages & Penalties', shortage),
                          _payslipRow('Loan EMI Recovery', emi),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(thickness: 1.5),
                
                // Summary Totals
                _payslipRow('Total Additions (Gross)', gross, isBold: true),
                _payslipRow('Total Deductions', totalDeducts, isBold: true),
                const SizedBox(height: 12),
                
                // Net salary box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('NET IN-HAND PAID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF065F46))),
                      Text('₹${net.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF065F46))),
                    ],
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Signatures row
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        SizedBox(width: 100, child: Divider(color: Colors.black)),
                        Text('Employee Signature', style: TextStyle(fontSize: 10)),
                      ],
                    ),
                    Column(
                      children: [
                        SizedBox(width: 100, child: Divider(color: Colors.black)),
                        Text('Authorized Signatory', style: TextStyle(fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () async {
              try {
                final pdf = await _buildPayslipPdf(payslip, propName, propAddress, propContact, propEmail);
                await Printing.layoutPdf(
                  name: 'Payslip_${payslip['employee_name'] ?? 'Employee'}_$periodText',
                  onLayout: (format) async => pdf.save(),
                );
              } catch (e) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('Failed to print: $e')),
                );
              }
            },
            icon: const Icon(Icons.print, color: Colors.white, size: 16),
            label: const Text('Print / Export PDF', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE03E2D)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

Future<pw.Document> _buildPayslipPdf(
    Map<String, dynamic> payslip,
    String propName,
    String propAddress,
    String propContact,
    String propEmail,
  ) async {
    final pdf = pw.Document();
    
    final periodText = payslip['payrollRun'] != null
        ? payslip['payrollRun']['pay_period']?.toString() ?? ''
        : '';
        
    final base = double.tryParse(payslip['base_salary']?.toString() ?? '0') ?? 0.0;
    final prorated = double.tryParse(payslip['prorated_salary']?.toString() ?? '0') ?? 0.0;
    final commission = double.tryParse(payslip['sales_commission']?.toString() ?? '0') ?? 0.0;
    final arrears = double.tryParse(payslip['arrears']?.toString() ?? '0') ?? 0.0;
    final bonuses = double.tryParse(payslip['bonuses']?.toString() ?? '0') ?? 0.0;
    
    final shortage = double.tryParse(payslip['shortage_penalties']?.toString() ?? '0') ?? 0.0;
    final emi = double.tryParse(payslip['loan_emi']?.toString() ?? '0') ?? 0.0;
    final statutory = double.tryParse(payslip['statutory_deductions']?.toString() ?? '0') ?? 0.0;
    final totalDeducts = double.tryParse(payslip['total_deductions']?.toString() ?? '0') ?? 0.0;
    
    final gross = double.tryParse(payslip['gross_pay']?.toString() ?? '0') ?? 0.0;
    final net = double.tryParse(payslip['net_pay']?.toString() ?? '0') ?? 0.0;
    
    final daysPresent = double.tryParse(payslip['days_present']?.toString() ?? '0') ?? 0.0;
    final daysAbsent = double.tryParse(payslip['days_absent']?.toString() ?? '0') ?? 0.0;
    final daysLeave = double.tryParse(payslip['days_on_leave']?.toString() ?? '0') ?? 0.0;

    final employeeMap = payslip['employee'] ?? {};
    final designationMap = employeeMap['designation'] ?? {};
    final payStructureMap = employeeMap['payStructure'] ?? {};
    final rawComponents = payStructureMap['components'] ?? [];
    final List<Map<String, dynamic>> earningComponents = [];
    final List<Map<String, dynamic>> deductionComponents = [];

    for (var item in rawComponents) {
      final comp = item['component'] ?? item;
      final name = comp['name']?.toString() ?? '';
      final nature = comp['nature']?.toString() ?? '';
      if (name.isNotEmpty) {
        if (nature == 'Earning') {
          earningComponents.add(comp);
        } else if (nature == 'Deduction') {
          deductionComponents.add(comp);
        }
      }
    }

    final breakdown = payslip['components_breakdown'] is Map
        ? Map<String, dynamic>.from(payslip['components_breakdown'])
        : {};

    final Map<String, dynamic> kyc = emp['kyc_documents'] is Map
        ? Map<String, dynamic>.from(emp['kyc_documents'])
        : {};

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(24),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColor.fromHex('#D1D5DB')),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        propName.toUpperCase(),
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 16,
                          color: PdfColor.fromHex('#1E3A5F'),
                        ),
                      ),
                      if (propAddress.isNotEmpty) ...[
                        pw.SizedBox(height: 4),
                        pw.Text(propAddress, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#6B7280'))),
                      ],
                      if (propContact.isNotEmpty || propEmail.isNotEmpty) ...[
                        pw.SizedBox(height: 2),
                        pw.Text('Contact: $propContact | Email: $propEmail', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#6B7280'))),
                      ],
                      pw.SizedBox(height: 6),
                      pw.Text('PAYSLIP FOR THE MONTH OF', style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#6B7280'), fontWeight: pw.FontWeight.bold)),
                      pw.Text(periodText.toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13, color: PdfColor.fromHex('#E03E2D'))),
                      pw.SizedBox(height: 10),
                      pw.Divider(thickness: 1.5, color: PdfColor.fromHex('#E5E7EB')),
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),
                
                // Employee Details Table
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _pdfField('Employee Name:', emp['full_name']),
                          _pdfField('Employee Code:', emp['employee_code']),
                          _pdfField('Designation:', designationMap['name']?.toString() ?? _lookup(widget.designations, emp['designation_id'], 'name')),
                          _pdfField('Pay Grade:', payStructureMap['name']?.toString() ?? '—'),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _pdfField('Shift:', _lookup(widget.shifts, emp['shift_id'], 'name')),
                          _pdfField('PAN:', kyc['pan']),
                          _pdfField('ESI No:', kyc['esi']),
                          _pdfField('PF UAN:', kyc['pf_uan']),
                          _pdfField('Bank Acc:', emp['bank_account_no']),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.Divider(thickness: 1.5, color: PdfColor.fromHex('#E5E7EB')),
                pw.SizedBox(height: 8),
                
                // Attendance Summary
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    pw.Expanded(child: pw.Center(child: _pdfField('Days Present:', daysPresent.toStringAsFixed(1)))),
                    pw.Expanded(child: pw.Center(child: _pdfField('Days Absent:', daysAbsent.toStringAsFixed(1)))),
                    pw.Expanded(child: pw.Center(child: _pdfField('On Leave:', daysLeave.toStringAsFixed(1)))),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Divider(thickness: 1.5, color: PdfColor.fromHex('#E5E7EB')),
                pw.SizedBox(height: 12),
                
                // Earnings & Deductions Table
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Earnings
                    pw.Expanded(
                      child: pw.Container(
                        padding: const pw.EdgeInsets.only(right: 12),
                        decoration: pw.BoxDecoration(
                          border: pw.Border(right: pw.BorderSide(color: PdfColor.fromHex('#E5E7EB'))),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('EARNINGS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColor.fromHex('#059669'))),
                            pw.SizedBox(height: 8),
                            _pdfRow('Prorated Base Pay', prorated),
                            ...earningComponents.where((c) => !c['name'].toString().toLowerCase().contains('basic')).map((c) {
                              final name = c['name']?.toString() ?? '';
                              final val = double.tryParse(breakdown[name]?.toString() ?? '0') ?? 0.0;
                              return _pdfRow(name, val);
                            }).toList(),
                            _pdfRow('Sales Commission', commission),
                            _pdfRow('Arrears', arrears),
                            _pdfRow('Bonuses', bonuses),
                          ],
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 12),
                    // Deductions
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('DEDUCTIONS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColor.fromHex('#DC2626'))),
                          pw.SizedBox(height: 8),
                          ...deductionComponents.map((c) {
                            final name = c['name']?.toString() ?? '';
                            final val = double.tryParse(breakdown[name]?.toString() ?? '0') ?? 0.0;
                            return _pdfRow(name, val);
                          }).toList(),
                          _pdfRow('Shortages & Penalties', shortage),
                          _pdfRow('Loan EMI Recovery', emi),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 12),
                pw.Divider(thickness: 1.5, color: PdfColor.fromHex('#E5E7EB')),
                pw.SizedBox(height: 8),
                
                // Totals
                _pdfRow('Total Additions (Gross)', gross, isBold: true),
                _pdfRow('Total Deductions', totalDeducts, isBold: true),
                pw.SizedBox(height: 12),
                
                // Net Salary Box
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#ECFDF5'),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    border: pw.Border.all(color: PdfColor.fromHex('#A7F3D0')),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('NET IN-HAND PAID', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13, color: PdfColor.fromHex('#065F46'))),
                      pw.Text('Rs. ${net.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColor.fromHex('#065F46'))),
                    ],
                  ),
                ),
                pw.SizedBox(height: 48),
                
                // Signatures
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      children: [
                        pw.Container(width: 120, height: 1, color: PdfColors.black),
                        pw.SizedBox(height: 4),
                        pw.Text('Employee Signature', style: const pw.TextStyle(fontSize: 8)),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Container(width: 120, height: 1, color: PdfColors.black),
                        pw.SizedBox(height: 4),
                        pw.Text('Authorized Signatory', style: const pw.TextStyle(fontSize: 8)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
    return pdf;
  }

  pw.Widget _pdfField(String label, dynamic value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColor.fromHex('#4B5563'))),
          pw.SizedBox(width: 6),
          pw.Text(value?.toString() ?? '—', style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  pw.Widget _pdfRow(String label, double amount, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 9, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text('Rs. ${amount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 9, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }

  Widget _payslipField(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF4B5563))),
          const SizedBox(width: 6),
          Expanded(child: Text(value?.toString() ?? '—', style: const TextStyle(fontSize: 11))),
        ],
      ),
    );
  }

  Widget _payslipRow(String label, double amount, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 11, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text('₹${amount.toStringAsFixed(2)}', style: TextStyle(fontSize: 11, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  SHIFT QUICK-ADD DIALOG  (with real time pickers)
// ═══════════════════════════════════════════════════════
class _ShiftQuickAddDialog extends StatefulWidget {
  const _ShiftQuickAddDialog();
  @override
  State<_ShiftQuickAddDialog> createState() => _ShiftQuickAddDialogState();
}

class _ShiftQuickAddDialogState extends State<_ShiftQuickAddDialog> {
  final _nameCtrl  = TextEditingController();
  final _graceCtrl = TextEditingController(text: '15');
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _saving = false;
  String? _error;

  String _fmtTime(TimeOfDay? t) => t == null
      ? 'Tap to select'
      : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _toHHMM(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: (isStart ? _startTime : _endTime) ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() { if (isStart) _startTime = picked; else _endTime = picked; });
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _startTime == null || _endTime == null) {
      setState(() => _error = 'Shift name, start time and end time are required.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final res = await ApiClient.post(ApiEndpoints.hrmsShifts, {
        'name'              : _nameCtrl.text.trim(),
        'start_time'        : _toHHMM(_startTime!),
        'end_time'          : _toHHMM(_endTime!),
        'grace_period_mins' : int.tryParse(_graceCtrl.text.trim()) ?? 15,
        'is_active'         : true,
      });
      final data = res['data'];
      if (data != null && data is Map<String, dynamic>) {
        if (mounted) Navigator.pop(context, data);
      } else {
        setState(() {
          _error = res['message']?.toString() ?? 'Server returned no data';
          _saving = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.schedule,
                        color: Color(0xFF2563EB), size: 17),
                  ),
                  const SizedBox(width: 10),
                  const Text('New Shift',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close,
                        size: 18, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            // ── Content ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
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
                  TextField(
                    controller: _nameCtrl,
                    autofocus: true,
                    style: const TextStyle(fontSize: 13),
                    decoration: _inputDecor(
                        'Shift Name *', 'e.g. Morning Shift',
                        Icons.label_outline),
                  ),
                  const SizedBox(height: 8),
                  _timeTile('Start Time *', _startTime, () => _pickTime(true)),
                  const SizedBox(height: 6),
                  _timeTile('End Time *', _endTime, () => _pickTime(false)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _graceCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 13),
                    decoration: _inputDecor(
                        'Grace Period (mins)', '15', Icons.timer_outlined),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // ── Actions ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8)),
                    child: const Text('Cancel',
                        style: TextStyle(
                            color: Color(0xFF6B7280), fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE03E2D),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(7)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 9),
                      elevation: 0,
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('Save Shift',
                            style: TextStyle(
                                color: Colors.white,
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

  Widget _timeTile(String label, TimeOfDay? time, VoidCallback onTap) {
    final selected = time != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: selected
                  ? const Color(0xFFE03E2D)
                  : const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time,
                color: selected
                    ? const Color(0xFFE03E2D)
                    : const Color(0xFF9CA3AF),
                size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 10,
                          color: selected
                              ? const Color(0xFFE03E2D)
                              : const Color(0xFF9CA3AF))),
                  Text(_fmtTime(time),
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: selected
                              ? const Color(0xFF1A1A2E)
                              : const Color(0xFF9CA3AF))),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: selected
                    ? const Color(0xFFE03E2D)
                    : const Color(0xFF9CA3AF),
                size: 16),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecor(String label, String hint, IconData icon) =>
      InputDecoration(
        labelText: label, hintText: hint,
        labelStyle: const TextStyle(fontSize: 12),
        hintStyle: const TextStyle(color: Color(0xFFD1D5DB), fontSize: 12),
        prefixIcon: Icon(icon, color: const Color(0xFF9CA3AF), size: 16),
        filled: true, fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
                color: Color(0xFFE03E2D), width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
      );
}

// ═══════════════════════════════════════════════════════
//  PAY STRUCTURE QUICK-ADD DIALOG
//  Select from master salary components (no re-entry)
// ═══════════════════════════════════════════════════════
class _PayStructureQuickAddDialog extends StatefulWidget {
  const _PayStructureQuickAddDialog();
  @override
  State<_PayStructureQuickAddDialog> createState() =>
      _PayStructureQuickAddDialogState();
}

class _PayStructureQuickAddDialogState
    extends State<_PayStructureQuickAddDialog> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  // Masters loaded from API
  List<Map<String, dynamic>> _allComponents = [];
  bool _loadingMasters = true;

  // User-selected component IDs
  final Set<int> _selectedIds = {};

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadComponents();
  }

  Future<void> _loadComponents() async {
    try {
      final res = await ApiClient.get(ApiEndpoints.hrmsSalaryComponents);
      final list = res['data'];
      if (list is List) {
        setState(() {
          _allComponents = list.cast<Map<String, dynamic>>();
          _loadingMasters = false;
        });
      } else {
        setState(() => _loadingMasters = false);
      }
    } catch (_) {
      setState(() => _loadingMasters = false);
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Structure name is required.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final res = await ApiClient.post(ApiEndpoints.hrmsPayStructures, {
        'name'        : _nameCtrl.text.trim(),
        'description' : _descCtrl.text.trim(),
        'componentIds': _selectedIds.toList(),
      });
      final data = res['data'];
      if (data != null && data is Map<String, dynamic>) {
        if (mounted) Navigator.pop(context, data);
      } else {
        setState(() {
          _error = res['message']?.toString() ?? 'Server returned no data';
          _saving = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final earnings =
        _allComponents.where((c) => c['nature'] == 'Earning').toList();
    final deductions =
        _allComponents.where((c) => c['nature'] == 'Deduction').toList();
    final selectedCount = _selectedIds.length;

    return Dialog(
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 28, vertical: 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 580),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                        Icons.account_balance_wallet_outlined,
                        color: Color(0xFFE03E2D), size: 17),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('New Pay Structure',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close,
                        size: 18, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),

            // ── Scrollable content ──
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Error banner
                    if (_error != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(
                              color: const Color(0xFFFECACA)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.error_outline,
                              color: Color(0xFFDC2626), size: 14),
                          const SizedBox(width: 6),
                          Expanded(child: Text(_error!,
                              style: const TextStyle(
                                  color: Color(0xFFDC2626),
                                  fontSize: 11))),
                        ]),
                      ),

                    // Name & Description
                    TextField(
                      controller: _nameCtrl,
                      autofocus: true,
                      style: const TextStyle(fontSize: 13),
                      decoration: _inputDecor(
                          'Structure Name *',
                          'e.g. Grade A \u2013 7th Pay',
                          Icons.drive_file_rename_outline),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descCtrl,
                      style: const TextStyle(fontSize: 13),
                      decoration: _inputDecor(
                          'Description', 'Optional notes', Icons.notes),
                    ),
                    const SizedBox(height: 14),

                    // Assign Components header
                    Row(
                      children: [
                        const Text('ASSIGN COMPONENTS',
                            style: TextStyle(
                                fontSize: 9,
                                letterSpacing: 1.1,
                                color: Color(0xFF9CA3AF),
                                fontWeight: FontWeight.w700)),
                        const SizedBox(width: 6),
                        if (selectedCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE03E2D),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text('$selectedCount selected',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Loading / Empty / List
                    if (_loadingMasters)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                color: Color(0xFFE03E2D), strokeWidth: 2),
                          ),
                        ),
                      )
                    else if (_allComponents.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFFFED7AA)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.info_outline,
                              color: Color(0xFFD97706), size: 14),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'No salary components in masters.\n'
                              'Go to HR Masters \u2192 Salary Components to add HRA, PF, etc.',
                              style: const TextStyle(
                                  color: Color(0xFFD97706),
                                  fontSize: 11),
                            ),
                          ),
                        ]),
                      )
                    else ...[
                      if (earnings.isNotEmpty) ...[
                        _sectionLabel('EARNINGS',
                            const Color(0xFF059669)),
                        const SizedBox(height: 4),
                        ...earnings.map((c) => _componentTile(
                            c, const Color(0xFF059669))),
                        const SizedBox(height: 10),
                      ],
                      if (deductions.isNotEmpty) ...[
                        _sectionLabel('DEDUCTIONS',
                            const Color(0xFFE03E2D)),
                        const SizedBox(height: 4),
                        ...deductions.map((c) => _componentTile(
                            c, const Color(0xFFE03E2D))),
                      ],
                    ],
                  ],
                ),
              ),
            ),

            const Divider(height: 1),
            // ── Actions ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving
                        ? null : () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8)),
                    child: const Text('Cancel',
                        style: TextStyle(
                            color: Color(0xFF6B7280), fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE03E2D),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(7)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 9),
                      elevation: 0,
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('Save Structure',
                            style: TextStyle(
                                color: Colors.white,
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

  /// Checkbox-style tappable row for a master salary component
  Widget _componentTile(Map<String, dynamic> comp, Color color) {
    final id = (comp['id'] as num?)?.toInt() ?? 0;
    final selected = _selectedIds.contains(id);
    final type    = comp['type']?.toString()    ?? 'Fixed';
    final formula = comp['formula']?.toString() ?? '';

    return GestureDetector(
      onTap: () => setState(() {
        if (selected) _selectedIds.remove(id);
        else _selectedIds.add(id);
      }),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? color.withAlpha(18) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: selected ? color : const Color(0xFFE5E7EB),
              width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 18, height: 18,
              decoration: BoxDecoration(
                color: selected ? color : Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                    color: selected ? color : const Color(0xFFD1D5DB),
                    width: 1.5),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(comp['name']?.toString() ?? '',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? color : const Color(0xFF1A1A2E))),
                  if (type == 'Percentage' && formula.isNotEmpty)
                    Text('$formula% of Basic',
                        style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF9CA3AF))),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: type == 'Fixed'
                    ? const Color(0xFFEFF6FF)
                    : color.withAlpha(20),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(type,
                  style: TextStyle(
                      fontSize: 9, fontWeight: FontWeight.w700,
                      color: type == 'Fixed'
                          ? const Color(0xFF2563EB) : color,
                      letterSpacing: 0.3)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Text(label,
        style: TextStyle(
            fontSize: 9, letterSpacing: 1.0,
            color: color, fontWeight: FontWeight.w700)),
  );

  InputDecoration _inputDecor(
          String label, String hint, IconData icon) =>
      InputDecoration(
        labelText: label, hintText: hint,
        labelStyle: const TextStyle(fontSize: 12),
        hintStyle:
            const TextStyle(color: Color(0xFFD1D5DB), fontSize: 12),
        prefixIcon:
            Icon(icon, color: const Color(0xFF9CA3AF), size: 16),
        filled: true, fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
                color: Color(0xFFE03E2D), width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
      );

}
// ═══════════════════════════════════════════════════════
//  QUICK-ADD DIALOG (reusable inline create helper)
// ═══════════════════════════════════════════════════════

/// Data class describing one field inside a _QuickAddDialog
class _QField {
  final TextEditingController ctrl;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;

  const _QField({
    required this.ctrl,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType = TextInputType.text,
  });
}

/// Generic quick-create dialog. Shows [fields], calls [onSave] on confirm,
/// returns the newly created map (or null if cancelled/failed).
class _QuickAddDialog extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final List<_QField> fields;
  final Future<Map<String, dynamic>?> Function() onSave;

  const _QuickAddDialog({
    required this.title,
    required this.icon,
    required this.iconColor,
    this.iconBg = const Color(0xFFF3F4F6),
    required this.fields,
    required this.onSave,
  });

  @override
  State<_QuickAddDialog> createState() => _QuickAddDialogState();
}

class _QuickAddDialogState extends State<_QuickAddDialog> {
  bool _saving = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      title: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: widget.iconBg,
            child: Icon(widget.icon, color: widget.iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Text(widget.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: Color(0xFFDC2626), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!,
                          style: const TextStyle(
                              color: Color(0xFFDC2626), fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ],
            ...List.generate(widget.fields.length, (i) {
              final f = widget.fields[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: f.ctrl,
                  keyboardType: f.keyboardType,
                  autofocus: i == 0,
                  decoration: InputDecoration(
                    labelText: f.label,
                    hintText: f.hint,
                    hintStyle: const TextStyle(color: Color(0xFFD1D5DB)),
                    prefixIcon:
                        Icon(f.icon, color: const Color(0xFF9CA3AF), size: 18),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: Color(0xFFE03E2D), width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 12),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel',
              style: TextStyle(color: Color(0xFF6B7280))),
        ),
        ElevatedButton(
          onPressed: _saving
              ? null
              : () async {
                  setState(() { _saving = true; _error = null; });
                  try {
                    final result = await widget.onSave();
                    if (result == null) {
                      setState(() {
                        _error = 'Please fill in all required fields.';
                        _saving = false;
                      });
                      return;
                    }
                    if (mounted) Navigator.pop(context, result);
                  } catch (e) {
                    setState(() {
                      _error = e.toString().replaceAll('Exception: ', '');
                      _saving = false;
                    });
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE03E2D),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Text('Save',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

Map<String, dynamic> _calculateSalaryBreakdown(double baseSalary, Map<String, dynamic> structure) {
  final components = List<Map<String, dynamic>>.from(structure['components'] ?? structure['hr_salary_components'] ?? []);
  
  double basic = baseSalary; // default fallback
  
  // Find basic component
  final basicComp = components.firstWhere(
    (c) => c['name'].toString().toLowerCase().contains('basic'),
    orElse: () => {},
  );
  
  if (basicComp.isNotEmpty) {
    final type = basicComp['type']?.toString();
    final formula = basicComp['formula']?.toString() ?? '';
    if (type == 'Percentage') {
      final pct = double.tryParse(formula.replaceAll('%', '').trim()) ?? 50.0;
      basic = baseSalary * (pct / 100.0);
    } else if (type == 'Formula') {
      basic = _evalFormula(formula, baseSalary: baseSalary, basic: baseSalary);
    } else if (type == 'Fixed') {
      basic = double.tryParse(formula) ?? baseSalary;
    } else {
      basic = baseSalary; 
    }
  }

  final List<Map<String, dynamic>> earnings = [];
  final List<Map<String, dynamic>> deductions = [];
  
  double totalEarnings = 0.0;
  double totalDeductions = 0.0;

  final List<Map<String, dynamic>> fixedEarnings = [];
  final List<Map<String, dynamic>> fixedDeductions = [];

  for (final comp in components) {
    final name = comp['name']?.toString() ?? '';
    final nature = comp['nature']?.toString() ?? 'Earning';
    final type = comp['type']?.toString() ?? 'Fixed';
    final formula = comp['formula']?.toString() ?? '';

    if (comp['id'] == basicComp['id']) {
      earnings.add({
        'name': name,
        'value': basic,
        'nature': 'Earning',
        'type': type,
      });
      totalEarnings += basic;
      continue;
    }

    if (type == 'Fixed') {
      if (nature == 'Earning') {
        fixedEarnings.add(comp);
      } else {
        fixedDeductions.add(comp);
      }
      continue;
    }

    double val = 0.0;
    if (type == 'Percentage') {
      final pct = double.tryParse(formula.replaceAll('%', '').trim()) ?? 0.0;
      val = basic * (pct / 100.0);
    } else if (type == 'Formula') {
      val = _evalFormula(formula, baseSalary: baseSalary, basic: basic);
    }

    if (nature == 'Earning') {
      earnings.add({
        'name': name,
        'value': val,
        'nature': 'Earning',
        'type': type,
      });
      totalEarnings += val;
    } else {
      deductions.add({
        'name': name,
        'value': val,
        'nature': 'Deduction',
        'type': type,
      });
      totalDeductions += val;
    }
  }

  for (final comp in fixedDeductions) {
    final name = comp['name']?.toString() ?? '';
    double val = 0.0;
    if (name.toLowerCase().contains('tax') || name.toLowerCase().contains('pt')) {
      val = 200.0;
    } else {
      val = 0.0; 
    }
    deductions.add({
      'name': name,
      'value': val,
      'nature': 'Deduction',
      'type': 'Fixed',
    });
    totalDeductions += val;
  }

  if (fixedEarnings.isNotEmpty) {
    final remainder = baseSalary - totalEarnings;
    final valPerComp = remainder > 0 ? remainder / fixedEarnings.length : 0.0;
    for (final comp in fixedEarnings) {
      final name = comp['name']?.toString() ?? '';
      earnings.add({
        'name': name,
        'value': valPerComp,
        'nature': 'Earning',
        'type': 'Fixed',
      });
      totalEarnings += valPerComp;
    }
  }

  // Safety check: If no explicit Basic or Base salary component was added in the earnings list,
  // we automatically inject the Base Salary as the foundation of the earnings.
  final bool hasBasic = earnings.any((e) {
    final name = e['name'].toString().toLowerCase();
    return name.contains('basic') || name.contains('base');
  });
  
  if (!hasBasic) {
    earnings.insert(0, {
      'name': 'Basic Salary',
      'value': baseSalary,
      'nature': 'Earning',
      'type': 'Fixed',
    });
    totalEarnings += baseSalary;
  }

  final netSalary = totalEarnings - totalDeductions;

  return {
    'earnings': earnings,
    'deductions': deductions,
    'totalEarnings': totalEarnings,
    'totalDeductions': totalDeductions,
    'netSalary': netSalary,
  };
}

double _evalFormula(String formula, {required double baseSalary, required double basic}) {
  try {
    String f = formula.toLowerCase()
      .replaceAll('basic', basic.toString())
      .replaceAll('base_salary', baseSalary.toString())
      .replaceAll('base', baseSalary.toString())
      .replaceAll(' ', '');
      
    final RegExp doubleRegExp = RegExp(r'^\d+(\.\d+)?$');
    if (doubleRegExp.hasMatch(f)) {
      return double.tryParse(f) ?? 0.0;
    }
    
    if (f.contains('*')) {
      final parts = f.split('*');
      final val1 = double.tryParse(parts[0]) ?? 0.0;
      final val2 = double.tryParse(parts[1]) ?? 0.0;
      return val1 * val2;
    }
    if (f.contains('/')) {
      final parts = f.split('/');
      final val1 = double.tryParse(parts[0]) ?? 0.0;
      final val2 = double.tryParse(parts[1]) ?? 1.0;
      return val1 / val2;
    }
    if (f.contains('+')) {
      final parts = f.split('+');
      final val1 = double.tryParse(parts[0]) ?? 0.0;
      final val2 = double.tryParse(parts[1]) ?? 0.0;
      return val1 + val2;
    }
    if (f.contains('-')) {
      final parts = f.split('-');
      final val1 = double.tryParse(parts[0]) ?? 0.0;
      final val2 = double.tryParse(parts[1]) ?? 0.0;
      return val1 - val2;
    }
    
    return double.tryParse(f) ?? 0.0;
  } catch (_) {
    return 0.0;
  }
}
