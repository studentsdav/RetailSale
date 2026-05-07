import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../models/reports/cash_ledger_model.dart';

class CashLedgerController extends ChangeNotifier {
  bool loading = false;
  List<CashLedgerEntry> entries = [];
  double openingBalance = 0;
  double totalIn = 0;
  double totalOut = 0;
  double closingBalance = 0;

  Future<void> load({
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    loading = true;
    notifyListeners();

    final res = await ApiClient.get(
      '/api/finance/ledger'
      '?from_date=${DateFormat('yyyy-MM-dd').format(fromDate)}'
      '&to_date=${DateFormat('yyyy-MM-dd').format(toDate)}',
    );

    entries =
        (res['data'] as List).map((e) => CashLedgerEntry.fromJson(e)).toList();
    openingBalance =
        double.tryParse((res['summary']?['openingBalance'] ?? 0).toString()) ??
            0;
    totalIn =
        double.tryParse((res['summary']?['totalIn'] ?? 0).toString()) ?? 0;
    totalOut =
        double.tryParse((res['summary']?['totalOut'] ?? 0).toString()) ?? 0;
    closingBalance =
        double.tryParse((res['summary']?['closingBalance'] ?? 0).toString()) ??
            0;

    loading = false;
    notifyListeners();
  }
}
