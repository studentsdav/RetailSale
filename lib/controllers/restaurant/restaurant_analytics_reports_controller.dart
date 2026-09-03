import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../core/config/date_time_service.dart';
import '../../models/reports/sales_report_model.dart';

class RestaurantAnalyticsReportsController extends ChangeNotifier {
  bool loading = false;

  DateTime fromDate = DateTimeService.instance.nowInTimeZone.subtract(const Duration(days: 30));
  DateTime toDate = DateTimeService.instance.nowInTimeZone;
  String? search;

  List<SalesReport> salesList = [];
  SalesSummary summary = SalesSummary.empty;

  Future<void> init() async {
    await load();
  }

  Future<void> load() async {
    loading = true;
    notifyListeners();

    try {
      final query = '?from_date=${DateFormat("yyyy-MM-dd").format(fromDate)}'
          '&to_date=${DateFormat("yyyy-MM-dd").format(toDate)}'
          '${search != null && search!.trim().isNotEmpty ? "&search=${Uri.encodeComponent(search!.trim())}" : ""}';

      final res = await ApiClient.get('${ApiEndpoints.salesReport}$query');

      salesList = (res['data'] as List? ?? [])
          .map((e) => SalesReport.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      summary = SalesSummary.fromJson(
        Map<String, dynamic>.from(res['summary'] ?? const {}),
      );
    } catch (e, stackTrace) {
      debugPrint('Error loading restaurant analytics data: $e');
      debugPrint('Stack trace: $stackTrace');
      salesList = [];
      summary = SalesSummary.empty;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void reset() {
    fromDate = DateTimeService.instance.nowInTimeZone.subtract(const Duration(days: 30));
    toDate = DateTimeService.instance.nowInTimeZone;
    search = null;
    notifyListeners();
  }
}
