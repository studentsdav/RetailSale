import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../models/reports/stock_item_model.dart';

class StockBalanceController extends ChangeNotifier {
  bool loading = false;
  List<StockItem> items = [];

  Future<void> load() async {
    loading = true;
    notifyListeners();

    final res = await ApiClient.get(ApiEndpoints.stockBalance);

    items = (res['data'] as List).map((e) => StockItem.fromJson(e)).toList();

    loading = false;
    notifyListeners();
  }

  int get totalQty => items.fold(0, (s, e) => s + e.qty.toInt());

  double get totalValue => items.fold(0, (s, e) => s + e.value);

  int get lowStockCount => items.where((e) => e.isLow).length;

  List<CategoryStock> get categoryData {
    final map = <String, double>{};
    for (final i in items) {
      map[i.category] = (map[i.category] ?? 0) + i.value;
    }
    return map.entries.map((e) => CategoryStock(e.key, e.value)).toList();
  }

  List<StockItem> get topValueItems {
    final sorted = [...items];
    sorted.sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(5).toList();
  }
}
