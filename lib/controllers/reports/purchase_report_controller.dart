import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:retailpos/models/reports/purchase_report_model.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../models/inventory/supplier_model.dart';

class PurchaseReportController extends ChangeNotifier {
  bool loading = false;

  DateTime fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime toDate = DateTime.now();

  int? supplierId;
  String? status;
  String? search;

  List<PurchaseOrderReport> list = [];

  double totalAmount = 0;
  int totalOrders = 0;

  List<Supplier> suppliers = [];

  // ================= INIT =================
  Future<void> init() async {
    await loadSuppliers();
    await load();
  }

  // ================= LOAD SUPPLIERS =================
  Future<void> loadSuppliers() async {
    final res = await ApiClient.get(ApiEndpoints.suppliers);

    final data = res['data'] as List;

    suppliers = data.map((e) => Supplier.fromJson(e)).toList();

    notifyListeners();
  }

  // ================= LOAD REPORT =================
  Future<void> load() async {
    loading = true;
    notifyListeners();

    // try {
    // Build query string manually
    String query = "?from_date=${DateFormat('yyyy-MM-dd').format(fromDate)}"
        "&to_date=${DateFormat('yyyy-MM-dd').format(toDate)}";

    if (supplierId != null) {
      query += "&supplier_id=$supplierId";
    }

    if (status != null && status!.isNotEmpty) {
      query += "&status=$status";
    }

    if (search != null && search!.isNotEmpty) {
      query += "&search=${Uri.encodeComponent(search!)}";
    }

    final res = await ApiClient.get("${ApiEndpoints.purReport}$query");

    final data = res['data'] as List;

    list = data.map((e) => PurchaseOrderReport.fromJson(e)).toList();

    totalOrders = list.length;

    totalAmount = list.fold(
      0,
      (sum, e) => sum + e.totalAmount,
    );
    // } catch (e) {

    //   list = [];
    //   totalOrders = 0;
    //   totalAmount = 0;
    // }

    loading = false;
    notifyListeners();
  }

  // ================= RESET =================
  void reset() {
    supplierId = null;
    status = null;
    search = null;
    fromDate = DateTime.now().subtract(const Duration(days: 30));
    toDate = DateTime.now();
    notifyListeners();
  }

  Future<Map<String, dynamic>> loadPoDetails(int poId) async {
    final res = await ApiClient.get('/api/purchase-orders/$poId/details');
    return Map<String, dynamic>.from(res['data'] ?? const {});
  }
}

