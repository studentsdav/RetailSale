import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';

class HrmsController extends ChangeNotifier {
  // State fields
  bool loading = false;
  String? error;

  // Masters data
  List<Map<String, dynamic>> employees = [];
  List<Map<String, dynamic>> shifts = [];
  List<Map<String, dynamic>> leaveTypes = [];
  List<Map<String, dynamic>> designations = [];
  List<Map<String, dynamic>> payStructures = [];
  List<Map<String, dynamic>> salaryComponents = [];

  // Attendance data
  List<Map<String, dynamic>> attendanceRecords = [];

  // Leave data
  List<Map<String, dynamic>> leaveApplications = [];

  // Loan data
  List<Map<String, dynamic>> loans = [];

  // Payroll data
  List<Map<String, dynamic>> payrollPreview = [];
  Map<String, dynamic>? currentPayrollRun;

  // Handover data
  List<Map<String, dynamic>> handovers = [];

  void _setLoading(bool val) {
    loading = val;
    notifyListeners();
  }

  void _setError(dynamic e) {
    error = e.toString();
    notifyListeners();
  }

  // ==================== MASTERS ====================

  Future<void> loadEmployees() async {
    try {
      _setLoading(true);
      final res = await ApiClient.get(ApiEndpoints.hrmsEmployees);
      employees = List<Map<String, dynamic>>.from(res['data'] ?? []);
    } catch (e) {
      _setError(e);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadShifts() async {
    try {
      _setLoading(true);
      final res = await ApiClient.get(ApiEndpoints.hrmsShifts);
      shifts = List<Map<String, dynamic>>.from(res['data'] ?? []);
    } catch (e) {
      _setError(e);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadLeaveTypes() async {
    try {
      _setLoading(true);
      final res = await ApiClient.get(ApiEndpoints.hrmsLeaveTypes);
      leaveTypes = List<Map<String, dynamic>>.from(res['data'] ?? []);
    } catch (e) {
      _setError(e);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadDesignations() async {
    try {
      _setLoading(true);
      final res = await ApiClient.get(ApiEndpoints.hrmsDesignations);
      designations = List<Map<String, dynamic>>.from(res['data'] ?? []);
    } catch (e) {
      _setError(e);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadSalaryComponents() async {
    try {
      _setLoading(true);
      final res = await ApiClient.get(ApiEndpoints.hrmsSalaryComponents);
      salaryComponents = List<Map<String, dynamic>>.from(res['data'] ?? []);
    } catch (e) {
      _setError(e);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadPayStructures() async {
    try {
      _setLoading(true);
      final res = await ApiClient.get(ApiEndpoints.hrmsPayStructures);
      payStructures = List<Map<String, dynamic>>.from(res['data'] ?? []);
    } catch (e) {
      _setError(e);
    } finally {
      _setLoading(false);
    }
  }

  // ==================== EMPLOYEES ====================

  Future<Map<String, dynamic>> createEmployee(Map<String, dynamic> data) async {
    try {
      _setLoading(true);
      // ApiClient.post takes positional body argument
      final res = await ApiClient.post(ApiEndpoints.hrmsEmployees, data);
      await loadEmployees();
      return res as Map<String, dynamic>;
    } catch (e) {
      _setError(e);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateEmployee(int id, Map<String, dynamic> data) async {
    try {
      _setLoading(true);
      await ApiClient.put('${ApiEndpoints.hrmsEmployees}/$id', data);
      await loadEmployees();
    } catch (e) {
      _setError(e);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> terminateEmployee(int id, Map<String, dynamic> data) async {
    try {
      _setLoading(true);
      await ApiClient.post('${ApiEndpoints.hrmsEmployees}/$id/terminate', data);
      await loadEmployees();
    } catch (e) {
      _setError(e);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // ==================== ATTENDANCE ====================

  Future<void> loadAttendance(int employeeId, String month) async {
    try {
      _setLoading(true);
      final res = await ApiClient.get(
          '${ApiEndpoints.hrmsAttendance}?employee_id=$employeeId&month=$month');
      attendanceRecords = List<Map<String, dynamic>>.from(res['data'] ?? []);
    } catch (e) {
      _setError(e);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> punchIn(int employeeId) async {
    try {
      _setLoading(true);
      await ApiClient.post('${ApiEndpoints.hrmsAttendance}/punch-in',
          {'employee_id': employeeId});
    } catch (e) {
      _setError(e);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> punchOut(int employeeId) async {
    try {
      _setLoading(true);
      await ApiClient.post('${ApiEndpoints.hrmsAttendance}/punch-out',
          {'employee_id': employeeId});
    } catch (e) {
      _setError(e);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> manualAttendance(Map<String, dynamic> data) async {
    try {
      _setLoading(true);
      await ApiClient.post('${ApiEndpoints.hrmsAttendance}/manual', data);
    } catch (e) {
      _setError(e);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // ==================== LEAVES ====================

  Future<void> loadLeaves({int? employeeId, String? status}) async {
    try {
      _setLoading(true);
      String query = '';
      if (employeeId != null) query += 'employee_id=$employeeId&';
      if (status != null) query += 'status=$status';
      final res = await ApiClient.get('${ApiEndpoints.hrmsLeaves}?$query');
      leaveApplications = List<Map<String, dynamic>>.from(res['data'] ?? []);
    } catch (e) {
      _setError(e);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> applyLeave(Map<String, dynamic> data) async {
    try {
      _setLoading(true);
      await ApiClient.post(ApiEndpoints.hrmsLeaves, data);
      await loadLeaves();
    } catch (e) {
      _setError(e);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> approveLeave(int leaveId) async {
    try {
      _setLoading(true);
      // put requires a body — pass empty map
      await ApiClient.put('${ApiEndpoints.hrmsLeaves}/$leaveId/approve', {});
      await loadLeaves();
    } catch (e) {
      _setError(e);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> rejectLeave(int leaveId) async {
    try {
      _setLoading(true);
      await ApiClient.put('${ApiEndpoints.hrmsLeaves}/$leaveId/reject', {});
      await loadLeaves();
    } catch (e) {
      _setError(e);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // ==================== LOANS ====================

  Future<void> loadLoans({int? employeeId}) async {
    try {
      _setLoading(true);
      final query = employeeId != null ? '?employee_id=$employeeId' : '';
      final res = await ApiClient.get('${ApiEndpoints.hrmsLoans}$query');
      loans = List<Map<String, dynamic>>.from(res['data'] ?? []);
    } catch (e) {
      _setError(e);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> createLoan(Map<String, dynamic> data) async {
    try {
      _setLoading(true);
      await ApiClient.post(ApiEndpoints.hrmsLoans, data);
      await loadLoans();
    } catch (e) {
      _setError(e);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // ==================== PAYROLL ====================

  Future<void> previewPayroll(String payPeriod) async {
    try {
      _setLoading(true);
      final res = await ApiClient.post(
          '${ApiEndpoints.hrmsPayroll}/preview', {'pay_period': payPeriod});
      payrollPreview = List<Map<String, dynamic>>.from(res['data'] ?? []);
    } catch (e) {
      _setError(e);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> runPayroll(String payPeriod) async {
    try {
      _setLoading(true);
      final res = await ApiClient.post(
          '${ApiEndpoints.hrmsPayroll}/run', {'pay_period': payPeriod});
      currentPayrollRun = res['data'] as Map<String, dynamic>?;
    } catch (e) {
      _setError(e);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> approvePayroll(int payrollRunId) async {
    try {
      _setLoading(true);
      await ApiClient.post(
          '${ApiEndpoints.hrmsPayroll}/$payrollRunId/approve', {});
    } catch (e) {
      _setError(e);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // ==================== CASHIER HANDOVER ====================

  Future<void> createHandover(Map<String, dynamic> data) async {
    try {
      _setLoading(true);
      await ApiClient.post(ApiEndpoints.hrmsHandover, data);
    } catch (e) {
      _setError(e);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadHandovers({int? cashierId}) async {
    try {
      _setLoading(true);
      final query = cashierId != null ? '?cashier_id=$cashierId' : '';
      final res = await ApiClient.get('${ApiEndpoints.hrmsHandovers}$query');
      handovers = List<Map<String, dynamic>>.from(res['data'] ?? []);
    } catch (e) {
      _setError(e);
    } finally {
      _setLoading(false);
    }
  }
}
