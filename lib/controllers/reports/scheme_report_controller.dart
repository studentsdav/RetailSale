import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../models/inventory/sale_scheme_model.dart';

class SchemeReportRow {
  final Map<String, dynamic> enrollment;
  final Map<String, dynamic>? progress;
  final Map<String, dynamic> advance;

  SchemeReportRow({
    required this.enrollment,
    required this.progress,
    required this.advance,
  });

  factory SchemeReportRow.fromJson(Map<String, dynamic> json) {
    return SchemeReportRow(
      enrollment: Map<String, dynamic>.from(json['enrollment'] ?? const {}),
      progress: json['progress'] == null
          ? null
          : Map<String, dynamic>.from(json['progress']),
      advance: Map<String, dynamic>.from(json['advance'] ?? const {}),
    );
  }
}

class SchemeReportController extends ChangeNotifier {
  bool loading = false;
  DateTime asOfDate = DateTime.now();
  SaleScheme? selectedScheme;
  String reportFilter = 'RUNNING';
  List<SaleScheme> schemes = [];
  List<SchemeReportRow> rows = [];

  Future<void> init() async {
    await loadSchemes();
  }

  Future<void> loadSchemes() async {
    final res = await ApiClient.get(ApiEndpoints.salesSchemes);
    schemes = (res['data'] as List? ?? const [])
        .map((e) => SaleScheme.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    notifyListeners();
  }

  Future<void> loadReport() async {
    final scheme = selectedScheme;
    if (scheme == null) return;

    loading = true;
    notifyListeners();
    try {
      final res = await ApiClient.get(
        '${ApiEndpoints.schemeReport}'
        '?scheme_id=${scheme.id}'
        '&date=${Uri.encodeComponent(asOfDate.toIso8601String())}'
        '&report_filter=${Uri.encodeComponent(reportFilter)}',
      );
      final data = Map<String, dynamic>.from(res['data'] ?? const {});
      rows = (data['rows'] as List? ?? const [])
          .map((e) => SchemeReportRow.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> loadItemAdvanceLedger({
    required String customerName,
    required String customerPhone,
    required String customerGstin,
    required int itemId,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    final res = await ApiClient.get(
      '${ApiEndpoints.sales}/item-advances/ledger'
      '?customer_name=${Uri.encodeComponent(customerName)}'
      '&customer_phone=${Uri.encodeComponent(customerPhone)}'
      '&customer_gstin=${Uri.encodeComponent(customerGstin)}'
      '&item_id=$itemId'
      '&from_date=${Uri.encodeComponent(fromDate.toIso8601String())}'
      '&to_date=${Uri.encodeComponent(toDate.toIso8601String())}',
    );
    return Map<String, dynamic>.from(res['data'] ?? const {});
  }

  Future<Map<String, dynamic>> loadCycleDetail({
    required dynamic enrollmentId,
    required String customerName,
    required String customerPhone,
    required String customerGstin,
    required DateTime date,
  }) async {
    final scheme = selectedScheme;
    if (scheme == null) return const {};
    final res = await ApiClient.get(
      '${ApiEndpoints.schemeCycleDetail}'
      '?scheme_id=${scheme.id}'
      '&enrollment_id=${Uri.encodeComponent((enrollmentId ?? '').toString())}'
      '&customer_name=${Uri.encodeComponent(customerName)}'
      '&customer_phone=${Uri.encodeComponent(customerPhone)}'
      '&customer_gstin=${Uri.encodeComponent(customerGstin)}'
      '&date=${Uri.encodeComponent(date.toIso8601String())}',
    );
    return Map<String, dynamic>.from(res['data'] ?? const {});
  }

  Future<Map<String, dynamic>> loadSaleDetails(int saleId) async {
    final res = await ApiClient.get('${ApiEndpoints.sales}/$saleId');
    return Map<String, dynamic>.from(res['data'] ?? const {});
  }
}
