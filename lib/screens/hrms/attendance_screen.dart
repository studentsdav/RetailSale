import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({Key? key}) : super(key: key);

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _currentMonth = DateTime.now();
  bool _isLoading = false;
  String _selectedEmployee = 'All';
  
  List<Map<String, dynamic>> _leaveRequests = [];
  List<Map<String, dynamic>> _loanRequests = [];
  List<Map<String, dynamic>> _attendancePunches = [];
  List<Map<String, dynamic>> _employeesList = [];
  List<Map<String, dynamic>> _shiftsList = [];
  List<Map<String, dynamic>> _holidaysList = [];
  List<Map<String, dynamic>> _leaveTypesList = [];
  final _searchCtrl = TextEditingController();
  final ScrollController _heatmapHorizontalController = ScrollController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tabController.dispose();
    _heatmapHorizontalController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }
  
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        ApiClient.get(ApiEndpoints.hrmsEmployees),
        ApiClient.get('${ApiEndpoints.hrmsAttendance}?month=${_currentMonth.year}-${_currentMonth.month.toString().padLeft(2, '0')}'),
        ApiClient.get(ApiEndpoints.hrmsLeaves),
        ApiClient.get(ApiEndpoints.hrmsLoans),
        ApiClient.get(ApiEndpoints.hrmsShifts),
        ApiClient.get('/api/hrms/holidays'),
        ApiClient.get(ApiEndpoints.hrmsLeaveTypes),
      ]);
      setState(() {
        _employeesList     = List<Map<String, dynamic>>.from(results[0]['data'] ?? []);
        _attendancePunches = List<Map<String, dynamic>>.from(results[1]['data'] ?? []);
        _leaveRequests     = List<Map<String, dynamic>>.from(results[2]['data'] ?? []);
        _loanRequests      = List<Map<String, dynamic>>.from(results[3]['data'] ?? []);
        _shiftsList        = List<Map<String, dynamic>>.from(results[4]['data'] ?? []);
        _holidaysList      = List<Map<String, dynamic>>.from(results[5]['data'] ?? []);
        _leaveTypesList    = List<Map<String, dynamic>>.from(results[6]['data'] ?? []);
      });
    } catch (_) {}
    finally { setState(() => _isLoading = false); }
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
      _loadData();
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
      _loadData();
    });
  }

  String _monthYearString(DateTime date) {
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _lookupEmployeeName(dynamic id) {
    if (id == null) return '—';
    final found = _employeesList.where((e) => e['id'].toString() == id.toString()).toList();
    return found.isNotEmpty ? (found.first['full_name'] ?? '—').toString() : 'Employee #$id';
  }

  double _getEmployeeShiftDuration(dynamic empId) {
    if (empId == null) return 8.0;
    final found = _employeesList.where((e) => e['id'].toString() == empId.toString()).toList();
    if (found.isEmpty) return 8.0;
    final emp = found.first;
    final shift = emp['shift'] ?? {};
    final startStr = shift['start_time']?.toString() ?? '09:00:00';
    final endStr = shift['end_time']?.toString() ?? '17:00:00';
    try {
      final sParts = startStr.split(':');
      final eParts = endStr.split(':');
      final sH = int.parse(sParts[0]);
      final sM = int.parse(sParts[1]);
      final eH = int.parse(eParts[0]);
      final eM = int.parse(eParts[1]);
      int diff = (eH * 60 + eM) - (sH * 60 + sM);
      if (diff <= 0) diff += 1440;
      return diff / 60.0;
    } catch (_) {
      return 8.0;
    }
  }

  String _fmtTimeOnly(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) return '—';
    try {
      final dt = DateTime.parse(dateTimeStr).toLocal();
      final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final m = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '$h:$m $period';
    } catch (_) {
      return dateTimeStr;
    }
  }

  Future<void> _handleLeaveAction(int id, bool approve) async {
    setState(() => _isLoading = true);
    try {
      final action = approve ? 'approve' : 'reject';
      final res = await ApiClient.put('${ApiEndpoints.hrmsLeaves}/$id/$action', {});
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Leave successfully ${approve ? "approved" : "rejected"}'),
            backgroundColor: approve ? const Color(0xFF059669) : const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {}
    finally { _loadData(); }
  }

  Future<void> _handleLoanAction(int id, String status) async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiClient.put('${ApiEndpoints.hrmsLoans}/$id/status', {'status': status});
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Loan request successfully $status'),
            backgroundColor: status == 'Approved' ? const Color(0xFF059669) : const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {}
    finally { _loadData(); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Attendance & Approvals', style: TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.bold, fontSize: 17)),
        iconTheme: const IconThemeData(color: Color(0xFF1A1A2E)),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.beach_access, color: Color(0xFFE03E2D), size: 18),
            label: const Text('Apply Bulk Leave', style: TextStyle(color: Color(0xFFE03E2D), fontWeight: FontWeight.bold, fontSize: 13)),
            onPressed: _showBulkLeaveDialog,
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            icon: const Icon(Icons.calendar_month, color: Color(0xFFE03E2D), size: 18),
            label: const Text('Auto-Apply Weekly Offs', style: TextStyle(color: Color(0xFFE03E2D), fontWeight: FontWeight.bold, fontSize: 13)),
            onPressed: _runAutoWeeklyOffs,
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            icon: const Icon(Icons.event_note, color: Color(0xFFE03E2D), size: 18),
            label: const Text('Holidays', style: TextStyle(color: Color(0xFFE03E2D), fontWeight: FontWeight.bold, fontSize: 13)),
            onPressed: _showHolidaysDialog,
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFE03E2D),
          unselectedLabelColor: const Color(0xFF6B7280),
          indicatorColor: const Color(0xFFE03E2D),
          tabs: const [
            Tab(text: 'SUMMARY'),
            Tab(text: 'ATTENDANCE LOG'),
            Tab(text: 'PENDING APPROVALS'),
          ],
        ),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE03E2D)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildSummaryTab(),
                _buildAttendanceLogTab(),
                _buildApprovalsTab(),
              ],
            ),
    );
  }

  Widget _buildMonthPicker() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(icon: const Icon(Icons.chevron_left), onPressed: _previousMonth),
        Text(_monthYearString(_currentMonth), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
        IconButton(icon: const Icon(Icons.chevron_right), onPressed: _nextMonth),
      ],
    );
  }

  Widget _buildSummaryTab() {
    final daysInMonth = DateUtils.getDaysInMonth(_currentMonth.year, _currentMonth.month);
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    bool isMarkedToday(int employeeId) {
      return _attendancePunches.any((p) => p['employee_id'] == employeeId && p['punch_date'].toString().startsWith(todayStr));
    }

    final query = _searchCtrl.text.toLowerCase().trim();
    final filteredEmployees = _employeesList.where((emp) {
      final name = (emp['full_name'] ?? '').toString().toLowerCase();
      final code = (emp['employee_code'] ?? '').toString().toLowerCase();
      return name.contains(query) || code.contains(query);
    }).toList();

    // Sort unmarked employees to the top
    filteredEmployees.sort((a, b) {
      final markedA = isMarkedToday(a['id'] as int);
      final markedB = isMarkedToday(b['id'] as int);
      if (markedA == markedB) return 0;
      return markedA ? 1 : -1;
    });

    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFF2563EB), size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'To mark/edit attendance manually, click on any employee name or calendar date cell.',
                  style: TextStyle(color: Color(0xFF1E40AF), fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        _buildMonthPicker(),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (val) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search employees...',
              prefixIcon: const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
        const SizedBox(height: 6),
        _buildLegend(),
        Expanded(
          child: _card(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  color: const Color(0xFF1E3A5F),
                  child: const Text('Employee Attendance Heatmap', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                Expanded(
                  child: filteredEmployees.isEmpty
                      ? const Center(child: Text('No matching employee records found.', style: TextStyle(color: Colors.grey)))
                      : SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: Scrollbar(
                            controller: _heatmapHorizontalController,
                            thumbVisibility: true,
                            trackVisibility: true,
                            thickness: 8.0,
                            child: SingleChildScrollView(
                              controller: _heatmapHorizontalController,
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(const Color(0xFF1E3A5F).withOpacity(0.9)),
                                columns: [
                                  const DataColumn(label: Text('Employee Name', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                  for (int i = 1; i <= daysInMonth; i++)
                                    DataColumn(label: Text(i.toString().padLeft(2, '0'), style: const TextStyle(color: Colors.white))),
                                ],
                                rows: filteredEmployees.map((emp) {
                                  final empId = emp['id'] as int;
                                  final marked = isMarkedToday(empId);
                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        InkWell(
                                          onTap: () {
                                            final defaultDay = (DateTime.now().month == _currentMonth.month && DateTime.now().year == _currentMonth.year)
                                                ? DateTime.now().day
                                                : 1;
                                            final dateStr = '${_currentMonth.year}-${_currentMonth.month.toString().padLeft(2, '0')}-${defaultDay.toString().padLeft(2, '0')}';
                                            final punch = _attendancePunches.firstWhere(
                                              (p) => p['employee_id'] == empId && p['punch_date'].toString().startsWith(dateStr),
                                              orElse: () => {},
                                            );
                                            _showPunchDialog(empId, dateStr, punch);
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: marked ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              emp['full_name'] ?? '—',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: marked ? const Color(0xFF059669) : const Color(0xFFDC2626),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      for (int i = 1; i <= daysInMonth; i++)
                                        DataCell(_buildHeatmapCell(i, empId)),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildHeatmapCell(int day, int employeeId) {
    final dateStr = '${_currentMonth.year}-${_currentMonth.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
    final punch = _attendancePunches.firstWhere(
      (p) => p['employee_id'] == employeeId && p['punch_date'].toString().startsWith(dateStr),
      orElse: () => {},
    );
    
    String status = '';
    if (punch.isNotEmpty) {
      final s = punch['status']?.toString().toLowerCase() ?? '';
      if (s == 'present') {
        status = 'P';
      } else if (s == 'absent') {
        status = 'A';
      } else if (s == 'leave' || s == 'on-leave' || s == 'unpaid leave' || s == 'paid leave') {
        status = 'L';
      } else if (s == 'half day' || s == 'half-day') {
        status = 'H';
      } else if (s == 'holiday') {
        status = 'F';
      } else if (s == 'weekly off' || s == 'weekly-off') {
        status = 'W';
      }
    } else {
      final emp = _employeesList.firstWhere((e) => e['id'] == employeeId, orElse: () => {});
      final shift = emp['shift'] ?? {};
      final weeklyOffs = shift['weekly_offs'] ?? ['Sunday'];
      final date = DateTime.tryParse(dateStr);
      if (date != null) {
        bool isWeeklyOff = false;
        final dayName = DateFormat('EEEE').format(date);
        if (weeklyOffs.contains(dayName)) {
          isWeeklyOff = true;
        } else if (dayName == 'Saturday') {
          int satCount = 0;
          for (int d = 1; d <= date.day; d++) {
            if (DateTime(date.year, date.month, d).weekday == DateTime.saturday) {
              satCount++;
            }
          }
          final checkStr = "${satCount}${satCount == 1 ? 'st' : satCount == 2 ? 'nd' : satCount == 3 ? 'rd' : 'th'} Saturday";
          if (weeklyOffs.contains(checkStr)) isWeeklyOff = true;
        }
        if (isWeeklyOff) status = 'W';
      }
    }
    
    Color bg = Colors.white;
    Color text = Colors.black;
    if (status == 'P') { bg = const Color(0xFFECFDF5); text = const Color(0xFF059669); }
    else if (status == 'A') { bg = const Color(0xFFFEF2F2); text = const Color(0xFFDC2626); }
    else if (status == 'L') { bg = const Color(0xFFFFFBEB); text = const Color(0xFFD97706); }
    else if (status == 'H') { bg = const Color(0xFFFFF7ED); text = const Color(0xFFEA580C); }
    else if (status == 'W') { bg = const Color(0xFFF3F4F6); text = const Color(0xFF6B7280); }
    else if (status == 'F') { bg = const Color(0xFFEFF6FF); text = const Color(0xFF2563EB); }
    
    return InkWell(
      onTap: () => _showPunchDialog(employeeId, dateStr, punch),
      child: Container(
        margin: const EdgeInsets.all(2),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5)),
        child: Text(status, style: TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: 10)),
      ),
    );
  }
 
  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendItem('P', 'Present', const Color(0xFFECFDF5), const Color(0xFF059669)),
        const SizedBox(width: 8),
        _legendItem('A', 'Absent', const Color(0xFFFEF2F2), const Color(0xFFDC2626)),
        const SizedBox(width: 8),
        _legendItem('L', 'Leave', const Color(0xFFFFFBEB), const Color(0xFFD97706)),
        const SizedBox(width: 8),
        _legendItem('H', 'Half Day', const Color(0xFFFFF7ED), const Color(0xFFEA580C)),
        const SizedBox(width: 8),
        _legendItem('W', 'Weekly Off', const Color(0xFFF3F4F6), const Color(0xFF6B7280)),
        const SizedBox(width: 8),
        _legendItem('F', 'Holiday', const Color(0xFFEFF6FF), const Color(0xFF2563EB)),
      ],
    );
  }

  Widget _legendItem(String code, String label, Color bg, Color text) {
    return Row(
      children: [
        Container(
          width: 20, height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
          child: Text(code, style: TextStyle(color: text, fontSize: 10, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
      ],
    );
  }

  Widget _buildAttendanceLogTab() {
    final filteredPunches = (_selectedEmployee == 'All'
        ? _attendancePunches
        : _attendancePunches.where((p) => p['employee_id'].toString() == _selectedEmployee).toList())
      ..sort((a, b) {
        final da = a['punch_date']?.toString() ?? '';
        final db = b['punch_date']?.toString() ?? '';
        return da.compareTo(db);
      });

    return Column(
      children: [
        _card(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedEmployee,
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<String>(value: 'All', child: Text('All Employees')),
                      ..._employeesList.map((e) => DropdownMenuItem<String>(
                            value: e['id'].toString(),
                            child: Text('${e['full_name']} (${e['employee_code']})'),
                          )),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedEmployee = v);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 16),
              _buildMonthPicker(),
            ],
          ),
        ),
        Expanded(
          child: _card(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: filteredPunches.isEmpty
                      ? const Center(child: Text('No attendance records found for this selection.', style: TextStyle(color: Colors.grey)))
                      : SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              showCheckboxColumn: false,
                              headingRowColor: WidgetStateProperty.all(const Color(0xFF1E3A5F)),
                              columns: const [
                                DataColumn(label: Text('Date', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Employee', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Status', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('In Time', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Out Time', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Req. Hours', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Work Hours', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Overtime', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Less Hours', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                DataColumn(label: Text('Source', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                              ],
                              rows: filteredPunches.map((punch) {
                                final empName = _lookupEmployeeName(punch['employee_id']);
                                final empId = punch['employee_id'] as int;
                                final dateStr = punch['punch_date']?.toString() ?? '';

                                return DataRow(
                                  onSelectChanged: (selected) {
                                    if (selected == true) {
                                      _showPunchDialog(empId, dateStr, punch);
                                    }
                                  },
                                  cells: [
                                    DataCell(Text(punch['punch_date']?.toString() ?? '')),
                                    DataCell(Text(empName)),
                                    DataCell(_buildStatusChip(punch['status']?.toString() ?? 'Present')),
                                    DataCell(Text(punch['punch_in'] != null ? _fmtTimeOnly(punch['punch_in']) : '—')),
                                    DataCell(Text(punch['punch_out'] != null ? _fmtTimeOnly(punch['punch_out']) : '—')),
                                    DataCell(Builder(builder: (context) {
                                       final reqHrs = _getEmployeeShiftDuration(empId);
                                       return Text('${reqHrs.toStringAsFixed(2)} hrs');
                                    })),
                                    DataCell(Builder(builder: (context) {
                                      double hrs = 0.0;
                                      if (punch['punch_in'] != null && punch['punch_out'] != null) {
                                        final inDt = DateTime.tryParse(punch['punch_in'].toString())?.toLocal();
                                        final outDt = DateTime.tryParse(punch['punch_out'].toString())?.toLocal();
                                        if (inDt != null && outDt != null) {
                                          hrs = outDt.difference(inDt).inMinutes / 60.0;
                                        }
                                      } else {
                                        hrs = double.tryParse(punch['hours_worked']?.toString() ?? '0') ?? 0.0;
                                      }
                                      return Text('${hrs.toStringAsFixed(2)} hrs', style: const TextStyle(fontWeight: FontWeight.bold));
                                    })),
                                    DataCell(Builder(builder: (context) {
                                      double hrs = 0.0;
                                      if (punch['punch_in'] != null && punch['punch_out'] != null) {
                                        final inDt = DateTime.tryParse(punch['punch_in'].toString())?.toLocal();
                                        final outDt = DateTime.tryParse(punch['punch_out'].toString())?.toLocal();
                                        if (inDt != null && outDt != null) {
                                          hrs = outDt.difference(inDt).inMinutes / 60.0;
                                        }
                                      } else {
                                        hrs = double.tryParse(punch['hours_worked']?.toString() ?? '0') ?? 0.0;
                                      }
                                      final reqHrs = _getEmployeeShiftDuration(empId);
                                      final savedOt = punch['overtime_hours'] != null ? double.tryParse(punch['overtime_hours'].toString()) : null;
                                      final ot = savedOt ?? (hrs > reqHrs ? (hrs - reqHrs) : 0.0);
                                      return Text(
                                        '${ot.toStringAsFixed(2)} hrs',
                                        style: TextStyle(
                                          color: ot > 0 ? const Color(0xFF059669) : Colors.grey,
                                          fontWeight: ot > 0 ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      );
                                    })),
                                    DataCell(Builder(builder: (context) {
                                      double hrs = 0.0;
                                      if (punch['punch_in'] != null && punch['punch_out'] != null) {
                                        final inDt = DateTime.tryParse(punch['punch_in'].toString())?.toLocal();
                                        final outDt = DateTime.tryParse(punch['punch_out'].toString())?.toLocal();
                                        if (inDt != null && outDt != null) {
                                          hrs = outDt.difference(inDt).inMinutes / 60.0;
                                        }
                                      } else {
                                        hrs = double.tryParse(punch['hours_worked']?.toString() ?? '0') ?? 0.0;
                                      }
                                      final reqHrs = _getEmployeeShiftDuration(empId);
                                      final statusLower = punch['status']?.toString().toLowerCase() ?? '';
                                      final isWorkedDay = statusLower == 'present' || statusLower == 'half day' || statusLower == 'half-day';
                                      final less = (isWorkedDay && hrs < reqHrs) ? (reqHrs - hrs) : 0.0;
                                      return Text(
                                        '${less.toStringAsFixed(2)} hrs',
                                        style: TextStyle(
                                          color: less > 0 ? const Color(0xFFDC2626) : Colors.grey,
                                          fontWeight: less > 0 ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      );
                                    })),
                                    DataCell(Text(punch['punch_source']?.toString() ?? 'System')),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildApprovalsTab() {
    final pendingLeaves = _leaveRequests.where((l) => l['status'].toString().toLowerCase() == 'pending').toList();
    final pendingLoans = _loanRequests.where((l) => l['status'].toString().toLowerCase() == 'pending' || l['status'].toString().toLowerCase() == 'active').toList();

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        _sectionHeader('Leave Requests needing Approval (${pendingLeaves.length})'),
        if (pendingLeaves.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Text('No pending leave applications.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 13)),
          )
        else
          ...pendingLeaves.map((l) {
            final empName = _lookupEmployeeName(l['employee_id']);
            final leaveTypeName = l['leaveType'] != null ? (l['leaveType']['name'] ?? 'Leave') : 'Leave';
            final totalDays = l['total_days'] ?? 0;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(empName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(12)),
                        child: Text(leaveTypeName, style: const TextStyle(color: Color(0xFFD97706), fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Duration: ${l['start_date']} to ${l['end_date']} ($totalDays days)', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                  if (l['reason'] != null && l['reason'].toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('Reason: "${l['reason']}"', style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563), fontStyle: FontStyle.italic)),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFEF2F2),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: () => _handleLeaveAction(l['id'], false),
                        child: const Text('Reject', style: TextStyle(color: Color(0xFFDC2626), fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFECFDF5),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: () => _handleLeaveAction(l['id'], true),
                        child: const Text('Approve', style: TextStyle(color: Color(0xFF059669), fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        
        const SizedBox(height: 16),
        _sectionHeader('Loan & Advance Requests needing Approval (${pendingLoans.length})'),
        if (pendingLoans.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Text('No pending loan/advance requests.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 13)),
          )
        else
          ...pendingLoans.map((loan) {
            final empName = _lookupEmployeeName(loan['employee_id']);
            final amount = loan['loan_amount'] ?? 0;
            final emi = loan['monthly_emi'] ?? 0;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(empName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12)),
                        child: const Text('Loan Request', style: TextStyle(color: Color(0xFF2563EB), fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Amount Requested: ₹$amount', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
                  Text('Proposed EMI: ₹$emi/month', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                  if (loan['notes'] != null && loan['notes'].toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('Notes: "${loan['notes']}"', style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563), fontStyle: FontStyle.italic)),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFEF2F2),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: () => _handleLoanAction(loan['id'], 'Rejected'),
                        child: const Text('Reject', style: TextStyle(color: Color(0xFFDC2626), fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFECFDF5),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: () => _handleLoanAction(loan['id'], 'Approved'),
                        child: const Text('Approve', style: TextStyle(color: Color(0xFF059669), fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E3A5F), letterSpacing: 0.5)),
    );
  }

  void _showManualPunchDialog() {
    final inCtrl = TextEditingController();
    final outCtrl = TextEditingController();
    String? selectedEmpId;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manual Attendance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Employee'),
              items: _employeesList.map((e) => DropdownMenuItem(value: e['id'].toString(), child: Text(e['full_name'] ?? ''))).toList(),
              onChanged: (v) => selectedEmpId = v,
            ),
            const SizedBox(height: 16),
            TextFormField(controller: inCtrl, decoration: const InputDecoration(labelText: 'Punch In Time', hintText: 'YYYY-MM-DD HH:MM:SS')),
            const SizedBox(height: 16),
            TextFormField(controller: outCtrl, decoration: const InputDecoration(labelText: 'Punch Out Time', hintText: 'YYYY-MM-DD HH:MM:SS')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (selectedEmpId == null) return;
              try {
                await ApiClient.post('${ApiEndpoints.hrmsAttendance}/manual', {
                  'employee_id': int.parse(selectedEmpId!),
                  'punch_date': inCtrl.text.split(' ')[0],
                  'punch_in': inCtrl.text,
                  'punch_out': outCtrl.text.isEmpty ? null : outCtrl.text,
                  'status': 'Present',
                });
                Navigator.pop(context);
                _loadData();
              } catch (_) {}
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE03E2D)),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showBulkLeaveDialog() {
    int? selectedEmpId;
    int? selectedLeaveTypeId;
    DateTime? startDate;
    DateTime? endDate;
    List<Map<String, dynamic>> employeeLeaveBalances = [];
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final emp = _employeesList.firstWhere((e) => e['id'] == selectedEmpId, orElse: () => {});
          if (emp.isNotEmpty && employeeLeaveBalances.isEmpty) {
            employeeLeaveBalances = emp['leaveBalances'] != null
                ? List<Map<String, dynamic>>.from(emp['leaveBalances'])
                : [];
          }

          String fmtDate(DateTime? d) {
            if (d == null) return 'Select Date';
            return DateFormat('yyyy-MM-dd').format(d);
          }

          Future<void> pickDateRange() async {
            final picked = await showDateRangePicker(
              context: ctx,
              firstDate: DateTime(2025),
              lastDate: DateTime(2030),
              initialDateRange: startDate != null && endDate != null
                  ? DateTimeRange(start: startDate!, end: endDate!)
                  : null,
            );
            if (picked != null) {
              setS(() {
                startDate = picked.start;
                endDate = picked.end;
              });
            }
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Apply Bulk Leave', style: TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Employee', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF4B5563))),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    value: selectedEmpId,
                    items: _employeesList.map((e) {
                      return DropdownMenuItem<int>(
                        value: e['id'] as int,
                        child: Text(e['full_name'] ?? ''),
                      );
                    }).toList(),
                    onChanged: (v) {
                      setS(() {
                        selectedEmpId = v;
                        selectedLeaveTypeId = null;
                        employeeLeaveBalances = [];
                      });
                    },
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      hintText: 'Choose Employee',
                    ),
                  ),
                  if (selectedEmpId != null) ...[
                    const SizedBox(height: 16),
                    const Text('Leave Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF4B5563))),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      value: selectedLeaveTypeId != null && _leaveTypesList.any((lt) => lt['id'] == selectedLeaveTypeId) ? selectedLeaveTypeId : null,
                      items: _leaveTypesList.map((lt) {
                        final ltId = lt['id'] as int;
                        final ltName = lt['name'] ?? 'Leave';
                        final bal = employeeLeaveBalances.firstWhere((b) => b['leave_type_id'] == ltId, orElse: () => {});
                        double allocated = double.tryParse(lt['annual_quota']?.toString() ?? '14') ?? 14.0;
                        double used = 0;
                        if (bal.isNotEmpty) {
                          allocated = double.tryParse(bal['allocated_quota']?.toString() ?? '0') ?? 0.0;
                          used = double.tryParse(bal['used_quota']?.toString() ?? '0') ?? 0.0;
                        }
                        final remaining = allocated - used;
                        return DropdownMenuItem<int>(
                          value: ltId,
                          child: Text('$ltName ($remaining/$allocated remaining)'),
                        );
                      }).toList(),
                      onChanged: (v) {
                        setS(() {
                          selectedLeaveTypeId = v;
                        });
                      },
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        hintText: 'Select Leave Type',
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Date Range', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF4B5563))),
                    const SizedBox(height: 6),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: pickDateRange,
                      icon: const Icon(Icons.date_range, color: Color(0xFFE03E2D), size: 18),
                      label: Text(
                        startDate == null
                            ? 'Choose Start & End Dates'
                            : '${fmtDate(startDate)}  to  ${fmtDate(endDate)}',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF6B7280))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE03E2D),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: (selectedEmpId == null || selectedLeaveTypeId == null || startDate == null || endDate == null || isSaving)
                    ? null
                    : () async {
                        setS(() => isSaving = true);
                        try {
                          final bal = employeeLeaveBalances.firstWhere((b) => b['leave_type_id'] == selectedLeaveTypeId, orElse: () => {});
                          final activeLt = _leaveTypesList.firstWhere((lt) => lt['id'] == selectedLeaveTypeId, orElse: () => {});
                          double allocated = double.tryParse(activeLt['annual_quota']?.toString() ?? '14') ?? 14.0;
                          double used = 0;
                          if (bal.isNotEmpty) {
                            allocated = double.tryParse(bal['allocated_quota']?.toString() ?? '0') ?? 0.0;
                            used = double.tryParse(bal['used_quota']?.toString() ?? '0') ?? 0.0;
                          }
                          double remaining = allocated - used;

                          final List<Future> requests = [];
                          for (DateTime date = startDate!; date.isBefore(endDate!.add(const Duration(days: 1))); date = date.add(const Duration(days: 1))) {
                            final dateStr = DateFormat('yyyy-MM-dd').format(date);

                            // Check if Holiday
                            bool isHoliday = _holidaysList.any((h) => h['holiday_date'] == dateStr);

                            // Check if Weekly Off
                            bool isWeeklyOff = false;
                            final shift = emp['shift'] ?? {};
                            final weeklyOffs = shift['weekly_offs'] ?? ['Sunday'];
                            final dayName = DateFormat('EEEE').format(date);
                            if (weeklyOffs.contains(dayName)) {
                              isWeeklyOff = true;
                            } else if (dayName == 'Saturday') {
                              int satCount = 0;
                              for (int d = 1; d <= date.day; d++) {
                                if (DateTime(date.year, date.month, d).weekday == DateTime.saturday) {
                                  satCount++;
                                }
                              }
                              final checkStr = "${satCount}${satCount == 1 ? 'st' : satCount == 2 ? 'nd' : satCount == 3 ? 'rd' : 'th'} Saturday";
                              if (weeklyOffs.contains(checkStr)) isWeeklyOff = true;
                            }

                            if (isHoliday || isWeeklyOff) {
                              continue; // Skip holiday and weekly off days
                            }

                            String statusStr = 'Unpaid Leave';
                            if (remaining > 0) {
                              statusStr = 'Leave';
                              remaining -= 1.0;
                            }

                            final payload = {
                              'employee_id': selectedEmpId,
                              'punch_date': dateStr,
                              'punch_in': null,
                              'punch_out': null,
                              'status': statusStr,
                              'hours_worked': 0.0,
                              'overtime_hours': 0.0,
                              'lateness_mins': 0,
                              'punch_source': 'Manual',
                              'leave_type_id': selectedLeaveTypeId,
                            };

                            requests.add(ApiClient.post('/api/hrms/attendance/manual', payload));
                          }

                          await Future.wait(requests);
                          Navigator.pop(ctx);
                          _loadData();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Bulk leave applied successfully!'),
                              backgroundColor: Color(0xFF059669),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        } catch (e) {
                          setS(() => isSaving = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      },
                child: isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Apply', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bg, fg;
    switch (status.toLowerCase()) {
      case 'present': bg = const Color(0xFFECFDF5); fg = const Color(0xFF059669); break;
      case 'absent': bg = const Color(0xFFFEF2F2); fg = const Color(0xFFDC2626); break;
      case 'half-day': bg = const Color(0xFFFFF7ED); fg = const Color(0xFFEA580C); break;
      case 'on-leave': bg = const Color(0xFFFFFBEB); fg = const Color(0xFFD97706); break;
      case 'active': bg = const Color(0xFFECFDF5); fg = const Color(0xFF059669); break;
      case 'approved': bg = const Color(0xFFEFF6FF); fg = const Color(0xFF2563EB); break;
      case 'terminated': bg = const Color(0xFFFEF2F2); fg = const Color(0xFFDC2626); break;
      default: bg = const Color(0xFFF3F4F6); fg = const Color(0xFF6B7280);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(status, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Future<void> _runAutoWeeklyOffs() async {
    setState(() => _isLoading = true);
    try {
      final monthStr = DateFormat('yyyy-MM').format(_currentMonth);
      final res = await ApiClient.post('/api/hrms/attendance/auto-weekly-offs', {
        'month': monthStr,
      });
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Weekly offs applied successfully!'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      await _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showHolidaysDialog() {
    final nameCtrl = TextEditingController();
    DateTime? selectedDate = DateTime.now();
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.event_note, color: Color(0xFFE03E2D)),
              SizedBox(width: 8),
              Text('Calendar Holidays', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: 400,
            height: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Add holiday form
                const Text('Mark New Holiday', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E3A5F))),
                const SizedBox(height: 8),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Holiday Name (e.g. Diwali, Holi)',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(
                          selectedDate == null ? 'Select Date' : DateFormat('yyyy-MM-dd').format(selectedDate!),
                          style: const TextStyle(fontSize: 12),
                        ),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate ?? DateTime.now(),
                            firstDate: DateTime(2025),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) {
                            setD(() {
                              selectedDate = picked;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE03E2D)),
                      onPressed: () async {
                        if (nameCtrl.text.trim().isEmpty || selectedDate == null) return;
                        try {
                          await ApiClient.post('/api/hrms/holidays', {
                            'name': nameCtrl.text.trim(),
                            'holiday_date': DateFormat('yyyy-MM-dd').format(selectedDate!),
                          });
                          nameCtrl.clear();
                          // Reload
                          await _loadData();
                          setD(() {});
                        } catch (_) {}
                      },
                      child: const Text('Add', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
                const Divider(height: 24),
                const Text('Existing Holidays', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E3A5F))),
                const SizedBox(height: 8),
                Expanded(
                  child: _holidaysList.isEmpty
                      ? const Center(child: Text('No holidays defined yet', style: TextStyle(color: Colors.grey, fontSize: 12)))
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: _holidaysList.length,
                          separatorBuilder: (c, i) => const Divider(height: 1),
                          itemBuilder: (c, idx) {
                            final h = _holidaysList[idx];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(h['name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              subtitle: Text(h['holiday_date'] ?? '', style: const TextStyle(fontSize: 11)),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                onPressed: () async {
                                  try {
                                    await ApiClient.delete('/api/hrms/holidays/${h['id']}');
                                    await _loadData();
                                    setD(() {});
                                  } catch (_) {}
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close', style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }

  void _showPunchDialog(int employeeId, String dateStr, Map<String, dynamic> existingPunch) {
    String status = existingPunch['status'] ?? 'Present';
    
    // Normalize status names
    if (status.toLowerCase() == 'present') status = 'Present';
    else if (status.toLowerCase() == 'absent') status = 'Absent';
    else if (status.toLowerCase() == 'on-leave' || status.toLowerCase() == 'leave' || status.toLowerCase() == 'paid leave') status = 'Leave';
    else if (status.toLowerCase() == 'unpaid leave') status = 'Unpaid Leave';
    else if (status.toLowerCase() == 'half-day' || status.toLowerCase() == 'half day') status = 'Half Day';
    else if (status.toLowerCase() == 'weekly off' || status.toLowerCase() == 'weekly-off') status = 'Weekly Off';
    else if (status.toLowerCase() == 'holiday') status = 'Holiday';
    else status = 'Present';

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final isToday = (dateStr == todayStr);
    final bool hasPunchIn = (existingPunch['punch_in'] != null);
    final bool hasPunchOut = (existingPunch['punch_out'] != null);
    final bool isBothAdded = hasPunchIn && hasPunchOut;
    final bool isOnlyInAdded = hasPunchIn && !hasPunchOut;

    // Get leave balances
    final emp = _employeesList.firstWhere((e) => e['id'] == employeeId, orElse: () => {});
    final List<Map<String, dynamic>> leaveBalances = emp['leaveBalances'] != null
        ? List<Map<String, dynamic>>.from(emp['leaveBalances'])
        : [];
    int? selectedLeaveTypeId = existingPunch['leave_type_id'] != null
        ? int.tryParse(existingPunch['leave_type_id'].toString())
        : null;

    // Get shift details for default timings and calculations
    final defaultShiftId = emp['shift_id'] != null ? int.tryParse(emp['shift_id'].toString()) : null;
    int? selectedShiftId = defaultShiftId;

    TimeOfDay parseTimeStr(String str, TimeOfDay defaultVal) {
      try {
        final parts = str.split(':');
        if (parts.length >= 2) {
          final h = int.parse(parts[0]);
          final m = int.parse(parts[1]);
          return TimeOfDay(hour: h, minute: m);
        }
      } catch (_) {}
      return defaultVal;
    }

    Map<String, dynamic> getSelectedShift() {
      if (selectedShiftId != null) {
        final found = _shiftsList.firstWhere((s) => s['id'] == selectedShiftId, orElse: () => {});
        if (found.isNotEmpty) return found;
      }
      return emp['shift'] ?? {};
    }

    double getShiftDurationHours() {
      final activeShift = getSelectedShift();
      final startStr = activeShift['start_time']?.toString() ?? '09:00:00';
      final endStr = activeShift['end_time']?.toString() ?? '17:00:00';
      final sTime = parseTimeStr(startStr, const TimeOfDay(hour: 9, minute: 0));
      final eTime = parseTimeStr(endStr, const TimeOfDay(hour: 17, minute: 0));
      final sMins = sTime.hour * 60 + sTime.minute;
      final eMins = eTime.hour * 60 + eTime.minute;
      int diffMins = eMins - sMins;
      if (diffMins <= 0) diffMins += 1440;
      return diffMins / 60.0;
    }

    final activeShift = getSelectedShift();
    final shiftStartTimeStr = activeShift['start_time']?.toString() ?? '09:00:00';
    final shiftEndTimeStr = activeShift['end_time']?.toString() ?? '17:00:00';

    final defaultInTime = parseTimeStr(shiftStartTimeStr, const TimeOfDay(hour: 9, minute: 0));
    final defaultOutTime = parseTimeStr(shiftEndTimeStr, const TimeOfDay(hour: 17, minute: 0));

    TimeOfDay? punchInTime;
    TimeOfDay? punchOutTime;

    if (existingPunch['punch_in'] != null) {
      final dt = DateTime.tryParse(existingPunch['punch_in'].toString())?.toLocal();
      if (dt != null) punchInTime = TimeOfDay.fromDateTime(dt);
    }
    if (existingPunch['punch_out'] != null) {
      final dt = DateTime.tryParse(existingPunch['punch_out'].toString())?.toLocal();
      if (dt != null) punchOutTime = TimeOfDay.fromDateTime(dt);
    }

    punchInTime ??= defaultInTime;
    punchOutTime ??= defaultOutTime;

    final hoursWorkedCtrl = TextEditingController(text: (existingPunch['hours_worked'] ?? '8.0').toString());
    final overtimeCtrl = TextEditingController(text: (existingPunch['overtime_hours'] ?? '0.0').toString());
    final latenessCtrl = TextEditingController(text: (existingPunch['lateness_mins'] ?? '0').toString());
    final lessTimeCtrl = TextEditingController();
    String punchSource = existingPunch['punch_source'] ?? 'Manual';
    if (punchSource != 'Manual' && punchSource != 'Device' && punchSource != 'Mobile App' && punchSource != 'System') {
      punchSource = 'Manual';
    }

    int calculateLateness(TimeOfDay inTime) {
      final curShift = getSelectedShift();
      final curStartTimeStr = curShift['start_time']?.toString() ?? '09:00:00';
      final gracePeriod = int.tryParse(curShift['grace_period_mins']?.toString() ?? '15') ?? 15;
      
      final shiftParts = curStartTimeStr.split(':');
      final shiftHour = shiftParts.isNotEmpty ? (int.tryParse(shiftParts[0]) ?? 9) : 9;
      final shiftMin = shiftParts.length > 1 ? (int.tryParse(shiftParts[1]) ?? 0) : 0;

      final inMins = inTime.hour * 60 + inTime.minute;
      final shiftMins = shiftHour * 60 + shiftMin;
      final diff = inMins - shiftMins;
      return diff > gracePeriod ? diff : 0;
    }

    bool isTimeEnabled(String currentStatus) {
      return currentStatus == 'Present' || currentStatus == 'Half Day';
    }

    void runCalculations(TimeOfDay inTime, TimeOfDay outTime, StateSetter setDs, {bool isInit = false}) {
      final shiftDurationHours = getShiftDurationHours();

      if (!isTimeEnabled(status)) {
        hoursWorkedCtrl.text = '0.00';
        overtimeCtrl.text = '0.00';
        lessTimeCtrl.text = shiftDurationHours.toStringAsFixed(2);
        latenessCtrl.text = '0';
        return;
      }

      final inMins = inTime.hour * 60 + inTime.minute;
      final outMins = outTime.hour * 60 + outTime.minute;
      
      double diffHours = 0.0;
      if (outMins < inMins) {
        // Crosses midnight (night shift)
        diffHours = ((outMins + 1440) - inMins) / 60.0;
        
        if (diffHours > 22.0 && !isInit) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Out time cannot be earlier than In time!'),
              backgroundColor: Color(0xFFDC2626),
              behavior: SnackBarBehavior.floating,
            ),
          );
          setDs(() {
            punchOutTime = inTime;
          });
          return;
        }
      } else {
        diffHours = (outMins - inMins) / 60.0;
      }

      hoursWorkedCtrl.text = diffHours.toStringAsFixed(2);

      // Overtime & Less Time calculated based on active shift duration
      if (diffHours > shiftDurationHours) {
        overtimeCtrl.text = (diffHours - shiftDurationHours).toStringAsFixed(2);
        lessTimeCtrl.text = '0.00';
      } else {
        overtimeCtrl.text = '0.00';
        lessTimeCtrl.text = (shiftDurationHours - diffHours).toStringAsFixed(2);
      }

      // Auto Half Day (if worked less than half shift duration)
      if (diffHours < (shiftDurationHours / 2.0) && status == 'Present') {
        status = 'Half Day';
      }

      // Lateness
      latenessCtrl.text = calculateLateness(inTime).toString();
    }

    // Call calculations immediately on open
    runCalculations(punchInTime!, punchOutTime!, (fn) => fn(), isInit: true);

    // Initial Lateness calculation if only punch_in exists
    if (hasPunchIn && existingPunch['punch_out'] == null) {
      latenessCtrl.text = calculateLateness(punchInTime).toString();
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Log Attendance: $dateStr', style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_shiftsList.isNotEmpty) ...[
                  const Text('Shift', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF4B5563))),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    value: selectedShiftId != null && _shiftsList.any((s) => s['id'] == selectedShiftId) ? selectedShiftId : null,
                    items: _shiftsList.map((s) {
                      final name = s['name'] ?? 'Shift';
                      final start = s['start_time']?.toString().substring(0, 5) ?? '00:00';
                      final end = s['end_time']?.toString().substring(0, 5) ?? '00:00';
                      return DropdownMenuItem<int>(
                        value: s['id'] as int,
                        child: Text('$name ($start – $end)'),
                      );
                    }).toList(),
                    onChanged: isBothAdded ? null : (v) => setDs(() {
                      selectedShiftId = v;
                      final activeShift = getSelectedShift();
                      final shiftStartTimeStr = activeShift['start_time']?.toString() ?? '09:00:00';
                      final shiftEndTimeStr = activeShift['end_time']?.toString() ?? '17:00:00';

                      final defaultInTime = parseTimeStr(shiftStartTimeStr, const TimeOfDay(hour: 9, minute: 0));
                      final defaultOutTime = parseTimeStr(shiftEndTimeStr, const TimeOfDay(hour: 17, minute: 0));

                      if (!hasPunchIn) {
                        punchInTime = defaultInTime;
                      }
                      if (!hasPunchOut) {
                        punchOutTime = defaultOutTime;
                      }
                      runCalculations(punchInTime!, punchOutTime!, setDs, isInit: true);
                    }),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: isBothAdded,
                      fillColor: isBothAdded ? const Color(0xFFF3F4F6) : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                const Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF4B5563))),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: status,
                  items: const [
                    DropdownMenuItem(value: 'Present', child: Text('Present')),
                    DropdownMenuItem(value: 'Absent', child: Text('Absent')),
                    DropdownMenuItem(value: 'Leave', child: Text('Paid Leave')),
                    DropdownMenuItem(value: 'Unpaid Leave', child: Text('Unpaid Leave')),
                    DropdownMenuItem(value: 'Half Day', child: Text('Half Day')),
                    DropdownMenuItem(value: 'Weekly Off', child: Text('Weekly Off')),
                    DropdownMenuItem(value: 'Holiday', child: Text('Holiday')),
                  ],
                  onChanged: isBothAdded ? null : (v) => setDs(() {
                    status = v!;
                    runCalculations(punchInTime!, punchOutTime!, setDs);
                  }),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: isBothAdded,
                    fillColor: isBothAdded ? const Color(0xFFF3F4F6) : null,
                  ),
                ),
                 if (status == 'Leave') ...[
                  const SizedBox(height: 16),
                  const Text('Leave Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF4B5563))),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    value: selectedLeaveTypeId != null && _leaveTypesList.any((lt) => lt['id'] == selectedLeaveTypeId) ? selectedLeaveTypeId : null,
                    items: _leaveTypesList.map((lt) {
                      final ltId = lt['id'] as int;
                      final ltName = lt['name'] ?? 'Leave';
                      final bal = leaveBalances.firstWhere((b) => b['leave_type_id'] == ltId, orElse: () => {});
                      double allocated = double.tryParse(lt['annual_quota']?.toString() ?? '14') ?? 14.0;
                      double used = 0;
                      if (bal.isNotEmpty) {
                        allocated = double.tryParse(bal['allocated_quota']?.toString() ?? '0') ?? 0.0;
                        used = double.tryParse(bal['used_quota']?.toString() ?? '0') ?? 0.0;
                      }
                      final remaining = allocated - used;
                      return DropdownMenuItem<int>(
                        value: ltId,
                        child: Text('$ltName ($remaining/$allocated remaining)'),
                      );
                    }).toList(),
                    onChanged: isBothAdded ? null : (v) => setDs(() {
                      selectedLeaveTypeId = v;
                      final bal = leaveBalances.firstWhere((b) => b['leave_type_id'] == v, orElse: () => {});
                      final activeLt = _leaveTypesList.firstWhere((lt) => lt['id'] == v, orElse: () => {});
                      double allocated = double.tryParse(activeLt['annual_quota']?.toString() ?? '14') ?? 14.0;
                      double used = 0;
                      if (bal.isNotEmpty) {
                        allocated = double.tryParse(bal['allocated_quota']?.toString() ?? '0') ?? 0.0;
                        used = double.tryParse(bal['used_quota']?.toString() ?? '0') ?? 0.0;
                      }
                      final remaining = allocated - used;
                      if (remaining > 0) {
                        status = 'Leave';
                      } else {
                        status = 'Unpaid Leave';
                      }
                      runCalculations(punchInTime!, punchOutTime!, setDs);
                    }),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      hintText: 'Select Leave Type',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: status == 'Leave' ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          status == 'Leave' ? Icons.check_circle_outline : Icons.error_outline,
                          size: 14,
                          color: status == 'Leave' ? const Color(0xFF059669) : const Color(0xFFDC2626),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          status == 'Leave' ? 'Paid Leave Assigned (Quota Available)' : 'Unpaid Leave Assigned (Quota Exhausted)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: status == 'Leave' ? const Color(0xFF059669) : const Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const Text('Punch Timings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF4B5563))),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                          backgroundColor: (!isBothAdded && !isOnlyInAdded && isTimeEnabled(status)) ? null : const Color(0xFFF3F4F6),
                        ),
                        onPressed: (!isBothAdded && !isOnlyInAdded && isTimeEnabled(status)) ? () async {
                          final t = await showTimePicker(context: ctx, initialTime: punchInTime!);
                          if (t != null) {
                            setDs(() {
                              punchInTime = t;
                              runCalculations(punchInTime!, punchOutTime!, setDs);
                            });
                          }
                        } : null,
                        child: Text('In: ${punchInTime!.format(ctx)}', style: TextStyle(fontSize: 12, color: (!isBothAdded && !isOnlyInAdded && isTimeEnabled(status)) ? null : Colors.grey)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                          backgroundColor: (!isBothAdded && isTimeEnabled(status)) ? null : const Color(0xFFF3F4F6),
                        ),
                        onPressed: (!isBothAdded && isTimeEnabled(status)) ? () async {
                          final t = await showTimePicker(context: ctx, initialTime: punchOutTime!);
                          if (t != null) {
                            setDs(() {
                              punchOutTime = t;
                              runCalculations(punchInTime!, punchOutTime!, setDs);
                            });
                          }
                        } : null,
                        child: Text('Out: ${punchOutTime!.format(ctx)}', style: TextStyle(fontSize: 12, color: (!isBothAdded && isTimeEnabled(status)) ? null : Colors.grey)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: hoursWorkedCtrl,
                  keyboardType: TextInputType.number,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Hours Worked',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: const Color(0xFFF3F4F6),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: overtimeCtrl,
                  keyboardType: TextInputType.number,
                  readOnly: true,
                  style: const TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'Overtime Hours',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: const Color(0xFFF3F4F6),
                    prefixIcon: const Icon(Icons.add_circle_outline, color: Color(0xFF059669)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lessTimeCtrl,
                  keyboardType: TextInputType.number,
                  readOnly: true,
                  style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'Less Time (Shortage Hours)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: const Color(0xFFF3F4F6),
                    prefixIcon: const Icon(Icons.remove_circle_outline, color: Color(0xFFDC2626)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: latenessCtrl,
                  keyboardType: TextInputType.number,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Lateness Minutes',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: const Color(0xFFF3F4F6),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Punch Source', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF4B5563))),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: punchSource,
                  items: const [
                    DropdownMenuItem(value: 'Manual', child: Text('Manual Entry')),
                    DropdownMenuItem(value: 'Device', child: Text('Biometric / Device')),
                    DropdownMenuItem(value: 'Mobile App', child: Text('Mobile GPS App')),
                    DropdownMenuItem(value: 'System', child: Text('System Generated')),
                  ],
                  onChanged: isBothAdded ? null : (v) => setDs(() => punchSource = v!),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: isBothAdded,
                    fillColor: isBothAdded ? const Color(0xFFF3F4F6) : null,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(isBothAdded ? 'Close' : 'Cancel', style: const TextStyle(color: Color(0xFF6B7280))),
            ),
            if (!isBothAdded)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE03E2D),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  try {
                    final parts = dateStr.split('-');
                    final year = int.parse(parts[0]);
                    final month = int.parse(parts[1]);
                    final day = int.parse(parts[2]);

                    final inDt = DateTime(year, month, day, punchInTime!.hour, punchInTime!.minute);
                    final outDt = DateTime(year, month, day, punchOutTime!.hour, punchOutTime!.minute);

                    final payload = {
                      'employee_id': employeeId,
                      'punch_date': dateStr,
                      'punch_in': inDt.toIso8601String(),
                      'punch_out': outDt.toIso8601String(),
                      'status': status,
                      'hours_worked': double.tryParse(hoursWorkedCtrl.text) ?? 8.0,
                      'overtime_hours': double.tryParse(overtimeCtrl.text) ?? 0.0,
                      'lateness_mins': int.tryParse(latenessCtrl.text) ?? 0,
                      'punch_source': punchSource,
                      'leave_type_id': selectedLeaveTypeId,
                    };

                    await ApiClient.post('/api/hrms/attendance/manual', payload);
                    Navigator.pop(ctx);
                    _loadData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Attendance recorded successfully!'),
                        backgroundColor: Color(0xFF059669),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  } catch (e) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                },
                child: const Text('Save', style: TextStyle(color: Colors.white)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child, EdgeInsets? padding}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 2))],
      ),
      child: child,
    );
  }
}
