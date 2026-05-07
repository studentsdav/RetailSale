import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../models/reports/loyalty_report_model.dart';

class LoyaltyReportController extends ChangeNotifier {
  bool loading = false;
  List<LoyaltyMasterRow> rows = [];

  Future<void> load({String search = ''}) async {
    loading = true;
    notifyListeners();
    try {
      final query = search.trim().isEmpty
          ? ApiEndpoints.loyaltyMasterReport
          : '${ApiEndpoints.loyaltyMasterReport}?search=${Uri.encodeComponent(search.trim())}';
      final res = await ApiClient.get(query);
      rows = (res['data'] as List? ?? const [])
          .map((e) => LoyaltyMasterRow.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      rows = [];
    }
    loading = false;
    notifyListeners();
  }

  Future<List<LoyaltyLedgerRow>> getLedger(String customerKey) async {
    final res = await ApiClient.get(
      '${ApiEndpoints.loyaltyLedgerReport}?customer_key=${Uri.encodeComponent(customerKey)}',
    );
    return (res['data'] as List? ?? const [])
        .map((e) => LoyaltyLedgerRow.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
