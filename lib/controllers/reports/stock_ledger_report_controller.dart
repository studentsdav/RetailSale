import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';

class StockLedgerReportController extends ChangeNotifier {
  bool loading = false;
  List<Map<String, dynamic>> transactions = [];

  String? fromDate;
  String? toDate;

  Future<void> load({
    DateTime? from,
    DateTime? to,
  }) async {
    loading = true;
    notifyListeners();

    final fromValue = from?.toIso8601String().substring(0, 10);
    final toValue = to?.toIso8601String().substring(0, 10);

    final response = await ApiClient.get(
      '${ApiEndpoints.closingReport}?from_date=$fromValue&to_date=$toValue',
    );

    fromDate = response['from_date'];
    toDate = response['to_date'];

    transactions = (response['transactions'] as List? ?? const [])
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList();

    loading = false;
    notifyListeners();
  }
}
