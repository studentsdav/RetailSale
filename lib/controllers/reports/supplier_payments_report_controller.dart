import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';
import '../../models/inventory/supplier_model.dart';

class SupplierPaymentsReportController extends ChangeNotifier {
  bool loading = false;
  List<Supplier> suppliers = [];
  List<Map<String, dynamic>> transactions = [];
  double totalPaid = 0.0;
  double totalCreditAdjusted = 0.0;
  int transactionCount = 0;

  Future<void> loadSuppliers() async {
    try {
      final res = await ApiClient.get(ApiEndpoints.suppliers);
      suppliers = (res['data'] as List)
          .map((e) => Supplier.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading suppliers: $e");
    }
  }

  Future<void> load({
    DateTime? from,
    DateTime? to,
    String? supplierId,
    String? paymentMode,
    String? search,
  }) async {
    loading = true;
    notifyListeners();

    try {
      final fromValue = from != null ? DateFormat('yyyy-MM-dd').format(from) : '';
      final toValue = to != null ? DateFormat('yyyy-MM-dd').format(to) : '';

      final queryParams = [
        'fromDate=$fromValue',
        'toDate=$toValue',
        'supplierId=${supplierId ?? ''}',
        'paymentMode=${paymentMode ?? ''}',
        'search=${Uri.encodeComponent(search ?? '')}',
      ].join('&');

      final response = await ApiClient.get(
        '${ApiEndpoints.supplierPaymentsReport}?$queryParams',
      );

      transactions = (response['data'] as List? ?? const [])
          .map((entry) => Map<String, dynamic>.from(entry as Map))
          .toList();

      totalPaid = (response['summary']?['totalPaid'] ?? 0.0).toDouble();
      totalCreditAdjusted = (response['summary']?['totalCreditAdjusted'] ?? 0.0).toDouble();
      transactionCount = (response['summary']?['count'] ?? 0);
    } catch (e) {
      debugPrint("Error loading supplier payments report: $e");
      transactions = [];
      totalPaid = 0.0;
      totalCreditAdjusted = 0.0;
      transactionCount = 0;
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
