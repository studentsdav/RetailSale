import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';

class StockOutReportController extends ChangeNotifier {
  bool loading = false;

  List<dynamic> originalData = []; // Full DB data
  List<dynamic> data = []; // Filtered data

  double totalNet = 0;

  DateTime fromDate = DateTime.now();
  DateTime toDate = DateTime.now();

  String reportType = 'detail';

  // Local filters
  String? selectedDepartment;
  String? selectedItem;

  Future<void> load() async {
    loading = true;
    notifyListeners();

    final res = await ApiClient.get(
      '${ApiEndpoints.stockOutReport}'
      '?from_date=${DateFormat('yyyy-MM-dd').format(fromDate)}'
      '&to_date=${DateFormat('yyyy-MM-dd').format(toDate)}'
      '&type=$reportType',
    );

    originalData = res['data'];
    data = List.from(originalData);

    _calculateTotal(reportType);

    loading = false;
    notifyListeners();
  }

  void applyLocalFilter() {
    data = originalData.where((e) {
      final matchDept =
          selectedDepartment == null || e['department'] == selectedDepartment;

      final matchItem = selectedItem == null || e['item_name'] == selectedItem;

      return matchDept && matchItem;
    }).toList();

    _calculateTotal(reportType);
    notifyListeners();
  }

  void _calculateTotal(reportType) {
    totalNet = data.fold(0.0, (sum, e) {
      double amount = 0.0;
      if (reportType == "summary") {
        amount = double.tryParse(e['total_amount']?.toString() ?? "") ?? 0.0;
      } else {
        amount = double.tryParse(e['amount']?.toString() ?? "") ?? 0.0;
      }

      return sum + amount;
    });
  }

  List<String> get departments => originalData
      .map((e) => e['department']?.toString() ?? '')
      .toSet()
      .where((e) => e.isNotEmpty)
      .toList();

  List<String> get items => originalData
      .map((e) => e['item_name']?.toString() ?? '')
      .toSet()
      .where((e) => e.isNotEmpty)
      .toList();
}
