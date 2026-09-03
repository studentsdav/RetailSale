import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/config/date_time_service.dart';

class StockTransferReportController extends ChangeNotifier {
  bool loading = false;
  List<Map<String, dynamic>> transfers = [];

  DateTime fromDate = DateTimeService.instance.nowInTimeZone;
  DateTime toDate = DateTimeService.instance.nowInTimeZone;
  String search = '';

  Future<void> load() async {
    loading = true;
    notifyListeners();

    final response = await ApiClient.get(
      '${ApiEndpoints.stockTransferReport}'
      '?from_date=${DateFormat('yyyy-MM-dd').format(fromDate)}'
      '&to_date=${DateFormat('yyyy-MM-dd').format(toDate)}'
      '&search=${Uri.encodeComponent(search)}',
    );

    transfers = (response['data'] as List? ?? const [])
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList();

    loading = false;
    notifyListeners();
  }

  double get totalPackCount => transfers.fold<double>(
        0,
        (sum, row) => sum + (double.tryParse('${row['pack_count'] ?? 0}') ?? 0),
      );

  double get totalLooseQty => transfers.fold<double>(
        0,
        (sum, row) => sum + (double.tryParse('${row['loose_qty'] ?? 0}') ?? 0),
      );
}
