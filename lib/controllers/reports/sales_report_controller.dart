import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../models/reports/sales_report_model.dart';

class SalesReportController extends ChangeNotifier {
  bool loading = false;

  DateTime fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime toDate = DateTime.now();
  String? paymentMode;
  String? search;

  List<SalesReport> list = [];
  SalesSummary summary = SalesSummary.empty;
  List<SalesBreakdownEntry> paymentModes = [];
  List<SalesBreakdownEntry> timeZones = [];
  List<SalesHeatmapRow> heatmapRows = [];
  List<SalesTaxSummary> taxSummary = [];
  List<SalesComparisonPoint> monthOnMonth = [];
  List<SalesComparisonPoint> weekOnWeek = [];
  List<SalesComparisonPoint> dayOnDay = [];
  SalesBreakdownEntry? highestZone;
  SalesBreakdownEntry? lowestZone;

  double get totalQty => summary.totalQty;
  double get totalSales => summary.totalRevenue;
  double get totalDiscount => summary.totalDiscount;

  Future<void> init() async {
    await load();
  }

  Future<void> load() async {
    loading = true;
    notifyListeners();

    try {
      var query = '?from_date=${DateFormat('yyyy-MM-dd').format(fromDate)}'
          '&to_date=${DateFormat('yyyy-MM-dd').format(toDate)}';

      if (paymentMode != null && paymentMode!.isNotEmpty) {
        query += '&payment_mode=$paymentMode';
      }

      if (search != null && search!.trim().isNotEmpty) {
        query += '&search=${Uri.encodeComponent(search!.trim())}';
      }

      final res = await ApiClient.get('${ApiEndpoints.salesReport}$query');
      list = (res['data'] as List)
          .map((e) => SalesReport.fromJson(e))
          .toList();
      summary = SalesSummary.fromJson(
        Map<String, dynamic>.from(res['summary'] ?? const {}),
      );
      paymentModes = (res['payment_mode_breakdown'] as List? ?? [])
          .map((e) => SalesBreakdownEntry.fromJson(
                Map<String, dynamic>.from(e),
                keyField: 'payment_mode',
                labelField: 'payment_mode',
              ))
          .toList();
      timeZones = (res['time_zone_breakdown'] as List? ?? [])
          .map((e) => SalesBreakdownEntry.fromJson(
                Map<String, dynamic>.from(e),
                keyField: 'zone',
                labelField: 'label',
                amountField: 'total_sales',
              ))
          .toList();
      heatmapRows = (((res['heatmaps'] ?? const {})['item_zone_sales']) as List? ??
              [])
          .map((e) => SalesHeatmapRow.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      taxSummary = (res['tax_summary'] as List? ?? [])
          .map((e) => SalesTaxSummary.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      final insights = Map<String, dynamic>.from(res['insights'] ?? const {});
      final highest = insights['highest_sale_zone'];
      final lowest = insights['lowest_sale_zone'];
      highestZone = highest == null
          ? null
          : SalesBreakdownEntry.fromJson(
              Map<String, dynamic>.from(highest),
              keyField: 'zone',
              labelField: 'label',
              amountField: 'total_sales',
            );
      lowestZone = lowest == null
          ? null
          : SalesBreakdownEntry.fromJson(
              Map<String, dynamic>.from(lowest),
              keyField: 'zone',
              labelField: 'label',
              amountField: 'total_sales',
            );

      final comparisons = Map<String, dynamic>.from(res['comparisons'] ?? const {});
      monthOnMonth = (comparisons['month_on_month'] as List? ?? [])
          .map((e) =>
              SalesComparisonPoint.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      weekOnWeek = (comparisons['week_on_week'] as List? ?? [])
          .map((e) =>
              SalesComparisonPoint.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      dayOnDay = (comparisons['day_on_day'] as List? ?? [])
          .map((e) =>
              SalesComparisonPoint.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      list = [];
      summary = SalesSummary.empty;
      paymentModes = [];
      timeZones = [];
      heatmapRows = [];
      taxSummary = [];
      monthOnMonth = [];
      weekOnWeek = [];
      dayOnDay = [];
      highestZone = null;
      lowestZone = null;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void reset() {
    fromDate = DateTime.now().subtract(const Duration(days: 30));
    toDate = DateTime.now();
    paymentMode = null;
    search = null;
    notifyListeners();
  }
}
