import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../models/inventory/item_model.dart';

class ItemAdvanceReportController extends ChangeNotifier {
  bool loading = false;
  List<Item> items = [];
  Item? selectedItem;
  DateTime fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime toDate = DateTime.now();
  Map<String, dynamic> report = const {};

  Future<void> init() async {
    await loadItems();
  }

  Future<void> loadItems() async {
    final res = await ApiClient.get(ApiEndpoints.items);
    items = (res['data'] as List? ?? const [])
        .map((e) => Item.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    notifyListeners();
  }

  Future<void> loadReport({
    required String customerName,
    required String customerPhone,
    required String customerGstin,
  }) async {
    final item = selectedItem;
    if (item == null) return;

    loading = true;
    notifyListeners();
    try {
      final res = await ApiClient.get(
        '${ApiEndpoints.sales}/item-advances/ledger'
        '?customer_name=${Uri.encodeComponent(customerName)}'
        '&customer_phone=${Uri.encodeComponent(customerPhone)}'
        '&customer_gstin=${Uri.encodeComponent(customerGstin)}'
        '&item_id=${item.id}'
        '&from_date=${Uri.encodeComponent(fromDate.toIso8601String())}'
        '&to_date=${Uri.encodeComponent(toDate.toIso8601String())}',
      );
      report = Map<String, dynamic>.from(res['data'] ?? const {});
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
