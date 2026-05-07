import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../models/reports/damage_item_model.dart';
import '../../models/reports/damage_report_model.dart';

class DamageReportController extends ChangeNotifier {
  bool loading = false;
  List<DamageItem> items = [];

  DateTime from = DateTime.now().subtract(const Duration(days: 6));
  DateTime to = DateTime.now();

  Future<void> load() async {
    loading = true;
    notifyListeners();

    final res = await ApiClient.get(
      '${ApiEndpoints.damageReport}'
      '?from=${DateFormat('yyyy-MM-dd').format(from)}'
      '&to=${DateFormat('yyyy-MM-dd').format(to)}',
    );

    items = (res['data'] as List).map((e) => DamageItem.fromJson(e)).toList();

    loading = false;
    notifyListeners();
  }

  // ---------------- KPIs ----------------

  int get totalQty => items.fold(0, (s, e) => s + e.qty.toInt());

  double get totalValue => items.fold(0, (s, e) => s + e.amount);

  int get todayQty => items
      .where((e) => DateUtils.isSameDay(e.date, DateTime.now()))
      .fold(0, (s, e) => s + e.qty.toInt());

  String get topCategory {
    if (items.isEmpty) return '-';

    final map = <String, double>{};
    for (final e in items) {
      map[e.category] = (map[e.category] ?? 0) + e.amount;
    }

    return map.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  List<CategoryDamage> get categoryData {
    final map = <String, double>{};
    for (final e in items) {
      map[e.category] = (map[e.category] ?? 0) + e.amount;
    }

    return map.entries.map((e) => CategoryDamage(e.key, e.value)).toList();
  }

  List<DailyDamage> get last7Days {
    final now = DateTime.now();

    return List.generate(7, (i) {
      final day = now.subtract(Duration(days: i));
      final total = items
          .where((e) => DateUtils.isSameDay(e.date, day))
          .fold<double>(0, (s, e) => s + e.amount);

      return DailyDamage(DateFormat('dd-MMM').format(day), total);
    }).reversed.toList();
  }

  List<DamageItem> get topItems {
    final sorted = [...items];
    sorted.sort((a, b) => b.amount.compareTo(a.amount));
    return sorted.take(5).toList();
  }
}

class DamageReportsumController extends ChangeNotifier {
  bool loading = false;

  List<DamageReportModel> data = [];

  DateTime fromDate = DateTime.now();
  DateTime toDate = DateTime.now();

  Future<void> load() async {
    loading = true;
    notifyListeners();

    final res = await ApiClient.get(
      '${ApiEndpoints.damagesumReport}'
      '?from_date=${DateFormat('yyyy-MM-dd').format(fromDate)}'
      '&to_date=${DateFormat('yyyy-MM-dd').format(toDate)}',
    );

    data = (res['data'] as List)
        .map((e) => DamageReportModel.fromJson(e))
        .toList();

    loading = false;
    notifyListeners();
  }

  double get totalNet => data.fold(
        0,
        (sum, e) => sum + e.items.fold(0, (s, i) => s + i.amount),
      );
}
