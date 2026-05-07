import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../models/reports/stock_in_model.dart';

class StockInReportController extends ChangeNotifier {
  bool loading = false;

  /// Full data from API
  List<StockInModel> originalData = [];

  /// Filtered data (after supplier/item/search filter)
  List<StockInModel> filteredData = [];

  DateTime fromDate = DateTime.now();
  DateTime toDate = DateTime.now();
  String search = '';

  // ================= LOAD FROM API =================
  Future<void> load() async {
    loading = true;
    notifyListeners();

    final res = await ApiClient.get(
      '${ApiEndpoints.stockInReport}'
      '?from_date=${DateFormat('yyyy-MM-dd').format(fromDate)}'
      '&to_date=${DateFormat('yyyy-MM-dd').format(toDate)}'
      '&search=$search',
    );

    originalData =
        (res['data'] as List).map((e) => StockInModel.fromJson(e)).toList();

    // Initially filtered data = original
    filteredData = List.from(originalData);

    loading = false;
    notifyListeners();
  }

  // ================= LOCAL FILTER =================
  void applyLocalFilter({
    String? supplier,
    String? item,
    String? search,
  }) {
    filteredData = originalData.where((e) {
      final matchSupplier = supplier == null || e.supplier == supplier;

      final matchItem = item == null || e.itemName == item;

      final matchSearch = search == null ||
          search.isEmpty ||
          e.itemName.toLowerCase().contains(search.toLowerCase()) ||
          e.supplier.toLowerCase().contains(search.toLowerCase());

      return matchSupplier && matchItem && matchSearch;
    }).toList();

    notifyListeners();
  }

  // ================= DROPDOWN DATA =================
  List<String> get suppliers =>
      originalData.map((e) => e.supplier).toSet().toList()..sort();

  List<String> get items =>
      originalData.map((e) => e.itemName).toSet().toList()..sort();

  // ================= TOTAL NET =================
  double get totalNet => filteredData.fold(
        0,
        (sum, e) => sum + e.netAmount,
      );

  // ================= GROUP BY INVOICE =================
  Map<int, List<StockInModel>> get groupFilteredByInvoice {
    final map = <int, List<StockInModel>>{};

    for (final r in filteredData) {
      map.putIfAbsent(r.inwardsNo, () => []);
      map[r.inwardsNo]!.add(r);
    }

    return map;
  }
}
