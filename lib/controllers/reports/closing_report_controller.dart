import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../models/closing_item_model.dart';

class ClosingReportController extends ChangeNotifier {
  bool loading = false;
  List<ClosingItem> list = [];
  List<Map<String, dynamic>> transactions = [];

  String? fromDate;
  String? toDate;

  Future<void> load({
    DateTime? from,
    DateTime? to,
  }) async {
    loading = true;
    notifyListeners();

    final f = from?.toIso8601String().substring(0, 10);
    final t = to?.toIso8601String().substring(0, 10);

    final res = await ApiClient.get(
      '${ApiEndpoints.closingReport}?from_date=$f&to_date=$t',
    );

    fromDate = res['from_date'];
    toDate = res['to_date'];

    list = (res['data'] as List).map((e) => ClosingItem.fromJson(e)).toList();
    transactions = (res['transactions'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    loading = false;
    notifyListeners();
  }
}
