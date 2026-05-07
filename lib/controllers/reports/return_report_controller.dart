import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inventory/core/api/endpoints.dart';

import '../../core/api/api_client.dart';
import '../../models/reports/return_report_model.dart';

class ReturnReportController extends ChangeNotifier {
  bool loading = false;

  DateTime fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime toDate = DateTime.now();

  String? search;

  List<ReturnReport> list = [];

  Future<void> init() async {
    await load();
  }

  Future<void> load() async {
    loading = true;
    notifyListeners();

    //  try {
    String query = "?from_date=${DateFormat('yyyy-MM-dd').format(fromDate)}"
        "&to_date=${DateFormat('yyyy-MM-dd').format(toDate)}";

    if (search != null && search!.isNotEmpty) {
      query += "&search=${Uri.encodeComponent(search!)}";
    }

    final res = await ApiClient.get('${ApiEndpoints.returnReport}$query');

    final data = res['data'] as List;

    list = data.map((e) => ReturnReport.fromJson(e)).toList();
    // } catch (e) {
    //   list = [];
    // }

    loading = false;
    notifyListeners();
  }

  void reset() {
    search = null;
    fromDate = DateTime.now().subtract(const Duration(days: 30));
    toDate = DateTime.now();
  }
}
