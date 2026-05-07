import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inventory/core/api/endpoints.dart';

import '../../core/api/api_client.dart';
import '../../models/reports/request_report_model.dart';

class RequestReportController extends ChangeNotifier {
  bool loading = false;

  DateTime fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime toDate = DateTime.now();

  String? status;
  String? approvalStatus;
  String? department;
  String? search;

  List<RequestReport> list = [];

  double grandTotal = 0;
  double totalQty = 0;

  // ================= INIT =================
  Future<void> init() async {
    await load();
  }

  // ================= LOAD REPORT =================
  Future<void> load() async {
    loading = true;
    notifyListeners();

    try {
      String query = "?from_date=${DateFormat('yyyy-MM-dd').format(fromDate)}"
          "&to_date=${DateFormat('yyyy-MM-dd').format(toDate)}";

      if (status != null && status!.isNotEmpty) {
        query += "&status=$status";
      }

      if (approvalStatus != null && approvalStatus!.isNotEmpty) {
        query += "&approval_status=$approvalStatus";
      }

      if (department != null && department!.isNotEmpty) {
        query += "&department=${Uri.encodeComponent(department!)}";
      }

      if (search != null && search!.isNotEmpty) {
        query += "&search=${Uri.encodeComponent(search!)}";
      }

      final res = await ApiClient.get('${ApiEndpoints.requestReport}$query');

      final data = res['data'] as List;

      list = data.map((e) => RequestReport.fromJson(e)).toList();

      // Calculate summary
      grandTotal = 0;
      totalQty = 0;

      for (var r in list) {
        grandTotal += r.totalAmount;
        totalQty += r.totalQty;
      }
    } catch (e) {
      list = [];
      grandTotal = 0;
      totalQty = 0;
    }

    loading = false;
    notifyListeners();
  }

  // ================= RESET =================
  void reset() {
    status = null;
    approvalStatus = null;
    department = null;
    search = null;
    fromDate = DateTime.now().subtract(const Duration(days: 30));
    toDate = DateTime.now();
    notifyListeners();
  }
}
